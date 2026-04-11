import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart' hide FocusMode;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/background_service.dart';
import '../controllers/focus_controller.dart';
import '../models/study_mode.dart';
import 'dnd_select_view.dart';
import '../widgets/calculator_dialog.dart';
import '../models/focus_mode.dart';
import '../utils/vision_utils.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/glass_error_banner.dart';
import '../../games/views/games_list_view.dart';
import '../../gemini/views/tutor_chat_view.dart';
import 'permission_flow_view.dart';

class FocusView extends StatefulWidget {
  final List<CameraDescription> cameras;
  final FocusMode? initialMode;
  final bool autoStart;
  final int? targetMinutes; // When set by a parent remote command
  final List<String>? blockedApps; // Target distractor apps set by parent
  const FocusView({
    super.key,
    required this.cameras,
    this.initialMode,
    this.autoStart = false,
    this.targetMinutes,
    this.blockedApps,
  });

  @override
  State<FocusView> createState() => _FocusViewState();
}

class _FocusViewState extends State<FocusView> with WidgetsBindingObserver {
  // Camera
  CameraController? _controller;
  late FaceDetector _faceDetector;
  late ImageLabeler _imageLabeler;
  final FocusController _focusController = FocusController();

  // Pipeline
  bool _isBusy = false;
  bool _isInitializing = true;
  bool _sessionStarted = false;
  bool _modeApplied = false;
  String? _errorMessage;
  DateTime _lastFrameTime = DateTime.now();
  bool _wasCameraActiveBeforePause = false;
  bool _wasInBreakMode = false;
  bool _isGameRouteActive = false;
  Future<void>? _disposeFuture;

  // App Guardian (DND)
  bool _dndEnabled = false;
  bool _hasGuardianPermissions = false;
  Set<String> _allowedApps = {};
  bool _dndStateLoaded = false;
  bool _timeUpAlertShown = false;

