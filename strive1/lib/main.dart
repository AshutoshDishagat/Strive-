import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme_controller.dart';
import 'core/services/auth_service.dart';
import 'core/services/background_service.dart';
import 'core/services/firestore_service.dart';
import 'features/auth/views/login_view.dart';
import 'features/home/views/home_view.dart';
import 'features/parent/views/parent_main_view.dart';
import 'features/focus/views/focus_view.dart';
import 'models/user_profile.dart';

// background
List<CameraDescription> _cameras = [];

/// A global navigator key so the remote-command listener can push routes
/// from anywhere — even when HomeView is not mounted.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // immediately
  runApp(const StriveApp());
}

class StriveApp extends StatefulWidget {
  const StriveApp({super.key});

  @override
  State<StriveApp> createState() => _StriveAppState();
}

class _StriveAppState extends State<StriveApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    // Initialize
    _initFuture = _initializeSystem();
  }

  Future<void> _initializeSystem() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Initialise foreground-task config so it is ready before any session starts
    BackgroundFocusService().init();
    try {
      _cameras = await availableCameras();
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.instance.isDarkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'Strive 😁',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          theme: ThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: AppColors.background,
            primaryColor: AppColors.primary,
            fontFamily: 'Inter',
          ),
          home: FutureBuilder(
            future: _initFuture,
            builder: (context, snapshot) {
              // Firebase
              if (snapshot.connectionState == ConnectionState.done) {
                return AuthWrapper(cameras: _cameras);
              }
              // background
              // instantly
              return Scaffold(
                backgroundColor: AppColors.background,
                body: const SizedBox.shrink(),
              );
            },
          ),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final List<CameraDescription> cameras;

  const AuthWrapper({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        // immediately
        if (snapshot.hasData) {
          // Patch existing accounts to ensure email is saved correctly
          AuthService().patchLegacyProfile(snapshot.data!);

          // User is logged in — check their role
          return _RoleGate(cameras: cameras);
        }

        // Handle
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const SizedBox.shrink(),
          );
        }

        // Return
        return const LoginView();
      },
    );
  }
}

/// Fetches the user's role from Firestore and routes to the correct home.
/// Also hosts the GLOBAL remote-command listener so study sessions can be
/// launched from the parent's phone regardless of which screen the student  
/// is currently on.
class _RoleGate extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _RoleGate({required this.cameras});

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  late final Stream<UserProfile?> _profileStream;
  UserRole? _localRole;

  // ── Global remote-command listener ────────────────────────────────────────
  StreamSubscription<Map<String, dynamic>?>? _remoteCommandSub;
  bool _isHandlingRemoteCommand = false;
  int? _lastHandledCommandId;

  @override
  void initState() {
    super.initState();
    _profileStream = _firestoreService.getUserProfileStream();
    _initLocalRoleAndListener();
  }

  Future<void> _initLocalRoleAndListener() async {
    final role = await _authService.getLocalRole();
    if (mounted) {
      setState(() {
        _localRole = role;
      });
      // ONLY start the listener and FCM if this device is locally acting as a Student
      if (_localRole == UserRole.student) {
        _startRemoteCommandListener();
        _setupFCM();
      }
    }
  }

  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Save token to Firestore so Cloud Function can send to it
    final token = await messaging.getToken();
    if (token != null) {
      await _firestoreService.setStudentFCMToken(token);
    }

    // Handle token refresh
    messaging.onTokenRefresh.listen((fcmToken) {
      _firestoreService.setStudentFCMToken(fcmToken);
    }).onError((err) {});

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleFCMNavigation(message);
    });

    // Handle initial message if app was terminated and opened via notification
    messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        // Delay slightly to ensure navigator is mounted
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleFCMNavigation(message);
        });
      }
    });
  }

  void _handleFCMNavigation(RemoteMessage message) {
    if (message.data['action'] == 'start') {
      final minutes = int.tryParse(message.data['duration_minutes']?.toString() ?? '25') ?? 25;
      final isUnlimited = minutes == 0;
      
      List<String>? blockedApps;
      final rawBlockedApps = message.data['blocked_apps'];
      if (rawBlockedApps is String) {
        // sometimes FCM payload lists are stringified
        blockedApps = rawBlockedApps.replaceAll('[', '').replaceAll(']', '').split(',').map((e) => e.trim()).toList();
      }

      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => FocusView(
              cameras: widget.cameras,
              autoStart: true,
              targetMinutes: isUnlimited ? null : minutes,
              blockedApps: blockedApps,
            ),
          ),
        );
      }
    }
  }

  /// Listens to Firestore for a parent-issued "start" command.
  /// Works regardless of which role/screen is active on this device.
  void _startRemoteCommandListener() {
    _remoteCommandSub =
        _firestoreService.getRemoteCommandStream().listen((data) async {
      if (data == null) return;
      if (data['handled'] == true) return;
      if (data['action'] != 'start') return;
      if (_isHandlingRemoteCommand) return;

      final cmdId = data['command_id'] as int?;
      if (cmdId != null && cmdId == _lastHandledCommandId) return;

      _isHandlingRemoteCommand = true;
      _lastHandledCommandId = cmdId;
      
      final minutes = (data['duration_minutes'] as num?)?.toInt() ?? 25;
      final isUnlimited = minutes == 0;

      List<String>? blockedApps;
      if (data['blocked_apps'] != null) {
        // Firestore lists come as List<dynamic>
        blockedApps = List<String>.from(data['blocked_apps'] as List);
      }

      // Mark as handled immediately so the parent status dialog updates
      await _firestoreService.markCommandHandled();

      // Use the global navigator key — works from any screen
      final nav = navigatorKey.currentState;
      if (nav == null) {
        _isHandlingRemoteCommand = false;
        return;
      }

      // Show a banner notification
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isUnlimited
                        ? '📚 Your parent started an unlimited study session!'
                        : '📚 Your parent started a $minutes-min study session!',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      await Future.delayed(const Duration(seconds: 3));

      // Push FocusView via the global navigator
      await nav.push(
        MaterialPageRoute(
          builder: (_) => FocusView(
            cameras: widget.cameras,
            autoStart: true,
            targetMinutes: isUnlimited ? null : minutes,
            blockedApps: blockedApps,
          ),
        ),
      );

      _isHandlingRemoteCommand = false;
    });
  }

  @override
  void dispose() {
    _remoteCommandSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        // Show loading while waiting for the first stream emission
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final profile = snapshot.data;
        
        // Prioritize local role if available (set during login on this device)
        // This ensures shared accounts can have different views on different hardware
        final effectiveRole = _localRole ?? profile?.role ?? UserRole.student;

        // If parent role detected → parent main navigation
        if (effectiveRole == UserRole.parent) {
          return const ParentMainView();
        }

        // Default to student view
        return HomeView(cameras: widget.cameras);
      },
    );
  }
}
