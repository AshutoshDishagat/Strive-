import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/services/firestore_service.dart';
import 'link_student_view.dart';

class ParentHomeView extends StatefulWidget {
  const ParentHomeView({super.key});

  @override
  State<ParentHomeView> createState() => _ParentHomeViewState();
}

class _ParentHomeViewState extends State<ParentHomeView> {
  final _firestoreService = FirestoreService();

  bool _isSending = false;

  Future<void> _sendStartCommand(
      String studentId, int minutes, List<String> blockedApps) async {
    setState(() => _isSending = true);
    try {
      await _firestoreService.sendRemoteStartCommand(
          studentId, minutes, blockedApps);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to send — check your connection: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isSending = false);
      return;
    }
    if (!mounted) return;
    setState(() => _isSending = false);

    // Show a live-updating status dialog
    await _showCommandStatusDialog(studentId, minutes);
  }

  Future<void> _showCommandStatusDialog(String studentId, int minutes) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CommandStatusDialog(
        firestoreService: _firestoreService,
        studentId: studentId,
        minutes: minutes,
      ),
    );
  }

  void _showBlockedAppsPicker(String studentId, int minutes) {
    // A predefined list of common distractor apps
    final Map<String, String> commonApps = {
      'Instagram': 'com.instagram.android',
      'TikTok': 'com.zhiliaoapp.musically',
      'YouTube': 'com.google.android.youtube',
      'Snapchat': 'com.snapchat.android',
      'Facebook': 'com.facebook.katana',
      'Reddit': 'com.reddit.frontpage',
      'X / Twitter': 'com.twitter.android',
      'Discord': 'com.discord',
      'WhatsApp': 'com.whatsapp',
      'Netflix': 'com.netflix.mediaclient',
    };

    List<String> selectedPackages = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Select Apps to Block',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "These apps will be blocked on the student's phone.",
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        itemCount: commonApps.length,
                        itemBuilder: (context, index) {
                          String appName = commonApps.keys.elementAt(index);
                          String pkg = commonApps.values.elementAt(index);
                          bool isSelected = selectedPackages.contains(pkg);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withAlpha(30)
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: CheckboxListTile(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              checkColor: Colors.white,
                              title: Text(
                                appName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              onChanged: (bool? val) {
                                setBottomSheetState(() {
                                  if (val == true) {
                                    selectedPackages.add(pkg);
                                  } else {
                                    selectedPackages.remove(pkg);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _sendStartCommand(studentId, minutes, selectedPackages);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Start Session',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDurationPicker(String studentId) {
    final durations = [15, 25, 30, 45, 60, 90];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select Session Duration',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "The study session will start on the student's phone.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...durations.map((min) => GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showBlockedAppsPicker(studentId, min);
                        },
                        child: Container(
                          width: 90,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.primary.withAlpha(50)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$min',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('min',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      )),
                  // No Time Limit tile
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showBlockedAppsPicker(studentId, 0); // 0 means unlimited
                    },
                    child: Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(20),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.success.withAlpha(80)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.all_inclusive_rounded,
                              color: AppColors.success, size: 24),
                          const SizedBox(height: 4),
                          Text('No Limit',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _firestoreService.getUserProfileStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data;
        final studentId = profile?.linkedStudentId;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'PARENT DASHBOARD',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Overview',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                if (studentId == null || studentId.isEmpty) ...[
                  _buildNoStudentCard(),
                ] else ...[
                  // Auto-connected student card
                  FutureBuilder<String?>(
                    future: _firestoreService.getUserDocEmail(studentId),
                    builder: (context, emailSnapshot) {
                      final email = emailSnapshot.data ?? "Loading...";
                      return _buildConnectedCard(email);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Remote start
                  _buildRemoteStartCard(studentId),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoStudentCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.link_off_rounded, color: AppColors.textSecondary, size: 48),
          const SizedBox(height: 16),
          Text(
            'No Student Linked',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Link your child\'s student account to start monitoring and managing their sessions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LinkStudentView()),
              );
            },
            icon: const Icon(Icons.link_rounded, color: Colors.white, size: 20),
            label: const Text('Link a Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedCard(String studentEmail) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: ThemeController.instance.isDarkMode
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(30),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.link_rounded, color: AppColors.success, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONNECTED ACCOUNT',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  studentEmail,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Linked securely',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteStartCard(String studentId) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isSending ? null : () => _showDurationPicker(studentId),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withAlpha(180),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(80),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(18),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start Study Session',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap to remotely start a focus timer',
                    style: TextStyle(
                        color: Color(0xCCFFFFFF), fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withAlpha(180), size: 24),
          ],
        ),
      ),
    );
  }
}

/// A self-contained dialog that:
/// - Shows a spinner while waiting for the student's phone
/// - Switches to ✅ success when Firestore status == 'started'
/// - Switches to ⚠️ timeout after 15 seconds with no response
class _CommandStatusDialog extends StatefulWidget {
  final FirestoreService firestoreService;
  final String studentId;
  final int minutes;

  const _CommandStatusDialog({
    required this.firestoreService,
    required this.studentId,
    required this.minutes,
  });

  @override
  State<_CommandStatusDialog> createState() => _CommandStatusDialogState();
}

class _CommandStatusDialogState extends State<_CommandStatusDialog> {
  static const _timeoutSeconds = 15;

  // 'pending' | 'started' | 'timeout'
  String _phase = 'pending';
  int _secondsLeft = _timeoutSeconds;

  late final Timer _ticker;
  late final StreamSubscription<Map<String, dynamic>?> _sub;

  @override
  void initState() {
    super.initState();

    // Listen to Firestore for the student ack
    _sub = widget.firestoreService
        .watchCommandStatus(widget.studentId)
        .listen((data) {
      if (!mounted) return;
      final status = data?['status'] as String?;
      if (status == 'started' && _phase == 'pending') {
        setState(() => _phase = 'started');
        _ticker.cancel();
        // Auto-close after 2s
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });

    // Tick every second for countdown + timeout detection
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_phase != 'pending') return;
      final left = _secondsLeft - 1;
      if (left <= 0) {
        _ticker.cancel();
        setState(() {
          _secondsLeft = 0;
          _phase = 'timeout';
        });
      } else {
        setState(() => _secondsLeft = left);
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: _phase == 'started'
              ? AppColors.success
              : _phase == 'timeout'
                  ? Colors.orangeAccent
                  : AppColors.primary,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.all(28),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_phase == 'started') ...[
            // ✅ SUCCESS
            const Icon(Icons.check_circle_rounded,
                color: Colors.greenAccent, size: 56),
            const SizedBox(height: 16),
            Text(
              'Session Started! ✅',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.minutes == 0
                  ? 'Unlimited study session is now active on the student\'s phone.'
                  : '${widget.minutes}-min session is now active on the student\'s phone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ] else if (_phase == 'timeout') ...[
            // ⚠️ TIMEOUT
            const Icon(Icons.phonelink_off_rounded,
                color: Colors.orangeAccent, size: 56),
            const SizedBox(height: 16),
            Text(
              'No Response',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'The student\'s phone did not respond within $_timeoutSeconds seconds.\n\n'
              'Possible reasons:\n'
              '• Phone is off or has no internet\n'
              '• The Strive app is not open\n'
              '• App is running in background',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OK',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            // ⏳ PENDING — spinner + countdown
            SizedBox(
              height: 52,
              width: 52,
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text(
              'Waiting for Student\'s Phone…',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.minutes == 0
                  ? 'Command sent. Starting unlimited session…'
                  : 'Command sent. Starting ${widget.minutes}-min session…',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Text(
              'Timing out in ${_secondsLeft}s…',
              style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ],
      ),
    );
  }
}
