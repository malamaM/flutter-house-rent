import 'package:flutter/material.dart';

/// Keeps Haven usable when Android combines a large font setting with Display
/// zoom. Moderate accessibility scaling is preserved; only the extreme range
/// that breaks compact navigation and property controls is capped.
class HavenResponsiveMedia extends StatelessWidget {
  static const double maxTextScaleFactor = 1.35;

  final Widget child;

  const HavenResponsiveMedia({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(
          maxScaleFactor: maxTextScaleFactor,
        ),
      ),
      child: child,
    );
  }
}
