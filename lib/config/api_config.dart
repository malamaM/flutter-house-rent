import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:http/http.dart' as http;

class ApiConfig {
  ApiConfig._();

  static const _envOrigin = String.fromEnvironment('API_ORIGIN');
  static const _developmentHost = String.fromEnvironment(
    'DEV_API_HOST',
    defaultValue: 'malamas-MacBook-Pro.local',
  );

  /// Production server URL used when building release versions if API_ORIGIN is omitted.
  static const _productionOrigin =
      'https://haven-c4fga3bbgxgjhyab.southafricanorth-01.azurewebsites.net';

  static String? _sessionOrigin;
  static Future<void>? _initialization;

  /// Resolves the API once for this process. The app prefers Azure and only
  /// falls back to the development server when Azure is unreachable during
  /// startup. It never changes origin later in the session.
  static Future<void> initialize() => _initialization ??= _resolveOrigin();

  static Future<void> get ready => initialize();

  static Future<void> _resolveOrigin() async {
    if (_envOrigin.isNotEmpty) {
      _sessionOrigin = _normalize(_envOrigin);
      return;
    }

    final candidates = <String>[
      _productionOrigin,
      _developmentOrigin,
    ];
    for (final candidate in candidates) {
      if (await _isHealthy(candidate)) {
        _sessionOrigin = candidate;
        return;
      }
    }

    // Keep the preferred live origin while offline. This prevents a transient
    // network loss from silently moving an authenticated session elsewhere.
    _sessionOrigin = _productionOrigin;
  }

  static Future<bool> _isHealthy(String candidate) async {
    try {
      final response = await http
          .get(Uri.parse('$candidate/api/health'))
          .timeout(const Duration(milliseconds: 2800));
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final payload = jsonDecode(response.body);
      return payload is Map && payload['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  static String _normalize(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  static String get _developmentOrigin {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid || Platform.isIOS) {
      return 'http://$_developmentHost:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  /// Server origin:
  /// 1. Uses `--dart-define=API_ORIGIN=...` if provided.
  /// 2. In Release/Production mode: defaults to your live production HTTPS domain.
  /// 3. In Debug mode: mobile builds use the Mac's Bonjour hostname so both
  ///    simulators and physical devices survive DHCP address changes. Desktop
  ///    and web builds continue to use loopback.
  static String get origin {
    if (_sessionOrigin != null) return _sessionOrigin!;
    if (_envOrigin.isNotEmpty) {
      return _normalize(_envOrigin);
    }
    if (kReleaseMode) {
      return _productionOrigin;
    }
    return _developmentOrigin;
  }

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
