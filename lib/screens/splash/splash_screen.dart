import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/screens/home/app_shell.dart';
import 'package:house_rent/screens/login/login.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/theme/app_colors.dart';
import 'package:house_rent/widgets/zambian_signature.dart';

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
    unawaited(_progress.animateTo(.84, curve: Curves.easeOutCubic));
    _continue();
  }

  Future<void> _continue() async {
    final launchedAt = DateTime.now();
    // Use the locally cached identity first. It avoids making every launch
    // wait on the network, while SessionService still refreshes stale session
    // information safely in the background.
    final userFuture = SessionService.currentUser(allowExpired: true);
    final user = await userFuture;
    if (user != null) {
      // The first home feed and its visible images are the work users would
      // otherwise feel just after the splash disappears. Keep it here, where
      // the animation stays fluid, but cap the wait for slow/offline networks.
      await _warmFirstHome()
          .timeout(const Duration(milliseconds: 3200), onTimeout: () {});
    }
    final elapsed = DateTime.now().difference(launchedAt);
    const minimumSplash = Duration(milliseconds: 1900);
    if (elapsed < minimumSplash) {
      await Future.delayed(minimumSplash - elapsed);
    }
    if (!mounted) return;
    await _progress.animateTo(1,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOutCubic);
    if (!mounted) return;
    Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              user != null ? const AppShell() : const SignInScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
              opacity: CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic),
              child: child),
          transitionDuration: const Duration(milliseconds: 380),
        ));
  }

  Future<void> _warmFirstHome() async {
    try {
      final feed = await House.fetchHomeFeed();
      if (!mounted) return;
      final homes = <House>[
        ...feed.recommended,
        ...feed.deals,
        ...feed.all,
      ];
      final seen = <int>{};
      final visibleHomes = homes.where((home) => seen.add(home.id)).take(4);
      await Future.wait(visibleHomes.map((home) async {
        if (home.imageUrl.isEmpty) return;
        try {
          await precacheImage(
                  CachedNetworkImageProvider(home.imageUrl), context)
              .timeout(const Duration(milliseconds: 1400));
        } catch (_) {
          // Feed data is still warm; the card can load this image normally.
        }
      }));
    } catch (_) {
      // The Home screen retains its normal cache/error states when offline.
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final backdrop = dark ? const Color(0xFF0D1210) : const Color(0xFF102A24);
    final glow = dark ? const Color(0xFF275E4D) : AppColors.primary;
    final accent = dark ? const Color(0xFFD99055) : const Color(0xFFF0A365);
    return Scaffold(
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
  }

  @override
  void dispose() {
    _entrance.dispose();
    _progress.dispose();
    super.dispose();
  }
}
