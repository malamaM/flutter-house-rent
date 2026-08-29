import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HavenSettingsGroup extends StatelessWidget {
  final String? label;
  final List<Widget> children;

  const HavenSettingsGroup({super.key, this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(label!.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 11,
                    letterSpacing: .7,
                    color: colors.onSurfaceVariant)),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant, width: .7),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index != children.length - 1)
                    Divider(
                        height: .7, indent: 62, color: colors.outlineVariant),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class HavenSettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;
  final Widget? trailing;

  const HavenSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.color,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = iconColor ?? color ?? colors.primary;
    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      pressedOpacity: .68,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: color ?? colors.onSurface,
                          fontWeight: FontWeight.w600,
                          height: 1.2)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(CupertinoIcons.chevron_forward,
                    size: 16, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
