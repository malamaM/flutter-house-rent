import 'package:flutter/material.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/services/premium_haptics.dart';

class Categories extends StatelessWidget {
  final String? selectedType;
  final ValueChanged<String?> onSelected;

  const Categories({
    Key? key,
    required this.selectedType,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const categories = <_Category>[
      _Category('All homes', Icons.key_rounded, null),
      _Category('Apartments', Icons.apartment_rounded, 'Apartment'),
      _Category('Houses', Icons.home_work_outlined, 'House'),
      _Category('Bedsitters', Icons.single_bed_rounded, 'Bedsitter'),
      _Category('Flats', Icons.domain_rounded, 'Flat'),
      _Category('Other', Icons.holiday_village_outlined, 'Other'),
    ];
    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = categories[index];
          final selected = selectedType == item.type;
          return InkWell(
            onTap: () {
              if (!selected) PremiumHaptics.selection();
              onSelected(item.type);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 94,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
                border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(16),
                boxShadow: selected ? null : AppColors.premiumShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon,
                      size: 23,
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 7),
                  Text(item.label,
                      style: TextStyle(
                          color: selected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Category {
  final String label;
  final IconData icon;
  final String? type;

  const _Category(this.label, this.icon, this.type);
}
