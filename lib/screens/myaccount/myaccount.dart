import 'package:flutter/material.dart';
import 'package:house_rent/screens/myaccount/changepassword/change_password.dart';
import 'package:house_rent/screens/myaccount/update/update_profile.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/theme/theme_controller.dart';

class MyAccount extends StatelessWidget {
  const MyAccount({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(
                        'Keep your contact details current so owners and renters can reach you.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.primaryDark))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _AccountItem(
            icon: Icons.person_outline_rounded,
            title: 'Personal information',
            subtitle: 'Name, email, phone and profile photo',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListenableBuilder(
              listenable: ThemeController.instance,
              builder: (context, _) => SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark mode',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle:
                    const Text('Use Haven Zambia’s calm evening appearance'),
                value: ThemeController.instance.isDark,
                onChanged: ThemeController.instance.setDark,
              ),
            ),
          ),
          _AccountItem(
            icon: Icons.lock_outline_rounded,
            title: 'Password',
            subtitle: 'Update your account password',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ChangePassword())),
          ),
          const SizedBox(height: 28),
          Text(
              'Privacy and support features will appear here as they become available.',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _AccountItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountItem(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 4), child: Text(subtitle)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
