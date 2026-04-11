import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:usage_stats/usage_stats.dart';
import '../../../core/theme/colors.dart';

/// Full-screen permission flow shown when the user taps "Start Session"
/// with App Guardian enabled.
///
/// Returns `true` via `Navigator.pop` when all required permissions have
/// been granted, so the caller can safely start the focus session.
class PermissionFlowView extends StatefulWidget {
  const PermissionFlowView({super.key});

  @override
  State<PermissionFlowView> createState() => _PermissionFlowViewState();
}

class _PermissionFlowViewState extends State<PermissionFlowView>
    with WidgetsBindingObserver {
  bool _hasUsage = false;
  bool _hasBackground = false;
  bool _hasDisplay = false;

  bool _faqExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permissions whenever the app resumes (user returns from Settings).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final usage = await UsageStats.checkUsagePermission() ?? false;
    final background = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    final display = await FlutterForegroundTask.canDrawOverlays;
    if (!mounted) return;
    setState(() {
      _hasUsage = usage;
      _hasBackground = background;
      _hasDisplay = display;
    });
  }

  bool get _allGranted => _hasUsage && _hasBackground && _hasDisplay;

  // ── Allow handlers ──────────────────────────────────────────────────────────

  Future<void> _requestUsage() async {
    await UsageStats.grantUsagePermission();
    await _refresh();
  }

  Future<void> _requestBackground() async {
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    await _refresh();
  }

  Future<void> _requestDisplay() async {
    await FlutterForegroundTask.openSystemAlertWindowSettings();
    await _refresh();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Close button ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: Icon(Icons.close_rounded,
                    color: AppColors.textSecondary, size: 24),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // ── Headline ─────────────────────────────────────────────
                    Text(
                      'Enable permission\nto start focusing',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Permission rows ──────────────────────────────────────
                    _PermissionTile(
                      title: 'Usage permission',
                      subtitle: 'This allows us to track your app usage.',
                      isGranted: _hasUsage,
                      isLocked: false, // always available first
                      onAllow: _requestUsage,
                    ),

                    _Divider(),

                    _PermissionTile(
                      title: 'Background permission',
                      subtitle:
                          'Keeps Strive active when you switch apps.',
                      isGranted: _hasBackground,
                      isLocked: !_hasUsage, // locked until usage granted
                      onAllow: _requestBackground,
                    ),

                    _Divider(),

                    _PermissionTile(
                      title: 'Display over other apps',
                      subtitle:
                          'Actively pulls you back into Strive when distracted.',
                      isGranted: _hasDisplay,
                      isLocked: !_hasBackground, // locked until background granted
                      onAllow: _requestDisplay,
                    ),

                    const Spacer(),

                    // ── All-granted banner ───────────────────────────────────
                    if (_allGranted)
                      AnimatedOpacity(
                        opacity: 1,
                        duration: const Duration(milliseconds: 400),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha(20),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.success.withAlpha(70)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: AppColors.success, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'All set! You\'re ready to focus.',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Continue button ──────────────────────────────────────
                    AnimatedOpacity(
                      opacity: _allGranted ? 1.0 : 0.35,
                      duration: const Duration(milliseconds: 300),
                      child: GestureDetector(
                        onTap: _allGranted
                            ? () => Navigator.pop(context, true)
                            : null,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Continue',
                            style: TextStyle(
                              color: AppColors.background,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── FAQ row ──────────────────────────────────────────────
                    GestureDetector(
                      onTap: () =>
                          setState(() => _faqExpanded = !_faqExpanded),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primary.withAlpha(30),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.help_outline_rounded,
                                      color: AppColors.primary, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Why should I give this permission?',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _faqExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_right_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                            if (_faqExpanded) ...[
                              const SizedBox(height: 14),
                              const _FaqItem(
                                icon: Icons.bar_chart_rounded,
                                title: 'Usage permission',
                                body:
                                    'Strive needs to know which app is currently open so it can block distracting apps and keep you on task. Without this, the App Guardian cannot function.',
                              ),
                              const SizedBox(height: 10),
                              const _FaqItem(
                                icon: Icons.battery_charging_full_rounded,
                                title: 'Background permission',
                                body:
                                    'Android aggressively kills background processes to save battery. This permission ensures Strive\'s focus guardian stays alive for the entire session without being interrupted.',
                              ),
                              const SizedBox(height: 10),
                              const _FaqItem(
                                icon: Icons.screen_share_rounded,
                                title: 'Display over other apps',
                                body:
                                    'When you open a restricted app (like social media), this permission allows Strive to physically appear on top of that app and send you back to your study session.',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _PermissionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isGranted;
  final bool isLocked;
  final VoidCallback onAllow;

  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.isLocked,
    required this.onAllow,
  });

  @override
  Widget build(BuildContext context) {
    final isDimmed = isLocked && !isGranted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: AnimatedOpacity(
        opacity: isDimmed ? 0.38 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text block
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
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Action
            if (isGranted)
              Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 26)
            else
              GestureDetector(
                onTap: isDimmed ? null : onAllow,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDimmed
                        ? AppColors.border
                        : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'Allow',
                    style: TextStyle(
                      color: isDimmed
                          ? AppColors.textSecondary
                          : AppColors.background,
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
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppColors.border,
      height: 1,
    );
  }
}

class _FaqItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _FaqItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              const SizedBox(height: 3),
              Text(body,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
