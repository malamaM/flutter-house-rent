import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/screens/profile/profile.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/theme/app_colors.dart';

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
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                border: Border.all(color: Colors.white38, width: .7),
                borderRadius: BorderRadius.circular(13),
                boxShadow: AppColors.premiumShadow,
              ),
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
      final user = await SessionService.currentUser();
      final picture = user?['profile_picture'];
      if (picture != null && mounted) {
        setState(() => profileImageUrl = ApiConfig.storageUrl(picture));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 19,
      backgroundColor: AppColors.primaryLight,
      backgroundImage: profileImageUrl == null
          ? null
          : CachedNetworkImageProvider(profileImageUrl!),
      child: profileImageUrl == null
          ? const Icon(Icons.person_outline_rounded,
              color: AppColors.primary, size: 21)
          : null,
    );
  }
}
