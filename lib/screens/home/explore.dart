import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/services/current_location_service.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/screens/home/filter_screen.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:latlong2/latlong.dart';

class Explore extends StatefulWidget {
  const Explore({Key? key}) : super(key: key);

  @override
  State<Explore> createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  final MapController mapController = MapController();
  Map<String, String> filters = {};
  List<House> houses = [];
  bool loading = true;
  LatLng? currentLocation;
  bool _mapReady = false;
  bool _centeredOnUser = false;

  @override
  void initState() {
    super.initState();
    AppCache.instance.refreshes.addListener(_handleCacheRefresh);
    _fetch();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation({bool refresh = false}) async {
    final position = refresh
        ? await CurrentLocationService.instance.refresh()
        : await CurrentLocationService.instance.warm();
    if (!mounted || position == null) return;
    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });
    _centerOnCurrentLocation();
  }

  void _centerOnCurrentLocation() {
    if (!_mapReady || currentLocation == null) return;
    mapController.move(currentLocation!, 14.5);
    _centeredOnUser = true;
  }

  void _onMapReady() {
    _mapReady = true;
    if (currentLocation != null) {
      _centerOnCurrentLocation();
    } else if (houses.isNotEmpty) {
      mapController.move(
          LatLng(houses.first.latitude!, houses.first.longitude!), 12.5);
    }
  }

  void _handleCacheRefresh() {
    if (AppCache.instance.refreshes.value?.resource == 'houses' && mounted) {
      _fetch(showLoading: false);
    }
  }

  @override
  void dispose() {
    AppCache.instance.refreshes.removeListener(_handleCacheRefresh);
    super.dispose();
  }

  Future<void> _fetch({bool showLoading = true}) async {
    if (showLoading) setState(() => loading = true);
    try {
      final result = await House.fetchHouses(filters: filters);
      if (!mounted) return;
      setState(() {
        houses = result
            .where((item) => item.latitude != null && item.longitude != null)
            .toList();
        loading = false;
      });
      if (_mapReady &&
          !_centeredOnUser &&
          currentLocation == null &&
          houses.isNotEmpty) {
        mapController.move(
            LatLng(houses.first.latitude!, houses.first.longitude!), 12.5);
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openFilters() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FilterScreen(initialFilters: filters)),
    );
    if (result is Map<String, String>) {
      setState(() => filters = result);
      _fetch();
    }
  }

  Future<void> _preview(House house) async {
    final tabNavigator = Navigator.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 18),
            PropertyCard(
              horizontal: true,
              house: house,
              onTap: () {
                Navigator.pop(context);
                tabNavigator.push(
                    MaterialPageRoute(builder: (_) => Details(house: house)));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkMap = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
                center: LatLng(-15.3875, 28.3228),
                zoom: 12,
                maxZoom: 18,
                onMapReady: _onMapReady),
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
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.malamachiluwe.houserent',
                  ),
                )
              else
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.malamachiluwe.houserent',
                ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  disableClusteringAtZoom: 18,
                  zoomToBoundsOnClick: true,
                  spiderfyCluster: true,
                  spiderfyCircleRadius: 48,
                  size: const Size(46, 46),
                  anchor: AnchorPos.align(AnchorAlign.center),
                  fitBoundsOptions: const FitBoundsOptions(
                      padding: EdgeInsets.all(54), maxZoom: 15),
                  markers: houses
                      .map((house) => Marker(
                            point: LatLng(house.latitude!, house.longitude!),
                            width: 54,
                            height: 54,
                            builder: (_) => GestureDetector(
                              onTap: () => _preview(house),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceDark,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 3),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 10,
                                        offset: Offset(0, 4))
                                  ],
                                ),
                                child: const Icon(Icons.home_rounded,
                                    color: Colors.white, size: 22),
                              ),
                            ),
                          ))
                      .toList(),
                  builder: (_, markers) => Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: Text('${markers.length}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              if (currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation!,
                      width: 30,
                      height: 30,
                      builder: (_) => Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1677FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 8)
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(15),
                      elevation: 2,
                      child: InkWell(
                        onTap: _openFilters,
                        borderRadius: BorderRadius.circular(15),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, size: 21),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text('Search this area',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant))),
                              const Icon(Icons.tune_rounded,
                                  color: AppColors.primary, size: 20),
                              if (filters.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle),
                                  child: Text('${filters.length}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 156,
            child: FloatingActionButton.small(
              heroTag: 'map-current-location',
              onPressed: () => _loadCurrentLocation(refresh: true),
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: AppColors.primary,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                loading
                    ? 'Finding homes…'
                    : '${houses.length} homes on the map',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 100,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: .84),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  darkMap ? '© OpenStreetMap © CARTO' : '© OpenStreetMap',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
