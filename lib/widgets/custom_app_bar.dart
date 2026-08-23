import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/screens/profile/profile.dart';
import 'package:house_rent/screens/profile/marketplace_hub_screen.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/marketplace_service.dart';
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
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HAVEN ZAMBIA',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                            height: 1,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: .9)),
                    const SizedBox(height: 4),
                    Text('Find where you belong',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                            height: 1,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 10)),
                  ],
                ),
              ),
            ),
            const _NotificationButton(),
            const SizedBox(width: 8),
            Material(
              color: Theme.of(context).colorScheme.surface,
              shape: CircleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor)),
              child: InkWell(
                onTap: () => Navigator.push(context,
                    HavenPageRoute(builder: (_) => const ProfileScreen())),
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

class _NotificationButton extends StatefulWidget {
  const _NotificationButton();
  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
  int unread = 0;
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), _load);
  }

  Future<void> _load() async {
    try {
      final count = await MarketplaceService.instance.unreadNotificationCount();
      if (mounted) {
        setState(() => unread = count);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Updates',
        onPressed: () => Navigator.push(
                context,
                HavenPageRoute(
                    builder: (_) => const MarketplaceHubScreen(initialTab: 2)))
            .then((_) => _load()),
        icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.notifications_none_rounded)),
      );
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
    final picture = SessionService.cachedUser?['profile_picture'];
    if (picture != null) profileImageUrl = ApiConfig.storageUrl(picture);
    _fetchProfileImage();
  }

  Future<void> _fetchProfileImage() async {
    try {
      final user = await SessionService.currentUser();
      final picture = user?['profile_picture'];
      final resolved = picture == null ? null : ApiConfig.storageUrl(picture);
      if (mounted && resolved != profileImageUrl) {
        setState(() => profileImageUrl = resolved);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 19,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: profileImageUrl == null
          ? null
          : CachedNetworkImageProvider(ApiConfig.optimizedImageUrl(
              profileImageUrl!,
              width: 160,
              height: 160,
              quality: 76,
            )),
      child: profileImageUrl == null
          ? Icon(Icons.person_outline_rounded,
              color: Theme.of(context).colorScheme.primary, size: 21)
          : null,
    );
  }
}
