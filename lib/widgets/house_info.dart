import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/theme/app_colors.dart';

class HouseInfo extends StatelessWidget {
  final House house;

  const HouseInfo({Key? key, required this.house}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        children: [
          _Fact(
              icon: Icons.bed_outlined,
              value: '${house.bedrooms}',
              label: 'Bedrooms'),
          _Fact(
              icon: Icons.bathtub_outlined,
              value: '${house.bathrooms}',
              label: 'Bathrooms'),
          _Fact(
              icon: Icons.square_foot_outlined,
              value: '${house.size}',
              label: 'Square metres'),
          _Fact(
              icon: Icons.directions_car_outlined,
              value: '${house.carGarage}',
              label: 'Parking'),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Fact({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
