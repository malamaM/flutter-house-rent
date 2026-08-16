import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:house_rent/models/house.dart';

/// Fast, in-memory learning for the current app session. Server preferences
/// remain the baseline; strong current intent can quickly reorder unseen homes.
class SessionRecommendation extends ChangeNotifier {
  SessionRecommendation._();
  static final instance = SessionRecommendation._();

  final Map<int, double> _areas = {};
  final Map<String, double> _cities = {};
  final Map<String, double> _types = {};
  final Map<int, double> _bedrooms = {};
  final Map<int, double> _priceBands = {};
  final Map<int, double> _houses = {};
  bool _notificationScheduled = false;

  void reset() {
    _areas.clear();
    _cities.clear();
    _types.clear();
    _bedrooms.clear();
    _priceBands.clear();
    _houses.clear();
    _notifySafely();
  }

  void observe(House house, double weight) {
    if (weight == 0) return;
    if (house.areaId != null) _add(_areas, house.areaId!, weight);
    _add(_cities, house.address.toLowerCase(), weight * .45);
    if (house.type != null) _add(_types, house.type!, weight * .8);
    _add(_bedrooms, house.bedrooms, weight * .7);
    _add(_priceBands, _priceBand(house.priceRental), weight * .5);
    _add(_houses, house.id, weight * 2);
    _notifySafely();
  }

  void _notifySafely() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
      return;
    }
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      notifyListeners();
    });
  }

  double score(House house) {
    final exactArea = _areas[house.areaId] ?? 0;
    final adjacentBedrooms = (_bedrooms[house.bedrooms - 1] ?? 0) +
        (_bedrooms[house.bedrooms + 1] ?? 0);
    final adjacentPrice =
        (_priceBands[_priceBand(house.priceRental) - 1] ?? 0) +
            (_priceBands[_priceBand(house.priceRental) + 1] ?? 0);
    return house.recommendationScore +
        exactArea * 18 +
        (_cities[house.address.toLowerCase()] ?? 0) * 8 +
        (_types[house.type] ?? 0) * 11 +
        (_bedrooms[house.bedrooms] ?? 0) * 9 +
        adjacentBedrooms * 3 +
        (_priceBands[_priceBand(house.priceRental)] ?? 0) * 6 +
        adjacentPrice * 2 +
        (_houses[house.id] ?? 0) * 4;
  }

  List<House> rank(Iterable<House> houses) {
    final indexed = houses.toList().asMap().entries.toList();
    indexed.sort((a, b) {
      final comparison = score(b.value).compareTo(score(a.value));
      return comparison == 0 ? a.key.compareTo(b.key) : comparison;
    });
    return indexed.map((entry) => entry.value).toList();
  }

  static void _add<K>(Map<K, double> target, K key, double value) {
    target.update(key, (current) => (current + value).clamp(-12, 12),
        ifAbsent: () => value.clamp(-12, 12));
  }

  static int _priceBand(int price) => price <= 0 ? 0 : price ~/ 2500;
}
