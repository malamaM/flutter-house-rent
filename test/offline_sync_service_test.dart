import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/services/offline_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OfflineSyncService.instance.clear();
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
}
