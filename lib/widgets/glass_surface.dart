import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:house_rent/theme/app_colors.dart';

/// A restrained glass surface for controls that already have a defined shape.
/// The tint stays intentionally strong enough for accessible text contrast.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color tint;
  final Color borderColor;
  final double blur;
  final List<BoxShadow>? shadows;

  const GlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.tint = const Color(0xEFFFFFFF),
    this.borderColor = AppColors.glassBorder,
    this.blur = 18,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows ?? AppColors.premiumShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: borderRadius,
              border: Border.all(color: borderColor, width: .8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: .16),
                  Colors.white.withValues(alpha: .02),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
