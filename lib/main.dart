import 'package:flutter/material.dart';
import 'package:house_rent/screens/splash/splash_screen.dart';
import 'package:house_rent/theme/app_theme.dart';
import 'package:house_rent/services/performance_monitor.dart';
import 'package:house_rent/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  PerformanceMonitor.instance.initialize();
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
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeController.instance.mode,
        home: const SplashScreen(),
      ),
    );
  }
}
