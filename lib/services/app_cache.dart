import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small, versioned cache designed for API JSON rather than binary assets.
/// Images are cached separately by cached_network_image.
class AppCache {
  AppCache._();

  static final AppCache instance = AppCache._();

  static const _schema = 2;
  static const _storagePrefix = 'haven.cache.v$_schema.';
  static const _manifestKey = 'haven.cache.v$_schema.manifest';
  static const _maxEntries = 80;
  static const _maxCharacters = 1800000;

  final Map<String, CacheRecord> _memory = {};
  final Map<String, Future<dynamic>> _inFlight = {};
  final ValueNotifier<CacheRefreshEvent?> refreshes = ValueNotifier(null);

  String publicKey(String resource) => 'public:$resource';

  Future<String> privateKey(String resource) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return 'user:${_fingerprint(token ?? 'guest')}:$resource';
  }

  Future<CacheRecord?> read(
    String logicalKey, {
    bool includeExpired = true,
  }) async {
    final now = DateTime.now();
    final memory = _memory[logicalKey];
    if (memory != null) {
      if (includeExpired || !memory.isExpiredAt(now)) return memory;
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(logicalKey));
    if (raw == null) return null;
    try {
      final record = CacheRecord.fromJson(json.decode(raw));
      if (record.schema != _schema || record.logicalKey != logicalKey) {
        await remove(logicalKey);
        return null;
      }
      _memory[logicalKey] = record;
      unawaited(_markAccessed(prefs, logicalKey));
      if (!includeExpired && record.isExpiredAt(now)) return null;
      return record;
    } catch (_) {
      await remove(logicalKey);
      return null;
    }
  }

  Future<void> write(
    String logicalKey,
    dynamic value, {
    required Duration freshFor,
    required Duration keepFor,
  }) async {
    final now = DateTime.now();
    final record = CacheRecord(
      schema: _schema,
      logicalKey: logicalKey,
      value: value,
      storedAt: now,
      freshUntil: now.add(freshFor),
      expiresAt: now.add(keepFor),
    );
    final encoded = json.encode(record.toJson());
    if (encoded.length > _maxCharacters ~/ 2) return;

    _memory[logicalKey] = record;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(logicalKey), encoded);
    await _touchManifest(prefs, logicalKey, encoded.length);
  }

  Future<T> deduplicate<T>(String key, Future<T> Function() operation) {
    final active = _inFlight[key];
    if (active != null) return active as Future<T>;
    final future = operation();
    _inFlight[key] = future;
    future.then(
      (_) => _inFlight.remove(key),
      onError: (_) => _inFlight.remove(key),
    );
    return future;
  }

  void announce(String resource, String logicalKey) {
    refreshes.value = CacheRefreshEvent(
      resource: resource,
      logicalKey: logicalKey,
      occurredAt: DateTime.now(),
    );
  }

  Future<void> remove(String logicalKey) async {
    _memory.remove(logicalKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(logicalKey));
    final manifest = _readManifest(prefs)
      ..removeWhere((item) => item.logicalKey == logicalKey);
    await _saveManifest(prefs, manifest);
  }

  Future<void> removeMatching(bool Function(String key) predicate) async {
    final prefs = await SharedPreferences.getInstance();
    final manifest = _readManifest(prefs);
    final removing =
        manifest.where((item) => predicate(item.logicalKey)).toList();
    for (final item in removing) {
      _memory.remove(item.logicalKey);
      await prefs.remove(_storageKey(item.logicalKey));
    }
    manifest.removeWhere((item) => predicate(item.logicalKey));
    await _saveManifest(prefs, manifest);
  }

  Future<void> clearPrivateData() =>
      removeMatching((key) => key.startsWith('user:'));

  /// Updates matching JSON cache entries without waiting for a round trip.
  Future<void> mutateMatching(
    bool Function(String key) predicate,
    dynamic Function(dynamic value) mutate,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = _readManifest(prefs)
        .map((item) => item.logicalKey)
        .where(predicate)
        .toList();
    for (final key in keys) {
      final current = await read(key);
      if (current == null) continue;
      await write(
        key,
        mutate(current.value),
        freshFor: current.remainingFresh,
        keepFor: current.remainingLifetime,
      );
    }
  }

  Future<CacheDiagnostics> diagnostics() async {
    final prefs = await SharedPreferences.getInstance();
    final manifest = _readManifest(prefs);
    return CacheDiagnostics(
      entries: manifest.length,
      approximateCharacters:
          manifest.fold<int>(0, (total, item) => total + item.size),
      inFlightRequests: _inFlight.length,
    );
  }

  String _storageKey(String logicalKey) =>
      '$_storagePrefix${_fingerprint(logicalKey)}';

  String _fingerprint(String input) {
    var hash = 0x811c9dc5;
    for (final code in utf8.encode(input)) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  List<_ManifestItem> _readManifest(SharedPreferences prefs) {
    final raw = prefs.getString(_manifestKey);
    if (raw == null) return [];
    try {
      return (json.decode(raw) as List)
          .map((item) => _ManifestItem.fromJson(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _touchManifest(
    SharedPreferences prefs,
    String logicalKey,
    int size,
  ) async {
    final manifest = _readManifest(prefs)
      ..removeWhere((item) => item.logicalKey == logicalKey)
      ..add(_ManifestItem(logicalKey, DateTime.now(), size));
    manifest.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));

    var total = manifest.fold<int>(0, (sum, item) => sum + item.size);
    while (manifest.length > _maxEntries || total > _maxCharacters) {
      final oldest = manifest.removeLast();
      total -= oldest.size;
      _memory.remove(oldest.logicalKey);
      await prefs.remove(_storageKey(oldest.logicalKey));
    }
    await _saveManifest(prefs, manifest);
  }

  Future<void> _markAccessed(
    SharedPreferences prefs,
    String logicalKey,
  ) async {
    final manifest = _readManifest(prefs);
    final index = manifest.indexWhere((item) => item.logicalKey == logicalKey);
    if (index < 0) return;
    final current = manifest[index];
    manifest[index] = _ManifestItem(logicalKey, DateTime.now(), current.size);
    await _saveManifest(prefs, manifest);
  }

  Future<void> _saveManifest(
    SharedPreferences prefs,
    List<_ManifestItem> manifest,
  ) =>
      prefs.setString(
        _manifestKey,
        json.encode(manifest.map((item) => item.toJson()).toList()),
      );
}

class CacheRecord {
  final int schema;
  final String logicalKey;
  final dynamic value;
  final DateTime storedAt;
  final DateTime freshUntil;
  final DateTime expiresAt;

  const CacheRecord({
    required this.schema,
    required this.logicalKey,
    required this.value,
    required this.storedAt,
    required this.freshUntil,
    required this.expiresAt,
  });

  bool get isFresh => DateTime.now().isBefore(freshUntil);
  bool get isExpired => isExpiredAt(DateTime.now());
  bool isExpiredAt(DateTime now) => now.isAfter(expiresAt);
  Duration get age => DateTime.now().difference(storedAt);
  Duration get remainingFresh {
    final value = freshUntil.difference(DateTime.now());
    return value.isNegative ? Duration.zero : value;
  }

  Duration get remainingLifetime {
    final value = expiresAt.difference(DateTime.now());
    return value.isNegative ? const Duration(minutes: 1) : value;
  }

  factory CacheRecord.fromJson(Map<String, dynamic> json) => CacheRecord(
        schema: json['schema'],
        logicalKey: json['key'],
        value: json['value'],
        storedAt: DateTime.parse(json['stored_at']),
        freshUntil: DateTime.parse(json['fresh_until']),
        expiresAt: DateTime.parse(json['expires_at']),
      );

  Map<String, dynamic> toJson() => {
        'schema': schema,
        'key': logicalKey,
        'value': value,
        'stored_at': storedAt.toIso8601String(),
        'fresh_until': freshUntil.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      };
}

class CacheRefreshEvent {
  final String resource;
  final String logicalKey;
  final DateTime occurredAt;

  const CacheRefreshEvent({
    required this.resource,
    required this.logicalKey,
    required this.occurredAt,
  });
}

class CacheDiagnostics {
  final int entries;
  final int approximateCharacters;
  final int inFlightRequests;

  const CacheDiagnostics({
    required this.entries,
    required this.approximateCharacters,
    required this.inFlightRequests,
  });
}

class _ManifestItem {
  final String logicalKey;
  final DateTime lastAccessed;
  final int size;

  const _ManifestItem(this.logicalKey, this.lastAccessed, this.size);

  factory _ManifestItem.fromJson(Map<String, dynamic> json) => _ManifestItem(
        json['key'],
        DateTime.parse(json['accessed_at']),
        json['size'],
      );

  Map<String, dynamic> toJson() => {
        'key': logicalKey,
        'accessed_at': lastAccessed.toIso8601String(),
        'size': size,
      };
}
