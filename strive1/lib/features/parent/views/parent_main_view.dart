import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_controller.dart';
import 'parent_home_view.dart';
import 'parent_profile_view.dart';
import '../../reports/views/reports_view.dart';

class ParentMainView extends StatefulWidget {
  const ParentMainView({super.key});

  @override
  State<ParentMainView> createState() => _ParentMainViewState();
}

class _ParentMainViewState extends State<ParentMainView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          ParentHomeView(),
          // Reuse the exact same Reports UI the student sees — same UID, same data
          ReportsView(key: PageStorageKey('parent_reports')),
          ParentProfileView(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
                ThemeController.instance.isDarkMode ? 0 : 10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.grid_view_rounded, 'Home'),
              _buildNavItem(1, Icons.bar_chart_rounded, 'Reports'),
              _buildNavItem(2, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withAlpha(20)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color:
                    isActive ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
