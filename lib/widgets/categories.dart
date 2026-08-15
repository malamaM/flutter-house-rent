import 'package:flutter/material.dart';
import 'package:house_rent/screens/home/all_houses_screen.dart';
import 'package:house_rent/theme/app_colors.dart';

class Categories extends StatelessWidget {
  const Categories({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const categories = <_Category>[
      _Category('Rent', Icons.key_rounded, {'status': 'For Rent'}),
      _Category('Buy', Icons.villa_outlined, {'status': 'For Sale'}),
      _Category('Apartments', Icons.apartment_rounded, {'type': 'Apartment'}),
      _Category('Houses', Icons.home_work_outlined, {'type': 'House'}),
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
          return InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AllHousesScreen(
                      title: item.label, filters: item.filters)),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 94,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: index == 0 ? AppColors.primaryLight : AppColors.surface,
                border: Border.all(
                    color: index == 0
                        ? AppColors.primaryLight
                        : AppColors.divider),
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
  final Map<String, String> filters;

  const _Category(this.label, this.icon, this.filters);
}
