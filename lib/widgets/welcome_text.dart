import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeText extends StatefulWidget {
  const WelcomeText({Key? key}) : super(key: key);

  @override
  _WelcomeTextState createState() => _WelcomeTextState();
}

class _WelcomeTextState extends State<WelcomeText> {
  String firstName = "Ruize";

  @override
  void initState() {
    super.initState();
    _fetchFirstName();
  }

  Future<void> _fetchFirstName() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accessToken = prefs.getString('access_token');

    if (accessToken != null) {
      print('Access Token: $accessToken'); // Print the access token

      final response = await http.get(
        Uri.parse('http://localhost:8000/api/check-login-status'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('Request URL: ${response.request?.url}');
      print('Request Headers: ${response.request?.headers}');
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String? fetchedFirstName = data['user']?['first_name'];
        if (fetchedFirstName != null) {
          setState(() {
            firstName = fetchedFirstName;
          });
        } else {
          // Handle missing first name
          print('First name not found in response');
        }
      } else {
        // Handle error
        print('Failed to load first name');
      }
    } else {
      // Handle missing token
      print('Access token not found');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello $firstName',
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Find your sweet Home',
            style: Theme.of(context).textTheme.displayLarge!.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
