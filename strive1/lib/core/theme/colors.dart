import 'package:flutter/material.dart';

import 'theme_controller.dart';

class AppColors {
  static bool get _isDark => ThemeController.instance.isDarkMode;

  // Primary
  static Color get primary => _isDark
      ? const Color(0xFF00E5FF)
      : const Color(0xFF3F51B5); // Indigo
  static Color get accent =>
      _isDark ? const Color(0xFF00B8D4) : const Color(0xFF00BCD4); // Cyan

  // Surface
  static Color get background =>
      _isDark ? const Color(0xFF0A191E) : const Color(0xFFF5F7FA);
  static Color get surface => _isDark ? const Color(0xFF14282F) : Colors.white;
  static Color get card => _isDark ? Colors.white.withAlpha(8) : Colors.white;
  static Color get border =>
      _isDark ? Colors.white.withAlpha(20) : const Color(0xFFF1F5F9);

  // Palette
  static Color get textPrimary =>
      _isDark ? Colors.white : const Color(0xFF2D3436);
  static Color get textSecondary =>
      _isDark ? const Color(0xFF80959B) : const Color(0xFF64748B);

  // Palette
  static Color get success => const Color(0xFF4CAF50);
  static Color get warning => const Color(0xFFFFAB40);
  static Color get error => const Color(0xFFFF5252);

  static Color get darkOverlay => Colors.black54;
}
