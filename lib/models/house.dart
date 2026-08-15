import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class House {
  static const _apiBase = 'http://127.0.0.1:8000/api';
  static const _storageBase = 'http://127.0.0.1:8000/storage';
  static const _feedFreshFor = Duration(minutes: 5);
  static const _feedKeepFor = Duration(days: 14);
  static const _privateFreshFor = Duration(minutes: 2);
  static const _privateKeepFor = Duration(days: 30);

  static final ValueNotifier<HouseCacheState> cacheState =
      ValueNotifier(const HouseCacheState());

  String name;
  String address;
  String imageUrl;
  int id;
  int bedrooms;
  int bathrooms;
  int size;
  int carGarage;
  String? description;
  String? status;
  String? country;
  String? province;
  String? district;
  String? houseNumber;
  String? type;
  int priceRental;
  int pricePurchase;
  int gym;
  int swimmingPool;
  int garage;
  int views;
  String? demandLabel;
  double? latitude;
  double? longitude;
  bool isSaved;
  int? ownerId;
  String? ownerName;
  bool isVerified;
  bool isTopRated;
  double averageRating;
  int totalReviews;
  bool isFromCache;

  House(
    this.name,
    this.address,
    this.imageUrl, {
    this.id = 0,
    this.bedrooms = 0,
    this.bathrooms = 0,
    this.size = 0,
    this.carGarage = 0,
    this.description,
    this.status,
    this.country,
    this.province,
    this.district,
    this.houseNumber,
    this.type,
    this.priceRental = 0,
    this.pricePurchase = 0,
    this.gym = 0,
    this.swimmingPool = 0,
    this.garage = 0,
    this.views = 0,
    this.demandLabel,
    this.latitude,
    this.longitude,
    this.isSaved = false,
    this.ownerId,
    this.ownerName,
    this.isVerified = false,
    this.isTopRated = false,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.isFromCache = false,
  });

  bool get isForSale {
    final value = status?.trim().toLowerCase();
    return value == 'for sale' || value == 'sale' || value == 'purchase';
  }

  bool get isForRent {
    final value = status?.trim().toLowerCase();
    return value == 'for rent' || value == 'rent' || value == 'rental';
  }

  String get listingStatusLabel {
    if (isForSale) return 'For Sale';
    if (isForRent) return 'For Rent';
    return status?.trim().isNotEmpty == true ? status!.trim() : 'Available';
  }

  factory House.fromMap(Map<String, dynamic> map, {bool fromCache = false}) {
    final user = map['user'];
    final cover = map['image-cover'] ?? map['image_cover'];
    return House(
      map['title'] ?? 'Unknown property',
      map['city'] ?? map['address'] ?? 'Location unavailable',
      cover == null ? '' : '$_storageBase/$cover',
      id: _parseInt(map['id']),
      bedrooms: _parseInt(map['bedrooms']),
      bathrooms: _parseInt(map['bathrooms']),
      size: _parseInt(map['size']),
      carGarage: _parseInt(map['car_garage']),
      description: map['description'],
      status: map['status'],
      country: map['country'],
      province: map['province'],
      district: map['district'],
      houseNumber: map['house_number'],
      type: map['type'],
      priceRental: _parseInt(map['price-rental'] ?? map['price_rental']),
      pricePurchase: _parseInt(map['price-purchase'] ?? map['price_purchase']),
      gym: _parseInt(map['gym']),
      swimmingPool: _parseInt(map['swimming_pool']),
      garage: _parseInt(map['garage']),
      views: _parseInt(map['views']),
      demandLabel: map['demand_label']?.toString(),
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      isSaved: map['is_saved'] == true || map['is_saved'] == 1,
      ownerId: user == null ? null : _parseInt(user['id']),
      ownerName: _ownerName(user),
      isVerified: user != null &&
          ((user['is_verified'] == true || user['is_verified'] == 1) ||
              _hasBadge(user, 'verified')),
      isTopRated: user != null && _hasBadge(user, 'top_rated'),
      averageRating:
          user == null ? 0 : _parseDouble(user['average_rating']) ?? 0,
      totalReviews: user == null ? 0 : _parseInt(user['total_reviews']),
      isFromCache: fromCache,
    );
  }

  Map<String, dynamic> toCacheMap() => {
        'id': id,
        'title': name,
        'city': address,
        'image-cover': imageUrl.startsWith('$_storageBase/')
            ? imageUrl.substring('$_storageBase/'.length)
            : imageUrl,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'size': size,
        'car_garage': carGarage,
        'description': description,
        'status': status,
        'country': country,
        'province': province,
        'district': district,
        'house_number': houseNumber,
        'type': type,
        'price-rental': priceRental,
        'price-purchase': pricePurchase,
        'gym': gym,
        'swimming_pool': swimmingPool,
        'garage': garage,
        'views': views,
        'demand_label': demandLabel,
        'latitude': latitude,
        'longitude': longitude,
        'is_saved': isSaved,
        'user': ownerId == null
            ? null
            : {
                'id': ownerId,
                'name': ownerName,
                'is_verified': isVerified,
                'trust_badges': [
                  if (isVerified) {'type': 'verified'},
                  if (isTopRated) {'type': 'top_rated'},
                ],
                'average_rating': averageRating,
                'total_reviews': totalReviews,
              },
      };

  static Future<List<House>> fetchHouses({
    Map<String, String>? filters,
    bool forceRefresh = false,
  }) async {
    final normalizedFilters = Map<String, String>.fromEntries(
      (filters ?? {}).entries.where((entry) => entry.value.trim().isNotEmpty),
    );
    final token = await _token();
    final scope = token == null
        ? AppCache.instance.publicKey('houses')
        : await AppCache.instance.privateKey('houses');
    final key = '$scope:${_canonicalFilters(normalizedFilters)}';
    return _cachedList(
      key: key,
      resource: 'houses',
      freshFor: _feedFreshFor,
      keepFor: _feedKeepFor,
      forceRefresh: forceRefresh,
      fetch: () async {
        final uri = Uri.parse('$_apiBase/houses').replace(
            queryParameters:
                normalizedFilters.isEmpty ? null : normalizedFilters);
        final response = await http
            .get(uri, headers: _headers(token))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) {
          throw HttpException('Could not load properties', response.statusCode);
        }
        return _dataList(response.body);
      },
    );
  }

  static Future<List<House>> fetchSavedHouses(
      {bool forceRefresh = false}) async {
    final token = await _requiredToken();
    final key = await AppCache.instance.privateKey('saved_houses');
    return _cachedList(
      key: key,
      resource: 'saved_houses',
      freshFor: _privateFreshFor,
      keepFor: _privateKeepFor,
      forceRefresh: forceRefresh,
      fetch: () async {
        final response = await http
            .get(Uri.parse('$_apiBase/saved-houses'), headers: _headers(token))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) {
          throw HttpException(
              'Could not load saved homes', response.statusCode);
        }
        return _dataList(response.body);
      },
    );
  }

  static Future<List<House>> fetchMyHouses({bool forceRefresh = false}) async {
    final token = await _requiredToken();
    final key = await AppCache.instance.privateKey('my_houses');
    return _cachedList(
      key: key,
      resource: 'my_houses',
      freshFor: _privateFreshFor,
      keepFor: _privateKeepFor,
      forceRefresh: forceRefresh,
      fetch: () async {
        final response = await http
            .get(Uri.parse('$_apiBase/my-houses'), headers: _headers(token))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) {
          throw HttpException(
              'Could not load your listings', response.statusCode);
        }
        return _dataList(response.body);
      },
    );
  }

  static Future<List<House>> _cachedList({
    required String key,
    required String resource,
    required Duration freshFor,
    required Duration keepFor,
    required bool forceRefresh,
    required Future<List<dynamic>> Function() fetch,
  }) async {
    final cached = await AppCache.instance.read(key);
    if (!forceRefresh && cached != null && !cached.isExpired) {
      final houses = _housesFromValue(cached.value, fromCache: true);
      cacheState.value = HouseCacheState(
        resource: resource,
        servedFromCache: true,
        isStale: !cached.isFresh,
        updatedAt: cached.storedAt,
      );
      if (!cached.isFresh) {
        unawaited(_refreshListInBackground(
          key: key,
          resource: resource,
          freshFor: freshFor,
          keepFor: keepFor,
          fetch: fetch,
        ));
      }
      return houses;
    }

    try {
      return await _refreshList(
        key: key,
        resource: resource,
        freshFor: freshFor,
        keepFor: keepFor,
        fetch: fetch,
      );
    } catch (_) {
      if (cached != null) {
        cacheState.value = HouseCacheState(
          resource: resource,
          servedFromCache: true,
          isStale: true,
          updatedAt: cached.storedAt,
        );
        return _housesFromValue(cached.value, fromCache: true);
      }
      rethrow;
    }
  }

  static Future<List<House>> _refreshList({
    required String key,
    required String resource,
    required Duration freshFor,
    required Duration keepFor,
    required Future<List<dynamic>> Function() fetch,
  }) {
    return AppCache.instance.deduplicate<List<House>>('refresh:$key', () async {
      final raw = await fetch();
      await AppCache.instance.write(
        key,
        raw,
        freshFor: freshFor,
        keepFor: keepFor,
      );
      final now = DateTime.now();
      cacheState.value = HouseCacheState(
        resource: resource,
        servedFromCache: false,
        isStale: false,
        updatedAt: now,
      );
      AppCache.instance.announce(resource, key);
      return _housesFromValue(raw);
    });
  }

  static Future<void> _refreshListInBackground({
    required String key,
    required String resource,
    required Duration freshFor,
    required Duration keepFor,
    required Future<List<dynamic>> Function() fetch,
  }) async {
    try {
      await _refreshList(
        key: key,
        resource: resource,
        freshFor: freshFor,
        keepFor: keepFor,
        fetch: fetch,
      );
    } catch (_) {
      // Stale data remains usable; the next foreground refresh will retry.
    }
  }

  static Future<bool> toggleSaveHouse(
    int houseId, {
    bool? currentlySaved,
  }) async {
    final token = await _requiredToken();
    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/houses/$houseId/save'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return currentlySaved ?? false;
      final isSaved = json.decode(response.body)['is_saved'] == true;
      await _patchSavedStatus(houseId, isSaved);
      return isSaved;
    } catch (_) {
      return currentlySaved ?? false;
    }
  }

  static Future<void> _patchSavedStatus(int houseId, bool isSaved) async {
    await AppCache.instance.mutateMatching(
      (key) => key.contains(':houses:'),
      (value) => _mapList(value, (item) {
        if (_parseInt(item['id']) == houseId) item['is_saved'] = isSaved;
        return item;
      }),
    );
    await AppCache.instance.removeMatching(
      (key) => key.endsWith(':saved_houses'),
    );
    AppCache.instance.announce('saved_houses', 'house:$houseId');
  }

  static Future<bool> updateHouse(
    int id,
    Map<String, dynamic> data, {
    String? coverImagePath,
    List<String>? galleryImagePaths,
    List<int>? deletedImageIds,
  }) async {
    try {
      final token = await _requiredToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiBase/houses/$id'),
      )..headers.addAll(_headers(token));
      request.fields['_method'] = 'PUT';
      data.forEach((key, value) => request.fields[key] = value.toString());
      if (coverImagePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image_cover', coverImagePath),
        );
      }
      for (var i = 0; i < (galleryImagePaths?.length ?? 0); i++) {
        request.files.add(await http.MultipartFile.fromPath(
          'images[$i]',
          galleryImagePaths![i],
        ));
      }
      for (var i = 0; i < (deletedImageIds?.length ?? 0); i++) {
        request.fields['deleted_images[$i]'] = deletedImageIds![i].toString();
      }
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 40)),
      );
      if (response.statusCode == 200) {
        await invalidatePropertyData(id: id);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> createHouse(
    Map<String, dynamic> data,
    String coverImagePath,
    List<String> galleryImagePaths,
  ) async {
    try {
      final token = await _requiredToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiBase/houses'),
      )..headers.addAll(_headers(token));
      data.forEach((key, value) => request.fields[key] = value.toString());
      request.files.add(
        await http.MultipartFile.fromPath('image_cover', coverImagePath),
      );
      for (final path in galleryImagePaths) {
        request.files.add(await http.MultipartFile.fromPath('images[]', path));
      }
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 40)),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await invalidatePropertyData();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> invalidatePropertyData({int? id}) async {
    await AppCache.instance.removeMatching(
      (key) =>
          key.contains(':houses:') ||
          key.endsWith(':my_houses') ||
          key.endsWith(':saved_houses') ||
          (id != null && key.contains('house:$id')),
    );
    AppCache.instance.announce('houses', id == null ? 'all' : 'house:$id');
  }

  static Future<void> recordView(int id) async {
    try {
      await http
          .post(Uri.parse('$_apiBase/houses/$id/view'))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static List<dynamic> _dataList(String body) {
    final decoded = json.decode(body);
    final data = decoded is Map<String, dynamic> ? decoded['data'] : decoded;
    return data is List ? data : <dynamic>[];
  }

  static List<House> _housesFromValue(dynamic value, {bool fromCache = false}) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => House.fromMap(
              Map<String, dynamic>.from(item),
              fromCache: fromCache,
            ))
        .toList();
  }

  static dynamic _mapList(
    dynamic value,
    Map<String, dynamic> Function(Map<String, dynamic>) transform,
  ) {
    if (value is! List) return value;
    return value.map((item) {
      if (item is! Map) return item;
      return transform(Map<String, dynamic>.from(item));
    }).toList();
  }

  static String _canonicalFilters(Map<String, String> filters) {
    final entries = filters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.isEmpty
        ? 'all'
        : entries.map((entry) => '${entry.key}=${entry.value}').join('&');
  }

  static Map<String, String> _headers(String? token) => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String> _requiredToken() async {
    final token = await _token();
    if (token == null) throw const AuthenticationException();
    return token;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String? _ownerName(dynamic user) {
    if (user == null) return null;
    final direct = user['name']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final parts = [user['first_name'], user['last_name']]
        .where((value) => value?.toString().trim().isNotEmpty == true)
        .map((value) => value.toString().trim())
        .toList();
    return parts.isEmpty ? null : parts.join(' ');
  }

  static bool _hasBadge(dynamic user, String type) {
    if (user is! Map || user['trust_badges'] is! List) return false;
    return (user['trust_badges'] as List).any(
      (badge) => badge is Map && badge['type'] == type,
    );
  }
}

class HouseCacheState {
  final String? resource;
  final bool servedFromCache;
  final bool isStale;
  final DateTime? updatedAt;

  const HouseCacheState({
    this.resource,
    this.servedFromCache = false,
    this.isStale = false,
    this.updatedAt,
  });
}

class HttpException implements Exception {
  final String message;
  final int statusCode;

  const HttpException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class AuthenticationException implements Exception {
  const AuthenticationException();

  @override
  String toString() => 'Sign in required';
}
