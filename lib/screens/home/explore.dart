import 'dart:async';

import 'package:flutter/material.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/services/app_feedback.dart';
import 'package:house_rent/services/current_location_service.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/services/cached_map_tile_provider.dart';
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
  final DraggableScrollableController _resultsSheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Map<String, String> filters = {};
  List<House> houses = [];
  bool loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _requestGeneration = 0;
  Timer? _searchDebounce;
  LatLng? currentLocation;
  bool _mapReady = false;
  bool _centeredOnUser = false;
  List<_AreaOption> _areaOptions = const [];
  Set<int> _preferredAreaIds = const {};
  Object? _resultsError;

  @override
  void initState() {
    super.initState();
    AppCache.instance.refreshes.addListener(_handleCacheRefresh);
    _fetch();
    _loadCurrentLocation();
    _loadAreaOptions();
    _searchFocus.addListener(_refreshSuggestions);
  }

  Future<void> _loadAreaOptions() async {
    try {
      final results = await Future.wait([
        RecommendationService.instance.options(),
        RecommendationService.instance.profile(),
      ]);
      final options = results[0] as dynamic;
      final profile = results[1] as Map<String, dynamic>?;
      final preferred =
          (profile?['areas'] is List ? profile!['areas'] as List : const [])
              .whereType<Map>()
              .map((area) => int.tryParse('${area['id']}') ?? 0)
              .where((id) => id > 0)
              .toSet();
      final areas = <_AreaOption>[
        for (final city in options.cities)
          for (final area in city.areas)
            _AreaOption(area.id, area.name, city.name, city.province),
      ];
      if (!mounted) return;
      setState(() {
        _areaOptions = areas;
        _preferredAreaIds = preferred;
      });
    } catch (_) {
      // Free-text search remains available if suggestions cannot be loaded.
    }
  }

  void _refreshSuggestions() {
    // Do not rebuild synchronously while the text field is acquiring focus.
    // Let Flutter paint the focused field/keyboard first, then reveal the
    // recommendation menu on the next frame.
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  List<_AreaOption> get _suggestedAreas {
    final query = _searchController.text.trim().toLowerCase();
    final rankedDistricts = houses
        .take(12)
        .map((house) => house.district?.toLowerCase())
        .whereType<String>()
        .toSet();
    final matches = _areaOptions.where((option) {
      if (query.isEmpty) return true;
      return option.name.toLowerCase().contains(query) ||
          option.city.toLowerCase().contains(query) ||
          option.province.toLowerCase().contains(query);
    }).toList();
    matches.sort((a, b) {
      int score(_AreaOption option) {
        var value = _preferredAreaIds.contains(option.id) ? 100 : 0;
        if (rankedDistricts.contains(option.name.toLowerCase())) value += 30;
        if (query.isNotEmpty && option.name.toLowerCase().startsWith(query)) {
          value += 20;
        }
        return value;
      }

      final byScore = score(b).compareTo(score(a));
      return byScore != 0 ? byScore : a.name.compareTo(b.name);
    });
    return matches.take(6).toList();
  }

  void _selectArea(_AreaOption area) {
    _searchDebounce?.cancel();
    _searchController.text = area.name;
    _searchFocus.unfocus();
    _search(area.name, immediate: true);
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
    } else {
      final mapped = houses
          .where((house) => house.latitude != null && house.longitude != null)
          .toList();
      if (mapped.isEmpty) return;
      mapController.move(
          LatLng(mapped.first.latitude!, mapped.first.longitude!), 12.5);
    }
  }

  void _handleCacheRefresh() {
    final event = AppCache.instance.refreshes.value;
    final isActiveTabRefresh =
        event?.resource == 'tab-refresh' && event?.logicalKey == '1';
    if ((event?.resource == 'houses' || isActiveTabRefresh) && mounted) {
      if (isActiveTabRefresh && _resultsSheetController.isAttached) {
        unawaited(_resultsSheetController.animateTo(
          .18,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        ));
      }
      _fetch(showLoading: false, forceRefresh: isActiveTabRefresh);
    }
  }

  @override
  void dispose() {
    AppCache.instance.refreshes.removeListener(_handleCacheRefresh);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus
      ..removeListener(_refreshSuggestions)
      ..dispose();
    _resultsSheetController.dispose();
    super.dispose();
  }

  Future<void> _fetch({
    bool showLoading = true,
    bool reset = true,
    bool panToResults = false,
    bool forceRefresh = false,
  }) async {
    if (_loadingMore && !reset) return;
    final generation = reset ? ++_requestGeneration : _requestGeneration;
    final requestedPage = reset ? 1 : _page + 1;
    if (showLoading && mounted) {
      setState(() {
        loading = true;
        _resultsError = null;
      });
    }
    if (!reset && mounted) setState(() => _loadingMore = true);
    try {
      final result = await House.fetchHouses(filters: {
        ...filters,
        'page': '$requestedPage',
        'per_page': '20',
      }, forceRefresh: forceRefresh);
      if (!mounted || generation != _requestGeneration) return;
      final located = result
          .where((item) => item.latitude != null && item.longitude != null)
          .toList();
      setState(() {
        houses = reset ? result : [...houses, ...result];
        _page = requestedPage;
        _hasMore = result.length == 20;
        loading = false;
        _loadingMore = false;
        _resultsError = null;
      });
      if (panToResults && located.isNotEmpty) {
        _panToResults(located);
      } else if (_mapReady &&
          !_centeredOnUser &&
          currentLocation == null &&
          located.isNotEmpty) {
        mapController.move(
            LatLng(located.first.latitude!, located.first.longitude!), 12.5);
      }
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          loading = false;
          _loadingMore = false;
          _resultsError = error;
        });
      }
    }
  }

  void _panToResults(List<House> results) {
    if (!_mapReady || results.isEmpty) return;
    final latitude = results
            .map((house) => house.latitude!)
            .reduce((left, right) => left + right) /
        results.length;
    final longitude = results
            .map((house) => house.longitude!)
            .reduce((left, right) => left + right) /
        results.length;
    mapController.move(LatLng(latitude, longitude), 13.5);
  }

  void _search(String value, {bool immediate = false}) {
    _searchDebounce?.cancel();
    void apply() {
      final keyword = value.trim();
      setState(() {
        if (keyword.isEmpty) {
          filters.remove('keyword');
        } else {
          filters['keyword'] = keyword;
        }
      });
      _fetch(panToResults: keyword.isNotEmpty);
    }

    if (immediate) {
      apply();
    } else {
      _searchDebounce = Timer(const Duration(milliseconds: 450), apply);
    }
  }

  void _loadMore() {
    if (!loading && !_loadingMore && _hasMore) {
      _fetch(showLoading: false, reset: false);
    }
  }

  Future<void> _openFilters() async {
    final result = await Navigator.push(
      context,
      HavenPageRoute(builder: (_) => FilterScreen(initialFilters: filters)),
    );
    if (result is Map<String, String>) {
      _searchController.text = result['keyword'] ?? '';
      setState(() => filters = result);
      _fetch(panToResults: result.isNotEmpty);
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
                tabNavigator.push(Details.route(house));
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
                    tileProvider: CachedMapTileProvider.instance,
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.malamachiluwe.houserent',
                  ),
                )
              else
                TileLayer(
                  tileProvider: CachedMapTileProvider.instance,
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
                      .where((house) =>
                          house.latitude != null && house.longitude != null)
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
              child: TapRegion(
                groupId: 'map-search-region',
                onTapOutside: (_) {
                  if (_searchFocus.hasFocus) {
                    _searchFocus.unfocus();
                    if (mounted) setState(() {});
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapSearchBar(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onTap: () {
                        if (!_searchFocus.hasFocus) {
                          _searchFocus.requestFocus();
                        }
                        _refreshSuggestions();
                      },
                      filterCount: filters.length,
                      onChanged: (value) {
                        setState(() {});
                        _search(value);
                      },
                      onSubmitted: (value) => _search(value, immediate: true),
                      onFilters: _openFilters,
                    ),
                    if (_searchFocus.hasFocus && _areaOptions.isNotEmpty)
                      _AreaSuggestions(
                        areas: _suggestedAreas,
                        personalized: _searchController.text.trim().isEmpty,
                        onSelected: _selectArea,
                      ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 72, right: 16),
                child: FloatingActionButton.small(
                  heroTag: 'map-current-location',
                  tooltip: 'Centre on my location',
                  onPressed: () => _loadCurrentLocation(refresh: true),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.my_location_rounded),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 238,
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
          _ResultsSheet(
            controller: _resultsSheetController,
            houses: houses,
            loading: loading,
            loadingMore: _loadingMore,
            errorMessage: _resultsError == null
                ? null
                : AppFeedback.messageFor(_resultsError!,
                    fallback: 'Haven could not load homes for this map area.'),
            hasFilters: filters.isNotEmpty,
            onRetry: () => _fetch(panToResults: true),
            onLoadMore: _loadMore,
            onOpen: (house) => Navigator.push(context, Details.route(house)),
          ),
        ],
      ),
    );
  }
}

