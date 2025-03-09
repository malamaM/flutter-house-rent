import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_rent/screens/home/home.dart';
import 'package:house_rent/screens/login/login.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAccessToken(context);
  }

  Future<void> _checkAccessToken(BuildContext context) async {
    await Future.delayed(const Duration(seconds: 4));
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    if (accessToken != null) {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/check-login-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Home()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => SignInScreen()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => SignInScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Image.network("https://i.postimg.cc/Qtxc8xgv/welcome-image.png"),
              const Spacer(flex: 3),
              Text(
                "Welcome to our freedom \nmessaging app",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                "Freedom talk any person of your \nmother language.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .color!
                      .withOpacity(0.64),
                ),
              ),
              const Spacer(flex: 3),
              CircularProgressIndicator(), // Add this line for the loader
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}