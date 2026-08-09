import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_rent/screens/profile/profile.dart';
import 'package:house_rent/screens/my_listings/my_listings.dart';
import 'package:house_rent/theme/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                // Menu action (simplified for production look)
                Scaffold.of(context).openDrawer(); // Alternatively, use a bottom sheet
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider, width: 1),
                ),
                child: SvgPicture.asset(
                  'assets/icons/menu.svg',
                  width: 20,
                  height: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Text(
              "Home",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              child: const ProfileAvatar(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({Key? key}) : super(key: key);

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  String profileImageUrl = "https://i.postimg.cc/0jqKB6mS/Profile-Image.png";

  @override
  void initState() {
    super.initState();
    _fetchProfileImage();
  }

  Future<void> _fetchProfileImage() async {
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
          final String? profilePicture = data['user']?['profile_picture'];
          if (profilePicture != null && mounted) {
            final String sanitized = profilePicture.replaceAll("\\", "");
            setState(() {
              profileImageUrl = "http://localhost:8000/storage/$sanitized";
            });
          }
        }
      }
    } catch (e) {
      // Handle gracefully
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(profileImageUrl),
      ),
    );
  }
}
