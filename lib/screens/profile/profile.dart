import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/screens/login/login.dart';
import 'package:house_rent/screens/my_listings/my_listings.dart';
import 'package:house_rent/screens/myaccount/myaccount.dart';
import 'package:house_rent/screens/profile/verification_request_screen.dart';
import 'package:house_rent/screens/profile/recommendation_history_screen.dart';
import 'package:house_rent/screens/profile/offline_sync_screen.dart';
import 'package:house_rent/screens/profile/marketplace_hub_screen.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/media_upload_policy.dart';
import 'package:house_rent/services/session_token_store.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';
import 'package:house_rent/widgets/haven_settings_group.dart';
import 'package:house_rent/widgets/zambia_pattern.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:house_rent/services/session_recommendation.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? imageUrl;
  String name = 'Haven Zambia member';
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
            imageUrl = picture == null ? null : ApiConfig.storageUrl(picture);
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
    try {
      await MediaUploadPolicy.validateFile(image.path,
          maxBytes: MediaUploadPolicy.maxImageBytes, label: 'Profile photo');
      final token = await SessionTokenStore.read();
      if (token == null) return;
      final request = http.MultipartRequest(
          'POST', Uri.parse('${ApiConfig.apiBase}/update-profile-picture'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath(
          'profile_picture', File(image.path).path));
      final response = await http.Response.fromStream(
          await request.send().timeout(const Duration(minutes: 2)));
      if (response.statusCode == 200) {
        await SessionService.currentUser(forceRefresh: true);
        await _loadProfile();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated')));
      } else {
        throw HavenApiException.fromResponse(response,
            operation: 'update your profile photo');
      }
    } on HavenApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on MediaUploadException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiErrorResolver.message(error,
                fallback: 'Haven could not update your profile photo.'))));
      }
    }
  }

  Future<void> _logout() async {
    final token = await SessionTokenStore.read();
    if (token != null) {
      try {
        await http.post(
          Uri.parse('${ApiConfig.apiBase}/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json'
          },
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await SessionService.clear();
    SessionRecommendation.instance.reset();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        HavenPageRoute(builder: (_) => const SignInScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const HavenNavigationBar(title: 'Profile'),
      body: loading
          ? const Center(child: CupertinoActivityIndicator(radius: 13))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                        colors.primaryContainer.withValues(alpha: .16),
                        colors.surface),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.outlineVariant, width: .7),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Positioned.fill(
                          child: IgnorePointer(child: ZambiaPattern())),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 43,
                                  backgroundColor: colors.primaryContainer,
                                  backgroundImage: imageUrl == null
                                      ? null
                                      : CachedNetworkImageProvider(
                                          ApiConfig.optimizedImageUrl(
                                            imageUrl!,
                                            width: 420,
                                            height: 420,
                                            quality: 80,
                                          ),
                                        ),
                                  child: imageUrl == null
                                      ? Icon(CupertinoIcons.person_fill,
                                          color: colors.primary, size: 36)
                                      : null,
                                ),
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Material(
                                    color: colors.primary,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: _changePhoto,
                                      customBorder: const CircleBorder(),
                                      child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                              CupertinoIcons.camera_fill,
                                              color: colors.onPrimary,
                                              size: 15)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            Text(name.isEmpty ? 'Haven Zambia member' : name,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(email,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                HavenSettingsGroup(
                  label: 'Property',
                  children: [
                    HavenSettingsRow(
                        icon: CupertinoIcons.chat_bubble_2,
                        title: 'Messages',
                        subtitle: 'Secure conversations about properties',
                        iconColor: colors.primary,
                        onTap: () => Navigator.push(
                            context,
                            HavenPageRoute(
                                builder: (_) => const MarketplaceHubScreen()))),
                    HavenSettingsRow(
                        icon: CupertinoIcons.calendar,
                        title: 'Viewings',
                        subtitle: 'Requests, confirmations and history',
                        iconColor: colors.secondary,
                        onTap: () => Navigator.push(
                            context,
                            HavenPageRoute(
                                builder: (_) => const MarketplaceHubScreen(
                                    initialTab: 1)))),
                    HavenSettingsRow(
                        icon: CupertinoIcons.bell,
                        title: 'Updates & saved searches',
                        subtitle: 'Replies and alerts for matching homes',
                        iconColor: colors.tertiary,
                        onTap: () => Navigator.push(
                            context,
                            HavenPageRoute(
                                builder: (_) => const MarketplaceHubScreen(
                                    initialTab: 2)))),
                    HavenSettingsRow(
                        icon: CupertinoIcons.lock_shield,
                        title: 'Paid reservations',
                        subtitle: 'Paid homes and your listing activity',
                        iconColor: colors.primary,
                        onTap: () => Navigator.push(
                            context,
                            HavenPageRoute(
                                builder: (_) => const MarketplaceHubScreen(
                                    initialTab: 4)))),
                    HavenSettingsRow(
                        icon: CupertinoIcons.cloud_upload,
                        title: 'Offline & sync',
                        subtitle: 'Pending changes and connection status',
                        iconColor: const Color(0xFF4B7BEC),
                        onTap: () => Navigator.push(
                            context,
                            HavenPageRoute(
                                builder: (_) => const OfflineSyncScreen()))),
                    HavenSettingsRow(
                        icon: CupertinoIcons.house,
                        title: 'My listings',
                        subtitle: 'Create and manage your properties',
                        iconColor: const Color(0xFFE08A2E),
                        onTap: () => Navigator.push(
                            context,
                            HavenPageRoute(
                                builder: (_) => const MyListingsScreen()))),
                  ],
                ),
                const SizedBox(height: 24),
                HavenSettingsGroup(label: 'Account', children: [
                  HavenSettingsRow(
                      icon: CupertinoIcons.person_crop_circle,
                      title: 'Account settings',
                      subtitle: 'Personal details, appearance and password',
                      iconColor: colors.primary,
                      onTap: () => Navigator.push(context,
                          HavenPageRoute(builder: (_) => const MyAccount()))),
                  HavenSettingsRow(
                      icon: CupertinoIcons.sparkles,
                      title: 'Your home search',
                      subtitle: 'Preferences and recommendation history',
                      iconColor: const Color(0xFF9B59B6),
                      onTap: () => Navigator.push(
                          context,
                          HavenPageRoute(
                              builder: (_) =>
                                  const RecommendationHistoryScreen()))),
                  HavenSettingsRow(
                      icon: CupertinoIcons.checkmark_shield,
                      title: 'Lister verification',
                      subtitle: 'Request a trusted identity badge',
                      iconColor: const Color(0xFF2E9D77),
                      onTap: () => Navigator.push(
                          context,
                          HavenPageRoute(
                              builder: (_) =>
                                  const VerificationRequestScreen()))),
                  HavenSettingsRow(
                      icon: CupertinoIcons.question_circle,
                      title: 'Help and support',
                      subtitle: 'Get help using Haven Zambia',
                      iconColor: const Color(0xFFE06C75),
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Support details are coming soon.')))),
                ]),
                const SizedBox(height: 24),
                HavenSettingsGroup(children: [
                  HavenSettingsRow(
                      icon: CupertinoIcons.square_arrow_right,
                      title: 'Sign out',
                      color: colors.error,
                      trailing: const SizedBox.shrink(),
                      onTap: _logout),
                ]),
              ],
            ),
    );
  }
}
