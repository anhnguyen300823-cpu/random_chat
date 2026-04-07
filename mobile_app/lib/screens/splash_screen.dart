import 'package:flutter/material.dart';
import '../main.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Thêm một chút delay cho hiệu ứng thị giác
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) return;

    var session = supabase.auth.currentSession;
    
    // Nếu chưa có phiên đăng nhập, thực hiện Đăng nhập ẩn danh tự động
    if (session == null) {
      try {
        final res = await supabase.auth.signInAnonymously();
        session = res.session;
      } catch (e) {
        debugPrint("Lỗi đăng nhập ẩn danh: $e");
      }
    }

    if (session == null) {
      // Nếu vẫn lỗi, thử lại sau hoặc báo lỗi (hiếm khi xảy ra)
      return;
    }

    try {
      // Kiểm tra xem người dùng đã có profile chưa
      final user = session.user;
      final profileData = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (profileData == null) {
        // Chưa có profile, chuyển sang màn hình Thiết lập Hồ sơ
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      } else {
        // Đã có profile, chuyển thẳng vào Trang chủ
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      debugPrint("Lỗi kiểm tra hồ sơ: $e");
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Random Chat',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
