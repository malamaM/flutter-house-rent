import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores typed JSON with freshness metadata', () async {
    const key = 'test:fresh-record';
    await AppCache.instance.write(
      key,
      {'name': 'Haven', 'count': 3},
      freshFor: const Duration(minutes: 5),
      keepFor: const Duration(days: 1),
    );

    final record = await AppCache.instance.read(key);

    expect(record, isNotNull);
    expect(record!.isFresh, isTrue);
    expect(record.value['name'], 'Haven');
    expect(record.value['count'], 3);
  });

  test('private cache namespaces change with the signed-in user', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', 'token-for-user-one');
    final first = await AppCache.instance.privateKey('saved_houses');

    await prefs.setString('access_token', 'token-for-user-two');
    final second = await AppCache.instance.privateKey('saved_houses');

    expect(first, isNot(second));
    expect(first, isNot(contains('token-for-user-one')));
    expect(second, isNot(contains('token-for-user-two')));
  });

  test('deduplicates simultaneous refresh work', () async {
    var calls = 0;
    Future<int> operation() async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return 42;
    }

    final values = await Future.wait([
      AppCache.instance.deduplicate('test:request', operation),
      AppCache.instance.deduplicate('test:request', operation),
      AppCache.instance.deduplicate('test:request', operation),
    ]);

    expect(values, [42, 42, 42]);
    expect(calls, 1);
  });

  test('clears private records without deleting public content', () async {
    const publicKey = 'public:test:feed';
    const privateKey = 'user:abc123:test:profile';
    await AppCache.instance.write(
      publicKey,
      [1, 2],
      freshFor: const Duration(minutes: 1),
      keepFor: const Duration(days: 1),
    );
    await AppCache.instance.write(
      privateKey,
      {'email': 'private@example.com'},
      freshFor: const Duration(minutes: 1),
      keepFor: const Duration(days: 1),
    );

    await AppCache.instance.clearPrivateData();

    expect(await AppCache.instance.read(publicKey), isNotNull);
    expect(await AppCache.instance.read(privateKey), isNull);
  });
}
