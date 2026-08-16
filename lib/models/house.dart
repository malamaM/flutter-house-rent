import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/services/app_cache.dart';
import 'package:house_rent/services/performance_monitor.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class House {
  static String get _apiBase => ApiConfig.apiBase;
  static String get _storageBase => ApiConfig.storageBase;
  static const _feedFreshFor = Duration(minutes: 5);
  static const _feedKeepFor = Duration(days: 14);
  static const _privateFreshFor = Duration(minutes: 2);
  static const _privateKeepFor = Duration(days: 30);
  static const _homeFeedCacheVersion = 3;
  static const _refreshRetryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
    Duration(minutes: 2),
  ];
  static final Map<String, Timer> _refreshRetryTimers = {};
  static final Map<String, int> _refreshRetryAttempts = {};

  static final ValueNotifier<HouseCacheState> cacheState =
      ValueNotifier(const HouseCacheState());

  String name;
  String address;
  String imageUrl;
  String thumbnailUrl;
  int id;
  int bedrooms;
  int bathrooms;
  int size;
  int carGarage;
  String? description;
  String? status;
  DateTime? publishedAt;
  DateTime? expiresAt;
  DateTime? archivedAt;
  String lifecycleStatus;
  int daysUntilExpiry;
  bool recentlyListed;
  String? country;
  String? province;
  String? district;
  int? cityId;
  int? areaId;
  String? houseNumber;
  String? type;
  int priceRental;
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
  List<HouseReelAsset> reelAssets;
  double recommendationScore;
  List<String> recommendationReasons;

  House(
    this.name,
    this.address,
    this.imageUrl, {
    this.id = 0,
    String? thumbnailUrl,
    this.bedrooms = 0,
    this.bathrooms = 0,
    this.size = 0,
    this.carGarage = 0,
    this.description,
    this.status,
    this.publishedAt,
    this.expiresAt,
    this.archivedAt,
    this.lifecycleStatus = 'active',
    this.daysUntilExpiry = 30,
    this.recentlyListed = false,
    this.country,
    this.province,
    this.district,
    this.cityId,
    this.areaId,
    this.houseNumber,
    this.type,
    this.priceRental = 0,
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
    this.reelAssets = const [],
    this.recommendationScore = 0,
    this.recommendationReasons = const [],
  }) : thumbnailUrl = thumbnailUrl ?? imageUrl;

  String get listingStatusLabel => 'For Rent';

  bool get isArchived => lifecycleStatus == 'archived' || status == 'Archived';
  bool get canRenew => isArchived || daysUntilExpiry <= 7;

  factory House.fromMap(Map<String, dynamic> map, {bool fromCache = false}) {
    final user = map['user'];
    final cover = map['image-cover'] ?? map['image_cover'];
    return House(
      map['title'] ?? 'Unknown property',
      map['city'] ?? map['address'] ?? 'Location unavailable',
      ApiConfig.storageUrl(cover),
      thumbnailUrl: ApiConfig.storageUrl(map['thumbnail-cover']).isEmpty
          ? ApiConfig.storageUrl(cover)
          : ApiConfig.storageUrl(map['thumbnail-cover']),
      id: _parseInt(map['id']),
      bedrooms: _parseInt(map['bedrooms']),
      bathrooms: _parseInt(map['bathrooms']),
      size: _parseInt(map['size']),
      carGarage: _parseInt(map['car_garage']),
      description: map['description'],
      status: map['status'],
      publishedAt: DateTime.tryParse(map['published_at']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(map['expires_at']?.toString() ?? ''),
      archivedAt: DateTime.tryParse(map['archived_at']?.toString() ?? ''),
      lifecycleStatus: map['lifecycle_status']?.toString() ?? 'active',
      daysUntilExpiry: _parseInt(map['days_until_expiry'] ?? 30),
      recentlyListed:
          map['recently_listed'] == true || map['recently_listed'] == 1,
      country: map['country'],
      province: map['province'],
      district: map['district'],
      cityId: _parseNullableInt(map['city_id']),
      areaId: _parseNullableInt(map['area_id']),
      houseNumber: map['house_number'],
      type: map['type'],
      priceRental: _parseInt(map['price-rental'] ?? map['price_rental']),
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
          (user['is_verified'] == true ||
              user['is_verified'] == 1 ||
              user['verification_status'] == 'verified'),
      isTopRated: user != null && _hasBadge(user, 'top_rated'),
      averageRating:
          user == null ? 0 : _parseDouble(user['average_rating']) ?? 0,
      totalReviews: user == null ? 0 : _parseInt(user['total_reviews']),
      isFromCache: fromCache,
      reelAssets: _reelAssets(map),
      recommendationScore: _parseDouble(map['recommendation_score']) ?? 0,
      recommendationReasons: (map['recommendation_reasons'] is List
              ? map['recommendation_reasons'] as List
              : const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toCacheMap() => {
        'id': id,
        'title': name,
        'city': address,
        'image-cover': imageUrl.startsWith('$_storageBase/')
            ? imageUrl.substring('$_storageBase/'.length)
            : imageUrl,
        'thumbnail-cover': thumbnailUrl.startsWith('$_storageBase/')
            ? thumbnailUrl.substring('$_storageBase/'.length)
            : thumbnailUrl,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'size': size,
        'car_garage': carGarage,
        'description': description,
        'status': status,
        'published_at': publishedAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'archived_at': archivedAt?.toIso8601String(),
        'lifecycle_status': lifecycleStatus,
        'days_until_expiry': daysUntilExpiry,
        'recently_listed': recentlyListed,
        'country': country,
        'province': province,
        'district': district,
        'city_id': cityId,
        'area_id': areaId,
        'house_number': houseNumber,
        'type': type,
        'price-rental': priceRental,
        'gym': gym,
        'swimming_pool': swimmingPool,
        'garage': garage,
        'views': views,
        'demand_label': demandLabel,
        'recommendation_score': recommendationScore,
        'recommendation_reasons': recommendationReasons,
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
        'media': reelAssets
            .where((asset) => asset.isVideo)
            .map((asset) => {
                  'path': asset.url,
                  'kind': asset.featured ? 'reel_video' : 'video',
                })
            .toList(),
        'images': reelAssets
            .where((asset) => !asset.isVideo && asset.url != imageUrl)
            .map((asset) => {'image': asset.url})
            .toList(),
      };

  static List<HouseReelAsset> _reelAssets(Map<String, dynamic> map) {
    final assets = <HouseReelAsset>[];
    final media = map['media'];
    if (media is List) {
      for (final item in media.whereType<Map>()) {
        final value = Map<String, dynamic>.from(item);
        final url = ApiConfig.storageUrl(value['path']);
        if (url.isNotEmpty) {
          assets.add(HouseReelAsset.video(
            url,
            featured: value['kind'] == 'reel_video',
            posterUrl: ApiConfig.storageUrl(map['image-cover']),
          ));
        }
      }
      assets
          .sort((a, b) => a.featured == b.featured ? 0 : (a.featured ? -1 : 1));
    }
    final seen = <String>{};
    final cover =
        ApiConfig.storageUrl(map['image-cover'] ?? map['image_cover']);
    if (cover.isNotEmpty && seen.add(cover)) {
      assets.add(HouseReelAsset.image(cover));
    }
    final images = map['images'];
    if (images is List) {
      for (final item in images.whereType<Map>()) {
        final url = ApiConfig.storageUrl(item['image']);
        if (url.isNotEmpty && seen.add(url)) {
          assets.add(HouseReelAsset.image(url));
        }
      }
    }
    return assets;
  }

  static Future<HomeFeedData> fetchHomeFeed({
    String? type,
    bool forceRefresh = false,
  }) async {
    final token = await _token();
    final filter = type == null || type.isEmpty ? 'all' : type;
    final scope = token == null
        ? AppCache.instance.publicKey('home_feed_v$_homeFeedCacheVersion')
        : await AppCache.instance
            .privateKey('home_feed_v$_homeFeedCacheVersion');
    final key = '$scope:$filter';
    final cached = await AppCache.instance.read(key);
    if (!forceRefresh && cached != null && !cached.isExpired) {
      if (!cached.isFresh) {
        unawaited(fetchHomeFeed(type: type, forceRefresh: true));
      }
      return HomeFeedData.fromMap(Map<String, dynamic>.from(cached.value),
          fromCache: true);
    }
    try {
      final uri = Uri.parse('$_apiBase/home-feed')
          .replace(queryParameters: filter == 'all' ? null : {'type': filter});
      final response = await PerformanceMonitor.instance.measure(
        'home_feed',
        () => http
            .get(uri, headers: _headers(token))
            .timeout(const Duration(seconds: 12)),
      );
      if (response.statusCode != 200) {
        throw HttpException('Could not load home feed', response.statusCode);
      }
      final value = Map<String, dynamic>.from(json.decode(response.body));
      await AppCache.instance
          .write(key, value, freshFor: _feedFreshFor, keepFor: _feedKeepFor);
      return HomeFeedData.fromMap(value);
    } catch (_) {
      if (cached != null) {
        return HomeFeedData.fromMap(Map<String, dynamic>.from(cached.value),
            fromCache: true);
      }
      rethrow;
    }
  }

  static Future<ReelsPageData> fetchReelsPage({
    String? cursor,
    bool forceRefresh = false,
  }) async {
    final token = await _token();
    final scope = token == null
        ? AppCache.instance.publicKey('reels-v2')
        : await AppCache.instance.privateKey('reels-v2');
    final key = '$scope:${cursor ?? 'first'}';
    final cached = cursor == null ? await AppCache.instance.read(key) : null;
    if (!forceRefresh && cached != null && !cached.isExpired) {
      return ReelsPageData.fromMap(Map<String, dynamic>.from(cached.value),
          fromCache: true);
    }
    try {
      final uri = Uri.parse('$_apiBase/reels').replace(queryParameters: {
        'per_page': '20',
        if (cursor != null) 'cursor': cursor,
      });
      final response = await PerformanceMonitor.instance.measure(
        'reels',
        () => http
            .get(uri, headers: _headers(token))
            .timeout(const Duration(seconds: 12)),
      );
      if (response.statusCode != 200) {
        throw HttpException('Could not load tours', response.statusCode);
      }
      final value = Map<String, dynamic>.from(json.decode(response.body));
      if (cursor == null) {
        await AppCache.instance.write(key, value,
            freshFor: const Duration(minutes: 3), keepFor: _feedKeepFor);
      }
      return ReelsPageData.fromMap(value);
    } catch (_) {
      if (cached != null) {
        return ReelsPageData.fromMap(Map<String, dynamic>.from(cached.value),
            fromCache: true);
      }
      rethrow;
    }
  }

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
    final key = await AppCache.instance.privateKey('my_houses:v2');
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
        refreshFailed: false,
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
          refreshFailed: true,
          updatedAt: cached.storedAt,
        );
        _scheduleRefreshRetry(
          key: key,
          resource: resource,
          freshFor: freshFor,
          keepFor: keepFor,
          fetch: fetch,
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
      final raw = await PerformanceMonitor.instance.measure(resource, fetch);
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
        refreshFailed: false,
        updatedAt: now,
      );
      _clearRefreshRetry(key);
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
      final cached = await AppCache.instance.read(key);
      cacheState.value = HouseCacheState(
        resource: resource,
        servedFromCache: true,
        isStale: true,
        refreshFailed: true,
        updatedAt: cached?.storedAt,
      );
      _scheduleRefreshRetry(
        key: key,
        resource: resource,
        freshFor: freshFor,
        keepFor: keepFor,
        fetch: fetch,
      );
    }
  }

  static void _scheduleRefreshRetry({
    required String key,
    required String resource,
    required Duration freshFor,
    required Duration keepFor,
    required Future<List<dynamic>> Function() fetch,
  }) {
    if (_refreshRetryTimers.containsKey(key)) return;
    final attempt = _refreshRetryAttempts[key] ?? 0;
    _refreshRetryAttempts[key] = attempt + 1;
    final delay =
        _refreshRetryDelays[attempt.clamp(0, _refreshRetryDelays.length - 1)];
    _refreshRetryTimers[key] = Timer(delay, () {
      _refreshRetryTimers.remove(key);
      unawaited(_refreshListInBackground(
        key: key,
        resource: resource,
        freshFor: freshFor,
        keepFor: keepFor,
        fetch: fetch,
      ));
    });
  }

  static void _clearRefreshRetry(String key) {
    _refreshRetryTimers.remove(key)?.cancel();
    _refreshRetryAttempts.remove(key);
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
    List<String>? videoPaths,
    String? reelVideoPath,
    List<int>? deletedMediaIds,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final token = await _requiredToken();
      final request = _ProgressMultipartRequest(
        'POST',
        Uri.parse('$_apiBase/houses/$id'),
        onProgress,
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
      for (var i = 0; i < (videoPaths?.length ?? 0); i++) {
        request.files.add(await http.MultipartFile.fromPath(
          'videos[$i]',
          videoPaths![i],
        ));
      }
      if (reelVideoPath != null) {
        request.files.add(
          await http.MultipartFile.fromPath('reel_video', reelVideoPath),
        );
      }
      for (var i = 0; i < (deletedMediaIds?.length ?? 0); i++) {
        request.fields['deleted_media[$i]'] = deletedMediaIds![i].toString();
      }
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(minutes: 3)),
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

  static Future<bool> createHouse(Map<String, dynamic> data,
      String coverImagePath, List<String> galleryImagePaths,
      {List<String> videoPaths = const [],
      String? reelVideoPath,
      void Function(double progress)? onProgress}) async {
    try {
      final token = await _requiredToken();
      final request = _ProgressMultipartRequest(
        'POST',
        Uri.parse('$_apiBase/houses'),
        onProgress,
      )..headers.addAll(_headers(token));
      data.forEach((key, value) => request.fields[key] = value.toString());
      request.files.add(
        await http.MultipartFile.fromPath('image_cover', coverImagePath),
      );
      for (final path in galleryImagePaths) {
        request.files.add(await http.MultipartFile.fromPath('images[]', path));
      }
      for (final path in videoPaths) {
        request.files.add(await http.MultipartFile.fromPath('videos[]', path));
      }
      if (reelVideoPath != null) {
        request.files.add(
          await http.MultipartFile.fromPath('reel_video', reelVideoPath),
        );
      }
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(minutes: 3)),
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
          key.contains(':home_feed') ||
          key.contains(':reels:') ||
          key.contains(':my_houses') ||
          key.endsWith(':saved_houses') ||
          (id != null && key.contains('house:$id')),
    );
    AppCache.instance.announce('houses', id == null ? 'all' : 'house:$id');
  }

  static Future<bool> renewListing(int id) async {
    try {
      final token = await _requiredToken();
      final response = await http
          .post(Uri.parse('$_apiBase/houses/$id/renew'),
              headers: _headers(token))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return false;
      await invalidatePropertyData(id: id);
      return true;
    } catch (_) {
      return false;
    }
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

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse('$value');
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
  final bool refreshFailed;
  final DateTime? updatedAt;

  const HouseCacheState({
    this.resource,
    this.servedFromCache = false,
    this.isStale = false,
    this.refreshFailed = false,
    this.updatedAt,
  });
}

class HouseReelAsset {
  final String url;
  final bool isVideo;
  final bool featured;
  final String? posterUrl;

  const HouseReelAsset._(this.url,
      {required this.isVideo, this.featured = false, this.posterUrl});
  factory HouseReelAsset.image(String url) =>
      HouseReelAsset._(url, isVideo: false);
  factory HouseReelAsset.video(String url,
          {required bool featured, String? posterUrl}) =>
      HouseReelAsset._(url,
          isVideo: true, featured: featured, posterUrl: posterUrl);
}

class HomeFeedData {
  final List<House> recommended;
  final List<House> deals;
  final List<House> all;
  final bool fromCache;

  const HomeFeedData(
      {required this.recommended,
      required this.deals,
      required this.all,
      this.fromCache = false});

  factory HomeFeedData.fromMap(Map<String, dynamic> map,
      {bool fromCache = false}) {
    List<House> parse(String key) =>
        (map[key] is List ? map[key] as List : const [])
            .whereType<Map>()
            .map((item) => House.fromMap(Map<String, dynamic>.from(item),
                fromCache: fromCache))
            .toList();
    return HomeFeedData(
      recommended: parse('recommended'),
      deals: parse('deals'),
      all: parse('all'),
      fromCache: fromCache,
    );
  }
}

class ReelsPageData {
  final List<House> houses;
  final String? nextCursor;
  final bool fromCache;

  const ReelsPageData(
      {required this.houses, this.nextCursor, this.fromCache = false});

  factory ReelsPageData.fromMap(Map<String, dynamic> map,
      {bool fromCache = false}) {
    final raw = map['data'] is List ? map['data'] as List : const [];
    return ReelsPageData(
      houses: raw
          .whereType<Map>()
          .map((item) => House.fromMap(Map<String, dynamic>.from(item),
              fromCache: fromCache))
          .toList(),
      nextCursor: map['next_cursor']?.toString(),
      fromCache: fromCache,
    );
  }
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

class _ProgressMultipartRequest extends http.MultipartRequest {
  final void Function(double progress)? onProgress;

  _ProgressMultipartRequest(super.method, super.url, this.onProgress);

  @override
  http.ByteStream finalize() {
    final total = contentLength;
    var sent = 0;
    final stream = super.finalize().transform<List<int>>(
      StreamTransformer.fromHandlers(handleData: (chunk, sink) {
        sent += chunk.length;
        if (total > 0) onProgress?.call((sent / total).clamp(0, 1));
        sink.add(chunk);
      }),
    );
    return http.ByteStream(stream);
  }
}
