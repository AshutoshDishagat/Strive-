import 'package:flutter/material.dart';

class ThemeController {
  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal();

  final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(true);
  int currentNavIndex = 0; // Persistent

  bool get isDarkMode => isDarkModeNotifier.value;

  void toggleTheme() {
    isDarkModeNotifier.value = !isDarkModeNotifier.value;
  }
}
