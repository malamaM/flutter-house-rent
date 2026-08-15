import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/property_card.dart';

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
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: AppColors.textSecondary, size: 18),
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
