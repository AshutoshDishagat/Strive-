import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_controller.dart';
import 'mini_sudoku_view.dart';
import 'patches_view.dart';
import 'zip_view.dart';
import 'tango_view.dart';

class GamesListView extends StatelessWidget {
  final bool isStandalone;
  const GamesListView({super.key, this.isStandalone = false});

  @override
  Widget build(BuildContext context) {
    Widget content = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_esports_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("BRAIN BREAKS",
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                  Text("Mini-Games Library",
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildGameCard(
            context,
            "Mini Sudoku",
            "Logic & Numbers",
            Icons.grid_4x4_rounded,
            AppColors.primary,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MiniSudokuView()));
            },
          ),
          _buildGameCard(
            context,
            "Patches",
            "Pattern Memory",
            Icons.extension_rounded,
            AppColors.accent,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PatchesView()));
            },
          ),
          _buildGameCard(
            context,
            "Zip",
            "Speed & Reflexes",
            Icons.speed_rounded,
            Colors.purple,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ZipView()));
            },
          ),
          _buildGameCard(
            context,
            "Tango",
            "Pair Matching",
            Icons.shuffle_rounded,
            Colors.orange,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TangoView()));
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );

    if (!isStandalone) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildGameCard(BuildContext context, String title, String subtitle, IconData icon, Color color, {VoidCallback? onTap}) {
    final isDark = ThemeController.instance.isDarkMode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 15, offset: const Offset(0, 4)),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withAlpha(isDark ? 50 : 25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle.toUpperCase(), style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary.withAlpha(128), size: 16),
          ],
        ),
      ),
    );
  }
}
