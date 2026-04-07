import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'chat_screen.dart';

class MatchingScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String mode;
  final Map<String, dynamic> filters;

  const MatchingScreen({
    super.key,
    required this.profile,
    required this.mode,
    required this.filters,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> with SingleTickerProviderStateMixin {
  late io.Socket socket;
  late AnimationController _controller;
  bool _isSearching = true;

  @override
  void initState() {
    super.initState();
    _initSocket();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  void _initSocket() {
    // Ưu tiên dùng URL từ lệnh build (flutter build web --dart-define=API_URL=https://...)
    // Nếu không có, mặc định dùng localhost (cho Web) hoặc 10.0.2.2 (cho Android Emulator)
    const String envUrl = String.fromEnvironment('API_URL');
    String serverUrl = envUrl.isNotEmpty 
        ? envUrl 
        : (kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000');
    
    socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('Connected to Socket.io server');
      socket.emit('find_partner', {
        'profile': widget.profile,
        'filters': widget.filters,
        'mode': widget.mode,
      });
    });

    socket.on('partner_found', (data) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            socket: socket,
            partnerProfile: data['partner'],
            myProfile: widget.profile,
          ),
        ),
      );
    });

    socket.onDisconnect((_) => print('Disconnected from Socket.io server'));
    socket.onError((error) => print('Socket Error: $error'));
  }

  @override
  void dispose() {
    _controller.dispose();
    // Do not dispose socket here if we are moving to ChatScreen, 
    // unless you handle reconnection in ChatScreen. 
    // Usually, we pass the socket to the next screen.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đang tìm kiếm...')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Container(
                      width: 200 * _controller.value,
                      height: 200 * _controller.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.deepPurple.withOpacity(1 - _controller.value),
                      ),
                    );
                  },
                ),
                CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(widget.profile['avatar_url'] ?? ''),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text(
              'Đang tìm một người lạ...',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Chế độ: ${widget.mode} | Bộ lọc: ${widget.filters['gender'] ?? 'Bất kỳ'}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 64),
            OutlinedButton(
              onPressed: () {
                socket.emit('end');
                socket.disconnect();
                Navigator.of(context).pop();
              },
              child: const Text('Hủy'),
            ),
          ],
        ),
      ),
    );
  }
}