class _MapSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final int filterCount;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilters;

  const _MapSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onTap,
    required this.filterCount,
    required this.onChanged,
    required this.onSubmitted,
    required this.onFilters,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        elevation: 2,
        child: SizedBox(
          height: 52,
          child: Row(children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onTap: onTap,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search an area',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            Stack(alignment: Alignment.topRight, children: [
              IconButton(
                onPressed: onFilters,
                icon: const Icon(Icons.tune_rounded,
                    color: AppColors.primary, size: 20),
              ),
              if (filterCount > 0)
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: Text('$filterCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
            const SizedBox(width: 3),
          ]),
        ),
      );
}

class _AreaOption {
  final int id;
  final String name;
  final String city;
  final String province;

  const _AreaOption(this.id, this.name, this.city, this.province);
}

class _AreaSuggestions extends StatelessWidget {
  final List<_AreaOption> areas;
  final bool personalized;
  final ValueChanged<_AreaOption> onSelected;

  const _AreaSuggestions({
    required this.areas,
    required this.personalized,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (areas.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
              color: Color(0x24000000), blurRadius: 24, offset: Offset(0, 9))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 11, 15, 5),
          child: Row(children: [
            Icon(
              personalized
                  ? Icons.auto_awesome_rounded
                  : Icons.location_on_outlined,
              size: 15,
              color: colors.primary,
            ),
            const SizedBox(width: 7),
            Text(
              personalized ? 'Suggested for you' : 'Matching areas',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: colors.primary),
            ),
          ]),
        ),
        for (final area in areas)
          InkWell(
            onTap: () => onSelected(area),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              child: Row(children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(area.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('${area.city}, ${area.province}',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        const SizedBox(height: 5),
      ]),
    );
  }
}

