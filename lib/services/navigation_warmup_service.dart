import 'dart:async';

import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/current_location_service.dart';

/// Warms only data used by likely next routes. Primary tab widgets themselves
/// are retained by AppShell; this cache makes opening their detail routes feel
/// immediate without mounting duplicate offstage screens.
class NavigationWarmupService {
  NavigationWarmupService._();
  static final instance = NavigationWarmupService._();

  final Set<int> _warmTabs = {};
  final Set<int> _warmHouses = {};

  Future<void> warmTab(int index) async {
    if (!_warmTabs.add(index)) return;
    try {
      if (index == 1) {
        await CurrentLocationService.instance.warm();
      }
      final houses = switch (index) {
        0 => await House.fetchHomeFeed(),
        1 => await House.fetchHouses(),
        2 => await House.fetchReelsPage(),
        _ => await House.fetchSavedHouses(),
      };
      final candidates = switch (houses) {
        HomeFeedData feed => [...feed.recommended, ...feed.deals, ...feed.all],
        ReelsPageData page => page.houses,
        List<House> list => list,
        _ => const <House>[],
      };
      await _warmDetails(candidates.take(3));
    } catch (_) {
      // A normal screen load still owns error presentation and retry behavior.
      _warmTabs.remove(index);
    }
  }

  Future<void> _warmDetails(Iterable<House> houses) async {
    for (final house in houses) {
      if (!_warmHouses.add(house.id)) continue;
      await Future.wait([
        PropertyDetailsService.gallery(house.id),
        PropertyDetailsService.media(house.id),
        if (house.ownerId != null) PropertyDetailsService.owner(house.id),
      ]).catchError((_) => <Object>[]);
      // Yield between homes so navigation and gestures always take priority.
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }
}
