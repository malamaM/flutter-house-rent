import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_rent/theme/app_colors.dart';

class WelcomeText extends StatefulWidget {
  const WelcomeText({Key? key}) : super(key: key);

  @override
  State<WelcomeText> createState() => _WelcomeTextState();
}

class _WelcomeTextState extends State<WelcomeText> {
  String firstName = "Explorer";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFirstName();
  }

  Future<void> _fetchFirstName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString('access_token');

      if (accessToken != null) {
        final response = await http.get(
          Uri.parse('http://localhost:8000/api/check-login-status'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final String? fetchedFirstName = data['user']?['first_name'];
          if (fetchedFirstName != null && mounted) {
            setState(() {
              firstName = fetchedFirstName;
            });
          }
        }
      }
    } catch (e) {
      // Silently handle error, fallback to "Explorer"
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Good Morning, ',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 60,
                  height: 16,
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.surfaceContainer,
                    color: AppColors.primaryLight,
                  ),
                )
              else
                Text(
                  firstName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s find your\nsweet home',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  height: 1.2,
                ),
          ),
        ],
      ),
    );
  }
}
