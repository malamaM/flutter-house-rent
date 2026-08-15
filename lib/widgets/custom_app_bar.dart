import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:house_rent/screens/profile/profile.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.roofing_rounded,
                  color: Colors.white, size: 23),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('HAVEN',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 1.2)),
                  Text('Find where you belong',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
            ),
            Material(
              color: AppColors.surface,
              shape: const CircleBorder(
                  side: BorderSide(color: AppColors.divider)),
              child: InkWell(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
                customBorder: const CircleBorder(),
                child: const Padding(
                    padding: EdgeInsets.all(4), child: ProfileAvatar()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);
}

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({Key? key}) : super(key: key);

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfileImage();
  }

  Future<void> _fetchProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return;
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/check-login-status'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final user = data['user'];
        final picture = user == null ? null : user['profile_picture'];
        if (picture != null && mounted) {
          setState(() => profileImageUrl =
              'http://localhost:8000/storage/${picture.toString().replaceAll("\\", "")}');
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 19,
      backgroundColor: AppColors.primaryLight,
      backgroundImage:
          profileImageUrl == null ? null : NetworkImage(profileImageUrl!),
      child: profileImageUrl == null
          ? const Icon(Icons.person_outline_rounded,
              color: AppColors.primary, size: 21)
          : null,
    );
  }
}
