import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  // Phones reach Laravel through this Mac's local-network hostname.
  // For an Android emulator, pass --dart-define=DEV_API_HOST=10.0.2.2.
  static const _developmentHost = String.fromEnvironment(
    'DEV_API_HOST',
    defaultValue: 'malamas-MacBook-Pro.local',
  );
  static const _originOverride = String.fromEnvironment('API_ORIGIN');

  static String get origin {
    if (_originOverride.isNotEmpty) {
      return _originOverride.replaceFirst(RegExp(r'/+$'), '');
    }
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final host = isMobile ? _developmentHost : '127.0.0.1';
    return Uri.parse('http://$host:8000').toString();
  }

  static Future<void> initialize() async {}

  static Future<void> get ready => initialize();

  static String get apiBase => '$origin/api';
  static String get storageBase => '$origin/storage';

  static String storageUrl(Object? path) {
    final value = '${path ?? ''}'.replaceAll('\\', '/');
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      // Cached listing payloads may contain an absolute URL from a previous
      // local/live session. Haven-owned storage must follow the backend chosen
      // for this process; truly external media remains untouched.
      final uri = Uri.tryParse(value);
      if (uri != null && uri.path.startsWith('/storage/')) {
        final relative = uri.path.substring('/storage/'.length);
        return Uri.parse('$storageBase/$relative')
            .replace(query: uri.hasQuery ? uri.query : null)
            .toString();
      }
      return value;
    }
    return '$storageBase/${value.replaceFirst(RegExp(r'^/+'), '')}';
  }

  /// Requests a server-cached image sized for the exact UI surface instead of
  /// downloading the original camera file. External images are left untouched.
  static String optimizedImageUrl(
    Object? path, {
    required int width,
    int? height,
    int quality = 78,
    String fit = 'cover',
    String format = 'webp',
  }) {
    final resolved = storageUrl(path);
    final uri = Uri.tryParse(resolved);
    final storageOrigin = Uri.tryParse(origin);
    if (uri == null ||
        storageOrigin == null ||
        uri.scheme != storageOrigin.scheme ||
        uri.host != storageOrigin.host ||
        uri.port != storageOrigin.port ||
        !uri.path.startsWith('/storage/')) {
      return resolved;
    }
    final sourcePath = uri.path.substring('/storage/'.length);
    // Demo photographs are deployment assets that are already normalized.
    // Serving them directly also avoids an expensive first-request transform
    // on small Azure App Service instances.
    if (sourcePath.startsWith('demo/')) {
      return resolved;
    }
    return Uri.parse('$apiBase/assets/image').replace(queryParameters: {
      'path': sourcePath,
      'w': width.clamp(64, 2400).toString(),
      if (height != null) 'h': height.clamp(64, 2400).toString(),
      'fit': fit,
      'format': format,
      'q': quality.clamp(45, 90).toString(),
    }).toString();
  }
}
