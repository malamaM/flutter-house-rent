import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/services/social_auth_service.dart';

enum SocialAuthConflictChoice { enterPassword, chooseAnother }

Future<SocialAuthConflictChoice?> showSocialAuthConflictSheet(
  BuildContext context,
  SocialAuthAccountConflict conflict,
) {
  return showModalBottomSheet<SocialAuthConflictChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: .55),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.lock_shield_fill,
                    color: colors.primary, size: 25),
              ),
              const SizedBox(height: 16),
              Text(
                'This email already has an account',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 9),
              Text(
                conflict.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                      context, SocialAuthConflictChoice.enterPassword),
                  child: const Text('Enter password'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  onPressed: () => Navigator.pop(
                      context, SocialAuthConflictChoice.chooseAnother),
                  child: const Text('Choose another sign-in option'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
