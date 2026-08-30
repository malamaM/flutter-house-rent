import 'dart:convert';

import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/models/marketplace.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/services/api_error.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MarketplaceException implements Exception {
  final String message;
  const MarketplaceException(this.message);
  @override
  String toString() => message;
}

class MarketplaceService {
  MarketplaceService._();
  static final instance = MarketplaceService._();

  static const _freshFor = Duration(minutes: 2);
  static const _keepFor = Duration(days: 14);

  Future<List<ConversationSummary>> conversations(
      {bool refresh = false}) async {
    final json = await _cachedGet(
        'marketplace:conversations:v2', 'conversations',
        refresh: refresh);
    return _pageItems(json).map(ConversationSummary.fromMap).toList();
  }

  Future<bool> hasUnreadMessages({bool refresh = false}) async {
    final conversations = await this.conversations(refresh: refresh);
    return conversations.any((conversation) => conversation.unreadCount > 0);
  }

  Future<List<ViewingSummary>> viewings({bool refresh = false}) async {
    final json = await _cachedGet('marketplace:viewings:v3', 'viewings',
        refresh: refresh);
    return _pageItems(json).map(ViewingSummary.fromMap).toList();
  }

  Future<NotificationInbox> notifications({bool refresh = false}) async {
    final json = await _cachedGet(
        'marketplace:notifications:v2', 'notifications',
        refresh: refresh);
    return NotificationInbox(
      unreadCount: (json['unread_count'] as num? ?? 0).toInt(),
      items: _pageItems(json['data'] is Map
              ? Map<String, dynamic>.from(json['data'])
              : const {})
          .map(HavenNotification.fromMap)
          .toList(),
    );
  }

  Future<int> unreadNotificationCount({bool refresh = false}) async =>
      (await notifications(refresh: refresh)).unreadCount;

  Future<List<SavedSearchSummary>> savedSearches({bool refresh = false}) async {
    final json = await _cachedGet(
        'marketplace:saved-searches:v2', 'saved-searches',
        refresh: refresh);
    return _directItems(json).map(SavedSearchSummary.fromMap).toList();
  }

  Future<bool> recommendationAlertsEnabled({bool refresh = false}) async {
    final json = await _cachedGet(
        'marketplace:saved-searches:v2', 'saved-searches',
        refresh: refresh);
    final alerts = json['home_alerts'] is Map
        ? Map<String, dynamic>.from(json['home_alerts'] as Map)
        : const <String, dynamic>{};
    return alerts['recommendation_matches_enabled'] == true ||
        alerts['recommendation_matches_enabled'] == 1;
  }

  Future<List<ChatMessage>> messages(int conversationId,
      {bool refresh = false}) async {
    final json = await _cachedGet(
      'marketplace:conversation:$conversationId:messages:v3',
      'conversations/$conversationId/messages',
      refresh: refresh,
      freshFor: const Duration(seconds: 20),
    );
    return _pageItems(json).map(ChatMessage.fromMap).toList().reversed.toList();
  }

  Future<int> startConversation(int houseId) async {
    final json = await _send('POST', 'houses/$houseId/conversation');
    await _invalidate('marketplace:conversations:v2');
    return (Map<String, dynamic>.from(json['conversation'] as Map)['id'] as num)
        .toInt();
  }

  Future<ChatMessage> sendMessage(int conversationId, String body) async {
    final json = await _send('POST', 'conversations/$conversationId/messages',
        {'body': body.trim()});
    await Future.wait([
      _invalidate('marketplace:conversation:$conversationId:messages:v3'),
      _invalidate('marketplace:conversations:v2'),
      _invalidate('marketplace:notifications:v2'),
    ]);
    return ChatMessage.fromMap(
        Map<String, dynamic>.from(json['message'] as Map));
  }

  Future<String> requestViewing(int houseId, DateTime requestedAt,
      {String? note}) async {
    final json = await _send('POST', 'houses/$houseId/viewings', {
      'requested_at': requestedAt.toUtc().toIso8601String(),
      if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
    });
    await _invalidate('marketplace:viewings:v3');
    return json['message']?.toString() ?? 'Viewing request sent.';
  }

  Future<void> updateViewing(int id, String status) async {
    await _send('PATCH', 'viewings/$id', {'status': status});
    await Future.wait([
      _invalidate('marketplace:viewings:v3'),
      _invalidate('marketplace:notifications:v2'),
    ]);
  }

