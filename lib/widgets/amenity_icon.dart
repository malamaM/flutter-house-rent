import 'package:flutter/material.dart';

IconData amenityIcon(String key) => switch (key) {
      'gym' => Icons.fitness_center_rounded,
      'swimming_pool' => Icons.pool_rounded,
      'garage' => Icons.garage_rounded,
      'security' => Icons.shield_outlined,
      'furnished' => Icons.chair_outlined,
      'backup_power' => Icons.bolt_rounded,
      'water_tank' => Icons.water_drop_outlined,
      'internet' => Icons.wifi_rounded,
      'pet_friendly' => Icons.pets_rounded,
      'garden' => Icons.yard_outlined,
      _ => Icons.check_circle_outline_rounded,
    };
