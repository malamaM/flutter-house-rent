import 'package:flutter/material.dart';
import 'package:house_rent/theme/app_colors.dart';

class ListerTrustBadges extends StatelessWidget {
  final bool verified;
  final bool topRated;
  final bool compact;

  const ListerTrustBadges({
    Key? key,
    required this.verified,
    required this.topRated,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!verified && !topRated) return const SizedBox.shrink();
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        if (verified)
          _TrustBadge(
            icon: Icons.verified_user_rounded,
            label: 'Identity verified',
            description:
                'Haven has reviewed this lister’s identity details. Always inspect a property before paying.',
            color: AppColors.primary,
            background: AppColors.primaryLight,
            compact: compact,
          ),
        if (topRated)
          _TrustBadge(
            icon: Icons.workspace_premium_rounded,
            label: 'Top rated',
            description:
                'Earned through at least five published reviews and a rating of 4.5 or higher.',
            color: const Color(0xFF8A5B00),
            background: const Color(0xFFFFEDC2),
            compact: compact,
          ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final Color background;
  final bool compact;

  const _TrustBadge(
      {required this.icon,
      required this.label,
      required this.description,
      required this.color,
      required this.background,
      required this.compact});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 34),
                  const SizedBox(height: 14),
                  Text(label,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(description,
                      style: Theme.of(context).textTheme.bodyLarge),
                ]),
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10, vertical: compact ? 5 : 7),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: compact ? 14 : 16),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
