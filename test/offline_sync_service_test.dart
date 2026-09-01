import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/services/offline_sync_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    RecommendationService.instance.setClientForTesting(null);
    await OfflineSyncService.instance.clear();
    await RecommendationService.instance.clearQueuedEvents();
  });

  tearDown(() async {
    RecommendationService.instance.setClientForTesting(null);
    await RecommendationService.instance.clearQueuedEvents();
  });

  test('contact messages are retained with a stable idempotency identifier',
      () async {
    await OfflineSyncService.instance
        .queueContactMessage(42, ' Is this home available? ');

    final actions = await OfflineSyncService.instance.pendingActions();
    expect(actions, hasLength(1));
    expect(actions.single['type'], 'contact_message');
    expect(actions.single['house_id'], 42);
    expect(actions.single['body'], 'Is this home available?');
    expect(
      actions.single['client_uuid'],
      matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
  });

  test('recommendation queue publishes its pending count for live sync UI',
      () async {
    await RecommendationService.instance.track('details', 42);

    expect(RecommendationService.instance.pendingCount.value, 1);
    expect(await RecommendationService.instance.pendingEventCount(), 1);

    await RecommendationService.instance.clearQueuedEvents();
    expect(RecommendationService.instance.pendingCount.value, 0);
  });

  test('a successful recommendation response drains the banner queue',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', 'test-token');
    var requests = 0;
    RecommendationService.instance
        .setClientForTesting(MockClient((request) async {
      requests++;
      return http.Response('{}', 200);
    }));

    await RecommendationService.instance.track('details', 42);
    await RecommendationService.instance.flush();

    expect(requests, 1);
    expect(RecommendationService.instance.pendingCount.value, 0);
    expect(await RecommendationService.instance.pendingEventCount(), 0);
  });

  test('stale recommendation events are discarded instead of retrying forever',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', 'test-token');
    await prefs.setStringList('recommendation_event_queue_v1', [
      jsonEncode({
        'client_event_id': '33333333-3333-4333-8333-333333333333',
        'house_id': 42,
        'event_type': 'details',
        'surface': 'details',
        'occurred_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 8))
            .toIso8601String(),
      }),
    ]);
    var requests = 0;
    RecommendationService.instance
        .setClientForTesting(MockClient((request) async {
      requests++;
      return http.Response('{}', 202);
    }));

    await RecommendationService.instance.flush();

    expect(requests, 0);
    expect(RecommendationService.instance.pendingCount.value, 0);
    expect(await RecommendationService.instance.pendingEventCount(), 0);
  });

  test('permanent recommendation responses clear rejected telemetry', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', 'test-token');
    RecommendationService.instance
        .setClientForTesting(MockClient((request) async {
      return http.Response('{"message":"validation failed"}', 422);
    }));

    await RecommendationService.instance.track('details', 42);
    await RecommendationService.instance.flush();

    expect(RecommendationService.instance.pendingCount.value, 0);
  });

  test('temporary recommendation failures remain queued for retry', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', 'test-token');
    RecommendationService.instance
        .setClientForTesting(MockClient((request) async {
      return http.Response('', 503);
    }));

    await RecommendationService.instance.track('details', 42);
    await RecommendationService.instance.flush();

    expect(RecommendationService.instance.pendingCount.value, 1);
  });
}
