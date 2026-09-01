import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/screens/profile/offline_sync_screen.dart';
import 'package:house_rent/services/offline_sync_service.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/theme/app_theme.dart';
import 'package:house_rent/widgets/offline_status_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    RecommendationService.instance.setClientForTesting(null);
    await OfflineSyncService.instance.clear();
    await RecommendationService.instance.clearQueuedEvents();
  });

  tearDown(() async {
    await RecommendationService.instance.clearQueuedEvents();
  });

  testWidgets('offline sync screen has one status surface and no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const OfflineSyncScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(OfflineStatusPill), findsNothing);
    expect(find.text('Everything is synced'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background recommendation telemetry does not pin sync UI',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recommendation_event_queue_v1', [
      jsonEncode({
        'client_event_id': '44444444-4444-4444-8444-444444444444',
        'house_id': 42,
        'event_type': 'details',
        'surface': 'details',
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      }),
    ]);
    await RecommendationService.instance.pendingEventCount();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const OfflineSyncScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(OfflineStatusPill), findsNothing);
    expect(find.text('Everything is synced'), findsOneWidget);
    expect(find.text('Recommendation signals waiting'), findsNothing);
    expect(find.textContaining('recommendation signal'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
