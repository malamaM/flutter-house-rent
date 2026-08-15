import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/details/details.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/services/reels_music_service.dart';
import 'package:house_rent/services/premium_haptics.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/widgets/demand_badge.dart';
import 'package:house_rent/widgets/lister_trust_badges.dart';
import 'package:house_rent/widgets/property_card.dart';
import 'package:house_rent/widgets/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({Key? key}) : super(key: key);

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  final music = ReelsMusicService();
  final List<House> houses = [];
  String? nextCursor;
  bool loading = true;
  bool loadingMore = false;
  int activeIndex = 0;
  bool muted = false;
  bool _tabActive = false;
  DateTime _shownAt = DateTime.now();
  final Map<int, double> _areaAffinity = {};
  final Map<String, double> _typeAffinity = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitial();
    _restoreAudio();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (_tabActive == active) return;
    _tabActive = active;
    if (active && !muted) {
      unawaited(music.play().catchError((_) {}));
    } else {
      unawaited(music.pause().catchError((_) {}));
    }
  }

  Future<void> _loadInitial() async {
    try {
      final page = await House.fetchReelsPage();
      if (!mounted) return;
      setState(() {
        houses.addAll(page.houses);
        nextCursor = page.nextCursor;
        loading = false;
      });
      if (houses.isNotEmpty) {
        unawaited(RecommendationService.instance
            .track('impression', houses.first.id));
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = nextCursor;
    if (cursor == null || loadingMore) return;
    loadingMore = true;
    try {
      final page = await House.fetchReelsPage(cursor: cursor);
      if (!mounted) return;
      setState(() {
        final known = houses.map((house) => house.id).toSet();
        houses.addAll(page.houses.where((house) => known.add(house.id)));
        nextCursor = page.nextCursor;
        loadingMore = false;
      });
    } catch (_) {
      loadingMore = false;
    }
  }

  Future<void> _restoreAudio() async {
    final prefs = await SharedPreferences.getInstance();
    muted = prefs.getBool('reels_muted') ?? false;
    if (!muted && _tabActive) {
      try {
        await music.play();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleAudio() async {
    PremiumHaptics.action();
    setState(() => muted = !muted);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reels_muted', muted);
    if (muted) {
      await music.pause();
    } else {
      try {
        await music.play();
      } catch (_) {}
    }
  }

  void _learn(House house, String event, double weight) {
    if (house.areaId != null) {
      _areaAffinity.update(house.areaId!, (value) => value + weight,
          ifAbsent: () => weight);
    }
    if (house.type != null) {
      _typeAffinity.update(house.type!, (value) => value + weight,
          ifAbsent: () => weight);
    }
    unawaited(RecommendationService.instance.track(event, house.id));
    _rerankUnseen();
  }

  void _rerankUnseen() {
    final start = activeIndex + 2;
    if (start >= houses.length - 1) return;
    final tail = houses.sublist(start);
    double score(House house) =>
        house.recommendationScore +
        (_areaAffinity[house.areaId] ?? 0) * 5 +
        (_typeAffinity[house.type] ?? 0) * 3;
    tail.sort((a, b) => score(b).compareTo(score(a)));
    setState(() => houses.replaceRange(start, houses.length, tail));
  }

  void _changedPage(int value) {
    final previous = houses[activeIndex];
    final watched = DateTime.now().difference(_shownAt).inMilliseconds;
    if (watched < 2500) {
      _learn(previous, 'fast_skip', -1.3);
    } else if (watched > 8000) {
      _learn(previous, 'complete', 1.1);
    } else {
      unawaited(RecommendationService.instance
          .track('pause', previous.id, durationMs: watched));
    }
    _shownAt = DateTime.now();
    PremiumHaptics.selection();
    setState(() => activeIndex = value);
    unawaited(
        RecommendationService.instance.track('impression', houses[value].id));
    if (value >= houses.length - 8) _loadMore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !muted) {
      unawaited(music.play().catchError((_) {}));
    } else if (state != AppLifecycleState.resumed) {
      unawaited(music.pause().catchError((_) {}));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    music.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : houses.isEmpty
              ? const Center(
                  child: ScreenState(
                      icon: Icons.slideshow_rounded,
                      title: 'Fresh tours coming soon',
                      message: 'New rental stories will appear here.'))
              : Stack(children: [
                  PageView.builder(
                    key: const PageStorageKey('tours-pages'),
                    scrollDirection: Axis.vertical,
                    itemCount: houses.length,
                    onPageChanged: _changedPage,
                    itemBuilder: (context, index) => _ReelCard(
                      house: houses[index],
                      active: index == activeIndex,
                      muted: muted,
                      onSignal: (event, weight) =>
                          _learn(houses[index], event, weight),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                      child: Row(children: [
                        const Expanded(
                            child: Text('Haven Tours',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800))),
                        Material(
                          color: Colors.black45,
                          shape: const CircleBorder(),
                          child: IconButton(
                              onPressed: _toggleAudio,
                              tooltip: muted ? 'Play music' : 'Mute music',
                              icon: Icon(
                                  muted
                                      ? Icons.volume_off_rounded
                                      : Icons.graphic_eq_rounded,
                                  color: Colors.white)),
                        ),
                      ]),
                    ),
                  ),
                ]),
    );
  }
}

class _ReelCard extends StatefulWidget {
  final House house;
  final bool active;
  final bool muted;
  final void Function(String event, double weight) onSignal;
  const _ReelCard({
    required this.house,
    required this.active,
    required this.muted,
    required this.onSignal,
  });

  @override
  State<_ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<_ReelCard> {
  final photos = PageController();
  Timer? timer;
  int photoIndex = 0;
  DateTime? autoAdvancePausedUntil;
  late Future<List<_TourAsset>> assets;
  late bool saved;

  @override
  void initState() {
    super.initState();
    saved = widget.house.isSaved;
    assets = _loadAssets();
    _schedule();
  }

  Future<List<_TourAsset>> _loadAssets() async {
    if (widget.house.reelAssets.isNotEmpty) {
      return widget.house.reelAssets
          .map((item) => item.isVideo
              ? _TourAsset.video(item.url, item.featured,
                  posterUrl: item.posterUrl)
              : _TourAsset.image(item.url))
          .toList();
    }
    final media = await PropertyDetailsService.media(widget.house.id);
    final gallery = await PropertyDetailsService.gallery(widget.house.id);
    return [
      ...media.map((item) => _TourAsset.video(item.url, item.featured)),
      ...<String>{widget.house.imageUrl, ...gallery.map((image) => image.url)}
          .where((url) => url.isNotEmpty)
          .map(_TourAsset.image),
    ];
  }

  @override
  void didUpdateWidget(covariant _ReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _schedule();
      if (widget.active) _precacheNextImage();
    }
  }

  Future<void> _precacheNextImage() async {
    final list = await assets;
    if (!mounted || list.isEmpty) return;
    for (var offset = 1; offset < list.length; offset++) {
      final candidate = list[(photoIndex + offset) % list.length];
      if (!candidate.isVideo) {
        await precacheImage(CachedNetworkImageProvider(candidate.url), context);
        return;
      }
    }
  }

  void _schedule() {
    timer?.cancel();
    if (!widget.active) return;
    timer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (MediaQuery.disableAnimationsOf(context)) return;
      final pausedUntil = autoAdvancePausedUntil;
      if (pausedUntil != null && DateTime.now().isBefore(pausedUntil)) return;
      final list = await assets;
      if (!mounted || list.length < 2 || !photos.hasClients) return;
      if (list[photoIndex].isVideo) return;
      final next = (photoIndex + 1) % list.length;
      await photos.animateToPage(next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic);
    });
  }

  Future<void> _toggleSave() async {
    final previous = saved;
    setState(() => saved = !saved);
    PremiumHaptics.action();
    final result =
        await House.toggleSaveHouse(widget.house.id, currentlySaved: previous);
    if (mounted && result != saved) setState(() => saved = result);
    widget.onSignal(result ? 'save' : 'unsave', result ? 2.4 : -1);
  }

  Future<void> _feedback() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Text('Tune your Haven',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final item in const [
              (
                'not_interested',
                'Not interested',
                Icons.visibility_off_outlined
              ),
              ('too_expensive', 'Too expensive', Icons.payments_outlined),
              ('wrong_area', 'Wrong area', Icons.location_off_outlined),
              ('wrong_bedrooms', 'Wrong number of bedrooms', Icons.bed_outlined)
            ])
              ListTile(
                leading: Icon(item.$3),
                title: Text(item.$2),
                onTap: () => Navigator.pop(context, item.$1),
              ),
          ]),
        ),
      ),
    );
    if (result != null) {
      widget.onSignal('not_interested', -3);
      unawaited(RecommendationService.instance.track(
          'not_interested', widget.house.id,
          metadata: {'reason': result}));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    photos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      FutureBuilder<List<_TourAsset>>(
        future: assets,
        builder: (context, snapshot) {
          final items =
              snapshot.data ?? [_TourAsset.image(widget.house.imageUrl)];
          return PageView.builder(
            controller: photos,
            physics: const PageScrollPhysics(),
            itemCount: items.length,
            onPageChanged: (value) {
              autoAdvancePausedUntil =
                  DateTime.now().add(const Duration(seconds: 12));
              PremiumHaptics.selection();
              setState(() => photoIndex = value);
              _precacheNextImage();
              widget.onSignal('media_swipe', .35);
            },
            itemBuilder: (_, index) {
              final item = items[index];
              if (item.isVideo) {
                return _TourVideo(
                    url: item.url,
                    active: widget.active && index == photoIndex,
                    muted: widget.muted,
                    featured: item.featured,
                    posterUrl: item.posterUrl);
              }
              return CachedNetworkImage(
                  imageUrl: item.url,
                  memCacheWidth: 1080,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const ColoredBox(color: Color(0xFF18211C)),
                  errorWidget: (_, __, ___) => const ColoredBox(
                      color: Color(0xFF18211C),
                      child: Icon(Icons.home_work_outlined,
                          color: Colors.white54, size: 64)));
            },
          );
        },
      ),
      const DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black26, Colors.transparent, Colors.black87],
                  stops: [0, .42, 1]))),
      Positioned(
        left: 18,
        right: 76,
        bottom: 108,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.house.demandLabel != null) ...[
            DemandBadge(demandLabel: widget.house.demandLabel),
            const SizedBox(height: 10)
          ],
          Text(widget.house.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 1.08)),
          const SizedBox(height: 8),
          Text(
              '${widget.house.address} · ${widget.house.bedrooms} bed · ${widget.house.bathrooms} bath',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 9),
          Text(formatPropertyPrice(widget.house),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          if (widget.house.isVerified || widget.house.isTopRated) ...[
            const SizedBox(height: 10),
            ListerTrustBadges(
                verified: widget.house.isVerified,
                topRated: widget.house.isTopRated,
                compact: true),
          ],
          const SizedBox(height: 11),
          const Row(children: [
            Icon(Icons.music_note_rounded, color: Colors.white70, size: 15),
            SizedBox(width: 5),
            Text('Original Haven ambient',
                style: TextStyle(color: Colors.white70, fontSize: 11))
          ]),
        ]),
      ),
      Positioned(
        right: 14,
        bottom: 118,
        child: Column(children: [
          _ReelAction(
              icon: saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: 'Save',
              onTap: _toggleSave),
          const SizedBox(height: 18),
          _ReelAction(
              icon: Icons.arrow_forward_rounded,
              label: 'View',
              onTap: () {
                widget.onSignal('details', 1.2);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => Details(house: widget.house)));
              }),
          const SizedBox(height: 18),
          _ReelAction(
              icon: Icons.more_horiz_rounded, label: 'Tune', onTap: _feedback),
        ]),
      ),
      Positioned(
        top: 82,
        left: 18,
        right: 18,
        child: FutureBuilder<List<_TourAsset>>(
          future: assets,
          builder: (_, snapshot) {
            final count = snapshot.data?.length ?? 0;
            if (count < 2) return const SizedBox.shrink();
            return Column(children: [
              Row(
                children: List.generate(
                  count,
                  (index) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 3,
                      margin:
                          EdgeInsets.only(right: index == count - 1 ? 0 : 4),
                      decoration: BoxDecoration(
                        color:
                            index == photoIndex ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Icon(Icons.swipe_rounded, color: Colors.white70, size: 15),
                SizedBox(width: 5),
                Text('Swipe for more',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ]),
            ]);
          },
        ),
      ),
    ]);
  }
}

