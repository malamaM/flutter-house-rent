import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Persists only tiles the user actually views. This provides useful recent
/// offline maps without bulk-downloading regions or violating provider limits.
class CachedMapTileProvider extends TileProvider {
  CachedMapTileProvider._();
  static final instance = CachedMapTileProvider._();
  static const userAgentPackageName = 'com.malamachiluwe.haven';
  static const openStreetMapUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      CachedNetworkImageProvider(
        getTileUrl(coordinates, options),
        headers: headers,
        cacheKey: 'map:${coordinates.z}:${coordinates.x}:${coordinates.y}:'
            '${options.urlTemplate.hashCode}',
      );
}
