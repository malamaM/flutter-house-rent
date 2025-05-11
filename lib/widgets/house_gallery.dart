import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImageItem {
  final String url;
  final String caption;
  
  ImageItem({required this.url, this.caption = ''});
}

class HouseGallery extends StatefulWidget {
  final int houseId;

  const HouseGallery({Key? key, required this.houseId}) : super(key: key);

  @override
  _HouseGalleryState createState() => _HouseGalleryState();
}

class _HouseGalleryState extends State<HouseGallery> {
  late Future<List<ImageItem>?> _imageUrls;
  bool _noImagesAvailable = false;

  @override
  void initState() {
    super.initState();
    print('HouseGallery initialized with houseId: ${widget.houseId}');
    _imageUrls = _fetchImages();
  }

  Future<List<ImageItem>?> _fetchImages() async {
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
          final List<ImageItem> images = List<ImageItem>.from(data['images'].map((imageObj) => 
            ImageItem(
              url: 'http://127.0.0.1:8000/storage/${imageObj['image']}',
              caption: imageObj['caption'] ?? '',
            )
          ));
          print('Processed image items: ${images.length}');
          return images;
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
  void _openFullScreen(BuildContext context, ImageItem image, List<ImageItem> allImages) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => FullScreenImage(
          image: image,
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

    return FutureBuilder<List<ImageItem>?>(
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
                    final imageUrl = imageUrls[index].url;
                    print('Loading image: $imageUrl');
                    return GestureDetector(
                      onTap: () => _openFullScreen(context, imageUrls[index], imageUrls),
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
  final ImageItem image;
  final List<ImageItem> allImages;
  
  const FullScreenImage({
    Key? key,
    required this.image,
    required this.allImages,
  }) : super(key: key);

  @override
  _FullScreenImageState createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late int _currentIndex;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.allImages.indexOf(widget.image);
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();
    
    // Wait for the layout to be built before scrolling to the current thumbnail
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedThumbnail();
    });
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedThumbnail() {
    // Calculate the offset to center the selected thumbnail
    final double thumbnailWidth = 70.0; // Width of thumbnail + padding
    final double offset = _currentIndex * thumbnailWidth;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scrollOffset = offset - (screenWidth / 2) + (thumbnailWidth / 2);
    
    // Scroll to position
    if (_thumbnailScrollController.hasClients) {
      _thumbnailScrollController.animateTo(
        scrollOffset.clamp(0.0, _thumbnailScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
      body: Stack(
        children: [
          // Main image viewer (without caption)
          PageView.builder(
            controller: _pageController,
            itemCount: widget.allImages.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _scrollToSelectedThumbnail();
              });
            },
            itemBuilder: (context, index) {
              final currentImage = widget.allImages[index];
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    currentImage.url,
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
          
          // Caption positioned above the carousel
          Positioned(
            left: 0,
            right: 0,
            bottom: 90, // Position above the carousel
            child: widget.allImages[_currentIndex].caption.isNotEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  color: Colors.black.withOpacity(0.7),
                  child: Text(
                    widget.allImages[_currentIndex].caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                )
              : const SizedBox.shrink(), // No space if no caption
          ),
          
          // Thumbnail carousel at bottom (unchanged)
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Container(
              height: 70,
              color: Colors.black.withOpacity(0.5),
              child: ListView.builder(
                controller: _thumbnailScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: widget.allImages.length,
                itemBuilder: (context, index) {
                  final bool isSelected = index == _currentIndex;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      width: 60,
                      decoration: BoxDecoration(
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          widget.allImages[index].url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}