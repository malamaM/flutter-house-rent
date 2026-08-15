import 'package:flutter/services.dart';

/// Small, intentional feedback only for completed choices and meaningful actions.
class PremiumHaptics {
  PremiumHaptics._();

  static Future<void> selection() => HapticFeedback.selectionClick();
  static Future<void> action() => HapticFeedback.lightImpact();
  static Future<void> success() => HapticFeedback.mediumImpact();
}
