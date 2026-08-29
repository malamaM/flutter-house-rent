import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/cached_map_tile_provider.dart';

class HouseLocationMap extends StatefulWidget {
  final House house;
  const HouseLocationMap({Key? key, required this.house}) : super(key: key);
  @override
  State<HouseLocationMap> createState() => _HouseLocationMapState();
}

class _HouseLocationMapState extends State<HouseLocationMap> {
  final MapController _controller = MapController();
  double _zoom = 14;

  void _changeZoom(double delta) {
    final center = LatLng(widget.house.latitude!, widget.house.longitude!);
    setState(() => _zoom = (_zoom + delta).clamp(11, 18));
    _controller.move(center, _zoom);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.house.latitude == null || widget.house.longitude == null) {
      return const SizedBox.shrink();
    }
    final center = LatLng(widget.house.latitude!, widget.house.longitude!);
    final darkMap = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Approximate location',
              style: Theme.of(context).textTheme.headlineMedium)),
      const SizedBox(height: 10),
      Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 220,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Theme.of(context).colorScheme.surfaceContainer,
              border: Border.all(color: Theme.of(context).dividerColor)),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(children: [
                FlutterMap(
                    mapController: _controller,
                    options: MapOptions(
                        center: center,
                        zoom: _zoom,
                        minZoom: 11,
                        maxZoom: 18,
                        interactiveFlags: InteractiveFlag.none),
                    children: [
                      if (darkMap)
                        ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            .68,
                            0,
                            0,
                            0,
                            0,
                            0,
                            .68,
                            0,
                            0,
                            0,
                            0,
                            0,
                            .68,
                            0,
                            0,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ]),
                          child: TileLayer(
                            tileProvider: CachedMapTileProvider.instance,
                            urlTemplate: CachedMapTileProvider.openStreetMapUrl,
                            userAgentPackageName:
                                CachedMapTileProvider.userAgentPackageName,
                          ),
                        )
                      else
                        TileLayer(
                          tileProvider: CachedMapTileProvider.instance,
                          urlTemplate: CachedMapTileProvider.openStreetMapUrl,
                          userAgentPackageName:
                              CachedMapTileProvider.userAgentPackageName,
                        ),
                      CircleLayer(circles: [
                        CircleMarker(
                            point: center,
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: .3),
                            borderColor: Theme.of(context).primaryColor,
                            borderStrokeWidth: 2,
                            useRadiusInMeter: true,
                            radius: 400)
                      ]),
                    ]),
                Positioned(
                    right: 10,
                    top: 10,
                    child: Column(children: [
                      _ZoomButton(
                          icon: Icons.add_rounded,
                          tooltip: 'Zoom in',
                          onTap: () => _changeZoom(1)),
                      const SizedBox(height: 6),
                      _ZoomButton(
                          icon: Icons.remove_rounded,
                          tooltip: 'Zoom out',
                          onTap: () => _changeZoom(-1)),
                    ])),
                Positioned(
                    right: 8,
                    bottom: 7,
                    child: IgnorePointer(
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withValues(alpha: .84),
                                borderRadius: BorderRadius.circular(5)),
                            child: Text('© OpenStreetMap',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 7))))),
              ]))),
    ]);
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ZoomButton(
      {required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: IconButton(
          onPressed: onTap,
          tooltip: tooltip,
          icon: Icon(icon),
          visualDensity: VisualDensity.compact));
}
