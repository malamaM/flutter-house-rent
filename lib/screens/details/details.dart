import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:house_rent/models/house.dart';
import 'package:house_rent/widgets/about.dart';
import 'package:house_rent/widgets/content_intro.dart';
import 'package:house_rent/widgets/details_app_bar.dart';
import 'package:house_rent/widgets/house_gallery.dart';
import 'package:house_rent/widgets/house_info.dart';

class Details extends StatelessWidget {
  final House house;
  const Details({
    Key? key,
    required this.house,
  }) : super(key: key);

  Future<Map<String, dynamic>> fetchOwner(String houseId) async {
    final url = 'http://127.0.0.1:8000/api/houses/$houseId/owner';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load owner info');
    }
  }

  void showOwnerDialog(BuildContext context, String houseId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Owner Contact', style: TextStyle(fontWeight: FontWeight.bold)),
          content: FutureBuilder<Map<String, dynamic>>(
            future: fetchOwner(houseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else if (!snapshot.hasData) {
                return const Text('No data found.');
              }
              final data = snapshot.data!;
              final user = data['user'] ?? {};
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.email, color: Theme.of(context).primaryColor),
                    title: Text(user['email'] ?? 'N/A'),
                  ),
                  ListTile(
                    leading: Icon(Icons.business, color: Theme.of(context).primaryColor),
                    title: Text(user['company'] ?? 'N/A'),
                  ),
                  ListTile(
                    leading: Icon(Icons.phone, color: Theme.of(context).primaryColor),
                    title: Text(user['phone_number'] ?? 'N/A'),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailsAppBar(house: house),
            const SizedBox(height: 10),
            HouseGallery(houseId: house.id),
            const SizedBox(height: 10),
            ContentIntro(house: house),
            const SizedBox(height: 20),
            HouseInfo(house: house),
            const SizedBox(height: 20),
            About(house: house),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: () => showOwnerDialog(context, house.id.toString()),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
