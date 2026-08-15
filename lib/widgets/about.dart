import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/theme/app_colors.dart';

class About extends StatelessWidget {
  final House house;

  const About({Key? key, required this.house}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About this home',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            house.description?.trim().isNotEmpty == true
                ? house.description!
                : 'The owner has not added a description yet. Contact them for more information.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
