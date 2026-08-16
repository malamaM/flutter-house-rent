import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

class ApiConfig {
  ApiConfig._();

  static const _envOrigin = String.fromEnvironment('API_ORIGIN');

  /// Production server URL used when building release versions if API_ORIGIN is omitted.
  static const _productionOrigin = 'https://api.havenzambia.com';

  /// Server origin:
  /// 1. Uses `--dart-define=API_ORIGIN=...` if provided.
  /// 2. In Release/Production mode: defaults to your live production HTTPS domain.
  /// 3. In Debug mode: automatically defaults to 10.0.2.2 (Android) or 127.0.0.1 (iOS/desktop).
  static String get origin {
    if (_envOrigin.isNotEmpty) {
      return _envOrigin;
    }
    if (kReleaseMode) {
      return _productionOrigin;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static String get apiBase => '$origin/api';
  static String get storageBase => '$origin/storage';

  static String storageUrl(Object? path) {
    final value = '${path ?? ''}'.replaceAll('\\', '/');
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '$storageBase/${value.replaceFirst(RegExp(r'^/+'), '')}';
  }
}
