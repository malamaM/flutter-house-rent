import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.action,
    required this.busyProvider,
    required this.onGoogle,
    required this.onApple,
    required this.onFacebook,
    this.lastUsedProvider,
  });

  final String action;
  final String? busyProvider;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onFacebook;
  final String? lastUsedProvider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(children: [
          Expanded(child: Container(height: .5, color: colors.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or $action with',
                style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Container(height: .5, color: colors.outlineVariant)),
        ]),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                label: '$action with Google',
                icon: Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset('assets/brand/google_g.svg'),
                ),
                busy: busyProvider == 'google',
                lastUsed: lastUsedProvider == 'google',
                onPressed: busyProvider == null ? onGoogle : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialButton(
                label: '$action with Apple',
                icon: Icon(Icons.apple, size: 38, color: colors.onSurface),
                busy: busyProvider == 'apple',
                lastUsed: lastUsedProvider == 'apple',
                onPressed: busyProvider == null ? onApple : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialButton(
                label: '$action with Facebook',
                icon: SvgPicture.asset(
                  'assets/brand/facebook.svg',
                  width: 36,
                  height: 36,
                ),
                busy: busyProvider == 'facebook',
                lastUsed: lastUsedProvider == 'facebook',
                onPressed: busyProvider == null ? onFacebook : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
    required this.lastUsed,
  });

  final String label;
  final Widget icon;
  final bool busy;
  final VoidCallback? onPressed;
  final bool lastUsed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
        button: true,
        label: label,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: lastUsed
                  ? colors.primary.withValues(alpha: .72)
                  : colors.outlineVariant.withValues(alpha: .8),
              width: lastUsed ? 1.35 : .7,
            ),
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(20),
            onPressed: onPressed,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (busy)
                  const CupertinoActivityIndicator(radius: 12)
                else
                  icon,
                if (lastUsed)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ));
  }
}
