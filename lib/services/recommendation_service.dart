import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/models/recommendation.dart';
import 'package:house_rent/models/house.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RecommendationService {
  RecommendationService._();
  static final instance = RecommendationService._();
  static const _queueKey = 'recommendation_event_queue_v1';
  Timer? _flushTimer;

  String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
      if (body is Map && body['errors'] is Map) {
        final errors = body['errors'] as Map;
        final first = errors.values.isEmpty ? null : errors.values.first;
        if (first is List && first.isNotEmpty) return '${first.first}';
      }
    } catch (_) {
      // A non-JSON error page should never leak into the user-facing message.
    }
    return fallback;
  }

  Future<String?> _token() async =>
      (await SharedPreferences.getInstance()).getString('access_token');

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
    final response = await http
        .get(Uri.parse('${ApiConfig.apiBase}/recommendation-options'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Could not load locations'));
    }
    return RecommendationOptions.fromMap(
        Map<String, dynamic>.from(jsonDecode(response.body)));
  }

  Future<void> saveProfile({
    required int cityId,
    required Set<int> areaIds,
    required int minBedrooms,
    required int maxBedrooms,
    required int minMonthlyPrice,
    required int maxMonthlyPrice,
    required Set<int> amenityIds,
    bool startNewSearch = false,
  }) async {
    final token = await _token();
    if (token == null) throw Exception('Sign in required');
    final response = await http
        .put(
          Uri.parse('${ApiConfig.apiBase}/recommendation-profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'city_id': cityId,
            'area_ids': areaIds.toList(),
            'min_bedrooms': minBedrooms,
            'max_bedrooms': maxBedrooms,
            'min_monthly_price': minMonthlyPrice,
            'max_monthly_price': maxMonthlyPrice,
            'amenity_ids': amenityIds.toList(),
            'start_new_search': startNewSearch,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception(
          _errorMessage(response, 'Could not save your rental preferences'));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('recommendation_profile_complete', true);
    await House.invalidatePropertyData();
  }

  Future<Map<String, dynamic>?> profile() async {
    final token = await _token();
    if (token == null) return null;
    final response = await http.get(
      Uri.parse('${ApiConfig.apiBase}/recommendation-profile'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final body = Map<String, dynamic>.from(jsonDecode(response.body));
    return body['profile'] is Map
        ? Map<String, dynamic>.from(body['profile'])
        : null;
  }

  Future<Map<String, dynamic>> history() async {
    final token = await _token();
    if (token == null) throw Exception('Sign in required');
    final response = await http.get(
      Uri.parse('${ApiConfig.apiBase}/recommendation-history'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Could not load recommendation history');
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
      throw Exception('Could not reset recommendation history');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
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
    await prefs.setStringList(_queueKey,
        queue.skip(queue.length > 200 ? queue.length - 200 : 0).toList());
    if (queue.length >= 12) {
      unawaited(flush());
    } else {
      _flushTimer?.cancel();
      _flushTimer = Timer(const Duration(seconds: 8), flush);
    }
  }

  Future<void> flush() async {
    _flushTimer?.cancel();
    final token = await _token();
    if (token == null) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_queueKey) ?? const [];
    if (encoded.isEmpty) return;
    final batch = encoded.take(100).map(jsonDecode).toList();
    try {
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
        await prefs.setStringList(
            _queueKey, encoded.skip(batch.length).toList());
      }
    } catch (_) {}
  }
}
