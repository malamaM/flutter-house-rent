import 'dart:convert';
import 'package:http/http.dart' as http;

class House {
  String name;
  String address;
  String imageUrl;
  int id; // Add id field
  int bedrooms;
  int bathrooms;
  int size;
  int carGarage;
  String? description; // Add description field

  House(
    this.name, 
    this.address, 
    this.imageUrl, 
    {
    this.id = 0,  // Add id parameter with default value
    this.bedrooms = 0, 
    this.bathrooms = 0, 
    this.size = 0, 
    this.carGarage = 0,
    this.description}
  );

  // Fetch recommended houses dynamically from the API
  static Future<List<House>> fetchHouses({String? filter}) async {
    const String apiUrl = 'http://127.0.0.1:8000/api/houses';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> housesData = data['data'];

        // Apply filtering if a filter is provided
        final filteredHouses = filter != null
            ? housesData.where((house) => house['status'] == filter).toList()
            : housesData;

        return filteredHouses.map((house) {
          return House(
            house['title'], // Use the 'title' field for the name
            house['city'], // Use the 'city' field for the address
            'http://127.0.0.1:8000/storage/${house['image-cover']}', // Add '/storage/' to the image URL
            id: house['id'] ?? 0,  // Extract the house id
            bedrooms: house['bedrooms'] ?? 0,
            bathrooms: house['bathrooms'] ?? 0,
            size: house['size'] ?? 0,
            carGarage: house['car_garage'] ?? 0,
            description: house['description'], // Add description from API
          );
        }).toList();
      } else {
        throw Exception('Failed to load houses');
      }
    } catch (e) {
      throw Exception('Error fetching houses: $e');
    }
  }
}
