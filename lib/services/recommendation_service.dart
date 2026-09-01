import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/models/recommendation.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:house_rent/services/offline_sync_service.dart';
import 'package:house_rent/services/network_status_service.dart';
import 'package:house_rent/services/session_token_store.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RecommendationService with WidgetsBindingObserver {
  RecommendationService._();
  static final instance = RecommendationService._();
  static const _queueKey = 'recommendation_event_queue_v1';
  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  Timer? _flushTimer;
  bool _flushing = false;
  bool _initialized = false;

  /// Starts durable event delivery. Events are still accepted before this is
  /// called, but initialization lets a restored network flush them promptly.
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    NetworkStatusService.instance.availability.addListener(_networkChanged);
    unawaited(_refreshPendingCount());
    unawaited(flush());
  }

  void _networkChanged() {
    if (NetworkStatusService.instance.isOnline) unawaited(flush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(flush());
  }

  Future<int> pendingEventCount() async {
    final count = (await SharedPreferences.getInstance())
            .getStringList(_queueKey)
            ?.length ??
        0;
    _setPendingCount(count);
    return count;
  }

  Future<void> _refreshPendingCount() async {
    await pendingEventCount();
  }

  void _setPendingCount(int count) {
    if (pendingCount.value != count) pendingCount.value = count;
  }

  String _errorMessage(http.Response response, String operation) {
    return ApiErrorResolver.responseDetail(response.body) ??
        ApiErrorResolver.statusMessage(response.statusCode, operation);
  }

  Future<String?> _token() => SessionTokenStore.read();

  Future<bool> needsOnboarding() async {
    final token = await _token();
    if (token == null) return false;
    final response = await http.get(
      Uri.parse('${ApiConfig.apiBase}/recommendation-profile'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return false;
    final body = Map<String, dynamic>.from(jsonDecode(response.body));
    final complete = body['complete'] == true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('recommendation_profile_complete', complete);
    return !complete;
  }

  Future<RecommendationOptions> options() async {
    final key = AppCache.instance.publicKey('recommendation-options:v2');
    final cached = await AppCache.instance.read(key);
    if (cached != null && !cached.isExpired) {
      return RecommendationOptions.fromMap(
          Map<String, dynamic>.from(cached.value));
    }
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.apiBase}/recommendation-options'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception(_errorMessage(response, 'load locations'));
      }
      final value = Map<String, dynamic>.from(jsonDecode(response.body));
      await AppCache.instance.write(key, value,
          freshFor: const Duration(days: 1), keepFor: const Duration(days: 90));
      return RecommendationOptions.fromMap(value);
    } catch (_) {
      if (cached != null) {
        return RecommendationOptions.fromMap(
            Map<String, dynamic>.from(cached.value));
      }
      rethrow;
    }
  }

  Future<void> saveProfile({
    required int cityId,
    required Set<int> areaIds,
    required int minBedrooms,
    required int maxBedrooms,
    int? minSelfContainedBedrooms,
    int? maxSelfContainedBedrooms,
    required int minMonthlyPrice,
    required int maxMonthlyPrice,
    required Set<int> amenityIds,
    bool startNewSearch = false,
  }) async {
    final token = await _token();
    if (token == null) throw Exception('Sign in required');
    final payload = <String, dynamic>{
      'city_id': cityId,
      'area_ids': areaIds.toList(),
      'min_bedrooms': minBedrooms,
      'max_bedrooms': maxBedrooms,
      if (minSelfContainedBedrooms != null)
        'min_self_contained_bedrooms': minSelfContainedBedrooms,
      if (maxSelfContainedBedrooms != null)
        'max_self_contained_bedrooms': maxSelfContainedBedrooms,
      'min_monthly_price': minMonthlyPrice,
      'max_monthly_price': maxMonthlyPrice,
      'amenity_ids': amenityIds.toList(),
      'start_new_search': startNewSearch,
    };
    http.Response? response;
    try {
      response = await http
          .put(
            Uri.parse('${ApiConfig.apiBase}/recommendation-profile'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json'
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      await OfflineSyncService.instance.queueRecommendationProfile(payload);
    } on SocketException {
      await OfflineSyncService.instance.queueRecommendationProfile(payload);
    } on http.ClientException {
      await OfflineSyncService.instance.queueRecommendationProfile(payload);
    }
    if (response != null &&
        (response.statusCode < 200 || response.statusCode >= 300)) {
      throw HavenApiException.fromResponse(
        response,
        operation: 'save your rental preferences',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('recommendation_profile_complete', true);
    final key = await AppCache.instance.privateKey('recommendation-profile:v1');
    if (response != null) {
      try {
        await House.invalidatePropertyData();
      } catch (_) {
        // Cache cleanup must not make a successfully saved profile look like
        // a failed submission.
      }
    } else {
      try {
        await AppCache.instance.write(
          key,
          {
            'city_id': cityId,
            'areas': areaIds.map((id) => {'id': id}).toList(),
            'min_bedrooms': minBedrooms,
            'max_bedrooms': maxBedrooms,
            if (minSelfContainedBedrooms != null)
              'min_self_contained_bedrooms': minSelfContainedBedrooms,
            if (maxSelfContainedBedrooms != null)
              'max_self_contained_bedrooms': maxSelfContainedBedrooms,
            'min_monthly_price': minMonthlyPrice,
            'max_monthly_price': maxMonthlyPrice,
            'amenities': amenityIds.map((id) => {'id': id}).toList(),
          },
          freshFor: const Duration(days: 1),
          keepFor: const Duration(days: 90),
        );
        AppCache.instance.announce('recommendation_profile', key);
      } catch (_) {
        // The queued mutation remains the source of truth until it syncs.
      }
    }
  }

  Future<Map<String, dynamic>?> profile() async {
    final token = await _token();
    if (token == null) return null;
    final key = await AppCache.instance.privateKey('recommendation-profile:v1');
    final cached = await AppCache.instance.read(key);
    if (cached != null && !cached.isExpired) {
      return Map<String, dynamic>.from(cached.value);
    }
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiBase}/recommendation-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = Map<String, dynamic>.from(jsonDecode(response.body));
      final profile = body['profile'] is Map
          ? Map<String, dynamic>.from(body['profile'])
          : null;
      if (profile != null) {
        await AppCache.instance.write(key, profile,
            freshFor: const Duration(hours: 6),
            keepFor: const Duration(days: 90));
      }
      return profile;
    } catch (_) {
      return cached?.value is Map
          ? Map<String, dynamic>.from(cached!.value)
          : null;
    }
  }

  Future<Map<String, dynamic>> history() async {
    final token = await _token();
    if (token == null) throw Exception('Sign in required');
    final response = await http.get(
      Uri.parse('${ApiConfig.apiBase}/recommendation-history'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HavenApiException.fromResponse(response,
          operation: 'load your recommendation history');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  Future<void> resetHistory() async {
    final token = await _token();
    if (token == null) throw Exception('Sign in required');
    final response = await http.delete(
      Uri.parse('${ApiConfig.apiBase}/recommendation-history'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HavenApiException.fromResponse(response,
          operation: 'reset your recommendation history');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
    _setPendingCount(0);
    await House.invalidatePropertyData();
  }

  Future<void> track(String type, int houseId,
      {String surface = 'reels',
      int? durationMs,
      double? completion,
      Map<String, dynamic>? metadata}) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = (prefs.getStringList(_queueKey) ?? []).toList();
    final random = Random.secure();
    String hex(int count) =>
        List.generate(count, (_) => random.nextInt(16).toRadixString(16))
            .join();
    final id =
        '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + random.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
    queue.add(jsonEncode({
      'client_event_id': id,
      'house_id': houseId,
      'event_type': type,
      'surface': surface,
      if (durationMs != null) 'duration_ms': durationMs,
      if (completion != null) 'completion': completion.clamp(0, 1),
      if (metadata != null) 'metadata': metadata,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    }));
    final persisted =
        queue.skip(queue.length > 200 ? queue.length - 200 : 0).toList();
    await prefs.setStringList(_queueKey, persisted);
    _setPendingCount(persisted.length);
    if (queue.length >= 12) {
      unawaited(flush());
    } else {
      _flushTimer?.cancel();
      _flushTimer = Timer(const Duration(seconds: 8), flush);
    }
  }

  Future<void> clearQueuedEvents() async {
    _flushTimer?.cancel();
    await (await SharedPreferences.getInstance()).remove(_queueKey);
    _setPendingCount(0);
  }

  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    _flushTimer?.cancel();
    try {
      final token = await _token();
      if (token == null) return;
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getStringList(_queueKey) ?? const [];
      if (encoded.isEmpty) {
        _setPendingCount(0);
        return;
      }
      final batch = encoded.take(100).map(jsonDecode).toList();
      final response = await http
          .post(
            Uri.parse('${ApiConfig.apiBase}/recommendation-events/batch'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json'
            },
            body: jsonEncode({'events': batch}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 202) {
        final remaining = encoded.skip(batch.length).toList();
        await prefs.setStringList(_queueKey, remaining);
        _setPendingCount(remaining.length);
        if (encoded.length > batch.length) {
          _flushTimer = Timer(const Duration(seconds: 2), flush);
        }
      } else {
        _flushTimer = Timer(const Duration(seconds: 30), flush);
      }
    } catch (_) {
      // Behavioural signals are valuable but never block the UI. They remain
      // durable and retry quietly when the network becomes available again.
      _flushTimer = Timer(const Duration(seconds: 30), flush);
    } finally {
      _flushing = false;
    }
  }
}
