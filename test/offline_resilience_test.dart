import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/services/listing_draft_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('failed deduplicated requests are removed and can retry', () async {
    var attempts = 0;
    Future<int> operation() async {
      attempts++;
      throw const FormatException('offline');
    }

    await expectLater(
        AppCache.instance.deduplicate<int>('offline-test', operation),
        throwsFormatException);
    await expectLater(
        AppCache.instance.deduplicate<int>('offline-test', operation),
        throwsFormatException);
    expect(attempts, 2);
  });

  test('listing drafts survive a new service read and can be cleared',
      () async {
    SharedPreferences.setMockInitialValues({});
    await ListingDraftService.instance.save('test-draft', {
      'title': 'Offline Kabulonga home',
      'price': '5000',
      'gallery': <String>[],
    });

    final restored = await ListingDraftService.instance.load('test-draft');
    expect(restored?['title'], 'Offline Kabulonga home');
    expect(restored?['saved_at'], isNotNull);

    await ListingDraftService.instance.clear('test-draft');
    expect(await ListingDraftService.instance.load('test-draft'), isNull);
  });
}
