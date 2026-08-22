import 'dart:async';

import 'package:flutter/services.dart';

/// Small, intentional feedback for meaningful choices and actions.
///
/// These calls are deliberately fire-and-forget: they use the device's local
/// haptic engine immediately and never wait for a request, cache write, or
/// other network confirmation.
class PremiumHaptics {
  PremiumHaptics._();

  static void selection() => _fire(HapticFeedback.selectionClick());
  static void action() => _fire(HapticFeedback.lightImpact());

  /// A distinct, immediately noticeable acknowledgement for saving a home.
  static void save() => _fire(HapticFeedback.mediumImpact());
  static void success() => _fire(HapticFeedback.mediumImpact());

  static void _fire(Future<void> feedback) {
    unawaited(feedback.catchError((_) {}));
  }
}
