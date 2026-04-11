import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/db/database_helper.dart';
import '../../../core/theme/theme_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/widgets/glass_error_banner.dart';
import 'personal_information_view.dart';
import 'notification_preferences_view.dart';
import 'linked_guardian_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  int _totalSessions = 0;
  int _streakDays = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final sessions = await DatabaseHelper.instance.getSessions(user?.uid);

      // Calculate
      int streak = 0;
      if (sessions.isNotEmpty) {
        // descending
        final uniqueDates = sessions
            .map((s) {
              final dt = DateTime.parse(s.startTime);
              return DateTime(dt.year, dt.month, dt.day);
            })
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

        // yesterday
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        if (uniqueDates.isNotEmpty) {
          var currentDateToCheck = todayDate;

          // yesterday
          if (uniqueDates.first.isAtSameMomentAs(todayDate) ||
              uniqueDates.first.isAtSameMomentAs(
                  todayDate.subtract(const Duration(days: 1)))) {
            currentDateToCheck = uniqueDates.first;

            for (var date in uniqueDates) {
              if (date.isAtSameMomentAs(currentDateToCheck)) {
                streak++;
                currentDateToCheck =
                    currentDateToCheck.subtract(const Duration(days: 1));
              } else {
                break; // streak
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalSessions = sessions.length;
          _streakDays = streak;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              "Failed to load profile stats: ${e.toString().split('\n')[0]}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.split(' ').first ?? 'Student';
    // Fallback
    final photoUrl = user?.photoURL ??
        'https://ui-avatars.com/api/?name=$displayName&background=00e5ff&color=0f2123&size=200';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "USER PROFILE",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 8.0),
                      child: GlassErrorBanner(
                        message: _errorMessage!,
                        onDismiss: () => setState(() => _errorMessage = null),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Section
                    const SizedBox(height: 24),
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.primary, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(100),
                                blurRadius: 15,
                              )
                            ],
                            image: DecorationImage(
                              image: NetworkImage(photoUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.verified,
                              color: AppColors.background, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: AppColors.primary.withAlpha(50)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, color: AppColors.primary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "DEEP WORK LEVEL: PRO",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stats
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          Expanded(
                              child: _buildStatCard("TOTAL SESSIONS",
                                  _isLoading ? "-" : "$_totalSessions")),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildStatCard(
                                  "FOCUS STREAK",
                                  _isLoading
                                      ? "-"
                                      : "$_streakDays Day${_streakDays == 1 ? '' : 's'}")),
                        ],
                      ),
                    ),

                    // Settings
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ACCOUNT SETTINGS",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildListTile(Icons.person, "Personal Information", onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PersonalInformationView(),
                              ),
                            );
                          }),
                          _buildListTile(
                              Icons.family_restroom, "Linked Guardian Account", onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LinkedGuardianView(),
                              ),
                            );
                          }),
                          _buildListTile(
                              Icons.notifications, "Notification Preferences", onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationPreferencesView(),
                              ),
                            );
                          }),
                          _buildThemeToggle(),
                          const SizedBox(height: 8),
                          _buildLogoutTile(context),
                          const SizedBox(height: 100), // Spacing
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ?? () {},
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ThemeController.instance.toggleTheme();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ValueListenableBuilder<bool>(
                    valueListenable:
                        ThemeController.instance.isDarkModeNotifier,
                    builder: (context, isDark, child) {
                      return Icon(
                        isDark ? Icons.dark_mode : Icons.light_mode,
                        color: AppColors.primary,
                        size: 20,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable:
                        ThemeController.instance.isDarkModeNotifier,
                    builder: (context, isDark, child) {
                      return Text(
                        isDark
                            ? "App Theme (Dark Mode)"
                            : "App Theme (Light Mode)",
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500),
                      );
                    },
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: ThemeController.instance.isDarkModeNotifier,
                  builder: (context, isDark, child) {
                    return Container(
                      width: 44,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        alignment: isDark
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.background : Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final bool? confirm = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors.border),
                ),
                title: Text("Log Out",
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                content: Text(
                  "Are you sure you want to log out of your account?",
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("Cancel",
                        style: TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Log Out",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );

          if (confirm == true) {
            // StreamBuilder
            await AuthService().signOut();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.redAccent.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.logout, color: Colors.redAccent, size: 20),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "Log Out",
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
