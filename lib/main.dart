import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:house_rent/screens/splash/splash_screen.dart';
import 'package:house_rent/theme/app_theme.dart';
import 'package:house_rent/services/performance_monitor.dart';
import 'package:house_rent/theme/theme_controller.dart';
import 'package:house_rent/services/app_feedback.dart';
import 'package:house_rent/services/offline_sync_service.dart';
import 'package:house_rent/services/recommendation_service.dart';
import 'package:house_rent/services/network_status_service.dart';
import 'package:house_rent/theme/haven_responsive_media.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never hold the first Flutter frame on a platform channel. On a physical
  // device the preferences channel can take a moment to become available;
  // rendering the splash first keeps launch responsive and lets the saved
  // theme apply as soon as it is available.
  unawaited(ThemeController.instance.load());
  unawaited(OfflineSyncService.instance.initialize());
  NetworkStatusService.instance.initialize();
  RecommendationService.instance.initialize();
  PerformanceMonitor.instance.initialize();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'Haven Zambia application',
    ));
    AppFeedback.error(error);
    return true;
  };
  ErrorWidget.builder = (details) {
    return const AppErrorView(
      message:
          'This part of the page could not be displayed. You can safely go back and try again.',
    );
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (_, __) => MaterialApp(
        title: 'Haven Zambia',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: AppFeedback.messengerKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeController.instance.mode,
        builder: (context, child) => HavenResponsiveMedia(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
