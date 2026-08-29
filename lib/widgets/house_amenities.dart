import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/models/recommendation.dart';
import 'package:house_rent/widgets/amenity_icon.dart';

class HouseAmenities extends StatelessWidget {
  final House house;

  const HouseAmenities({super.key, required this.house});

  List<RentalAmenity> get _amenities {
    if (house.amenities.isNotEmpty) return house.amenities;
    return [
      if (house.gym == 1) const RentalAmenity(0, 'gym', 'Gym', null),
      if (house.swimmingPool == 1)
        const RentalAmenity(0, 'swimming_pool', 'Swimming pool', null),
      if (house.garage == 1 || house.carGarage > 0)
        const RentalAmenity(0, 'garage', 'Garage', null),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final amenities = _amenities;
    if (amenities.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amenities', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final amenity in amenities)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(amenityIcon(amenity.key),
                          size: 20, color: colors.primary),
                      const SizedBox(width: 8),
                      Text(amenity.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
