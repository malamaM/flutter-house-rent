import 'package:flutter/material.dart';
import 'package:house_rent/screens/home/home.dart';
import 'package:house_rent/screens/login/login.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _continue();
  }

  Future<void> _continue() async {
    await Future.delayed(const Duration(milliseconds: 1300));
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    var authenticated = false;
    if (token != null) {
      try {
        final response = await http.get(
          Uri.parse('http://localhost:8000/api/check-login-status'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token'
          },
        ).timeout(const Duration(seconds: 5));
        authenticated = response.statusCode == 200;
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            authenticated ? const Home() : const SignInScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        children: [
          Positioned(
            right: -90,
            top: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(.35)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.roofing_rounded,
                        color: AppColors.primary, size: 36),
                  ),
                  const SizedBox(height: 24),
                  const Text('HAVEN',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 36,
                          letterSpacing: 3)),
                  const SizedBox(height: 8),
                  const Text('Find where you belong.',
                      style: TextStyle(color: Colors.white70, fontSize: 17)),
                  const Spacer(),
                  const LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.white12,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
