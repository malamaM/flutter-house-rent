import 'package:flutter/material.dart';

class AppColors {
  // A grounded, architectural palette: forest, warm stone and charcoal.
  static const Color primary = Color(0xFF176B55);
  static const Color primaryDark = Color(0xFF0D4638);
  static const Color primaryLight = Color(0xFFE1F0EA);
  static const Color accent = Color(0xFFE89A55);

  static const Color background = Color(0xFFF7F6F2);
  static const Color surface = Colors.white;
  static const Color surfaceContainer = Color(0xFFF0F1EC);
  static const Color surfaceDark = Color(0xFF17332D);

  static const Color textPrimary = Color(0xFF18201E);
  static const Color textSecondary = Color(0xFF66706D);
  static const Color textOnDark = Color(0xFFF8FAF9);

  // States
  static const Color error = Color(0xFFC84B4B);
  static const Color success = Color(0xFF2E7D62);
  static const Color warning = Color(0xFFE3A23B);

  static const Color divider = Color(0xFFE4E6E1);
  static const Color glassBorder = Color(0xB8FFFFFF);
  static const Color glassSurface = Color(0xEFFFFFFF);

  static const List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: Color(0x120D4638),
      blurRadius: 24,
      offset: Offset(0, 9),
    ),
    BoxShadow(
      color: Color(0x0AFFFFFF),
      blurRadius: 1,
      offset: Offset(0, -1),
    ),
  ];
}