  Future<ReviewEligibility> reviewEligibility(int listerId, int houseId) async {
    final json = await _send(
        'GET', 'users/$listerId/review-eligibility?house_id=$houseId');
    return ReviewEligibility(
        eligible: json['eligible'] == true, reason: json['reason']?.toString());
  }

  Future<String> reportListing(int houseId, String reason,
      {String? details}) async {
    final json = await _send('POST', 'reports', {
      'target_type': 'listing',
      'target_id': houseId,
      'reason': reason,
      if (details?.trim().isNotEmpty == true) 'details': details!.trim(),
    });
    return json['message']?.toString() ?? 'Report sent.';
  }

  Future<void> blockUser(int userId) => _send('POST', 'users/$userId/block');

  Future<void> updateAvailability(int houseId, String status) async {
    await _send('PATCH', 'houses/$houseId/availability',
        {'availability_status': status});
    await _invalidate('marketplace:viewings:v2');
  }

  Future<void> markNotificationRead(String id) async {
    await _send('PATCH', 'notifications/$id/read');
    await _invalidate('marketplace:notifications:v2');
  }

  Future<void> markAllNotificationsRead() async {
    await _send('PATCH', 'notifications/read-all');
    await _invalidate('marketplace:notifications:v2');
  }

  Future<void> createSavedSearch({
    required String name,
    required Map<String, dynamic> criteria,
    bool alertsEnabled = false,
  }) async {
    await _send('POST', 'saved-searches', {
      'name': name.trim(),
      'alerts_enabled': alertsEnabled,
      'criteria': criteria,
    });
    await _invalidate('marketplace:saved-searches:v2');
  }

  Future<void> setRecommendationAlerts(bool enabled) async {
    await _send('PATCH', 'saved-searches/home-alerts', {
      'recommendation_matches_enabled': enabled,
    });
    await _invalidate('marketplace:saved-searches:v2');
  }

  Future<void> setSavedSearchAlerts(int id, bool enabled) async {
    await _send('PATCH', 'saved-searches/$id', {'alerts_enabled': enabled});
    await _invalidate('marketplace:saved-searches:v2');
  }

  Future<void> deleteSavedSearch(int id) async {
    await _send('DELETE', 'saved-searches/$id');
    await _invalidate('marketplace:saved-searches:v2');
  }

  Future<Map<String, dynamic>> _cachedGet(
    String resource,
    String path, {
    required bool refresh,
    Duration freshFor = _freshFor,
  }) async {
    final key = await AppCache.instance.privateKey(resource);
    final cached = await AppCache.instance.read(key);
    if (!refresh && cached != null && cached.isFresh) {
      return Map<String, dynamic>.from(cached.value);
    }
    try {
      final value = await _send('GET', path);
      await AppCache.instance
          .write(key, value, freshFor: freshFor, keepFor: _keepFor);
      return value;
    } catch (_) {
      if (cached?.value is Map) return Map<String, dynamic>.from(cached!.value);
      rethrow;
    }
  }

  Future<void> _invalidate(String resource) async {
    final key = await AppCache.instance.privateKey(resource);
    await AppCache.instance.remove(key);
    AppCache.instance.announce(resource, key);
  }

  Future<Map<String, dynamic>> _send(String method, String path,
      [Map<String, dynamic>? body]) async {
    final token =
        (await SharedPreferences.getInstance()).getString('access_token');
    if (token == null) {
      throw const MarketplaceException('Please sign in first.');
    }
    try {
      final request = http.Request(
          method,
          Uri.parse(
              '${ApiConfig.apiBase}/${path.replaceFirst(RegExp(r'^/'), '')}'))
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        });
      if (body != null) request.body = json.encode(body);
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 12)),
      );
      Map<String, dynamic> decoded;
      try {
        decoded = response.body.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(json.decode(response.body));
      } catch (_) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw MarketplaceException(HavenApiException.fromResponse(response,
                  operation: 'complete this action')
              .message);
        }
        throw const FormatException('Invalid marketplace response');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MarketplaceException(
          HavenApiException.fromResponse(response,
                  operation: 'complete this action')
              .message,
        );
      }
      return decoded;
    } on MarketplaceException {
      rethrow;
    } catch (error) {
      throw MarketplaceException(ApiErrorResolver.message(
        error,
        fallback: 'Haven could not complete this marketplace action.',
      ));
    }
  }

  Iterable<Map<String, dynamic>> _pageItems(Map<String, dynamic> json) {
    final raw = json['data'];
    final list = raw is Map ? raw['data'] : raw;
    return (list as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from);
  }

  Iterable<Map<String, dynamic>> _directItems(Map<String, dynamic> json) =>
      (json['data'] as List? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from);
}
