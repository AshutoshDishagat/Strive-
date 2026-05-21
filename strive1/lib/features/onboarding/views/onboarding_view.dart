import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/firestore_service.dart';

/// Full-screen onboarding flow shown once on first launch after login.
/// Collects age group + requests ALL permissions before showing homepage.
/// Permissions are MANDATORY — user cannot proceed without granting them.
class OnboardingView extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingView({super.key, required this.onComplete});

  static const String _onboardingKey = 'onboarding_complete';

  /// Check if onboarding has been completed for the current user
  static Future<bool> isOnboardingComplete() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_onboardingKey}_$uid') ?? false;
  }

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Page state
  int _currentPage = 0; // 0 = Welcome, 1 = Age Group, 2 = Permissions, 3 = Ready

  // Age group
  String? _selectedAgeGroup;

  // Permissions — start as false, only set true after actual check
  bool _hasNotification = false;
  bool _hasUsage = false;
  bool _hasBackground = false;
  bool _hasDisplay = false;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();

    // Deliberately do NOT check permissions at init — check only when
    // the user reaches the permissions page, so they see the "Allow" buttons first.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// Re-check permissions whenever the app resumes (user returns from Settings).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentPage == 2) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final notification = await Permission.notification.isGranted;
    final usage = await UsageStats.checkUsagePermission() ?? false;
    final background =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    final display = await FlutterForegroundTask.canDrawOverlays;
    if (!mounted) return;
    setState(() {
      _hasNotification = notification;
      _hasUsage = usage;
      _hasBackground = background;
      _hasDisplay = display;
    });
  }

  bool get _allPermissionsGranted =>
      _hasNotification && _hasUsage && _hasBackground && _hasDisplay;

  /// Count of how many permissions are granted
  int get _grantedCount {
    int c = 0;
    if (_hasNotification) c++;
    if (_hasUsage) c++;
    if (_hasBackground) c++;
    if (_hasDisplay) c++;
    return c;
  }

  void _animateToPage(int page) {
    _fadeController.reset();
    _slideController.reset();
    setState(() => _currentPage = page);
    _fadeController.forward();
    _slideController.forward();

    // When entering permissions page, do a fresh check
    if (page == 2) {
      _refreshPermissions();
    }
  }

  // ── Permission request handlers ───────────────────────────────────────────

  Future<void> _requestNotification() async {
    await Permission.notification.request();
    // Small delay to let the OS finish setting the permission
    await Future.delayed(const Duration(milliseconds: 500));
    await _refreshPermissions();
  }

  Future<void> _requestUsage() async {
    await UsageStats.grantUsagePermission();
    // This opens system settings — refresh will happen on resume
  }

  Future<void> _requestBackground() async {
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    await Future.delayed(const Duration(milliseconds: 500));
    await _refreshPermissions();
  }

  Future<void> _requestDisplay() async {
    await FlutterForegroundTask.openSystemAlertWindowSettings();
    // This opens system settings — refresh will happen on resume
  }

  // ── Complete onboarding ───────────────────────────────────────────────────

  bool _isCompleting = false;

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return; // prevent double-taps
    setState(() => _isCompleting = true);

    // Save age group to Firestore — wrapped in try-catch so a Firestore
    // failure never blocks onboarding completion.
    try {
      if (_selectedAgeGroup != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirestoreService()
              .updateUserProfile(user.uid, {'age_group': _selectedAgeGroup});
        }
      }
    } catch (e) {
      debugPrint('[Onboarding] Failed to save age group — continuing anyway: $e');
    }

    // Mark onboarding as complete
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('${OnboardingView._onboardingKey}_$uid', true);
    } catch (e) {
      debugPrint('[Onboarding] Failed to save prefs — continuing anyway: $e');
    }

    if (mounted) {
      widget.onComplete();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: _buildCurrentPage(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case 0:
        return _buildWelcomePage();
      case 1:
        return _buildAgeGroupPage();
      case 2:
        return _buildPermissionsPage();
      case 3:
        return _buildReadyPage();
      default:
        return _buildWelcomePage();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Page 0: Welcome
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withAlpha(40),
                  AppColors.primary.withAlpha(15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withAlpha(60)),
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              color: AppColors.primary,
              size: 56,
            ),
          ),

          const SizedBox(height: 40),

          Text(
            "Welcome to Strive",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            "Let's set up your experience in just\na few quick steps.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const Spacer(flex: 3),

          _buildStepIndicator(),
          const SizedBox(height: 24),

          _buildPrimaryButton(
            label: "GET STARTED",
            onTap: () => _animateToPage(1),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Page 1: Age Group
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAgeGroupPage() {
    final ageGroups = [
      {'value': '4-8', 'label': 'Ages 4-8', 'emoji': '🧒', 'desc': 'Fun & gamified experience', 'img': 'assets/kids_mascot_fox.png'},
      {'value': '9-13', 'label': 'Ages 9-13', 'emoji': '🎮', 'desc': 'Engaging challenges & rewards', 'img': 'assets/teens_mascot_robot.png'},
      {'value': '14+', 'label': 'Ages 14+', 'emoji': '🎓', 'desc': 'Professional deep work mode', 'img': null},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildBackButton(() => _animateToPage(0)),
          const SizedBox(height: 24),

          Text(
            "Select your\nage group",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll tailor the interface to your needs.",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Age group cards
          ...ageGroups.map((group) {
            final isSelected = _selectedAgeGroup == group['value'];
            final hasImg = group['img'] != null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () =>
                    setState(() => _selectedAgeGroup = group['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withAlpha(15)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withAlpha(120)
                          : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.primary.withAlpha(20), blurRadius: 16, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Row(
                    children: [
                      // Cartoon image for kids, emoji for others
                      if (hasImg)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            group['img'] as String,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(group['emoji'] as String, style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(group['label'] as String, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(group['desc'] as String, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.textSecondary.withAlpha(80),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          _buildStepIndicator(),
          const SizedBox(height: 24),

          AnimatedOpacity(
            opacity: _selectedAgeGroup != null ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: _buildPrimaryButton(
              label: "CONTINUE",
              onTap: _selectedAgeGroup != null ? () => _animateToPage(2) : null,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Page 2: Permissions (MANDATORY — no skip)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPermissionsPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildBackButton(() => _animateToPage(1)),
          const SizedBox(height: 20),

          Text(
            'Grant permissions\nto continue',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            "All permissions are required for Strive to work.",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 10),

          // Progress badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _allPermissionsGranted
                  ? AppColors.success.withAlpha(15)
                  : AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _allPermissionsGranted
                  ? "✓  All 4 permissions granted"
                  : "$_grantedCount of 4 permissions granted",
              style: TextStyle(
                color: _allPermissionsGranted
                    ? AppColors.success
                    : AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Scrollable permission cards ──────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildPermissionCard(
                    icon: Icons.notifications_active_rounded,
                    title: "Notifications",
                    subtitle: "Receive session reminders & parent alerts.",
                    isGranted: _hasNotification,
                    isLocked: false,
                    onAllow: _requestNotification,
                  ),
                  const SizedBox(height: 10),

                  _buildPermissionCard(
                    icon: Icons.bar_chart_rounded,
                    title: "Usage Access",
                    subtitle: "Track which app is open to block distractions.",
                    isGranted: _hasUsage,
                    isLocked: !_hasNotification,
                    onAllow: _requestUsage,
                  ),
                  const SizedBox(height: 10),

                  _buildPermissionCard(
                    icon: Icons.battery_charging_full_rounded,
                    title: "Background Activity",
                    subtitle: "Keep Strive running during focus sessions.",
                    isGranted: _hasBackground,
                    isLocked: !_hasUsage,
                    onAllow: _requestBackground,
                  ),
                  const SizedBox(height: 10),

                  _buildPermissionCard(
                    icon: Icons.screen_share_rounded,
                    title: "Display Over Apps",
                    subtitle: "Pull you back when you open restricted apps.",
                    isGranted: _hasDisplay,
                    isLocked: !_hasBackground,
                    onAllow: _requestDisplay,
                  ),

                  const SizedBox(height: 16),

                  // All-granted success banner
                  if (_allPermissionsGranted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.success.withAlpha(70)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'All set! You\'re ready to go.',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Pinned bottom section ───────────────────────────────────────
          const SizedBox(height: 12),
          _buildStepIndicator(),
          const SizedBox(height: 16),

          AnimatedOpacity(
            opacity: _allPermissionsGranted ? 1.0 : 0.35,
            duration: const Duration(milliseconds: 300),
            child: _buildPrimaryButton(
              label: _allPermissionsGranted
                  ? "CONTINUE"
                  : "GRANT ALL PERMISSIONS TO CONTINUE",
              onTap: _allPermissionsGranted ? () => _animateToPage(3) : null,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Page 3: Ready!
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildReadyPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withAlpha(40),
                  AppColors.success.withAlpha(15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success.withAlpha(60)),
            ),
            child: Icon(
              Icons.celebration_rounded,
              color: AppColors.success,
              size: 56,
            ),
          ),

          const SizedBox(height: 40),

          Text(
            "You're all set!",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            "Your personalized experience is ready.\nLet's start your focus journey!",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  Icons.cake_rounded,
                  "Age Group",
                  _selectedAgeGroup ?? "Not set",
                ),
                const SizedBox(height: 12),
                Divider(color: AppColors.border),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  Icons.security_rounded,
                  "Permissions",
                  "All granted ✓",
                ),
              ],
            ),
          ),

          const Spacer(flex: 3),

          _buildStepIndicator(),
          const SizedBox(height: 24),

          _isCompleting
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _buildPrimaryButton(
                  label: "LAUNCH STRIVE 🚀",
                  onTap: _completeOnboarding,
                ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared Widgets
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBackButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(Icons.arrow_back_rounded,
            color: AppColors.textSecondary, size: 20),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index == _currentPage;
        final isPast = index < _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 32 : 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: isActive
                ? AppColors.primary
                : isPast
                    ? AppColors.primary.withAlpha(60)
                    : AppColors.border,
          ),
        );
      }),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    VoidCallback? onTap,
    bool isSecondary = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: isSecondary ? AppColors.surface : AppColors.primary,
          borderRadius: BorderRadius.circular(18),
          border: isSecondary ? Border.all(color: AppColors.border) : null,
          boxShadow: isSecondary
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSecondary ? AppColors.textPrimary : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  /// Modern card-style permission tile with clear Allow button
  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required bool isLocked,
    required VoidCallback onAllow,
  }) {
    final isDimmed = isLocked && !isGranted;

    return AnimatedOpacity(
      opacity: isDimmed ? 0.35 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isGranted
              ? AppColors.success.withAlpha(10)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isGranted
                ? AppColors.success.withAlpha(60)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isGranted
                    ? AppColors.success.withAlpha(20)
                    : AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isGranted ? AppColors.success : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Action: granted checkmark OR allow button
            if (isGranted)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF4CAF50), size: 20),
              )
            else
              GestureDetector(
                onTap: isDimmed ? null : onAllow,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDimmed
                        ? AppColors.border
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: isDimmed
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ],
                  ),
                  child: Text(
                    'Allow',
                    style: TextStyle(
                      color: isDimmed
                          ? AppColors.textSecondary
                          : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
