import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class House {
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
  double? latitude;
  double? longitude;
  bool isSaved;

  House(
    this.name, 
    this.address, 
    this.imageUrl, 
    {
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
    this.latitude,
    this.longitude,
    this.isSaved = false,
    }
  );

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Fetch recommended houses dynamically from the API
  static Future<List<House>> fetchHouses({Map<String, String>? filters}) async {
    String apiUrl = 'http://127.0.0.1:8000/api/houses';
    
    if (filters != null && filters.isNotEmpty) {
      final queryParams = filters.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      if (queryParams.isNotEmpty) {
        apiUrl += '?$queryParams';
      }
    }

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> housesData = data['data'];

        final filteredHouses = housesData;

        return filteredHouses.map((house) {
          return House(
            house['title'], // Use the 'title' field for the name
            house['city'], // Use the 'city' field for the address
            'http://127.0.0.1:8000/storage/${house['image-cover']}', // Add '/storage/' to the image URL
            id: _parseInt(house['id']),
            bedrooms: _parseInt(house['bedrooms']),
            bathrooms: _parseInt(house['bathrooms']),
            size: _parseInt(house['size']),
            carGarage: _parseInt(house['car_garage']),
            description: house['description'],
            status: house['status'],
            country: house['country'],
            province: house['province'],
            district: house['district'],
            houseNumber: house['house_number'],
            type: house['type'],
            priceRental: _parseInt(house['price-rental'] ?? house['price_rental']),
            pricePurchase: _parseInt(house['price-purchase'] ?? house['price_purchase']),
            gym: _parseInt(house['gym']),
            swimmingPool: _parseInt(house['swimming_pool']),
            garage: _parseInt(house['garage']),
            views: _parseInt(house['views']),
            latitude: _parseDouble(house['latitude']),
            longitude: _parseDouble(house['longitude']),
            isSaved: house['is_saved'] == true || house['is_saved'] == 1,
          );
        }).toList();
      } else {
        throw Exception('Failed to load houses');
      }
    } catch (e) {
      throw Exception('Error fetching houses: $e');
    }
  }

  // Toggle save status for a house
  static Future<bool> toggleSaveHouse(int houseId) async {
    final String apiUrl = 'http://127.0.0.1:8000/api/houses/$houseId/save';
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString('access_token');
      if (accessToken == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['is_saved'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error toggling save: $e');
      return false;
    }
  }

  // Fetch saved houses
  static Future<List<House>> fetchSavedHouses() async {
    const String apiUrl = 'http://127.0.0.1:8000/api/saved-houses';
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString('access_token');
      if (accessToken == null) throw Exception('Not authenticated');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> housesData = data['data'];

        return housesData.map((house) {
          return House(
            house['title'] ?? 'Unknown',
            house['city'] ?? 'Unknown',
            house['image-cover'] != null ? 'http://127.0.0.1:8000/storage/${house['image-cover']}' : 'https://via.placeholder.com/150',
            id: _parseInt(house['id']),
            bedrooms: _parseInt(house['bedrooms']),
            bathrooms: _parseInt(house['bathrooms']),
            size: _parseInt(house['size']),
            carGarage: _parseInt(house['car_garage']),
            description: house['description'],
            status: house['status'],
            country: house['country'],
            province: house['province'],
            district: house['district'],
            houseNumber: house['house_number'],
            type: house['type'],
            priceRental: _parseInt(house['price-rental'] ?? house['price_rental']),
            pricePurchase: _parseInt(house['price-purchase'] ?? house['price_purchase']),
            gym: _parseInt(house['gym']),
            swimmingPool: _parseInt(house['swimming_pool']),
            garage: _parseInt(house['garage']),
            views: _parseInt(house['views']),
            latitude: _parseDouble(house['latitude']),
            longitude: _parseDouble(house['longitude']),
            isSaved: house['is_saved'] == true || house['is_saved'] == 1,
          );
        }).toList();
      } else {
        throw Exception('Failed to load saved houses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching saved houses: $e');
    }
  }

  // Fetch my houses using the /my-houses endpoint
  static Future<List<House>> fetchMyHouses() async {
    const String apiUrl = 'http://127.0.0.1:8000/api/my-houses';
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString('access_token');
      if (accessToken == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> housesData = data['data']; // Laravel pagination returns items inside 'data'

        return housesData.map((house) {
          return House(
            house['title'] ?? 'Unknown',
            house['city'] ?? 'Unknown',
            house['image-cover'] != null ? 'http://127.0.0.1:8000/storage/${house['image-cover']}' : 'https://via.placeholder.com/150',
            id: _parseInt(house['id']),
            bedrooms: _parseInt(house['bedrooms']),
            bathrooms: _parseInt(house['bathrooms']),
            size: _parseInt(house['size']),
            carGarage: _parseInt(house['car_garage']),
            description: house['description'],
            status: house['status'],
            country: house['country'],
            province: house['province'],
            district: house['district'],
            houseNumber: house['house_number'],
            type: house['type'],
            priceRental: _parseInt(house['price-rental'] ?? house['price_rental']),
            pricePurchase: _parseInt(house['price-purchase'] ?? house['price_purchase']),
            gym: _parseInt(house['gym']),
            swimmingPool: _parseInt(house['swimming_pool']),
            garage: _parseInt(house['garage']),
            views: _parseInt(house['views']),
            latitude: _parseDouble(house['latitude']),
            longitude: _parseDouble(house['longitude']),
            isSaved: house['is_saved'] == true || house['is_saved'] == 1,
          );
        }).toList();
      } else {
        throw Exception('Failed to load my houses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching my houses: $e');
    }
  }

  // Update house details
  static Future<bool> updateHouse(int id, Map<String, dynamic> data, {String? coverImagePath, List<String>? galleryImagePaths, List<int>? deletedImageIds}) async {
    final String apiUrl = 'http://127.0.0.1:8000/api/houses/$id';
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString('access_token');
      
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers.addAll({
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      });
      
      // Add _method=PUT to fake a PUT request for Laravel
      request.fields['_method'] = 'PUT';

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      if (coverImagePath != null) {
        request.files.add(await http.MultipartFile.fromPath('image_cover', coverImagePath));
      }

      if (galleryImagePaths != null && galleryImagePaths.isNotEmpty) {
        for (int i = 0; i < galleryImagePaths.length; i++) {
          request.files.add(await http.MultipartFile.fromPath('images[$i]', galleryImagePaths[i]));
        }
      }

      if (deletedImageIds != null && deletedImageIds.isNotEmpty) {
        for (int i = 0; i < deletedImageIds.length; i++) {
          request.fields['deleted_images[$i]'] = deletedImageIds[i].toString();
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to update house: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating house: $e');
      return false;
    }
  }

  // Create new house listing
  static Future<bool> createHouse(Map<String, dynamic> data, String coverImagePath, List<String> galleryImagePaths) async {
    const String apiUrl = 'http://127.0.0.1:8000/api/houses';
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? accessToken = prefs.getString('access_token');
      if (accessToken == null) {
        throw Exception('Not authenticated');
      }

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.headers['Accept'] = 'application/json';

      // Add text fields
      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      // Add cover image
      request.files.add(await http.MultipartFile.fromPath('image_cover', coverImagePath));

      // Add gallery images
      for (var path in galleryImagePaths) {
        request.files.add(await http.MultipartFile.fromPath('images[]', path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        print('Failed to create house: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error creating house: $e');
      return false;
    }
  }

  // Record a view
  static Future<void> recordView(int id) async {
    final String apiUrl = 'http://127.0.0.1:8000/api/houses/$id/view';
    try {
      await http.post(Uri.parse(apiUrl));
    } catch (e) {
      print('Error recording view: $e');
    }
  }
}
