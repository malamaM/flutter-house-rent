import 'package:flutter/material.dart';
import 'package:house_rent/theme/app_colors.dart';

class DemandBadge extends StatelessWidget {
  final String? demandLabel;
  final bool compact;

  const DemandBadge({
    Key? key,
    required this.demandLabel,
    this.compact = false,
  }) : super(key: key);

  String? get label {
    switch (demandLabel) {
      case 'hot':
        return 'Hot right now';
      case 'popular_recently':
        return 'Popular recently';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text == null) return const SizedBox.shrink();

    final hot = demandLabel == 'hot';
    final foreground = hot ? const Color(0xFF8A3C0C) : AppColors.primaryDark;
    final background = hot ? const Color(0xFFFFE7CC) : AppColors.primaryLight;

    return Semantics(
      label: '$text based on recent interest',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x18000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                hot
                    ? Icons.local_fire_department_rounded
                    : Icons.trending_up_rounded,
                size: compact ? 14 : 16,
                color: foreground),
            const SizedBox(width: 5),
            Text(text,
                style: TextStyle(
                    color: foreground,
                    fontSize: compact ? 10 : 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
