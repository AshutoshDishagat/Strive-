import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/colors.dart';

class NotificationPreferencesView extends StatefulWidget {
  const NotificationPreferencesView({super.key});

  @override
  State<NotificationPreferencesView> createState() => _NotificationPreferencesViewState();
}

class _NotificationPreferencesViewState extends State<NotificationPreferencesView> {
  bool _dailyReminders = true;
  bool _sessionCompletion = true;
  bool _guardianAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyReminders = prefs.getBool('notif_daily_reminders') ?? true;
      _sessionCompletion = prefs.getBool('notif_session_completion') ?? true;
      _guardianAlerts = prefs.getBool('notif_guardian_alerts') ?? true;
    });
  }

  Future<void> _setPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary,
                        size: 16,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "NOTIFICATIONS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32), 
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Push Notifications",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSwitchTile(
                      icon: Icons.calendar_today_rounded,
                      title: "Daily Study Reminders",
                      subtitle: "Get a nudge to maintain your focus streak.",
                      value: _dailyReminders,
                      onChanged: (val) {
                        setState(() => _dailyReminders = val);
                        _setPreference('notif_daily_reminders', val);
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.done_all_rounded,
                      title: "Session Completion",
                      subtitle: "Alert when your study timer runs out.",
                      value: _sessionCompletion,
                      onChanged: (val) {
                        setState(() => _sessionCompletion = val);
                        _setPreference('notif_session_completion', val);
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.security_rounded,
                      title: "App Guardian Alerts",
                      subtitle: "Vibrations and alerts when you are distracted.",
                      value: _guardianAlerts,
                      onChanged: (val) {
                        setState(() => _guardianAlerts = val);
                        _setPreference('notif_guardian_alerts', val);
                      },
                    ),

                    const SizedBox(height: 48),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, color: AppColors.primary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              "To change sounds and vibration styles, go to your phone's system settings.",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
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

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withAlpha(50),
            ),
          ],
        ),
      ),
    );
  }
}
