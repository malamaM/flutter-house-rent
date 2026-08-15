import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/screens/home/filter_screen.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/custom_bottom_navigation_bar.dart';
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

  @override
  void initState() {
    super.initState();
    AppCache.instance.refreshes.addListener(_handleCacheRefresh);
    _fetch();
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
      if (houses.isNotEmpty) {
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

  void _preview(House house) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
                Navigator.push(context,
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
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(center: LatLng(-15.3875, 28.3228), zoom: 12),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.malamachiluwe.houserent',
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
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
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(15),
                    elevation: 2,
                    child: IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      color: AppColors.surface,
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
                              const Expanded(
                                  child: Text('Search this area',
                                      style: TextStyle(
                                          color: AppColors.textSecondary))),
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
        ],
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }
}