class _ResultsSheet extends StatelessWidget {
  final DraggableScrollableController controller;
  final List<House> houses;
  final bool loading;
  final bool loadingMore;
  final String? errorMessage;
  final bool hasFilters;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final ValueChanged<House> onOpen;

  const _ResultsSheet({
    required this.controller,
    required this.houses,
    required this.loading,
    required this.loadingMore,
    required this.errorMessage,
    required this.hasFilters,
    required this.onLoadMore,
    required this.onRetry,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: DraggableScrollableSheet(
          controller: controller,
          initialChildSize: .18,
          minChildSize: .14,
          maxChildSize: .82,
          snap: true,
          snapSizes: const [.18, .48, .82],
          builder: (context, controller) => Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 500) onLoadMore();
                return false;
              },
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(children: [
                      const SizedBox(height: 9),
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: .28),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              hasFilters
                                  ? 'Homes matching your search'
                                  : 'Recommended around you',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Text('${houses.length}',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ]),
                      ),
                    ]),
                  ),
                  if (loading && houses.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (errorMessage != null && houses.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.cloud_off_outlined, size: 32),
                            const SizedBox(height: 10),
                            Text(errorMessage!, textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            TextButton(
                                onPressed: onRetry,
                                child: const Text('Try again')),
                          ]),
                        ),
                      ),
                    )
                  else if (houses.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No homes found in this area')),
                    )
                  else ...[
                    if (errorMessage != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Material(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              dense: true,
                              title: Text(errorMessage!),
                              trailing: TextButton(
                                  onPressed: onRetry,
                                  child: const Text('Retry')),
                            ),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == houses.length) {
                              return const Padding(
                                padding: EdgeInsets.all(18),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              );
                            }
                            final house = houses[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: PropertyCard(
                                horizontal: true,
                                house: house,
                                onTap: () => onOpen(house),
                              ),
                            );
                          },
                          childCount: houses.length + (loadingMore ? 1 : 0),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
