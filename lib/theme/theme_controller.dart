import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final instance = ThemeController._();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    try {
      final value =
          (await SharedPreferences.getInstance()).getString('theme_mode');
      final loadedMode = value == 'dark'
          ? ThemeMode.dark
          : value == 'light'
              ? ThemeMode.light
              : ThemeMode.system;
      if (_mode == loadedMode) return;
      _mode = loadedMode;
      notifyListeners();
    } catch (_) {
      // System theme remains a safe default if the native preferences
      // channel is unavailable during the first frame.
    }
  }

  Future<void> setDark(bool enabled) async {
    _mode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await (await SharedPreferences.getInstance())
        .setString('theme_mode', enabled ? 'dark' : 'light');
  }
}
