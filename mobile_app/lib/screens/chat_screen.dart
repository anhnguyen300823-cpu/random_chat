import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../main.dart';
import 'matching_screen.dart';

class ChatScreen extends StatefulWidget {
  final io.Socket socket;
  final Map<String, dynamic> partnerProfile;
  final Map<String, dynamic> myProfile;

  const ChatScreen({
    super.key,
    required this.socket,
    required this.partnerProfile,
    required this.myProfile,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  
  bool _isPartnerTyping = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    widget.socket.on('receive_message', (data) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'isMe': false,
          'type': data['type'],
          'content': data['content'],
          'timestamp': DateTime.now(),
        });
      });
      _scrollToBottom();
    });

    widget.socket.on('typing', (data) {
      if (!mounted) return;
      setState(() => _isPartnerTyping = data['isTyping']);
    });

    widget.socket.on('partner_left', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Người lạ đã rời khỏi cuộc trò chuyện.')),
      );
      Navigator.of(context).pop();
    });
  }

  void _sendMessage(String type, dynamic content) {
    if (content == null || (content is String && content.trim().isEmpty)) return;

    final messageData = {
      'type': type,
      'content': content,
    };

    widget.socket.emit('send_message', messageData);
    
    setState(() {
      _messages.add({
        'isMe': true,
        'type': type,
        'content': content,
        'timestamp': DateTime.now(),
      });
      _messageController.clear();
    });
    _scrollToBottom();
    widget.socket.emit('typing', {'isTyping': false});
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('images').uploadBinary(fileName, bytes);
      final url = supabase.storage.from('images').getPublicUrl(fileName);
      _sendMessage('image', url);
    } catch (e) {
      debugPrint("Upload error: $e");
    }
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      setState(() => _isRecording = true);
      await _recorder.start(const RecordConfig(), path: 'voice.m4a');
    }
  }

  Future<void> _stopAndUploadRecording() async {
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path == null) return;

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      await supabase.storage.from('voices').uploadBinary(fileName, bytes);
      final url = supabase.storage.from('voices').getPublicUrl(fileName);
      _sendMessage('voice', url);
    } catch (e) {
      debugPrint("Voice upload error: $e");
    }
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: 8,
          itemBuilder: (context, index) {
            final stickerUrl = 'https://api.dicebear.com/7.x/bottts/png?seed=sticker$index';
            return GestureDetector(
              onTap: () {
                _sendMessage('sticker', stickerUrl);
                Navigator.pop(context);
              },
              child: Image.network(stickerUrl),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(widget.partnerProfile['avatar_url'] ?? ''),
            ),
            const SizedBox(width: 8),
            Text(widget.partnerProfile['nickname'] ?? 'Người lạ'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.socket.emit('next');
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => MatchingScreen(
                    profile: widget.myProfile,
                    mode: 'Text',
                    filters: const {},
                  ),
                ),
              );
            },
            child: const Text('Tiếp', style: TextStyle(color: Colors.deepPurple)),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              widget.socket.emit('end');
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _ChatBubble(msg: msg);
              },
            ),
          ),
          if (_isPartnerTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Người lạ đang gõ...', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.image), onPressed: _pickAndUploadImage),
          IconButton(icon: const Icon(Icons.emoji_emotions), onPressed: _showStickerPicker),
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: (val) {
                widget.socket.emit('typing', {'isTyping': val.isNotEmpty});
              },
              decoration: const InputDecoration(
                hintText: 'Nhập tin nhắn...',
                border: InputBorder.none,
              ),
              onSubmitted: (val) => _sendMessage('text', val),
            ),
          ),
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopAndUploadRecording(),
            child: Icon(
              Icons.mic,
              color: _isRecording ? Colors.red : Colors.grey,
              size: 30,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.deepPurple),
            onPressed: () => _sendMessage('text', _messageController.text),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> msg;

  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final bool isMe = msg['isMe'];
    final String type = msg['type'];
    final dynamic content = msg['content'];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepPurple : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
        ),
        child: _buildMessageContent(type, content, isMe),
      ),
    );
  }

  Widget _buildMessageContent(String type, dynamic content, bool isMe) {
    final Color textColor = isMe ? Colors.white : Colors.black87;

    switch (type) {
      case 'image':
        return Image.network(content, width: 200, height: 200, fit: BoxFit.cover);
      case 'sticker':
        return Image.network(content, width: 100, height: 100);
      case 'voice':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, color: textColor),
            const SizedBox(width: 8),
            Text('Tin nhắn thoại', style: TextStyle(color: textColor)),
          ],
        );
      case 'text':
      default:
        return Text(
          content,
          style: TextStyle(color: textColor, fontSize: 16),
        );
    }
  }
}