  void _onFocusChange() {
    if (!mounted) return;
    
    if (_focusController.isTimeUp && !_timeUpAlertShown) {
      _timeUpAlertShown = true;
      SystemSound.play(SystemSoundType.alert);
      _showTimeUpDialog();
    }

    if (_wasInBreakMode && !_focusController.isBreakMode) {
      if (_isGameRouteActive && mounted) {
        Navigator.pop(context);
        _isGameRouteActive = false;
      }
    }
    _wasInBreakMode = _focusController.isBreakMode;
    setState(() {});
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.primary),
          ),
          title: Row(
            children: [
              Icon(Icons.celebration_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text("Time's Up!",
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "Congratulations! You have completed your targeted study goal. Fantastic job maintaining your focus.",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Let them do overtime
                setState(() {
                  _focusController.isTimeUp = false;
                  _focusController.targetDurationSeconds = 0; // Disable target
                  _timeUpAlertShown = false;
                  _focusController.toggleTimer(); // Resume time (will count UP from now on)
                });
              },
              child: const Text("Enter Overtime",
                  style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _endSession(); // Actually end and pop
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("End Session",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _endSession() async {
    if (mounted) {
      if (_focusController.isTimerActive) {
        _focusController.toggleTimer();
      }
      Navigator.of(context).pop(); // Pops the FocusView and returns home
    }
  }

  Future<void> _loadDndState() async {
    final prefs = await SharedPreferences.getInstance();
    final allowedList = prefs.getStringList('allowed_apps') ?? [];
    if (!mounted) return;
    setState(() {
      _dndEnabled = true; // Always enabled now
      _allowedApps = Set.from(allowedList);
      _dndStateLoaded = true;
    });
    
    _hasGuardianPermissions = await BackgroundFocusService().checkPermissions();
    if (mounted) setState(() {});
  }

  Future<void> _saveDndState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dnd_enabled', _dndEnabled);
    await prefs.setStringList('allowed_apps', _allowedApps.toList());
  }

  /// Shows the full-screen permission flow and returns whether all permissions
  /// were granted so the session can proceed.
  Future<bool> _showPermissionFlow() async {
    final granted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PermissionFlowView()),
    );
    return granted == true;
  }

  // Performance

  late Uint8List _nv21Buffer;
  Timer? _stabilityWatchdog;

  @override
  void initState() {
    super.initState();
    _focusController.addListener(_onFocusChange);
    WidgetsBinding.instance.addObserver(this);
    _loadDndState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        enableLandmarks:
            false, // processing
      ),
    );
    _imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));

    // provided
    if (widget.initialMode != null && !_modeApplied) {
      _focusController.setFocusMode(widget.initialMode!);
      _modeApplied = true;
    }

    // explicitly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });

        if (widget.autoStart) {
          _startSession();
        }
      }
    });
  }

  Future<void> _bootPipeline() async {
    if (widget.cameras.isEmpty) {
      setState(() {
        _errorMessage = "Hardware Check: No Camera Found";
        _isInitializing = false;
      });
      return;
    }

    // Camera
    final front = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras[0],
    );

    // Initialize
    final controller = CameraController(
      front,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
      if (!mounted) return;

      // Reusable
      final size = controller.value.previewSize!;
      _nv21Buffer = Uint8List((size.width * size.height * 1.5).toInt());

      // Secure
      await controller.startImageStream((image) {
        if (!_isBusy) {
          // Throttle
          if (DateTime.now().difference(_lastFrameTime).inMilliseconds > 1000) {
            _runVisionPipeline(image);
            _lastFrameTime = DateTime.now();
          }
        }
      });

      setState(() {
        _controller = controller;
        _isInitializing = false;
        _sessionStarted = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Pipeline Boot Fail: ${e.toString().split('\n')[0]}";
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _startSession() async {
    debugPrint("FOCUS_DEBUG: _startSession called. autoStart=${widget.autoStart}");
    
    // 0. Ensure DND state is loaded before checking _dndEnabled
    if (!_dndStateLoaded) {
      debugPrint("FOCUS_DEBUG: Waiting for DND state to load...");
      await _loadDndState();
      if (!mounted) return;
    }

    // 0.5 — Duration selection.
    // If a parent remote command provided a target, skip the picker.
    int selectedDuration;
    if (widget.targetMinutes != null && widget.targetMinutes! > 0) {
      selectedDuration = widget.targetMinutes! * 60;
    } else {
      final int? picked = await _showDurationPickerBottomSheet();
      if (!mounted) return;
      if (picked == null) return; // User cancelled
      selectedDuration = picked;
    }
    _focusController.targetDurationSeconds = selectedDuration;
    
    debugPrint("FOCUS_DEBUG: _dndEnabled=$_dndEnabled, allowedAppsCount=${_allowedApps.length}");

    // 1. App Guardian / blocking setup
    //    ── Parent remote session: skip ALL user prompts and go straight to blacklist mode ──
    if (widget.autoStart && widget.blockedApps != null && widget.blockedApps!.isNotEmpty) {
      debugPrint("FOCUS_DEBUG: Parent session with ${widget.blockedApps!.length} blocked apps. Skipping DND prompts.");
      
      // Ensure permissions are in place before starting
      _hasGuardianPermissions = await BackgroundFocusService().checkPermissions();
      if (!_hasGuardianPermissions) {
        final granted = await _showPermissionFlow();
        if (!granted) return;
        _hasGuardianPermissions = await BackgroundFocusService().checkPermissions();
        if (!_hasGuardianPermissions) return;
      }
      if (!mounted) return;

    } else if (_dndEnabled) {
      // ── Normal student-initiated session ──
      bool usePrevious = false;
      if (_allowedApps.isNotEmpty) {
        if (widget.autoStart) {
          usePrevious = true;
        } else {
          final bool? choice = await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: AppColors.background,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "App Guardian",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You have ${_allowedApps.length} apps allowed from your previous session.",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Quick Start (Use Previous)",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.border),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "Edit Allowed Apps",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        if (choice == null) return; // User dismissed
        usePrevious = choice;
        }
      }

      debugPrint("FOCUS_DEBUG: App Guardian active. Checking permissions...");
      _hasGuardianPermissions = await BackgroundFocusService().checkPermissions();

      if (!_hasGuardianPermissions) {
        // Show full-screen permission flow
        final granted = await _showPermissionFlow();
        if (!granted) return; // User cancelled or didn't grant all permissions
        _hasGuardianPermissions = await BackgroundFocusService().checkPermissions();
        if (!_hasGuardianPermissions) return;
      }

      if (!mounted) return;

      if (!usePrevious) {
        // Show the enhanced App Picker/Focus Lock screen
        final Set<String>? result = await Navigator.push<Set<String>>(
          context,
          MaterialPageRoute(
            builder: (ctx) => DNDSelectView(
              initialAllowedApps: _allowedApps,
              onSave: (apps) {},
              showStartButton: true, // This enables the "LOCK & START" button
            ),
          ),
        );

        if (!mounted) return;
        if (result == null) return; // User cancelled/backed out, don't start session

        // Update the allowed apps from the picker's result
        setState(() {
          _allowedApps = result;
        });
        await _saveDndState();
      }
    }

    // 2. Proceed with Session Start
    setState(() {
      _isInitializing = true;
    });

    // Camera
    if (_controller == null || !_controller!.value.isInitialized) {
      await _bootPipeline();
    } else {
      setState(() {
        _isInitializing = false;
        _sessionStarted = true;
      });
    }

    // immediately
    if (!_focusController.isTimerActive) {
      _focusController.toggleTimer();
    }

    // Start blocking service
    if (widget.blockedApps != null && widget.blockedApps!.isNotEmpty) {
      // Parent remote session: BLACKLIST mode — block only the selected apps
      debugPrint("FOCUS_DEBUG: Starting blacklist service for ${widget.blockedApps!.length} apps: ${widget.blockedApps}");
      await BackgroundFocusService().start(widget.blockedApps!.toSet(), isBlacklist: true);
    } else if (_dndEnabled) {
      // Normal student session: WHITELIST mode — block everything except allowed apps
      await BackgroundFocusService().start(_allowedApps, isBlacklist: false);
    }
  }


  Future<void> _runVisionPipeline(CameraImage image) async {
    _isBusy = true;

    // Watchdog
    _stabilityWatchdog?.cancel();
    _stabilityWatchdog = Timer(const Duration(seconds: 4), () {
      if (_isBusy && mounted) {
        setState(() => _isBusy = false);
      }
    });

    try {
      final inputImage = await VisionUtils.buildInputImage(
        image: image,
        camera: _controller!.description,
        reusableBuffer: _nv21Buffer,
      );

      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      final labels = await _imageLabeler.processImage(inputImage);
      _focusController.processDetection(faces, labels: labels);
    } catch (e) {
      debugPrint("Vision Pipeline Lag: $e");
    } finally {
      _isBusy = false;
      _stabilityWatchdog?.cancel();
    }
  }

  Future<int?> _showDurationPickerBottomSheet() async {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  "Set Study Goal",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Choose how long you want to focus.",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                
                // Quick options
                Row(
                  children: [
                    Expanded(child: _buildDurationOption(context, 15 * 60, "15 min")),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDurationOption(context, 25 * 60, "25 min")),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDurationOption(context, 50 * 60, "50 min")),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildDurationOption(context, 90 * 60, "90 min")),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDurationOption(context, 120 * 60, "2 hrs")),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDurationOption(context, 0, "Open\nEnded", isPrimary: true)),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDurationOption(BuildContext context, int seconds, String label, {bool isPrimary = false}) {
    return InkWell(
      onTap: () => Navigator.pop(context, seconds),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary.withAlpha(20) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isPrimary ? AppColors.primary.withAlpha(80) : AppColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isPrimary ? AppColors.primary : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // backgrounded
      if (_controller != null && _controller!.value.isInitialized) {
        _disposeFuture = _controller!.dispose();
        _controller = null;
        _wasCameraActiveBeforePause = _focusController.isCameraActive;
        // toggle
        setState(() {});
      }
    } else if (state == AppLifecycleState.resumed) {
      // resumed
      if (_wasCameraActiveBeforePause && _controller == null) {
        setState(() {
          _isInitializing = true;
        });
        final pending = _disposeFuture;
        _disposeFuture = null;
        if (pending != null) {
          pending.whenComplete(() {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _bootPipeline();
            });
          });
        } else {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _bootPipeline();
          });
        }
      }
      // Re-check guardian permissions in case user just granted them in Settings
      if (_dndEnabled && !_hasGuardianPermissions) {
        BackgroundFocusService().checkPermissions().then((result) {
          if (mounted) setState(() => _hasGuardianPermissions = result);
        });
      }
    }
  }

  @override
  void dispose() {
    _focusController.removeListener(_onFocusChange);
    WidgetsBinding.instance.removeObserver(this);
    _stabilityWatchdog?.cancel();
    _focusController.saveSession();
    _controller?.dispose();
    _faceDetector.close();
    _imageLabeler.close();
    _focusController.dispose();
    // Stop App Guardian so blocking ends with the session
    if (_dndEnabled) BackgroundFocusService().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                GlassErrorBanner(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
                const Spacer(),
                const Icon(Icons.videocam_off_rounded,
                    color: Colors.white24, size: 80),
                const SizedBox(height: 24),
                const Text(
                  "Camera Access Failed",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "We couldn't start the AI tracking pipeline. You can still use the standard timer or try restarting.",
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _errorMessage = null;
                    _isInitializing = true;
                    _bootPipeline();
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text("Restart Pipeline",
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _errorMessage = null),
                  child: Text(
                    "Continue without AI",
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_sessionStarted,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        if (_focusController.isTimerActive) {
          _showEndSessionDialog();
        } else {
          // session
          // dialog
          // constructed
          _showEndSessionDialog();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: _focusController,
                        builder: (context, _) {
                          if (_focusController.currentMode == StudyMode.aiTutor) {
                            return Column(
                              children: [
                                const Expanded(
                                  flex: 3, 
                                  child: TutorChatView()
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(child: _buildModeIcons()),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              _buildInsightPanel(),
                              const Spacer(),
                            ],
                          );
                        },
                      ),
                    ),
                    if (_focusController.currentMode != StudyMode.aiTutor) ...[
                      _sessionStarted
                          ? _buildManualControls()
                          : _buildStartButton(),
                    ] else ...[
                      // In AI Tutor mode, use a more condensed control layout at the bottom
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           _buildManualControls(),
                           _buildTimerSection(),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8), // Reduced from 20 to fix offset
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: _focusController,
                builder: (context, _) {
                  if (_focusController.isBreakMode) {
                    return Positioned.fill(child: _buildBreakOverlay());
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
        floatingActionButton: null,
      ),
    );
  }

  Widget _buildStartButton() {
    return Column(
      children: [
        // ── Primary Start button ────────────────────────────────────────
        ElevatedButton(
          onPressed: _startSession,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            shadowColor: AppColors.primary.withAlpha(100),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_open_rounded,
                color: Colors.black,
                size: 26,
              ),
              SizedBox(width: 12),
              Text(
                "START WITH FOCUS LOCK",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "You will choose allowed apps before starting.",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_focusController.isTimerActive) {
                  _showEndSessionDialog();
                } else {
                  Navigator.pop(context);
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 24, 8),
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
            ),
            const SizedBox(width: 16),
            CircleAvatar(radius: 5, backgroundColor: AppColors.success),
            const SizedBox(width: 12),
            Text("AI TRACKING LIVE",
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
          ],
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => const CalculatorDialog(),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.calculate_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightPanel() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: _focusController,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInsightTile("POSTURE", _focusController.postureStatus),
                const SizedBox(height: 16),
                _buildInsightTile(
                    "DIRECTION", _focusController.gazeDirection.toUpperCase()),
                const SizedBox(height: 16),
                _buildTimerSection(),
                const SizedBox(height: 16),
                _buildModeIcons(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildCameraFeed(),
      ],
    );
  }

  Widget _buildInsightTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTimerSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("STUDY TIMER",
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(
            _focusController.formattedStudyTime,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildModeIcons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("CURRENT MODE",
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: FocusMode.predefinedModes.map((mode) {
            final isSelected = _focusController.selectedMode.id == mode.id;

            return GestureDetector(
              onTap: () => _focusController.setFocusMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isSelected ? 12 : 10),
                decoration: BoxDecoration(
                  color: isSelected ? mode.color : AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? mode.color.withAlpha(200)
                        : AppColors.border,
                    width: 2.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: mode.color.withAlpha(100),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Column(
                  children: [
                    Icon(
                      mode.icon,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      size: isSelected ? 24 : 20,
                    ),
                    if (isSelected) const SizedBox(height: 4),
                    if (isSelected)
                      Text(
                        mode.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCameraFeed() {
    return ListenableBuilder(
      listenable: _focusController,
      builder: (context, _) {
        if (!_focusController.isCameraActive) {
          return Container(
            width: 110,
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off,
                      color: AppColors.textSecondary, size: 32),
                  const SizedBox(height: 8),
                  Text("OFF",
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }

        if (_controller == null || !_controller!.value.isInitialized) {
          return Container(width: 110, height: 150, color: Colors.black26);
        }

        return RepaintBoundary(
          child: Container(
            width: 110,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: AppColors.primary.withAlpha(50), width: 1),
              boxShadow: ThemeController.instance.isDarkMode
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 10,
                      )
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize?.height ?? 1,
                  height: _controller!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildManualControls() {
    return ListenableBuilder(
      listenable: _focusController,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Camera
          _buildControlButton(
            icon: _focusController.isCameraActive
                ? Icons.videocam
                : Icons.videocam_off,
            label: _focusController.isCameraActive ? "Camera On" : "Camera Off",
            isActive: _focusController.isCameraActive,
            onTap: () async {
              _focusController.toggleCamera();
              if (!_focusController.isCameraActive) {
                // completely
                if (_controller != null) {
                  await _controller!.dispose();
                  _controller = null;
                  setState(() {});
                }
              } else {
                // physical
                if (_controller == null) {
                  setState(() {
                    _isInitializing = true;
                  });
                  await _bootPipeline();
                }
              }
            },
          ),
          const SizedBox(width: 24),
          // Button
          _buildControlButton(
            icon: Icons.stop_rounded,
            label: "End Session",
            isActive: false,
            isPrimary: true,
            onTap: () {
              if (_focusController.isTimerActive) {
                _focusController.toggleTimer(); // Pause before ending
              }
              _showEndSessionDialog();
            },
          ),
          const SizedBox(width: 24),
          _buildControlButton(
            icon: Icons.coffee_rounded,
            label: "Take Break",
            isActive: _focusController.isBreakMode,
            onTap: () {
              _showBreakDurationDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPrimary ? AppColors.primary : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isPrimary ? AppColors.primary : AppColors.border,
                width: 1,
              ),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                          color: AppColors.primary.withAlpha(40),
                          blurRadius: 15)
                    ]
                  : [],
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : AppColors.textPrimary,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive || isPrimary
                  ? AppColors.primary
                  : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showBreakDurationDialog() {
    final TextEditingController minController = TextEditingController();
    final TextEditingController secController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Set Break Time ☕", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Quick Select", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickTimeBtn(5, "5m", context),
                _buildQuickTimeBtn(10, "10m", context),
                _buildQuickTimeBtn(15, "15m", context),
              ],
            ),
            const SizedBox(height: 24),
            Text("Custom Time", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "MM",
                      hintStyle: TextStyle(color: AppColors.textSecondary.withAlpha(100)),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(":", style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: TextField(
                    controller: secController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: "SS",
                      hintStyle: TextStyle(color: AppColors.textSecondary.withAlpha(100)),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              int m = int.tryParse(minController.text) ?? 0;
              int s = int.tryParse(secController.text) ?? 0;
              int totalSec = (m * 60) + s;
              
              if (totalSec > 0) {
                Navigator.pop(context);
                _focusController.startBreak(totalSec);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Start Break", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTimeBtn(int minutes, String label, BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
        _focusController.startBreak(minutes * 60);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
      ),
      child: Text(label, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
    );
  }

  void _showEndSessionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("End Session? 🛑",
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          "Are you sure you want to end your deep work session now? Your progress will be saved.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (!_focusController.isTimerActive) {
                _focusController.toggleTimer(); // Resume if they cancelled
              }
            },
            child: Text("Keep Studying",
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // back
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("End & Save",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakOverlay() {
    return Container(
      color: Colors.black.withAlpha(220),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.coffee_rounded, size: 80, color: Colors.orangeAccent),
            const SizedBox(height: 24),
            const Text("Break Time!", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text("Returning in ${_focusController.formattedBreakTime}", style: const TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () async {
                _isGameRouteActive = true;
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const GamesListView(isStandalone: true)));
                _isGameRouteActive = false;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Play a Mini-Game 🎮", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                _focusController.endBreak();
              },
              child: const Text("Resume Focus Now", style: TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
