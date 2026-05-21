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
import '../../../core/services/firestore_service.dart';
import 'dart:async';
import '../../../models/user_profile.dart';

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
  String _selectedAgeGroup = '14+';
  StreamSubscription<UserProfile?>? _profileSub;

  @override
  void initState() {
    super.initState();
    _profileSub = FirestoreService().getUserProfileStream().listen((profile) {
      if (mounted && profile?.ageGroup != null) {
        // Map old values to current groups
        String ag = profile!.ageGroup!;
        if (ag == '19+' || ag == '14-18') ag = '14+';
        setState(() => _selectedAgeGroup = ag);
      }
    });
    _loadStats();
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final sessions = await DatabaseHelper.instance.getSessions(user?.uid);

      int streak = 0;
      if (sessions.isNotEmpty) {
        final uniqueDates = sessions
            .map((s) {
              final dt = DateTime.parse(s.startTime);
              return DateTime(dt.year, dt.month, dt.day);
            })
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        if (uniqueDates.isNotEmpty) {
          var currentDateToCheck = todayDate;
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
                break;
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateAgeGroup(String newGroup) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final previousGroup = _selectedAgeGroup;
    // Optimistic local update — UI changes immediately
    setState(() {
      _selectedAgeGroup = newGroup;
      _isLoading = true;
    });

    try {
      await FirestoreService().updateUserProfile(user.uid, {'age_group': newGroup});
      debugPrint('[ProfileView] Age group updated to $newGroup');
    } catch (e) {
      debugPrint('[ProfileView] Failed to update age group: $e');
      // Revert on failure
      if (mounted) {
        setState(() {
          _selectedAgeGroup = previousGroup;
          _errorMessage = 'Failed to update age group. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.split(' ').first ?? 'Student';
    final photoUrl = user?.photoURL ??
        'https://ui-avatars.com/api/?name=$displayName&background=00e5ff&color=0f2123&size=200';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _selectedAgeGroup == '14+' ? "ACCOUNT PROFILE" : "MY DETAILS 🦊",
                    style: tt.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: cs.primary,
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
                    const SizedBox(height: 24),
                    // ── Avatar ────────────────────────────────────────────
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.primary, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withAlpha(100),
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
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.verified, color: bg, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: tt.titleLarge?.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.primary.withAlpha(50)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, color: cs.primary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "DEEP WORK LEVEL: PRO",
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Stats ─────────────────────────────────────────────
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          Expanded(
                              child: _buildStatCard(context, "TOTAL SESSIONS",
                                  _isLoading ? "-" : "$_totalSessions")),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildStatCard(
                                  context,
                                  "FOCUS STREAK",
                                  _isLoading
                                      ? "-"
                                      : "$_streakDays Day${_streakDays == 1 ? '' : 's'}")),
                        ],
                      ),
                    ),
                    // ── Settings ──────────────────────────────────────────
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ACCOUNT SETTINGS",
                            style: tt.labelSmall?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildListTile(context, Icons.person, "Personal Information",
                              onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PersonalInformationView()),
                            );
                          }),
                          _buildListTile(context, Icons.family_restroom,
                              "Linked Guardian Account", onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LinkedGuardianView()),
                            );
                          }),
                          // Age Group Selector
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: cs.primary.withAlpha(40)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withAlpha(25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.cake_rounded,
                                        color: cs.primary, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text("App Age Group",
                                        style: tt.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w500)),
                                  ),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedAgeGroup,
                                      dropdownColor: cs.surface,
                                      icon: Icon(Icons.keyboard_arrow_down,
                                          color: cs.onSurface.withAlpha(130),
                                          size: 20),
                                      style: TextStyle(
                                        color: cs.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          _updateAgeGroup(newValue);
                                        }
                                      },
                                      items: const [
                                        DropdownMenuItem(
                                            value: '4-8',
                                            child: Text('4-8 years')),
                                        DropdownMenuItem(
                                            value: '9-13',
                                            child: Text('9-13 years')),
                                        DropdownMenuItem(
                                            value: '14+',
                                            child: Text('14+ years')),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _buildListTile(
                              context, Icons.notifications, "Notification Preferences",
                              onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const NotificationPreferencesView()),
                            );
                          }),
                          _buildThemeToggle(context),
                          const SizedBox(height: 8),
                          _buildLogoutTile(context),
                          const SizedBox(height: 100),
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

  Widget _buildStatCard(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: tt.labelSmall?.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                color: cs.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              )),
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title,
      {VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withAlpha(40)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(title,
                      style: tt.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500)),
                ),
                Icon(Icons.chevron_right,
                    color: cs.onSurface.withAlpha(130)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => ThemeController.instance.toggleTheme(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withAlpha(40)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ValueListenableBuilder<bool>(
                    valueListenable:
                        ThemeController.instance.isDarkModeNotifier,
                    builder: (context, isDark, _) => Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: cs.primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable:
                        ThemeController.instance.isDarkModeNotifier,
                    builder: (context, isDark, _) => Text(
                      isDark
                          ? "App Theme (Dark Mode)"
                          : "App Theme (Light Mode)",
                      style:
                          tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: ThemeController.instance.isDarkModeNotifier,
                  builder: (context, isDark, _) => Container(
                    width: 44,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDark ? cs.primary : AppColors.border,
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
                          color: isDark ? bg : Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
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
            builder: (BuildContext ctx) {
              final cs2 = Theme.of(ctx).colorScheme;
              final tt2 = Theme.of(ctx).textTheme;
              return AlertDialog(
                backgroundColor: cs2.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: cs2.primary.withAlpha(60)),
                ),
                title: Text("Log Out",
                    style: tt2.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                content: Text(
                  "Are you sure you want to log out of your account?",
                  style: tt2.bodyMedium,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text("Cancel",
                        style: TextStyle(color: cs2.onSurface.withAlpha(160))),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
            await AuthService().signOut();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.redAccent.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.logout, color: Colors.redAccent, size: 20),
              SizedBox(width: 16),
              Expanded(
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