class _TourAsset {
  final String url;
  final bool isVideo;
  final bool featured;
  final String? posterUrl;
  const _TourAsset._(this.url,
      {required this.isVideo, this.featured = false, this.posterUrl});
  factory _TourAsset.image(String url) => _TourAsset._(url, isVideo: false);
  factory _TourAsset.video(String url, bool featured, {String? posterUrl}) =>
      _TourAsset._(url,
          isVideo: true, featured: featured, posterUrl: posterUrl);
}

class _TourVideo extends StatefulWidget {
  final String url;
  final bool active;
  final bool muted;
  final bool featured;
  final String? posterUrl;
  const _TourVideo(
      {required this.url,
      required this.active,
      required this.muted,
      required this.featured,
      this.posterUrl});

  @override
  State<_TourVideo> createState() => _TourVideoState();
}

class _TourVideoState extends State<_TourVideo> {
  late final VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    controller.initialize().then((_) async {
      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0 : 1);
      if (widget.active) await controller.play();
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  @override
  void didUpdateWidget(covariant _TourVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!controller.value.isInitialized) return;
    if (oldWidget.muted != widget.muted) {
      unawaited(controller.setVolume(widget.muted ? 0 : 1));
    }
    if (widget.active) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Stack(fit: StackFit.expand, children: [
        if (widget.posterUrl != null && widget.posterUrl!.isNotEmpty)
          CachedNetworkImage(
              imageUrl: widget.posterUrl!,
              fit: BoxFit.cover,
              memCacheWidth: 1080),
        const ColoredBox(color: Color(0x4418211C)),
        const Center(
            child:
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
      ]);
    }
    return Stack(fit: StackFit.expand, children: [
      FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller))),
      Positioned(
        top: 118,
        left: 18,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.black54, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(
                widget.featured
                    ? Icons.auto_awesome_rounded
                    : Icons.videocam_rounded,
                color: Colors.white,
                size: 14),
            const SizedBox(width: 5),
            Text(widget.featured ? 'Featured tour' : 'Property video',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]);
  }
}

class _ReelAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ReelAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(children: [
        Material(
            color: Colors.black45,
            shape: const CircleBorder(),
            child: IconButton(
                onPressed: onTap,
                icon: Icon(icon, color: Colors.white),
                iconSize: 27)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ]);
}
