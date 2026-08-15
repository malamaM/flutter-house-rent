import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final instance = ThemeController._();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    final value =
        (await SharedPreferences.getInstance()).getString('theme_mode');
    _mode = value == 'dark'
        ? ThemeMode.dark
        : value == 'light'
            ? ThemeMode.light
            : ThemeMode.system;
  }

  Future<void> setDark(bool enabled) async {
    _mode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await (await SharedPreferences.getInstance())
        .setString('theme_mode', enabled ? 'dark' : 'light');
  }
}
