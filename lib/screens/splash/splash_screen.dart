import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/home/app_shell.dart';
import 'package:house_rent/screens/login/login.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/zambian_signature.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _progress;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  String _loadingLabel = 'Starting Haven Zambia…';
  Widget? _destination;
  bool _showSplash = true;
  bool _warmupCancelled = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 760));
    _progress = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1450));
    final curve =
        CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _fade = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0, .82, curve: Curves.easeOut));
    _slide =
        Tween(begin: const Offset(0, .08), end: Offset.zero).animate(curve);
    _entrance.forward();
    unawaited(_beginLoading());
  }

  Future<void> _beginLoading() async {
    await _advanceProgress(.12, 'Starting Haven Zambia…');
    await _continue();
  }

  Future<void> _advanceProgress(double value, String label) async {
    if (!mounted) return;
    setState(() => _loadingLabel = label);
    final distance = (value - _progress.value).abs();
    final milliseconds = (220 + (distance * 760)).round().clamp(220, 760);
    await _progress.animateTo(
      value,
      duration: Duration(milliseconds: milliseconds),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _continue() async {
    final launchedAt = DateTime.now();
    _WarmHomeResult? warmHome;
    // Use the locally cached identity first. It avoids making every launch
    // wait on the network, while SessionService still refreshes stale session
    // information safely in the background.
    final user = await SessionService.currentUser(allowExpired: true);
    await _advanceProgress(.31, 'Checking your saved account…');
    if (user != null) {
      // The first home feed and its visible images are the work users would
      // otherwise feel just after the splash disappears. Keep it here, where
      // the animation stays fluid, but cap the wait for slow/offline networks.
      await _advanceProgress(.42, 'Preparing homes for you…');
      warmHome = await _warmFirstHome().timeout(
        const Duration(milliseconds: 3200),
        onTimeout: () {
          _warmupCancelled = true;
          return null;
        },
      );
    } else {
      await _advanceProgress(.76, 'Preparing secure sign in…');
    }
    final elapsed = DateTime.now().difference(launchedAt);
    const minimumSplash = Duration(milliseconds: 2400);
    if (elapsed < minimumSplash) {
      await Future.delayed(minimumSplash - elapsed);
    }
    if (!mounted) return;
    await _advanceProgress(1, 'Your Haven is ready');
    if (!mounted) return;
    _warmupCancelled = true;
    setState(() {
      _destination = user != null
          ? AppShell(
              initialHomeFeed: warmHome?.feed,
              initialHomeType: warmHome?.type,
            )
          : const SignInScreen();
    });
    // Build and rasterize the destination while the completed splash remains
    // visible. When it is revealed there is no transition route, modal scope
    // or first-frame construction left to swallow the user's first gesture.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) setState(() => _showSplash = false);
  }

  Future<_WarmHomeResult?> _warmFirstHome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final type = prefs.getString('home_property_type');
      final feed = await House.fetchHomeFeed(type: type);
      if (_warmupCancelled) return null;
      await _advanceProgress(.72, 'Finding your best matches…');
      if (!mounted) return null;
      final homes = <House>[
        ...feed.recommended,
        ...feed.deals,
        ...feed.all,
      ];
      final seen = <int>{};
      // Decode only two hero images, one at a time. Decoding several full-size
      // images concurrently is a common source of the brief first-open hitch
      // on lower-power phones. The rest load naturally once the feed is shown.
      final visibleHomes = homes.where((home) => seen.add(home.id)).take(2);
      final homesToCache = visibleHomes.toList();
      for (var index = 0; index < homesToCache.length; index++) {
        final home = homesToCache[index];
        if (home.thumbnailUrl.isEmpty) continue;
        try {
          final targetWidth =
              (278 * MediaQuery.devicePixelRatioOf(context)).round().clamp(
                    320,
                    1200,
                  );
          await precacheImage(
                  ResizeImage.resizeIfNeeded(
                    targetWidth,
                    null,
                    CachedNetworkImageProvider(home.thumbnailUrl),
                  ),
                  context)
              .timeout(const Duration(milliseconds: 1100));
        } catch (_) {
          // Feed data is still warm; the card can load this image normally.
        }
        if (_warmupCancelled) return null;
        await _advanceProgress(
          .80 + ((index + 1) / homesToCache.length * .12),
          index + 1 == homesToCache.length
              ? 'Finishing the details…'
              : 'Preparing the first homes…',
        );
        // Give the splash animation a frame between image decodes.
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      return _WarmHomeResult(feed: feed, type: type);
    } catch (_) {
      // The Home screen retains its normal cache/error states when offline.
      if (mounted) {
        await _advanceProgress(.76, 'Getting things ready…');
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final backdrop = dark ? const Color(0xFF0D1210) : const Color(0xFF102A24);
    final glow = dark ? const Color(0xFF275E4D) : AppColors.primary;
    final accent = dark ? const Color(0xFFD99055) : const Color(0xFFF0A365);
    final splash = Scaffold(
        backgroundColor: backdrop,
        body: Stack(children: [
          Positioned(
              right: -92,
              top: -94,
              child: AnimatedBuilder(
                  animation: _entrance,
                  builder: (_, __) => Transform.scale(
                      scale: .88 + (_entrance.value * .12),
                      child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                glow.withValues(alpha: dark ? .25 : .48),
                                Colors.transparent
                              ])))))),
          Positioned(
              left: -130,
              bottom: -170,
              child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dark
                          ? const Color(0x0AD99055)
                          : const Color(0x0FF0A365)))),
          SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                          position: _slide,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Spacer(),
                                Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFF4F7F5),
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: const [
                                          BoxShadow(
                                              color: Color(0x35000000),
                                              blurRadius: 30,
                                              offset: Offset(0, 12))
                                        ]),
                                    child: const Icon(Icons.roofing_rounded,
                                        color: AppColors.primary, size: 37)),
                                const SizedBox(height: 25),
                                const Text('HAVEN ZAMBIA',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 31,
                                        letterSpacing: 2.2)),
                                const SizedBox(height: 7),
                                const Text('Find where you belong.',
                                    style: TextStyle(
                                        color: Color(0xFFB8CBC4),
                                        fontSize: 17)),
                                const Spacer(),
                                const ZambianSignature(onDark: true),
                                const SizedBox(height: 12),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: Text(_loadingLabel,
                                      key: ValueKey(_loadingLabel),
                                      style: const TextStyle(
                                          color: Color(0xFFB8CBC4),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(height: 18),
                                AnimatedBuilder(
                                    animation: _progress,
                                    builder: (_, __) => ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
                                        child: LinearProgressIndicator(
                                            value: _progress.value,
                                            minHeight: 4,
                                            backgroundColor: Colors.white10,
                                            color: accent))),
                              ]))))),
        ]));
    final destination = _destination;
    if (destination == null) return splash;
    return Stack(
      fit: StackFit.expand,
      children: [
        destination,
        if (_showSplash) splash,
      ],
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    _progress.dispose();
    super.dispose();
  }
}

class _WarmHomeResult {
  const _WarmHomeResult({required this.feed, required this.type});

  final HomeFeedData feed;
  final String? type;
}
