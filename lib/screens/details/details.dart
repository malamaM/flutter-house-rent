import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:house_rent/models/house.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_rent/widgets/about.dart';
import 'package:house_rent/widgets/content_intro.dart';
import 'package:house_rent/widgets/details_app_bar.dart';
import 'package:house_rent/widgets/house_gallery.dart';
import 'package:house_rent/widgets/house_info.dart';
import 'package:house_rent/widgets/house_location_map.dart';

class Details extends StatefulWidget {
  final House house;
  final bool isOwnerView;
  
  const Details({
    Key? key,
    required this.house,
    this.isOwnerView = false,
  }) : super(key: key);

  @override
  _DetailsState createState() => _DetailsState();
}

class _DetailsState extends State<Details> {
  @override
  void initState() {
    super.initState();
    if (!widget.isOwnerView) {
      House.recordView(widget.house.id);
    }
  }

  Future<Map<String, dynamic>> fetchOwner(String houseId) async {
    final url = 'http://127.0.0.1:8000/api/houses/$houseId/owner';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load owner info');
    }
  }

  Future<void> submitReview(int rating, String comment) async {
    if (widget.house.ownerId == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to leave a review')));
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/users/${widget.house.ownerId}/review'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'rating': rating,
          'comment': comment,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted successfully!')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Failed to submit review')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting review: $e')));
    }
  }

  void _showReviewDialog(BuildContext context) {
    int selectedRating = 5;
    TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Leave a Review', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Rate this agent/owner to help the community avoid scammers.'),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 30,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Optional comment...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    submitReview(selectedRating, commentController.text);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  child: const Text('Submit', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
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
            DetailsAppBar(house: widget.house),
            if (widget.isOwnerView)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Listing Stats',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          '${widget.house.views} Total Views',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            HouseGallery(houseId: widget.house.id),
            const SizedBox(height: 10),
            ContentIntro(house: widget.house),
            const SizedBox(height: 20),
            HouseInfo(house: widget.house),
            const SizedBox(height: 20),
            About(house: widget.house),
            const SizedBox(height: 20),
            HouseLocationMap(house: widget.house),
            const SizedBox(height: 20),
            
            // Agent Trust Card
            if (widget.house.ownerName != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Text(widget.house.ownerName![0].toUpperCase(), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.house.ownerName!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(width: 5),
                                  if (widget.house.isVerified)
                                    const Icon(Icons.verified, color: Colors.blue, size: 18),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 16),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${widget.house.averageRating.toStringAsFixed(1)} (${widget.house.totalReviews} reviews)',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _showReviewDialog(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Theme.of(context).primaryColor),
                        ),
                        child: Text('Leave a Review', style: TextStyle(color: Theme.of(context).primaryColor)),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            if (!widget.isOwnerView)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton(
                  onPressed: () => showOwnerDialog(context, widget.house.id.toString()),
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
