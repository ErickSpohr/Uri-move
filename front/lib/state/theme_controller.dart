import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda a preferência visual deste aparelho.
class ThemeController extends ChangeNotifier {
  static const _storageKey = 'dark_mode_enabled';

  bool _darkMode = false;

  bool get darkMode => _darkMode;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _darkMode = preferences.getBool(_storageKey) ?? false;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_storageKey, value);
  }
}
