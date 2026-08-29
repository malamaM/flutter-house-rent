import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/services/cached_map_tile_provider.dart';

void main() {
  test('map tile configuration does not require an embedded API key', () {
    expect(
      CachedMapTileProvider.openStreetMapUrl,
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    );
    expect(CachedMapTileProvider.openStreetMapUrl, isNot(contains('carto')));
    expect(
      CachedMapTileProvider.userAgentPackageName,
      'com.malamachiluwe.haven',
    );
  });
}
