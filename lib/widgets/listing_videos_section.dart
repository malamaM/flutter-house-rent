import 'package:flutter/material.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:video_player/video_player.dart';

class ListingVideosSection extends StatelessWidget {
  final int houseId;
  const ListingVideosSection({Key? key, required this.houseId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ListingMediaData>>(
      future: PropertyDetailsService.media(houseId),
      builder: (context, snapshot) {
        final videos = snapshot.data ?? [];
        if (videos.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Video tours',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              Text('Walk through the property before arranging a viewing.',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 238,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) =>
                  _ListingVideoCard(media: videos[index]),
            ),
          ),
        ]);
      },
    );
  }
}

class _ListingVideoCard extends StatefulWidget {
  final ListingMediaData media;
  const _ListingVideoCard({required this.media});

  @override
  State<_ListingVideoCard> createState() => _ListingVideoCardState();
}

class _ListingVideoCardState extends State<_ListingVideoCard> {
  late final VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.media.url));
    controller.initialize().then((_) {
      controller.setLooping(true);
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: controller.value.isInitialized
          ? () {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
              setState(() {});
            }
          : null,
      child: Container(
        width: 300,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(18)),
        child: Stack(fit: StackFit.expand, children: [
          if (controller.value.isInitialized)
            FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller)))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          Center(
              child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: controller.value.isPlaying ? 0 : 1,
                  child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 30)))),
          Positioned(
              left: 12,
              top: 12,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(
                      widget.media.featured
                          ? 'Featured Haven Tour'
                          : 'Property video',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)))),
        ]),
      ),
    );
  }
}
