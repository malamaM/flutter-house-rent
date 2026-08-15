class RentalCity {
  final int id;
  final String name;
  final String province;
  final List<RentalArea> areas;
  const RentalCity(this.id, this.name, this.province, this.areas);
  factory RentalCity.fromMap(Map<String, dynamic> map) => RentalCity(
        _int(map['id']),
        map['name']?.toString() ?? '',
        map['province']?.toString() ?? '',
        (map['areas'] is List ? map['areas'] as List : const [])
            .whereType<Map>()
            .map((item) => RentalArea.fromMap(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

class RentalArea {
  final int id;
  final String name;
  const RentalArea(this.id, this.name);
  factory RentalArea.fromMap(Map<String, dynamic> map) =>
      RentalArea(_int(map['id']), map['name']?.toString() ?? '');
}

class RentalAmenity {
  final int id;
  final String key;
  final String name;
  final String? icon;
  const RentalAmenity(this.id, this.key, this.name, this.icon);
  factory RentalAmenity.fromMap(Map<String, dynamic> map) => RentalAmenity(
      _int(map['id']),
      map['key']?.toString() ?? '',
      map['name']?.toString() ?? '',
      map['icon']?.toString());
}

class RecommendationOptions {
  final List<RentalCity> cities;
  final List<RentalAmenity> amenities;
  const RecommendationOptions(this.cities, this.amenities);
  factory RecommendationOptions.fromMap(Map<String, dynamic> map) =>
      RecommendationOptions(
        (map['cities'] is List ? map['cities'] as List : const [])
            .whereType<Map>()
            .map((item) => RentalCity.fromMap(Map<String, dynamic>.from(item)))
            .toList(),
        (map['amenities'] is List ? map['amenities'] as List : const [])
            .whereType<Map>()
            .map((item) =>
                RentalAmenity.fromMap(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

int _int(dynamic value) => int.tryParse('$value') ?? 0;
