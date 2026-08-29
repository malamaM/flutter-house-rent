import 'dart:async';

class ApiConfig {
  ApiConfig._();

  /// The app is intentionally live-only for now.
  static const _productionOrigin =
      'https://haven-c4fga3bbgxgjhyab.southafricanorth-01.azurewebsites.net';

  // Development routing is intentionally disabled. Keep this reference here
  // so local-server support can be restored later without being rediscovered.
  // static const _developmentHost = String.fromEnvironment(
  //   'DEV_API_HOST',
  //   defaultValue: 'malamas-MacBook-Pro.local',
  // );
  // static String get _developmentOrigin {
  //   if (kIsWeb) return 'http://127.0.0.1:8000';
  //   if (Platform.isAndroid || Platform.isIOS) {
  //     return 'http://$_developmentHost:8000';
  //   }
  //   return 'http://127.0.0.1:8000';
  // }

  static String? _sessionOrigin;
  static Future<void>? _initialization;

  /// Locks this process to the production API. An unreachable live service is
  /// surfaced as an offline/server error; it never redirects to a local host.
  static Future<void> initialize() => _initialization ??= _resolveOrigin();

  static Future<void> get ready => initialize();

  static Future<void> _resolveOrigin() async {
    _sessionOrigin = _productionOrigin;
  }

  static String get origin => _sessionOrigin ?? _productionOrigin;

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
