import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_controller.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.1,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(13), // opacity
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(8), // opacity
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: isDark ? blur : 0, sigmaY: isDark ? blur : 0),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha((opacity * 255).toInt())
                  : AppColors.card,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: AppColors.border,
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
