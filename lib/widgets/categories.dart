import 'package:flutter/material.dart';
import 'package:house_rent/theme/app_colors.dart';

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
            onTap: () => onSelected(item.type),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 94,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryLight : AppColors.surface,
                border: Border.all(
                    color:
                        selected ? AppColors.primaryLight : AppColors.divider),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 23, color: AppColors.primary),
                  const SizedBox(height: 7),
                  Text(item.label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
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
