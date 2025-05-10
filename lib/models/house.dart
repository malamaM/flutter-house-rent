import 'dart:convert';
import 'package:http/http.dart' as http;

class House {
  String name;
  String address;
  String imageUrl;

  House(this.name, this.address, this.imageUrl);

  // Fetch recommended houses dynamically from the API
  static Future<List<House>> fetchHouses() async {
    const String apiUrl = 'http://127.0.0.1:8000/api/houses';
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> housesData = data['data'];

        return housesData.map((house) {
          return House(
            house['title'], // Use the 'title' field for the name
            house['city'], // Use the 'city' field for the address
            'http://127.0.0.1:8000/storage/${house['image-cover']}', // Add '/storage/' to the image URL
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
