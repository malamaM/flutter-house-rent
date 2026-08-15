import 'dart:async';
import 'dart:convert';

import 'package:house_rent/services/app_cache.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService._();

  static const _apiBase = 'http://localhost:8000/api';
  static Map<String, dynamic>? _memoryUser;

  static Future<Map<String, dynamic>?> currentUser({
    bool forceRefresh = false,
    bool allowExpired = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return null;
    if (!forceRefresh && _memoryUser != null) return _memoryUser;

    final key = await AppCache.instance.privateKey('current_user');
    final cached = await AppCache.instance.read(
      key,
      includeExpired: allowExpired,
    );
    if (!forceRefresh && cached != null) {
      _memoryUser = Map<String, dynamic>.from(cached.value);
      if (!cached.isFresh) unawaited(_refreshInBackground(token, key));
      return _memoryUser;
    }

    try {
      return await _refresh(token, key);
    } on SessionExpiredException {
      await prefs.remove('access_token');
      await clear();
      return null;
    } catch (_) {
      if (cached != null) {
        _memoryUser = Map<String, dynamic>.from(cached.value);
        return _memoryUser;
      }
      return null;
    }
  }

  static Future<Map<String, dynamic>> _refresh(
    String token,
    String key,
  ) {
    return AppCache.instance.deduplicate('session:$key', () async {
      final response = await http.get(
        Uri.parse('$_apiBase/check-login-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 401) throw const SessionExpiredException();
      if (response.statusCode != 200) throw Exception('Session unavailable');
      final user =
          Map<String, dynamic>.from(json.decode(response.body)['user']);
      _memoryUser = user;
      await AppCache.instance.write(
        key,
        user,
        freshFor: const Duration(minutes: 15),
        keepFor: const Duration(days: 30),
      );
      AppCache.instance.announce('current_user', key);
      return user;
    });
  }

  static Future<void> _refreshInBackground(String token, String key) async {
    try {
      await _refresh(token, key);
    } on SessionExpiredException {
      final prefs = await SharedPreferences.getInstance();
      await clear();
      await prefs.remove('access_token');
    } catch (_) {
      // The cached identity remains available during temporary outages.
    }
  }

  static Future<void> updateCachedUser(Map<String, dynamic> changes) async {
    final key = await AppCache.instance.privateKey('current_user');
    final cached = await AppCache.instance.read(key);
    final merged = <String, dynamic>{
      if (cached?.value is Map) ...Map<String, dynamic>.from(cached!.value),
      ...changes,
    };
    _memoryUser = merged;
    await AppCache.instance.write(
      key,
      merged,
      freshFor: const Duration(minutes: 15),
      keepFor: const Duration(days: 30),
    );
    AppCache.instance.announce('current_user', key);
  }

  static Future<void> clear() async {
    _memoryUser = null;
    await AppCache.instance.clearPrivateData();
  }
}

class PropertyDetailsService {
  PropertyDetailsService._();

  static const _apiBase = 'http://127.0.0.1:8000/api';
  static const _storageBase = 'http://127.0.0.1:8000/storage';

  static Future<Map<String, dynamic>> owner(
    int houseId, {
    bool forceRefresh = false,
  }) async {
    // Contact details are deliberately kept in the private namespace so they
    // are purged on logout instead of surviving as shared public cache data.
    final key = await AppCache.instance.privateKey('house:$houseId:owner');
    final cached = await AppCache.instance.read(key);
    if (!forceRefresh && cached != null && !cached.isExpired) {
      if (!cached.isFresh) {
        unawaited(_ignoreRefresh(_refreshOwner(houseId, key)));
      }
      return Map<String, dynamic>.from(cached.value);
    }
    try {
      return await _refreshOwner(houseId, key);
    } catch (_) {
      if (cached != null) return Map<String, dynamic>.from(cached.value);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _refreshOwner(int houseId, String key) {
    return AppCache.instance.deduplicate('owner:$houseId', () async {
      final response = await http
          .get(Uri.parse('$_apiBase/houses/$houseId/owner'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw Exception('Owner unavailable');
      final owner =
          Map<String, dynamic>.from(json.decode(response.body)['user']);
      await AppCache.instance.write(
        key,
        owner,
        freshFor: const Duration(hours: 6),
        keepFor: const Duration(days: 14),
      );
      return owner;
    });
  }

  static Future<List<GalleryImageData>> gallery(
    int houseId, {
    bool forceRefresh = false,
  }) async {
    final key = AppCache.instance.publicKey('house:$houseId:gallery');
    final cached = await AppCache.instance.read(key);
    if (!forceRefresh && cached != null && !cached.isExpired) {
      if (!cached.isFresh) {
        unawaited(_ignoreRefresh(_refreshGallery(houseId, key)));
      }
      return _galleryFromValue(cached.value, fromCache: true);
    }
    try {
      return await _refreshGallery(houseId, key);
    } catch (_) {
      if (cached != null)
        return _galleryFromValue(cached.value, fromCache: true);
      rethrow;
    }
  }

  static Future<List<GalleryImageData>> _refreshGallery(
    int houseId,
    String key,
  ) {
    return AppCache.instance.deduplicate('gallery:$houseId', () async {
      final response = await http
          .post(
            Uri.parse('$_apiBase/houses/images'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            body: json.encode({'house_id': houseId}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 418) {
        await AppCache.instance.write(
          key,
          <dynamic>[],
          freshFor: const Duration(hours: 2),
          keepFor: const Duration(days: 7),
        );
        return <GalleryImageData>[];
      }
      if (response.statusCode != 200) throw Exception('Gallery unavailable');
      final images = json.decode(response.body)['images'];
      final value = images is List ? images : <dynamic>[];
      await AppCache.instance.write(
        key,
        value,
        freshFor: const Duration(hours: 12),
        keepFor: const Duration(days: 30),
      );
      return _galleryFromValue(value);
    });
  }

  static List<GalleryImageData> _galleryFromValue(
    dynamic value, {
    bool fromCache = false,
  }) {
    if (value is! List) return [];
    return value.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return GalleryImageData(
        id: map['id'] is int ? map['id'] : int.tryParse('${map['id']}'),
        url: '$_storageBase/${map['image']}',
        caption: map['caption'] ?? '',
        fromCache: fromCache,
      );
    }).toList();
  }

  static Future<void> _ignoreRefresh(Future<dynamic> refresh) async {
    try {
      await refresh;
    } catch (_) {
      // Existing cached details remain usable until the next retry.
    }
  }
}

class GalleryImageData {
  final int? id;
  final String url;
  final String caption;
  final bool fromCache;

  const GalleryImageData({
    this.id,
    required this.url,
    required this.caption,
    this.fromCache = false,
  });
}

class ListerReviewsService {
  ListerReviewsService._();

  static const _apiBase = 'http://127.0.0.1:8000/api';

  static Future<ListerReviewsData> fetch(
    int listerId, {
    bool forceRefresh = false,
  }) async {
    final key = AppCache.instance.publicKey('lister:$listerId:reviews');
    final cached = await AppCache.instance.read(key);
    if (!forceRefresh && cached != null && !cached.isExpired) {
      if (!cached.isFresh) {
        unawaited(_refresh(listerId, key).then<void>((_) {}, onError: (_) {}));
      }
      return ListerReviewsData.fromMap(Map<String, dynamic>.from(cached.value));
    }
    try {
      return await _refresh(listerId, key);
    } catch (_) {
      if (cached != null) {
        return ListerReviewsData.fromMap(
            Map<String, dynamic>.from(cached.value));
      }
      rethrow;
    }
  }

  static Future<ListerReviewsData> _refresh(int listerId, String key) {
    return AppCache.instance.deduplicate('reviews:$listerId', () async {
      final response = await http
          .get(Uri.parse('$_apiBase/users/$listerId/reviews'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw Exception('Reviews unavailable');
      final value = Map<String, dynamic>.from(json.decode(response.body));
      await AppCache.instance.write(
        key,
        value,
        freshFor: const Duration(minutes: 10),
        keepFor: const Duration(days: 14),
      );
      return ListerReviewsData.fromMap(value);
    });
  }

  static Future<void> invalidate(int listerId) =>
      AppCache.instance.removeMatching(
        (key) => key.contains('lister:$listerId:reviews'),
      );
}

class ListerReviewsData {
  final double average;
  final int total;
  final List<ListerReviewData> reviews;

  const ListerReviewsData(
      {required this.average, required this.total, required this.reviews});

  factory ListerReviewsData.fromMap(Map<String, dynamic> map) {
    final summary = map['summary'] is Map
        ? Map<String, dynamic>.from(map['summary'])
        : <String, dynamic>{};
    final data = map['data'] is List ? map['data'] as List : <dynamic>[];
    return ListerReviewsData(
      average: double.tryParse('${summary['average'] ?? 0}') ?? 0,
      total: int.tryParse('${summary['total'] ?? 0}') ?? 0,
      reviews: data
          .whereType<Map>()
          .map((item) =>
              ListerReviewData.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class ListerReviewData {
  final int id;
  final int rating;
  final String comment;
  final String reviewerName;
  final DateTime? createdAt;

  const ListerReviewData(
      {required this.id,
      required this.rating,
      required this.comment,
      required this.reviewerName,
      this.createdAt});

  factory ListerReviewData.fromMap(Map<String, dynamic> map) {
    final reviewer = map['reviewer'] is Map
        ? Map<String, dynamic>.from(map['reviewer'])
        : <String, dynamic>{};
    return ListerReviewData(
      id: int.tryParse('${map['id']}') ?? 0,
      rating: int.tryParse('${map['rating']}') ?? 0,
      comment: '${map['comment'] ?? ''}',
      reviewerName: '${reviewer['name'] ?? 'Haven user'}',
      createdAt: DateTime.tryParse('${map['created_at'] ?? ''}'),
    );
  }
}

class SessionExpiredException implements Exception {
  const SessionExpiredException();
}
