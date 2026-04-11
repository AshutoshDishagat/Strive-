import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../../../core/db/database_helper.dart';
import '../../../core/services/firestore_service.dart';
import '../../../models/session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/study_mode.dart';
import '../models/focus_mode.dart';

class FocusController extends ChangeNotifier {
  // State
  FocusMode selectedMode = FocusMode.predefinedModes.first;
  // State
  StudyMode currentMode = StudyMode.readingBook;
  String statusMessage = "Initializing Focus AI...";
  String gazeDirection = "NONE";
  String postureStatus = "SEARCHING...";
  double engagementScore = 0.0;
  DateTime sessionStartTime = DateTime.now();

  // Timer
  bool isTimerActive = false;
  bool isCameraActive = true;
  int studyDurationSeconds = 0;
  int targetDurationSeconds = 0;
  bool isTimeUp = false;
  Timer? _studyTimer;

  // Detection
  DateTime? lastDetectionTime;
  int _noFaceCounter = 0;
  static const int _maxRetriesAt2Fps = 2; // second

  // Distraction
  bool isDistracted = false;
  bool isBreakMode = false;

  // Break
  int breakDurationRemaining = 0;
  Timer? _breakTimer;

  void startBreak(int seconds) {
    isBreakMode = true;
    breakDurationRemaining = seconds;
    if (isTimerActive) {
      toggleTimer(); // Pauses the timer
    }
    statusMessage = "On Break ☕";
    postureStatus = "RECHARGING";
    gazeDirection = "NONE";
    _setDistraction(false);

    _breakTimer?.cancel();
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (breakDurationRemaining > 0) {
        breakDurationRemaining--;
        notifyListeners();
      } else {
        endBreak();
      }
    });

    notifyListeners();
  }

  void endBreak() {
    isBreakMode = false;
    _breakTimer?.cancel();
    statusMessage = "Break Over. Ready to Focus!";
    postureStatus = "SEARCHING...";
    gazeDirection = "NONE";
    
    // Resume automatically if not active
    if (!isTimerActive) {
      toggleTimer();
    }
    notifyListeners();
  }

  String get formattedBreakTime {
    int m = breakDurationRemaining ~/ 60;
    int s = breakDurationRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Performance
  String _prevStatus = "";
  int _prevSeconds = -1;

  FocusController() {
    // configuration
    _applyModeSettings(selectedMode);
  }

  void setFocusMode(FocusMode mode) {
    selectedMode = mode;
    _applyModeSettings(mode);
    notifyListeners();
  }

  void _applyModeSettings(FocusMode mode) {
    currentMode = mode.studyMode;
    isCameraActive = mode.isCameraRequired;

    if (isCameraActive) {
      statusMessage = "Mode: ${mode.title} (AI On)";
    } else {
      statusMessage = "Mode: ${mode.title} (Manual)";
    }
  }

  void processDetection(List<Face> faces, {List<ImageLabel> labels = const []}) {
    if (isBreakMode) return;
    lastDetectionTime = DateTime.now();

    final detectedItems = labels.map((l) => l.label.toLowerCase()).toList();
    
    // Print detected items to console for debugging
    debugPrint("Detected Labels: $detectedItems");

    final bool hasPhone = detectedItems.contains('mobile phone') || detectedItems.contains('cell phone') || detectedItems.contains('phone') || detectedItems.contains('tablet') || detectedItems.contains('telephone') || detectedItems.contains('laptop');
    
    final bool hasBook = detectedItems.any((item) => 
        ['book', 'binder', 'spiral notebook', 'notebook', 'paper', 'document', 'text', 'publication', 'reading', 'novel', 'diary', 'magazine', 'textbook', 'page'].contains(item)
    );

    if (faces.isEmpty) {
      _noFaceCounter++;
      if (_noFaceCounter >= _maxRetriesAt2Fps) {
        _setDistraction(true);
        postureStatus = "SEARCHING...";
        gazeDirection = "NONE";
        
        if (hasPhone) {
          statusMessage = "Phone Detected! 📴 Put it away";
        } else {
          statusMessage = "No Student Detected! ❌";
        }
        _notifyIfChanged();
      }
      return;
    }

    _noFaceCounter = 0;
    final face = faces[0];
    final bool isStrictMode = currentMode == StudyMode.strictBook;

    // Orientation
    final double? tiltX = face.headEulerAngleX; // Down
    final double? turnY = face.headEulerAngleY; // Right

    // centered
    final bool readingPose = (tiltX != null && tiltX < -12);
    final bool centeredPose = (turnY != null && turnY > -15 && turnY < 15);

    if (isStrictMode && hasPhone) {
      gazeDirection = "Using Phone";
      postureStatus = "DISTRACTED";
      statusMessage = "Phone Detected! 📴 Do not use phone while studying.";
      _setDistraction(true);
    } else if (readingPose && centeredPose) {
      if (!isStrictMode || hasBook) {
        gazeDirection = "Reading Book";
        postureStatus = "OPTIMAL";
        statusMessage = "Studying from Book 📖";
        _setDistraction(false);
      } else {
        gazeDirection = "Looking Down";
        postureStatus = "DISTRACTED";
        statusMessage = "Looking Down (No Book Detected) ❌";
        _setDistraction(true);
      }
    } else if (centeredPose) {
      gazeDirection = "Center";
      postureStatus = "OPTIMAL";
      statusMessage = "Focused on Screen ✅";
      _setDistraction(false);
    } else {
      gazeDirection = turnY != null ? (turnY > 15 ? "Left" : "Right") : "Away";
      postureStatus = "DISTRACTED";
      statusMessage = "Gaze Alert: Looking $gazeDirection! 🧐";
      _setDistraction(true);
    }

    // Engagement
    if (isDistracted) {
      engagementScore = (engagementScore > 0) ? engagementScore - 0.02 : 0;
    } else {
      engagementScore = (engagementScore < 1.0) ? engagementScore + 0.01 : 1.0;
    }

    _notifyIfChanged();
  }

  void _notifyIfChanged() {
    if (statusMessage != _prevStatus) {
      _prevStatus = statusMessage;
      notifyListeners();
    }
  }

  void _setDistraction(bool state) {
    if (state == isDistracted) return;

    isDistracted = state;
  }

  Future<void> saveSession() async {
    // Don't save empty sessions (e.g. user opened & immediately closed)
    if (studyDurationSeconds < 5) {
      debugPrint("Session too short (<5s), skipping save.");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    // focused
    final session = Session(
      userId: user?.uid,
      startTime: sessionStartTime.toIso8601String(),
      durationSeconds: studyDurationSeconds,
      engagementScore: engagementScore,
      studyMode: currentMode.name,
    );

    // SQLite
    await DatabaseHelper.instance.insertSession(session);

    // Firestore
    try {
      await FirestoreService().saveSession(session);
    } catch (e) {
      debugPrint("Failed to save session to Firestore: $e");
    }
  }

  void toggleTimer() {
    isTimerActive = !isTimerActive;
    if (isTimerActive) {
      statusMessage = isCameraActive
          ? "Resumed: AI Tracking Focus..."
          : "Resumed: Standard Timer Active";
      _studyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!isCameraActive) {
          // disabled
          studyDurationSeconds++;
          _checkTimeUp();
          notifyListeners();
        } else {
          // enabled
          bool isFocused = false;
          switch (currentMode) {
            case StudyMode.readingBook:
            case StudyMode.strictBook:
              isFocused = (gazeDirection == "Reading Book");
              break;
            case StudyMode.phoneScreen:
              isFocused = (gazeDirection == "Center");
              break;
            case StudyMode.mix:
              isFocused = (gazeDirection == "Reading Book" ||
                  gazeDirection == "Center");
              break;
            case StudyMode.aiTutor:
              isFocused = true; // Won't execute, camera is disabled
              break;
          }

          if (isFocused) {
            studyDurationSeconds++;
            if (studyDurationSeconds != _prevSeconds) {
              _prevSeconds = studyDurationSeconds;
              _checkTimeUp();
              notifyListeners();
            }
          }
        }
      });
    } else {
      statusMessage = "Session Paused ⏸️";
      _studyTimer?.cancel();
    }
    notifyListeners();
  }

  void _checkTimeUp() {
    if (targetDurationSeconds > 0 && studyDurationSeconds >= targetDurationSeconds && !isTimeUp) {
      isTimeUp = true;
      toggleTimer(); // Automatically pause the session
    }
  }

  void toggleCamera() {
    isCameraActive = !isCameraActive;
    if (!isCameraActive) {
      // Switched
      statusMessage = "Camera Off: Standard Timer ⏳";
      gazeDirection = "N/A";
      postureStatus = "MANUAL";
      _setDistraction(false);
    } else {
      // Switched
      statusMessage = "Camera On: AI Tracking Resumed 👁️";
      postureStatus = "SEARCHING...";
      gazeDirection = "NONE";
    }
    notifyListeners();
  }

  String get formattedStudyTime {
    int displaySeconds = targetDurationSeconds > 0 
        ? (targetDurationSeconds - studyDurationSeconds).clamp(0, targetDurationSeconds)
        : studyDurationSeconds;

    int hours = displaySeconds ~/ 3600;
    int minutes = (displaySeconds % 3600) ~/ 60;
    int seconds = displaySeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void setStudyMode(StudyMode newMode) {
    if (currentMode == newMode) return;
    currentMode = newMode;
    if (isCameraActive) {
      statusMessage = "Mode Switched: AI Tracking... 👁️";
      postureStatus = "SEARCHING...";
      gazeDirection = "NONE";
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _studyTimer?.cancel();
    _breakTimer?.cancel();
    super.dispose();
  }
}
