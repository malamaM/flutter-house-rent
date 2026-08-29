import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/config/api_config.dart';
import 'package:house_rent/navigation/haven_page_route.dart';
import 'package:house_rent/services/app_data_service.dart';

class HouseGallery extends StatefulWidget {
  final int houseId;

  const HouseGallery({Key? key, required this.houseId}) : super(key: key);

  @override
  State<HouseGallery> createState() => _HouseGalleryState();
}

class _HouseGalleryState extends State<HouseGallery> {
  late Future<List<GalleryImageData>> images;

  @override
  void initState() {
    super.initState();
    images = _loadImages();
  }

  @override
  void didUpdateWidget(covariant HouseGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      images = _loadImages();
    }
  }

  Future<List<GalleryImageData>> _loadImages() =>
      PropertyDetailsService.gallery(widget.houseId, forceRefresh: true);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GalleryImageData>>(
      future: images,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 112,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gallery',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Text(
                    '${items.length} photos',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 112,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    HavenPageRoute(
                      builder: (_) => FullScreenGallery(
                        images: items,
                        initialIndex: index,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: ApiConfig.optimizedImageUrl(
                        items[index].thumbnailUrl,
                        width: 520,
                        height: 400,
                        quality: 74,
                      ),
                      memCacheWidth: 520,
                      width: 148,
                      height: 112,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                          color:
                              Theme.of(context).colorScheme.surfaceContainer),
                      errorWidget: (_, __, ___) => Container(
                        width: 148,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FullScreenGallery extends StatefulWidget {
  final List<GalleryImageData> images;
  final int initialIndex;

  const FullScreenGallery({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late final PageController controller;
  late int index;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    controller = PageController(initialPage: index);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.images[index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${index + 1} of ${widget.images.length}'),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: widget.images.length,
            onPageChanged: (value) => setState(() => index = value),
            itemBuilder: (_, page) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: ApiConfig.optimizedImageUrl(
                    widget.images[page].url,
                    width: 1600,
                    quality: 84,
                    fit: 'contain',
                  ),
                  memCacheWidth: 1440,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          if (image.caption.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              bottom: 28,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  image.caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
