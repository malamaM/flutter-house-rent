import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/services/app_feedback.dart';
import 'package:house_rent/services/network_status_service.dart';
import 'package:house_rent/services/session_token_store.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Durable, last-write-wins queue for small idempotent offline mutations.
///
/// Media uploads are intentionally excluded: silently retaining sensitive or
/// very large files is unsafe. Those screens keep their explicit retry flow.
class OfflineSyncService with WidgetsBindingObserver {
  OfflineSyncService._();
  static final instance = OfflineSyncService._();

  static const _queueKey = 'offline_mutation_queue_v1';
  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  Timer? _retryTimer;
  bool _initialized = false;
  bool _syncing = false;
  int _retryAttempt = 0;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    NetworkStatusService.instance.availability.addListener(_networkChanged);
    await _refreshCount();
    if (pendingCount.value > 0) _schedule(const Duration(seconds: 2));
  }

  Future<void> queueSavedState(int houseId, bool isSaved) async {
    final prefs = await SharedPreferences.getInstance();
    final actions = _read(prefs)
      ..removeWhere((action) =>
          action['type'] == 'saved_state' && action['house_id'] == houseId)
      ..add({
        'type': 'saved_state',
        'house_id': houseId,
        'is_saved': isSaved,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    await _write(prefs, actions);
    _scheduleNextRetry();
  }

  Future<void> queueRecommendationProfile(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final actions = _read(prefs)
      ..removeWhere((action) => action['type'] == 'recommendation_profile')
      ..add({
        'type': 'recommendation_profile',
        'payload': payload,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    await _write(prefs, actions);
    _scheduleNextRetry();
  }

  Future<void> queueContactMessage(int houseId, String body) async {
    final message = body.trim();
    if (message.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final actions = _read(prefs)
      ..add({
        'type': 'contact_message',
        'house_id': houseId,
        'body': message,
        'client_uuid': _uuid(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    // Keep the durable queue bounded without disturbing newer user actions.
    if (actions.length > 100) actions.removeRange(0, actions.length - 100);
    await _write(prefs, actions);
    _scheduleNextRetry();
  }

  Future<void> clear() async {
    _retryTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
    pendingCount.value = 0;
    _retryAttempt = 0;
  }

  Future<List<Map<String, dynamic>>> pendingActions() async =>
      List.unmodifiable(_read(await SharedPreferences.getInstance()));

  Future<void> discardPending() => clear();

  Future<void> flush() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = await SessionTokenStore.read();
      if (token == null) return;
      final actions = _read(prefs);
      if (actions.isEmpty) return;

      var synced = 0;
      var conflicts = 0;
      final remaining = <Map<String, dynamic>>[];
      for (final action in actions) {
        try {
          final headers = {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          };
          late final http.Response response;
          if (action['type'] == 'saved_state') {
            response = await http
                .put(
                  Uri.parse(
                      '${ApiConfig.apiBase}/houses/${action['house_id']}/saved'),
                  headers: headers,
                  body: jsonEncode({'is_saved': action['is_saved'] == true}),
                )
                .timeout(const Duration(seconds: 10));
          } else if (action['type'] == 'recommendation_profile') {
            response = await http
                .put(
                  Uri.parse('${ApiConfig.apiBase}/recommendation-profile'),
                  headers: headers,
                  body: jsonEncode(action['payload']),
                )
                .timeout(const Duration(seconds: 12));
          } else if (action['type'] == 'contact_message') {
            final conversationResponse = await http
                .post(
                  Uri.parse(
                      '${ApiConfig.apiBase}/houses/${action['house_id']}/conversation'),
                  headers: headers,
                )
                .timeout(const Duration(seconds: 12));
            if (conversationResponse.statusCode < 200 ||
                conversationResponse.statusCode >= 300) {
              response = conversationResponse;
            } else {
              final payload = Map<String, dynamic>.from(
                  jsonDecode(conversationResponse.body));
              final conversation =
                  Map<String, dynamic>.from(payload['conversation'] as Map);
              response = await http
                  .post(
                    Uri.parse(
                        '${ApiConfig.apiBase}/conversations/${conversation['id']}/messages'),
                    headers: headers,
                    body: jsonEncode({
                      'body': action['body'],
                      'client_uuid': action['client_uuid'],
                    }),
                  )
                  .timeout(const Duration(seconds: 12));
            }
          } else {
            continue;
          }
          if (response.statusCode >= 200 && response.statusCode < 300) {
            if (action['type'] == 'contact_message') {
              final key = await AppCache.instance
                  .privateKey('marketplace:conversations:v3');
              await AppCache.instance.remove(key);
              AppCache.instance.announce('marketplace:conversations:v3', key);
            }
            synced++;
          } else if (response.statusCode == 401 ||
              response.statusCode == 403 ||
              response.statusCode == 404 ||
              response.statusCode == 409 ||
              response.statusCode == 422) {
            // Permanent failures must not retry forever.
            conflicts++;
          } else {
            remaining.add(action);
          }
        } catch (_) {
          NetworkStatusService.instance.reportOffline();
          remaining.add(action);
          // One connection failure is enough; preserve the rest without
          // generating a burst of doomed requests.
          final index = actions.indexOf(action);
          remaining.addAll(actions.skip(index + 1));
          break;
        }
      }
      await _write(prefs, remaining);
      if (synced > 0) {
        _retryAttempt = 0;
        NetworkStatusService.instance.reportOnline();
        AppFeedback.success(synced == 1
            ? 'Your offline change is now synced.'
            : '$synced offline changes are now synced.');
      }
      if (conflicts > 0) {
        AppFeedback.error(
          Exception(conflicts == 1
              ? 'One offline change could not be applied because the property or account changed.'
              : '$conflicts offline changes could not be applied because the properties or account changed.'),
        );
      }
    } finally {
      _syncing = false;
      if (pendingCount.value > 0) _scheduleNextRetry();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && pendingCount.value > 0) {
      unawaited(flush());
    }
  }

  void _networkChanged() {
    if (NetworkStatusService.instance.isOnline && pendingCount.value > 0) {
      unawaited(flush());
    }
  }

  List<Map<String, dynamic>> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(
      SharedPreferences prefs, List<Map<String, dynamic>> actions) async {
    await prefs.setString(_queueKey, jsonEncode(actions));
    pendingCount.value = actions.length;
  }

  Future<void> _refreshCount() async {
    pendingCount.value = _read(await SharedPreferences.getInstance()).length;
  }

  void _schedule(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(flush()));
  }

  void _scheduleNextRetry() {
    const seconds = [10, 20, 40, 80, 160, 300];
    final base = seconds[_retryAttempt.clamp(0, seconds.length - 1)];
    _retryAttempt++;
    // Small deterministic jitter prevents every device reconnecting together.
    final jitter = Duration(milliseconds: DateTime.now().millisecond % 1700);
    _schedule(Duration(seconds: base) + jitter);
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
