import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Versioned stale-while-revalidate storage for API JSON.
///
/// SQLite keeps larger feed payloads away from SharedPreferences and provides
/// bounded LRU eviction without repeatedly rewriting a cache manifest.
class AppCache {
  AppCache._();

  static final AppCache instance = AppCache._();
  static const _schema = 6;
  static const _maxEntries = 100;
  static const _maxBytes = 8 * 1024 * 1024;

  final Map<String, CacheRecord> _memory = {};
  final Map<String, Future<dynamic>> _inFlight = {};
  final ValueNotifier<CacheRefreshEvent?> refreshes = ValueNotifier(null);
  Database? _database;

  String publicKey(String resource) => 'public:$resource';

  Future<String> privateKey(String resource) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return 'user:${_fingerprint(token ?? 'guest')}:$resource';
  }

  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await openDatabase(
      path.join(await getDatabasesPath(), 'haven_api_cache.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE api_cache (
          cache_key TEXT PRIMARY KEY,
          payload TEXT NOT NULL,
          stored_at INTEGER NOT NULL,
          fresh_until INTEGER NOT NULL,
          expires_at INTEGER NOT NULL,
          accessed_at INTEGER NOT NULL,
          byte_size INTEGER NOT NULL
        )
      '''),
    );
    return _database!;
  }

  Future<CacheRecord?> read(String logicalKey,
      {bool includeExpired = true}) async {
    final now = DateTime.now();
    final memory = _memory[logicalKey];
    if (memory != null) {
      return includeExpired || !memory.isExpiredAt(now) ? memory : null;
    }
    final db = await _db;
    final rows = await db.query('api_cache',
        where: 'cache_key = ?', whereArgs: [logicalKey], limit: 1);
    if (rows.isEmpty) return null;
    try {
      final row = rows.first;
      final record = CacheRecord(
        schema: _schema,
        logicalKey: logicalKey,
        value: json.decode(row['payload'] as String),
        storedAt: DateTime.fromMillisecondsSinceEpoch(row['stored_at'] as int),
        freshUntil:
            DateTime.fromMillisecondsSinceEpoch(row['fresh_until'] as int),
        expiresAt:
            DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int),
      );
      _memory[logicalKey] = record;
      unawaited(db.update(
          'api_cache', {'accessed_at': now.millisecondsSinceEpoch},
          where: 'cache_key = ?', whereArgs: [logicalKey]));
      return includeExpired || !record.isExpiredAt(now) ? record : null;
    } catch (_) {
      await remove(logicalKey);
      return null;
    }
  }

  Future<void> write(String logicalKey, dynamic value,
      {required Duration freshFor, required Duration keepFor}) async {
    final now = DateTime.now();
    final encoded = json.encode(value);
    if (encoded.length > _maxBytes ~/ 2) return;
    final record = CacheRecord(
      schema: _schema,
      logicalKey: logicalKey,
      value: value,
      storedAt: now,
      freshUntil: now.add(freshFor),
      expiresAt: now.add(keepFor),
    );
    _memory[logicalKey] = record;
    final db = await _db;
    await db.insert(
      'api_cache',
      {
        'cache_key': logicalKey,
        'payload': encoded,
        'stored_at': now.millisecondsSinceEpoch,
        'fresh_until': record.freshUntil.millisecondsSinceEpoch,
        'expires_at': record.expiresAt.millisecondsSinceEpoch,
        'accessed_at': now.millisecondsSinceEpoch,
        'byte_size': encoded.length,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _evict(db);
  }

  Future<T> deduplicate<T>(String key, Future<T> Function() operation) {
    final active = _inFlight[key];
    if (active != null) return active as Future<T>;
    final future = operation();
    _inFlight[key] = future;
    // Do not use an unobserved `whenComplete` future here: when the request
    // fails it creates a second unhandled error even if the caller catches the
    // original one (which surfaced as repeated ClientSocketException reports).
    future.then<void>(
      (_) {
        _inFlight.remove(key);
      },
      onError: (Object _, StackTrace __) {
        _inFlight.remove(key);
      },
    );
    return future;
  }

  Future<List<dynamic>> valuesMatching(
      bool Function(String key) predicate) async {
    final db = await _db;
    final rows = await db.query('api_cache', columns: ['cache_key']);
    final values = <dynamic>[];
    for (final row in rows) {
      final key = row['cache_key'] as String;
      if (!predicate(key)) continue;
      final record = await read(key);
      if (record != null) values.add(record.value);
    }
    return values;
  }

  void announce(String resource, String logicalKey) {
    refreshes.value = CacheRefreshEvent(
        resource: resource, logicalKey: logicalKey, occurredAt: DateTime.now());
  }

  Future<void> remove(String logicalKey) async {
    _memory.remove(logicalKey);
    await (await _db)
        .delete('api_cache', where: 'cache_key = ?', whereArgs: [logicalKey]);
  }

  Future<void> removeMatching(bool Function(String key) predicate) async {
    final db = await _db;
    final rows = await db.query('api_cache', columns: ['cache_key']);
    final keys =
        rows.map((row) => row['cache_key'] as String).where(predicate).toList();
    if (keys.isEmpty) return;
    await db.transaction((txn) async {
      for (final key in keys) {
        _memory.remove(key);
        await txn.delete('api_cache', where: 'cache_key = ?', whereArgs: [key]);
      }
    });
  }

  Future<void> clearPrivateData() =>
      removeMatching((key) => key.startsWith('user:'));

  /// Clears downloaded API content while retaining the cached identity needed
  /// for offline sign-in continuity. Pending mutations and listing drafts live
  /// in separate stores and are never removed here.
  Future<void> clearContentCache() => removeMatching(
      (key) => !key.endsWith(':current_user') && !key.contains('current_user'));

  Future<void> mutateMatching(bool Function(String key) predicate,
      dynamic Function(dynamic value) mutate) async {
    final db = await _db;
    final rows = await db.query('api_cache', columns: ['cache_key']);
    for (final row in rows) {
      final key = row['cache_key'] as String;
      if (!predicate(key)) continue;
      final current = await read(key);
      if (current == null) continue;
      await write(key, mutate(current.value),
          freshFor: current.remainingFresh, keepFor: current.remainingLifetime);
    }
  }

  Future<CacheDiagnostics> diagnostics() async {
    final result = await (await _db).rawQuery(
        'SELECT COUNT(*) AS entries, COALESCE(SUM(byte_size), 0) AS bytes FROM api_cache');
    return CacheDiagnostics(
      entries: (result.first['entries'] as num).toInt(),
      approximateCharacters: (result.first['bytes'] as num).toInt(),
      inFlightRequests: _inFlight.length,
    );
  }

  /// Authentication continuity is retained separately from feed data, so a
  /// cached user profile must not make the UI claim homes are available
  /// offline on a first launch.
  Future<bool> hasDownloadedContent() async {
    final rows = await (await _db).query('api_cache', columns: ['cache_key']);
    return rows.any((row) {
      final key = row['cache_key'] as String;
      return !key.endsWith(':current_user') && !key.contains('current_user');
    });
  }

  Future<void> _evict(Database db) async {
    await db.delete('api_cache',
        where: 'expires_at < ?',
        whereArgs: [DateTime.now().millisecondsSinceEpoch]);
    final totals = await db.rawQuery(
        'SELECT COUNT(*) AS entries, COALESCE(SUM(byte_size), 0) AS bytes FROM api_cache');
    var entries = (totals.first['entries'] as num).toInt();
    var bytes = (totals.first['bytes'] as num).toInt();
    while (entries > _maxEntries || bytes > _maxBytes) {
      final oldest = await db.query('api_cache',
          columns: ['cache_key', 'byte_size'],
          orderBy: 'accessed_at ASC',
          limit: 1);
      if (oldest.isEmpty) break;
      final key = oldest.first['cache_key'] as String;
      bytes -= oldest.first['byte_size'] as int;
      entries--;
      _memory.remove(key);
      await db.delete('api_cache', where: 'cache_key = ?', whereArgs: [key]);
    }
  }

  String _fingerprint(String input) {
    var hash = 0x811c9dc5;
    for (final code in utf8.encode(input)) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class CacheRecord {
  final int schema;
  final String logicalKey;
  final dynamic value;
  final DateTime storedAt;
  final DateTime freshUntil;
  final DateTime expiresAt;

  const CacheRecord(
      {required this.schema,
      required this.logicalKey,
      required this.value,
      required this.storedAt,
      required this.freshUntil,
      required this.expiresAt});

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
}

class CacheRefreshEvent {
  final String resource;
  final String logicalKey;
  final DateTime occurredAt;
  const CacheRefreshEvent(
      {required this.resource,
      required this.logicalKey,
      required this.occurredAt});
}

class CacheDiagnostics {
  final int entries;
  final int approximateCharacters;
  final int inFlightRequests;
  const CacheDiagnostics(
      {required this.entries,
      required this.approximateCharacters,
      required this.inFlightRequests});
}
