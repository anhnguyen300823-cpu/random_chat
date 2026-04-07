import 'package:flutter/material.dart';
import '../main.dart';
import 'matching_screen.dart';
import 'profile_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedMode = 'text';

  /// dùng value chuẩn (không dùng tiếng Việt)
  String _filterGender = 'any';

  int _filterMinAge = 18;
  int _filterMaxAge = 40;

  Map<String, dynamic>? _userProfile;

  /// mapping value + label
  final List<Map<String, String>> genders = [
    {'value': 'any', 'label': 'Bất kỳ'},
    {'value': 'male', 'label': 'Nam'},
    {'value': 'female', 'label': 'Nữ'},
    {'value': 'other', 'label': 'Khác'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      setState(() {
        _userProfile = data;
      });
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  String _getGenderLabel(String value) {
    return genders.firstWhere((g) => g['value'] == value)['label']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Random Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Thiết lập hồ sơ',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_userProfile != null) ...[
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: _userProfile!['avatar_url'] != null &&
                              _userProfile!['avatar_url']
                                  .toString()
                                  .isNotEmpty
                          ? NetworkImage(_userProfile!['avatar_url'])
                          : null,
                      child: (_userProfile!['avatar_url'] == null ||
                              _userProfile!['avatar_url']
                                  .toString()
                                  .isEmpty)
                          ? const Icon(Icons.person, size: 40)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chào mừng, ${_userProfile!['nickname'] ?? 'User'}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(height: 48),
            ],

            const Text('Chọn Chế độ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    icon: Icons.text_fields,
                    label: 'Text',
                    isSelected: _selectedMode == 'text',
                    onTap: () => setState(() => _selectedMode = 'text'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ModeCard(
                    icon: Icons.videocam,
                    label: 'Video',
                    isSelected: _selectedMode == 'video',
                    onTap: () => setState(() => _selectedMode = 'video'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            const Text('Bộ lọc',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            /// ✅ Dropdown đã fix hoàn toàn
            DropdownButtonFormField<String>(
              value: _filterGender.toLowerCase(),
              decoration: const InputDecoration(
                labelText: 'Ưu tiên Giới tính',
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
                  _filterGender = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            const Text('Độ tuổi', style: TextStyle(fontSize: 16)),

            RangeSlider(
              values: RangeValues(
                _filterMinAge.toDouble(),
                _filterMaxAge.toDouble(),
              ),
              min: 13,
              max: 100,
              divisions: 87,
              labels: RangeLabels(
                _filterMinAge.toString(),
                _filterMaxAge.toString(),
              ),
              onChanged: (values) {
                setState(() {
                  _filterMinAge = values.start.toInt();
                  _filterMaxAge = values.end.toInt();
                });
              },
            ),

            const SizedBox(height: 48),

            ElevatedButton(
              onPressed: () {
                if (_userProfile == null) return;

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MatchingScreen(
                      profile: _userProfile!,
                      mode: _selectedMode,
                      filters: {
                        'gender': _filterGender == 'any'
                            ? null
                            : _filterGender,
                        'minAge': _filterMinAge,
                        'maxAge': _filterMaxAge,
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedMode == 'text'
                    ? Colors.deepPurple
                    : Colors.blueGrey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Bắt đầu Tìm kiếm!',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? Colors.deepPurple : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.deepPurple : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}