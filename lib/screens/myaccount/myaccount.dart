import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/screens/myaccount/changepassword/change_password.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/screens/myaccount/update/update_profile.dart';
import 'package:house_rent/theme/theme_controller.dart';
import 'package:house_rent/widgets/haven_navigation_bar.dart';
import 'package:house_rent/widgets/haven_settings_group.dart';

class MyAccount extends StatelessWidget {
  const MyAccount({Key? key}) : super(key: key);

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
