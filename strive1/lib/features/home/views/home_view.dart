import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/theme/colors.dart';
import '../../focus/views/focus_view.dart';
import '../../reports/views/reports_view.dart';
import '../../profile/views/profile_view.dart';
import '../../games/views/games_list_view.dart';
import '../../../core/db/database_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart' hide FocusMode;
import '../../../core/widgets/glass_error_banner.dart';
import '../../../core/theme/theme_controller.dart';

class HomeView extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeView({super.key, required this.cameras});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // Navigation
  int _currentIndex = ThemeController.instance.currentNavIndex;

  // State
  double _avgEngagement = 0.0;
  String _totalStudyTime = "0h 0m";
  String _engagementTrend = "+0%";
  String? _errorMessage;

  // Search
  bool _isSearchExpanded = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _commandPalette = [
    {
      'title': 'Go to Dashboard',
      'subtitle': 'Home Screen',
      'icon': Icons.grid_view_rounded,
      'action': 'nav_0'
    },
    {
      'title': 'Go to Reports',
      'subtitle': 'Session History',
      'icon': Icons.bar_chart_rounded,
      'action': 'nav_1'
    },
    {
      'title': 'Go to Profile',
      'subtitle': 'Account Settings',
      'icon': Icons.person_rounded,
      'action': 'nav_2'
    },
    {
      'title': 'Start Deep Work',
      'subtitle': 'AI Focus Timer',
      'icon': Icons.rocket_launch_rounded,
      'action': 'focus'
    },
    {
      'title': 'Study Buddy',
      'subtitle': 'AI Tutoring',
      'icon': Icons.psychology_rounded,
      'action': 'tool_buddy'
    },
    {
      'title': 'Snap-a-Doubt',
      'subtitle': 'Visual Help',
      'icon': Icons.camera_rounded,
      'action': 'tool_snap'
    },
    {
      'title': 'Ecosystem Analytics',
      'subtitle': 'Progress Logs',
      'icon': Icons.insights_rounded,
      'action': 'tool_analytics'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final sessions = await DatabaseHelper.instance.getSessions(user?.uid);
      if (!mounted) return;
      if (sessions.isEmpty) {
        setState(() {
          _avgEngagement = 0.0;
          _totalStudyTime = "0h 0m";
          _engagementTrend = "0%";
          _errorMessage = null;
        });
        return;
      }

      // Calculate
      int totalSeconds = 0;
      double totalScore = 0.0;

      // engagement
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      int todaySessions = 0;
      double todayScoreSum = 0.0;

      int pastSessions = 0;
      double pastScoreSum = 0.0;

      for (var session in sessions) {
        totalSeconds += session.durationSeconds;
        totalScore += session.engagementScore;

        // extraction
        bool isToday = session.startTime.startsWith(todayStr);
        if (isToday) {
          todaySessions++;
          todayScoreSum += session.engagementScore;
        } else {
          pastSessions++;
          pastScoreSum += session.engagementScore;
        }
      }

      // Format
      int hours = totalSeconds ~/ 3600;
      int minutes = (totalSeconds % 3600) ~/ 60;
      String formattedTime = "";
      if (hours > 0) {
        formattedTime = "${hours}h ${minutes}m";
      } else {
        formattedTime = "${minutes}m";
      }

      // Engagement
      double avgE = (totalScore / sessions.length) * 100;

      // Trend
      double todayAvg =
          todaySessions > 0 ? (todayScoreSum / todaySessions) * 100 : 0.0;
      double pastAvg =
          pastSessions > 0 ? (pastScoreSum / pastSessions) * 100 : 0.0;

      String trend = "0%";
      if (pastSessions > 0 && todaySessions > 0) {
        double diff = todayAvg - pastAvg;
        String sign = diff >= 0 ? "+" : "";
        trend = "$sign${diff.toStringAsFixed(0)}%";
      } else if (pastSessions == 0 && todaySessions > 0) {
        trend = "+${todayAvg.toStringAsFixed(0)}%";
      }
      setState(() {
        _avgEngagement = avgE;
        _totalStudyTime = formattedTime;
        _engagementTrend = trend;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              "Failed to load stats: ${e.toString().split('\n')[0]}";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Background
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              right: -100,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(25),
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.25,
              left: -100,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(15),
                ),
              ),
            ),

            // Content
            Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _errorMessage != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 8.0),
                          child: GlassErrorBanner(
                            message: _errorMessage!,
                            onDismiss: () =>
                                setState(() => _errorMessage = null),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_isSearchExpanded) {
                        setState(() {
                          _isSearchExpanded = false;
                          _searchQuery = "";
                          _searchController.clear();
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        _getChildForIndex(_currentIndex),
                        if (_isSearchExpanded && _searchQuery.isNotEmpty)
                          _buildSearchOverlay(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          decoration: BoxDecoration(
              color: AppColors.surface
                  .withAlpha(ThemeController.instance.isDarkMode ? 230 : 200),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.border),
              boxShadow: ThemeController.instance.isDarkMode
                  ? [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.grid_view_rounded, "Home"),
              _buildNavItem(1, Icons.bar_chart_rounded, "Reports"),
              _buildNavItem(2, Icons.person_rounded, "Profile"),
              _buildNavItem(3, Icons.sports_esports_rounded, "Games"),
            ],
          ),
        ),
      ),
      extendBody: true,
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.split(' ').first ?? 'Student';
    final photoUrl = user?.photoURL ??
        'https://ui-avatars.com/api/?name=$displayName&background=3F51B5&color=FFFFFF&size=200';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primary.withAlpha(50), width: 2),
                  image: DecorationImage(
                    image: NetworkImage(photoUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "STRIVE COMMAND",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    "Hello, $displayName",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          AnimatedScale(
            duration: const Duration(milliseconds: 300),
            scale: _isSearchExpanded ? 0 : 1,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isSearchExpanded ? 0 : 1,
              child: _isSearchExpanded
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        _buildModernIconButton(
                          Icons.search_rounded,
                          onTap: () => setState(() => _isSearchExpanded = true),
                        ),
                        const SizedBox(width: 12),
                        _buildModernIconButton(
                          ThemeController.instance.isDarkMode
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          onTap: () {
                            ThemeController.instance.toggleTheme();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
            ),
          ),
          if (_isSearchExpanded)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(left: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.primary.withAlpha(50)),
                  boxShadow: ThemeController.instance.isDarkMode
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withAlpha(8),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: "Search apps...",
                          hintStyle: TextStyle(
                              color: AppColors.textSecondary.withAlpha(150),
                              fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSearchExpanded = false;
                          _searchQuery = "";
                          _searchController.clear();
                        });
                      },
                      child: Icon(Icons.close_rounded,
                          color: AppColors.textSecondary, size: 20),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernIconButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: ThemeController.instance.isDarkMode
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(Icons.bolt_rounded, _engagementTrend,
              "${_avgEngagement.toStringAsFixed(0)}%", "Daily Engagement"),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
              Icons.schedule_rounded, null, _totalStudyTime, "Active Study"),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      IconData icon, String? tag, String value, String label) {
    final isDark = ThemeController.instance.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(13), // opacity
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              if (tag != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainAction() {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FocusView(
                  cameras: widget.cameras,
                  autoStart: false,
                ),
              ),
            );
            await Future.delayed(const Duration(milliseconds: 300));
            _loadStats();
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // effect
              if (!ThemeController.instance.isDarkMode)
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(30),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                ),
              Container(
                width: 245,
                height: 245,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(20),
                ),
              ),
              // Button
              Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.primary, width: 6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(
                            ThemeController.instance.isDarkMode ? 80 : 40),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ]),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded,
                        color: AppColors.primary, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      "START",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "SESSION",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_rounded, color: AppColors.primary, size: 14),
            const SizedBox(width: 8),
            Text(
              "Vision Tracking Ready",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "",
          style: TextStyle(
            color: AppColors.textSecondary.withAlpha(150),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        )
      ],
    );
  }


  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _currentIndex = index);
          ThemeController.instance.currentNavIndex = index;
          if (index == 0) {
            _loadStats();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _getChildForIndex(int index) {
    switch (index) {
      case 0:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              _buildStatsSection(),
              const SizedBox(height: 32),
              _buildMainAction(),
            ],
          ),
        );
      case 1:
        return ReportsView(key: UniqueKey());
      case 2:
        return const ProfileView();
      case 3:
        return const GamesListView();
      default:
        return const SizedBox();
    }
  }

  Widget _buildSearchOverlay() {
    final filtered = _commandPalette.where((cmd) {
      final query = _searchQuery.toLowerCase();
      return cmd['title'].toLowerCase().contains(query) ||
          cmd['subtitle'].toLowerCase().contains(query);
    }).toList();

    return Positioned.fill(
      child: Container(
        color: AppColors.background.withAlpha(220),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final cmd = filtered[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GestureDetector(
                      onTap: () => _handleCommand(cmd['action']),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(cmd['icon'],
                                  color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cmd['title'],
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    cmd['subtitle'].toUpperCase(),
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded,
                                color: AppColors.textSecondary.withAlpha(100),
                                size: 12),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCommand(String action) {
    setState(() {
      _isSearchExpanded = false;
      _searchQuery = "";
      _searchController.clear();
    });

    if (action.startsWith('nav_')) {
      final index = int.parse(action.split('_')[1]);
      setState(() => _currentIndex = index);
      ThemeController.instance.currentNavIndex = index;
    } else if (action == 'focus') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FocusView(
            cameras: widget.cameras,
            autoStart: false,
          ),
        ),
      ).then((_) => _loadStats());
    }
  }
}
