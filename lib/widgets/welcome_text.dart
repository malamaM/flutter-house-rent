import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeText extends StatefulWidget {
  const WelcomeText({Key? key}) : super(key: key);

  @override
  State<WelcomeText> createState() => _WelcomeTextState();
}

class _WelcomeTextState extends State<WelcomeText> {
  String firstName = 'there';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return;
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/check-login-status'),
        headers: {'Authorization': 'Bearer $token'},
      );
      dynamic value;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final user = data['user'];
        value = user == null ? null : user['first_name'];
      }
      if (value != null && mounted) setState(() => firstName = value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hello, $firstName',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 8),
          Text('Your next place\nstarts here.',
              style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 10),
          Text('Curated homes to rent and buy across Zambia.',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
