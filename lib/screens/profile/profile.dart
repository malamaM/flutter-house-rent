import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/screens/login/login.dart';
import 'package:house_rent/screens/my_listings/my_listings.dart';
import 'package:house_rent/screens/myaccount/myaccount.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? imageUrl;
  String name = 'Haven member';
  String email = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await SessionService.currentUser();
      if (user != null) {
        final picture = user['profile_picture'];
        if (mounted) {
          setState(() {
            name =
                '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
            email = user['email'] ?? '';
            imageUrl = picture == null
                ? null
                : 'http://localhost:8000/storage/${picture.toString().replaceAll("\\", "")}';
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _changePhoto() async {
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 82, maxWidth: 1400);
    if (image == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;
    final request = http.MultipartRequest(
        'POST', Uri.parse('http://localhost:8000/api/update-profile-picture'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(
        'profile_picture', File(image.path).path));
    final response = await request.send();
    if (response.statusCode == 200) {
      await SessionService.currentUser(forceRefresh: true);
      await _loadProfile();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated')));
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      try {
        await http.post(
          Uri.parse('http://localhost:8000/api/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json'
          },
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await SessionService.clear();
    await prefs.remove('access_token');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const SignInScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(22)),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage: imageUrl == null
                                ? null
                                : CachedNetworkImageProvider(imageUrl!),
                            child: imageUrl == null
                                ? const Icon(Icons.person_rounded,
                                    color: AppColors.primary, size: 36)
                                : null,
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Material(
                              color: AppColors.accent,
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: _changePhoto,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.camera_alt_outlined,
                                        color: Colors.white, size: 16)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name.isEmpty ? 'Haven member' : name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 5),
                            Text(email,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('Property',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                _ProfileItem(
                  icon: Icons.home_work_outlined,
                  title: 'My listings',
                  subtitle: 'Create and manage your properties',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MyListingsScreen())),
                ),
                const SizedBox(height: 24),
                Text('Account',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                _ProfileItem(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Account settings',
                  subtitle: 'Personal details and password',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MyAccount())),
                ),
                _ProfileItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Help and support',
                  subtitle: 'Get help using Haven',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Support details are coming soon.'))),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon:
                      const Icon(Icons.logout_rounded, color: AppColors.error),
                  label: const Text('Sign out',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileItem(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ])),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
