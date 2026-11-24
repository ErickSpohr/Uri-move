import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uri_move_app/state/theme_controller.dart';

void main() {
  test('restaura e salva a preferência de modo escuro', () async {
    SharedPreferences.setMockInitialValues({'dark_mode_enabled': true});
    final controller = ThemeController();

    await controller.load();
    expect(controller.themeMode, ThemeMode.dark);

    await controller.setDarkMode(false);
    expect(controller.themeMode, ThemeMode.light);
    expect(
      (await SharedPreferences.getInstance()).getBool('dark_mode_enabled'),
      false,
    );
  });
}
