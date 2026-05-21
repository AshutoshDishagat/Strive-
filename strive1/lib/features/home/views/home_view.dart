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
import '../../../core/services/firestore_service.dart';
import '../../../models/user_profile.dart';
import '../../../core/services/background_service.dart';
import '../../focus/views/permission_flow_view.dart';

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
  UserProfile? _userProfile;



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

  StreamSubscription<UserProfile?>? _profileSub;

  final List<Map<String, dynamic>> _dailyMissions = [
    {'title': 'Read 15 mins', 'icon': Icons.menu_book_rounded, 'color': Colors.cyanAccent, 'bgColor': Colors.cyan.withAlpha(51), 'done': false, 'xp': 50},
    {'title': 'Complete Homework', 'icon': Icons.assignment_rounded, 'color': Colors.purpleAccent, 'bgColor': Colors.purple.withAlpha(51), 'done': true, 'xp': 75},
    {'title': 'Focus Session', 'icon': Icons.timer_rounded, 'color': Colors.greenAccent, 'bgColor': Colors.green.withAlpha(51), 'done': false, 'xp': 100},
  ];

  @override
  void initState() {
    super.initState();
    _profileSub = FirestoreService().getUserProfileStream().listen((profile) {
      if (mounted) {
        debugPrint('[HomeView] Stream fired — ageGroup=${profile?.ageGroup}, role=${profile?.role}');
        // Auto-migrate old '19+' to '14+'
        if (profile?.ageGroup == '19+') {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            FirestoreService().updateUserProfile(user.uid, {'age_group': '14+'});
          }
        }
        setState(() => _userProfile = profile);
        debugPrint('[HomeView] _isKids=$_isKids');
      }
    });
    _loadStats();
  }

  bool get _isKids => _userProfile?.ageGroup == '4-8' || _userProfile?.ageGroup == '9-13';

  @override
  void dispose() {

    _profileSub?.cancel();
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
      backgroundColor: _isKids ? const Color(0xFF131834) : AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Container(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Background
              if (!_isKids) ...[
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
              ],
              // Content
              Column(
                children: [
                  _isKids ? _buildKidsHeader() : _buildHeader(),
                  if (!_isKids) const SizedBox(height: 16),
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
                    child: _getChildForIndex(_currentIndex),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          decoration: BoxDecoration(
              color: _isKids
                  ? const Color(0xFF1A1F3C)
                  : AppColors.surface.withAlpha(ThemeController.instance.isDarkMode ? 240 : 220),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _isKids ? Colors.cyanAccent.withAlpha(30) : AppColors.border.withAlpha(80),
              ),
              boxShadow: [
                BoxShadow(
                  color: _isKids
                      ? Colors.cyanAccent.withAlpha(10)
                      : Colors.black.withAlpha(ThemeController.instance.isDarkMode ? 40 : 10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.grid_view_rounded, _isKids ? "Dashboard" : "Home"),
              _buildNavItem(1, Icons.bar_chart_rounded, _isKids ? "Progress" : "Reports"),
              _buildNavItem(2, Icons.person_rounded, "Profile"),
              _buildNavItem(3, Icons.sports_esports_rounded, _isKids ? "Play" : "Games"),
            ],
          ),
        ),
      ),
      extendBody: true,
    );
  }

  Widget _buildKidsHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL ??
        'https://img.freepik.com/premium-photo/3d-avatar-boy-character_113255-92636.jpg';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF131834),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E2445), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Profile image with purple neon ring
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.purpleAccent.withAlpha(150), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.purpleAccent.withAlpha(30),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(photoUrl),
              backgroundColor: const Color(0xFF1E2445),
            ),
          ),
          const SizedBox(width: 14),
          // Strive logo text
          const Text(
            "Strive",
            style: TextStyle(
              color: Colors.purpleAccent,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: Color(0x66BA68C8),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _userProfile?.ageGroup == '9-13' ? '🎮' : '🚀',
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
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
              GestureDetector(
                onTap: _showAgeGroupSelector,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _userProfile?.ageGroup == '4-8' ? "STRIVE ADVENTURE! 🚀" : "STRIVE COMMAND",
                          style: TextStyle(
                            color: _userProfile?.ageGroup == '4-8' ? Colors.orangeAccent : AppColors.textSecondary,
                            fontSize: _userProfile?.ageGroup == '4-8' ? 12 : 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit, size: 10, color: AppColors.textSecondary),
                      ],
                    ),
                    Text(
                      _userProfile?.ageGroup == '4-8' ? "Hi, $displayName! 🌟" : "Hello, $displayName",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: _userProfile?.ageGroup == '4-8' ? 22 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_userProfile?.ageGroup == '4-8') ...[
                      const SizedBox(height: 12),
                      _buildKidsProgressBar(),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
    );
  }

  void _showAgeGroupSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Change Age Group (Testing)",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...['4-8', '9-13', '14+'].map((age) {
                  return ListTile(
                    title: Text("$age years", style: TextStyle(color: AppColors.textPrimary)),
                    trailing: _userProfile?.ageGroup == age ? Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () async {
                      Navigator.pop(context);
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        // Update Firestore
                        await FirestoreService().updateUserProfile(user.uid, {'age_group': age});
                        // Immediately update local state so UI reflects the change
                        if (mounted) {
                          final freshProfile = await FirestoreService().getUserProfile();
                          setState(() {
                            if (freshProfile != null) {
                              _userProfile = freshProfile;
                            } else {
                              // Fallback: create a local profile with new age group
                              _userProfile = UserProfile(
                                uid: user.uid,
                                email: user.email ?? '',
                                role: _userProfile?.role ?? UserRole.student,
                                linkedStudentId: _userProfile?.linkedStudentId,
                                ageGroup: age,
                              );
                            }
                          });
                        }
                        _loadStats();
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
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

  Widget _buildKidsProgressBar() {
    int totalMins = 0;
    try {
      final parts = _totalStudyTime.split(' ');
      if (parts.length == 2) {
        int h = int.parse(parts[0].replaceAll('h', ''));
        int m = int.parse(parts[1].replaceAll('m', ''));
        totalMins = h * 60 + m;
      }
    } catch (_) {}

    int level = (totalMins / 15).floor() + 1; // Level up every 15 minutes!
    int currentMinsInLevel = totalMins % 15;
    double progress = currentMinsInLevel / 15.0;
    
    // Choose emoji based on level
    final emojis = ["🥚", "🐣", "🐥", "🐢", "🦊", "🦁", "🐉", "🦄"];
    String currentEmoji = emojis[(level - 1) % emojis.length];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withAlpha(50), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Level $level $currentEmoji",
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                "$currentMinsInLevel / 15 XP",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.orange.withAlpha(30),
              color: Colors.orangeAccent,
              minHeight: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final isKids = _isKids;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
              isKids ? Icons.star_rounded : Icons.bolt_rounded,
              _engagementTrend,
              "${_avgEngagement.toStringAsFixed(0)}%",
              isKids ? "Super Power" : "Daily Engagement"),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
              isKids ? Icons.timer_rounded : Icons.schedule_rounded,
              null,
              _totalStudyTime,
              isKids ? "Quest Time" : "Active Study"),
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
    final isKids = _isKids;

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            // Ask for permissions BEFORE the start
            final hasPerms = await BackgroundFocusService().checkPermissions();
            if (!mounted) return;
            
            if (!hasPerms) {
              final granted = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PermissionFlowView()),
              );
              if (granted != true) return; // Abort if not granted
            }

            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FocusView(
                  cameras: widget.cameras,
                  autoStart: false,
                  isKidsMode: isKids,
                ),
              ),
            );
            await Future.delayed(const Duration(milliseconds: 300));
            _loadStats();
          },
          child: isKids ? _buildKidsStartButton() : _buildRegularStartButton(),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isKids ? Icons.pets_rounded : Icons.visibility_rounded, color: isKids ? Colors.orange : AppColors.primary, size: 14),
            const SizedBox(width: 8),
            Text(
              isKids ? "Your animal friend is watching! 👀" : "Vision Tracking Ready",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRegularStartButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
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
    );
  }

  Widget _buildKidsStartButton() {
    return const _PulsingButton();
  }



  Widget _buildKidsDashboardContent() {
    int completedCount = _dailyMissions.where((q) => q['done'] == true).length;
    int totalXP = _dailyMissions.where((q) => q['done'] == true).fold(0, (sum, q) => sum + (q['xp'] as int));
    
    return Column(
      children: [
        // Top Neon Cyber Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E2445), Color(0xFF131834)], // Sleeker internal gradient
            ),
            borderRadius: BorderRadius.circular(24), // Softer, more modern curve
            border: Border.all(color: Colors.purpleAccent.withAlpha(76), width: 1.5),
            boxShadow: [
               BoxShadow(
                 color: Colors.purpleAccent.withAlpha(25),
                 blurRadius: 25,
                 spreadRadius: 2,
                 offset: const Offset(0, 8),
               )
            ],
          ),
          child: Column(
            children: [
              // The brain image with double border ring effect
              Container(
                padding: const EdgeInsets.all(4), // Ring thickness
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.cyanAccent, Colors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withAlpha(102),
                      blurRadius: 25,
                      spreadRadius: 2,
                    )
                  ]
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF131834), // Inner background
                  ),
                  padding: const EdgeInsets.all(2), // Inner gap
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.network(
                      'https://img.freepik.com/premium-photo/happy-cute-brain-character-with-big-eyes-3d-render_642456-42.jpg',
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => const Icon(Icons.psychology, size: 80, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _userProfile?.ageGroup == '9-13' ? "Welcome back, Scholar!" : "Ready for Action?",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNeonStat("ENERGY", "100%", Colors.greenAccent, Icons.battery_charging_full_rounded),
                  _buildNeonStat("STREAK", "5 Days", Colors.orangeAccent, Icons.local_fire_department_rounded),
                  _buildNeonStat("TOTAL XP", "$totalXP", Colors.purpleAccent, Icons.stars_rounded),
                ],
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () async {
                   final hasPerms = await BackgroundFocusService().checkPermissions();
                   if (!mounted) return;
                   
                   if (!hasPerms) {
                     final granted = await Navigator.push(
                       context,
                       MaterialPageRoute(builder: (_) => const PermissionFlowView()),
                     );
                     if (granted != true) return;
                   }
       
                   if (!mounted) return;
                   await Navigator.push(
                     context,
                     MaterialPageRoute(builder: (_) => FocusView(cameras: widget.cameras, autoStart: false, isKidsMode: _isKids)),
                   );
                   await Future.delayed(const Duration(milliseconds: 300));
                   _loadStats();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFBA68C8), Color(0xFF9C27B0)], // Purple Gradient
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFBA68C8).withAlpha(102),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ]
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        "ENTER FOCUS ZONE",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Daily Missions
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF131834),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment_turned_in_rounded, color: Colors.cyanAccent, size: 28),
                  SizedBox(width: 12),
                  Text(
                    "Today's Missions",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Quests List
              ...List.generate(_dailyMissions.length, (index) {
                final quest = _dailyMissions[index];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      quest['done'] = !quest['done'];
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: quest['done'] ? (quest['bgColor'] as Color).withAlpha(25) : const Color(0xFF1E2445),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: quest['done'] ? (quest['color'] as Color).withAlpha(128) : Colors.white10,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: quest['done'] ? (quest['color'] as Color).withAlpha(51) : quest['bgColor'],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(quest['icon'] as IconData, color: quest['color'], size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: TextStyle(
                                  color: quest['done'] ? Colors.white60 : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  decoration: quest['done'] ? TextDecoration.lineThrough : TextDecoration.none,
                                ),
                                child: Text(quest['title']),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (quest['color'] as Color).withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "+${quest['xp']} XP",
                                  style: TextStyle(
                                    color: quest['color'],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: quest['done'] ? quest['color'] : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: quest['done'] ? Colors.transparent : Colors.white24, 
                              width: 2.5
                            ),
                            boxShadow: quest['done'] ? [
                              BoxShadow(color: (quest['color'] as Color).withAlpha(102), blurRadius: 10, spreadRadius: 1)
                            ] : [],
                          ),
                          child: quest['done'] ? const Icon(Icons.check_rounded, color: Colors.white, size: 28) : null,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Achievements Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E2445), Color(0xFF131834)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.purpleAccent.withAlpha(76), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.purpleAccent.withAlpha(25),
                blurRadius: 20,
                offset: const Offset(0, 5),
              )
            ]
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars_rounded, color: Colors.purpleAccent, size: 28),
                  SizedBox(width: 12),
                  Text(
                    "Daily Rewards",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  bool unlocked = index < completedCount;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: unlocked ? Colors.purpleAccent.withAlpha(51) : Colors.white10,
                      border: Border.all(
                        color: unlocked ? Colors.purpleAccent : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: unlocked ? [
                        BoxShadow(
                          color: Colors.purpleAccent.withAlpha(128),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ] : [],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        unlocked ? Icons.military_tech_rounded : Icons.lock_rounded,
                        key: ValueKey(unlocked),
                        color: unlocked ? Colors.purpleAccent : Colors.white38,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$completedCount / 3 Rewards Unlocked",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildNeonStat(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: color.withAlpha(128),
                blurRadius: 10,
              )
            ]
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }


  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    final isKids = _isKids;

    // Swap Games icon and label for Kids
    IconData displayIcon = icon;
    String displayLabel = label;
    if (isKids && index == 3) {
      displayIcon = Icons.toys_rounded;
      displayLabel = "Play";
    }

    final activeColor = Theme.of(context).colorScheme.primary;

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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withAlpha(18) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isActive ? activeColor.withAlpha(30) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: activeColor.withAlpha(25),
                            blurRadius: 12,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
                ),
                child: Icon(
                  displayIcon,
                  color: isActive ? activeColor : AppColors.textSecondary.withAlpha(140),
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayLabel,
                style: TextStyle(
                  color: isActive ? activeColor : AppColors.textSecondary.withAlpha(140),
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: 0.2,
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
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: _isKids ? _buildKidsDashboardContent() : Column(
            children: [
              _buildStatsSection(),
              const SizedBox(height: 32),
              _buildMainAction(),
              const SizedBox(height: 100), // Extra space for floating bottom nav bar
            ],
          ),
        );
      case 1:
        final reportsWidget = ReportsView(key: UniqueKey(), isKidsMode: _isKids);
        return Theme(
          data: _isKids ? _kidsTheme() : Theme.of(context),
          child: reportsWidget,
        );
      case 2:
        return Theme(
          data: _isKids ? _kidsTheme() : Theme.of(context),
          child: const ProfileView(),
        );
      case 3:
        return const GamesListView();
      default:
        return const SizedBox();
    }
  }

  /// Dark neon ThemeData — mirrors Kids Dashboard palette exactly
  ThemeData _kidsTheme() {
    const kBg      = Color(0xFF131834);
    const kSurface = Color(0xFF1E2445);
    const kCard    = Color(0xFF1A1F3C);
    const kPurple  = Colors.purpleAccent;
    const kCyan    = Colors.cyanAccent;

    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: kBg,
      colorScheme: const ColorScheme.dark(
        primary:   kPurple,
        secondary: kCyan,
        surface:   kSurface,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        error:     Colors.redAccent,
      ),
      cardColor: kCard,
      dividerColor: const Color(0x4DBA68C8),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F1428),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: kPurple,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
        iconTheme: IconThemeData(color: Colors.white70),
      ),
      textTheme: const TextTheme(
        displayLarge:  TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        displayMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        bodyLarge:     TextStyle(color: Colors.white),
        bodyMedium:    TextStyle(color: Colors.white70),
        bodySmall:     TextStyle(color: Colors.white54),
        titleLarge:    TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        titleMedium:   TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        titleSmall:    TextStyle(color: kPurple, fontWeight: FontWeight.bold),
        labelLarge:    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        labelSmall:    TextStyle(color: Colors.white54, letterSpacing: 1.3),
      ),
      iconTheme: const IconThemeData(color: kPurple, size: 22),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kPurple,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPurple,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: const Color(0x66BA68C8),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: kSurface,
        selectedColor: kPurple,
        side: BorderSide(color: kCyan, width: 1.5),
        labelStyle: TextStyle(color: Colors.white, fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x4DBA68C8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPurple, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white38),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: kPurple),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: kSurface,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: Color(0x4DBA68C8), width: 1.5),
        ),
        titleTextStyle: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        contentTextStyle: TextStyle(color: Colors.white70),
      ),
    );
  }



  void _handleCommand(String action) {
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

class _PulsingButton extends StatefulWidget {
  const _PulsingButton();

  @override
  State<_PulsingButton> createState() => _PulsingButtonState();
}

class _PulsingButtonState extends State<_PulsingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withAlpha(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.yellow.withAlpha(50),
                      blurRadius: 50,
                      spreadRadius: 15,
                    )
                  ],
                ),
              ),
              Container(
                width: 245,
                height: 245,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orangeAccent.withAlpha(60),
                ),
              ),
              Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purple[100],
                    border: Border.all(color: Colors.purpleAccent, width: 8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purpleAccent.withAlpha(100),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: const Offset(0, 8),
                      ),
                    ]),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("🚀", style: TextStyle(fontSize: 50)),
                    const SizedBox(height: 8),
                    const Text(
                      "GO!",
                      style: TextStyle(
                        color: Color(0xFF6A1B9A),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

