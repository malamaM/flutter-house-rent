import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/widgets/demand_badge.dart';

class ContentIntro extends StatelessWidget {
  final House house;

  const ContentIntro({Key? key, required this.house}) : super(key: key);

  String get location {
    final parts = <String>[
      house.address,
      if (house.district != null && house.district!.isNotEmpty) house.district!,
      if (house.province != null && house.province!.isNotEmpty) house.province!,
    ];
    return parts
        .where((value) => value != 'Unknown' && value != 'N/A')
        .toSet()
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(house.name, style: Theme.of(context).textTheme.headlineLarge),
          if (house.hasPublicNotice) ...[
            const SizedBox(height: 12),
            _PublicNotice(house: house),
          ],
          if (house.demandLabel != null || house.recentlyListed) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (house.recentlyListed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 14,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer),
                      const SizedBox(width: 5),
                      Text('Listed recently',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                if (house.demandLabel != null)
                  DemandBadge(demandLabel: house.demandLabel),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 18),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(
                      location.isEmpty
                          ? 'Location available on request'
                          : location,
                      style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: 16),
          Text(formatPropertyPrice(house),
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4)),
        ],
      ),
    );
  }
}

class _PublicNotice extends StatelessWidget {
  final House house;

  const _PublicNotice({required this.house});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.tertiary.withValues(alpha: .34)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.fact_check_outlined, size: 19, color: colors.tertiary),
        const SizedBox(width: 9),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              house.publicNoticeLabel ?? 'Details may need confirmation',
              style: TextStyle(
                color: colors.onTertiaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              house.publicNoticeMessage ??
                  'Confirm the price, availability and included features before making arrangements.',
              style: TextStyle(
                color: colors.onTertiaryContainer.withValues(alpha: .86),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
