import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/screens/myaccount/changepassword/change_password.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/screens/myaccount/update/update_profile.dart';
import 'package:house_rent/theme/theme_controller.dart';
import 'package:house_rent/services/social_auth_service.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';
import 'package:house_rent/widgets/haven_settings_group.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyAccount extends StatefulWidget {
  const MyAccount({Key? key}) : super(key: key);

  @override
  State<MyAccount> createState() => _MyAccountState();
}

class _MyAccountState extends State<MyAccount> {
  bool _connectingGoogle = false;
  bool _googleConnected = false;

  @override
  void initState() {
    super.initState();
    _googleConnected = SessionService.cachedUser?['google_id'] != null ||
        (SessionService.cachedUser?['auth_provider']
                ?.toString()
                .contains('google') ??
            false);
    _refreshAuthMethods();
  }

  Future<void> _refreshAuthMethods() async {
    try {
      final user = await SessionService.currentUser(forceRefresh: true);
      if (!mounted || user == null) return;
      setState(() => _googleConnected = user['google_id'] != null ||
          (user['auth_provider']?.toString().contains('google') ?? false));
    } catch (_) {
      // The cached account state remains usable while offline.
    }
  }

  Future<void> _connectGoogle() async {
    if (_connectingGoogle) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Connect Google sign-in?'),
        content: const Text(
            'Use the same email as this Haven account. Your password remains available, and Google will only be added after the identity is verified.'),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _connectingGoogle = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) {
        throw const SocialAuthException(
            'Your Haven session has expired. Please sign in again.');
      }
      await SocialAuthService.connectGoogleFromSettings(accessToken: token);
      if (mounted) {
        setState(() => _googleConnected = true);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google sign-in is now connected.')));
      }
    } on SocialAuthCanceled catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiErrorResolver.message(error,
                fallback:
                    'Google could not be connected. The Haven account was not changed.'))));
      }
    } finally {
      if (mounted) setState(() => _connectingGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HavenNavigationBar(title: 'Account settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(
                        'Keep your contact details current so owners and renters can reach you.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          HavenSettingsGroup(label: 'Your account', children: [
            HavenSettingsRow(
              icon: CupertinoIcons.person,
              title: 'Personal information',
              subtitle: 'Name, email, phone and profile photo',
              onTap: () => Navigator.push(context,
                  HavenPageRoute(builder: (_) => const EditProfileScreen())),
            ),
            HavenSettingsRow(
              icon: CupertinoIcons.person_crop_circle_badge_checkmark,
              title: _googleConnected
                  ? 'Google sign-in connected'
                  : 'Google sign-in',
              subtitle: _googleConnected
                  ? 'You can use Google or your password'
                  : (_connectingGoogle
                      ? 'Connecting securely…'
                      : 'Add Google as another way to sign in'),
              trailing: _connectingGoogle
                  ? const CupertinoActivityIndicator()
                  : Icon(
                      _googleConnected
                          ? CupertinoIcons.check_mark_circled
                          : CupertinoIcons.chevron_forward,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
              onTap: _googleConnected ? () {} : _connectGoogle,
            ),
            ListenableBuilder(
              listenable: ThemeController.instance,
              builder: (context, _) => HavenSettingsRow(
                icon: CupertinoIcons.moon,
                title: 'Dark mode',
                subtitle: 'Automatic, on or off',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(ThemeController.instance.preferenceLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(width: 7),
                  Icon(CupertinoIcons.chevron_forward,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ]),
                onTap: () => _showThemeModePicker(context),
              ),
            ),
            HavenSettingsRow(
              icon: CupertinoIcons.lock,
              title: 'Password',
              subtitle: 'Update your account password',
              onTap: () => Navigator.push(context,
                  HavenPageRoute(builder: (_) => const ChangePassword())),
            ),
          ]),
          const SizedBox(height: 28),
          Text(
              'Privacy and support features will appear here as they become available.',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _showThemeModePicker(BuildContext context) =>
      showCupertinoModalPopup<void>(
        context: context,
        builder: (sheetContext) => CupertinoActionSheet(
          title: const Text('Dark mode'),
          message: const Text('Choose how Haven Zambia should look.'),
          actions: [
            for (final option in const <(ThemeMode, String, String)>[
              (ThemeMode.system, 'Automatic', 'Match this device'),
              (ThemeMode.dark, 'On', 'Always use dark mode'),
              (ThemeMode.light, 'Off', 'Always use light mode'),
            ])
              CupertinoActionSheetAction(
                onPressed: () async {
                  await ThemeController.instance.setMode(option.$1);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: SizedBox(
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(option.$2),
                      if (ThemeController.instance.mode == option.$1)
                        const Positioned(
                            right: 18,
                            child: Icon(CupertinoIcons.check_mark, size: 17)),
                    ],
                  ),
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('Cancel'),
          ),
        ),
      );
}
