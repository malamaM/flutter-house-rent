import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HouseGallery extends StatefulWidget {
  final int houseId;

  const HouseGallery({Key? key, required this.houseId}) : super(key: key);

  @override
  _HouseGalleryState createState() => _HouseGalleryState();
}

class _HouseGalleryState extends State<HouseGallery> {
  late Future<List<String>?> _imageUrls;
  bool _noImagesAvailable = false;

  @override
  void initState() {
    super.initState();
    print('HouseGallery initialized with houseId: ${widget.houseId}');
    _imageUrls = _fetchImages();
  }

  Future<List<String>?> _fetchImages() async {
    final url = Uri.parse('http://127.0.0.1:8000/api/houses/images');
    print('Fetching images from: $url with houseId: ${widget.houseId}');
    
    try {
      // Use POST request instead of GET
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'house_id': widget.houseId
        }),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      // Check specifically for 418 status code
      if (response.statusCode == 418) {
        print('No images available for this house (418 response)');
        setState(() {
          _noImagesAvailable = true;
        });
        return null;
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Raw API response: ${response.body}');
        
        if (data['images'] != null && data['images'] is List) {
          final List<String> urls = List<String>.from(data['images'].map((imageObj) => 
            'http://127.0.0.1:8000/storage/${imageObj['image']}'
          ));
          print('Processed image URLs: $urls');
          return urls;
        } else {
          print('No images array found in response or empty array');
          setState(() {
            _noImagesAvailable = true;
          });
        }
      } else {
        print('Failed to load images: ${response.statusCode}, body: ${response.body}');
      }
      return [];
    } catch (e) {
      print('Error fetching gallery images: $e');
      return [];
    }
  }

  // Method to open full screen image
  void _openFullScreen(BuildContext context, String imageUrl, List<String> allImages) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => FullScreenImage(
          imageUrl: imageUrl,
          allImages: allImages,
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // If we already know there are no images, show the message immediately
    if (_noImagesAvailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gallery',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'No images available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<String>?>(
      future: _imageUrls,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Gallery loading state...');
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        
        if (snapshot.hasError) {
          print('Error in FutureBuilder: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          print('No images found for house ID: ${widget.houseId}');
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 100,
              child: Center(child: Text('No images available')),
            ),
          );
        }

        print('Gallery displaying ${snapshot.data!.length} images');
        final imageUrls = snapshot.data!;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gallery',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    final imageUrl = imageUrls[index];
                    print('Loading image: $imageUrl');
                    return GestureDetector(
                      onTap: () => _openFullScreen(context, imageUrl, imageUrls),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 120,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Failed to load image: $imageUrl, error: $error');
                              return Container(
                                width: 120,
                                height: 100,
                                color: Colors.grey[300],
                                child: const Icon(Icons.error_outline),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Full screen image viewer
class FullScreenImage extends StatefulWidget {
  final String imageUrl;
  final List<String> allImages;
  
  const FullScreenImage({
    Key? key,
    required this.imageUrl,
    required this.allImages,
  }) : super(key: key);

  @override
  _FullScreenImageState createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late PageController _pageController;
  late int _currentIndex;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.allImages.indexOf(widget.imageUrl);
    _pageController = PageController(initialPage: _currentIndex);
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Image ${_currentIndex + 1}/${widget.allImages.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.allImages.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.allImages[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}