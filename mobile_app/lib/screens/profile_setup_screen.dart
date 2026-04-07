import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nicknameController = TextEditingController();

  int _selectedAge = 18;

  /// ✅ value chuẩn (không dùng tiếng Việt)
  String _selectedGender = 'other';

  String _avatarUrl = '';
  bool _isLoading = false;

  /// mapping value ↔ label
  final List<Map<String, String>> genders = [
    {'value': 'male', 'label': 'Nam'},
    {'value': 'female', 'label': 'Nữ'},
    {'value': 'other', 'label': 'Khác'},
  ];

  @override
  void initState() {
    super.initState();
    _generateRandomAvatar();
  }

  void _generateRandomAvatar() {
    final seed = Random().nextInt(1000000);
    setState(() {
      _avatarUrl =
          'https://api.dicebear.com/7.x/pixel-art/svg?seed=$seed';
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;

      /// ✅ file name unique hơn
      final fileName =
          '${user.id}_${DateTime.now().microsecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('images').uploadBinary(fileName, bytes);

      final publicUrl =
          supabase.storage.from('images').getPublicUrl(fileName);

      setState(() {
        _avatarUrl = publicUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a nickname')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('profiles').upsert({
        'id': user.id,
        'nickname': _nicknameController.text.trim(),
        'age': _selectedAge,
        'gender': _selectedGender, /// ✅ lưu value chuẩn
        'avatar_url': _avatarUrl,
      });

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  String _getGenderLabel(String value) {
    return genders.firstWhere((g) => g['value'] == value)['label']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết lập Hồ sơ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _avatarUrl.isNotEmpty
                    ? NetworkImage(_avatarUrl)
                    : null,
                child: _avatarUrl.isEmpty
                    ? const Icon(Icons.person,
                        size: 60, color: Colors.grey)
                    : null,
              ),
            ),

            TextButton(
              onPressed: _generateRandomAvatar,
              child: const Text('Tạo Avatar ngẫu nhiên'),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Biệt danh',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                const Text('Tuổi:', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _selectedAge.toDouble(),
                    min: 13,
                    max: 100,
                    divisions: 87,
                    label: _selectedAge.toString(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAge = value.toInt();
                      });
                    },
                  ),
                ),
                Text(
                  _selectedAge.toString(),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// ✅ Dropdown đã fix 100%
            DropdownButtonFormField<String>(
              value: _selectedGender.toLowerCase(),
              decoration: const InputDecoration(
                labelText: 'Giới tính',
                border: OutlineInputBorder(),
              ),
              items: genders.map((g) {
                return DropdownMenuItem(
                  value: g['value'],
                  child: Text(g['label']!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGender = value!;
                });
              },
            ),

            const SizedBox(height: 32),

            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.deepPurple,
                    ),
                    child: const Text(
                      'Lưu & Tiếp tục',
                      style:
                          TextStyle(color: Colors.white),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}   