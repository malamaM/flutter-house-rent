import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/services/cached_map_tile_provider.dart';

void main() {
  test('map tile configuration does not require an embedded API key', () {
    expect(CachedMapTileProvider.voyagerUrl, isNot(contains('access_token')));
    expect(CachedMapTileProvider.voyagerUrl, isNot(contains('api_key')));
    expect(
      CachedMapTileProvider.userAgentPackageName,
      'com.malamachiluwe.haven',
    );
  });
}
