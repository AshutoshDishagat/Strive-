import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:usage_stats/usage_stats.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) async {
    // Initial
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // foreground
    if (Platform.isAndroid) {
      try {
        DateTime now = DateTime.now();
        // Use a slightly larger window to ensure we catch the current foreground app
        List<UsageInfo> usageStats = await UsageStats.queryUsageStats(
            now.subtract(const Duration(seconds: 10)), now);

        if (usageStats.isNotEmpty) {
          // Sort by lastTimeUsed to get the most recent app
          UsageInfo? lastApp;
          for (var info in usageStats) {
            if (info.packageName == null || info.lastTimeUsed == null) continue;
            if (lastApp == null ||
                (int.parse(info.lastTimeUsed!) >
                    int.parse(lastApp.lastTimeUsed!))) {
              lastApp = info;
            }
          }

          // package
          final String myPackageName =
              await FlutterForegroundTask.getData<String>(
                      key: 'my_package_name') ??
                  "com.example.strive1"; // Primary fallback

          if (lastApp != null) {
            if (lastApp.packageName != myPackageName) {
              // Retrieve
              final String? targetAppsJson =
                  await FlutterForegroundTask.getData<String>(
                      key: 'target_apps');
              final String? isBlacklistStr =
                  await FlutterForegroundTask.getData<String>(
                      key: 'is_blacklist');
              final bool isBlacklist = isBlacklistStr == 'true';

              bool isRestricted = false;

              if (isBlacklist) {
                // Blacklist mode: Block ONLY apps in the list
                if (targetAppsJson != null && targetAppsJson.isNotEmpty) {
                  final List<String> blockedApps = targetAppsJson.split(',');
                  if (blockedApps.contains(lastApp.packageName)) {
                    isRestricted = true;
                  }
                }
              } else {
                // Whitelist mode (Default): Block everything EXCEPT allowed apps
                isRestricted = true;
                if (targetAppsJson != null && targetAppsJson.isNotEmpty) {
                  final List<String> allowedApps = targetAppsJson.split(',');
                  if (allowedApps.contains(lastApp.packageName)) {
                    isRestricted = false;
                  }
                }
              }

              if (isRestricted) {
                log("Deep Work Protector: Restricted app detected: ${lastApp.packageName}. Blocking.");

                final String? firstSeen =
                    await FlutterForegroundTask.getData<String>(
                        key: 'restricted_since');
                if (firstSeen == null || firstSeen.isEmpty) {
                  await FlutterForegroundTask.saveData(
                      key: 'restricted_since',
                      value: DateTime.now().millisecondsSinceEpoch.toString());
                } else {
                  int firstTime = int.parse(firstSeen);
                  if (DateTime.now().millisecondsSinceEpoch - firstTime >=
                      10000) {
                    // 10 seconds passed, aggressively return to strive
                    FlutterForegroundTask.launchApp();
                  }
                }
              } else {
                await FlutterForegroundTask.saveData(
                    key: 'restricted_since', value: '');
              }
            } else {
              // Strive is back in foreground, reset timer
              await FlutterForegroundTask.saveData(
                  key: 'restricted_since', value: '');
            }
          }
        }
      } catch (e) {
        log("DND Monitor Error: $e");
      }
    }
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // Cleanup
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }
}

class BackgroundFocusService {
  static final BackgroundFocusService _instance =
      BackgroundFocusService._internal();
  factory BackgroundFocusService() => _instance;
  BackgroundFocusService._internal();

  void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'strive_focus_channel',
        channelName: 'Strive Focus Mode',
        channelDescription: 'Maintains focus session in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        buttons: [
          const NotificationButton(id: 'stop', text: 'End Session'),
        ],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 300, // Aggressive 0.3s check for lockdown
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> checkPermissions() async {
    bool hasUsage = await UsageStats.checkUsagePermission() ?? false;
    bool hasOverlay = await FlutterForegroundTask.canDrawOverlays;
    bool isIgnoringBattery =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;

    return hasUsage && hasOverlay && isIgnoringBattery;
  }

  Future<void> requestPermissions() async {
    if (!(await UsageStats.checkUsagePermission() ?? false)) {
      await UsageStats.grantUsagePermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    if (!await FlutterForegroundTask.canDrawOverlays) {
      await FlutterForegroundTask.openSystemAlertWindowSettings();
    }
  }

  Future<bool> start(Set<String> targetApps,
      {bool autoRequest = true, bool isBlacklist = false}) async {
    if (!await checkPermissions()) {
      if (autoRequest) {
        await requestPermissions();
      }
      return false; // Cannot start without permissions
    }

    // Save target apps and mode for the background isolate
    await FlutterForegroundTask.saveData(
        key: 'target_apps', value: targetApps.join(','));
    await FlutterForegroundTask.saveData(
        key: 'is_blacklist', value: isBlacklist.toString());

    // Save current package name so the blocker recognizes when we are "Home"
    String myPkg = "com.example.strive1";
    try {
      final usageStats = await UsageStats.queryUsageStats(
        DateTime.now().subtract(const Duration(seconds: 1)),
        DateTime.now(),
      );
      if (usageStats.isNotEmpty) {
        // The most recently used app right now is Strive itself
        myPkg = usageStats.last.packageName ?? myPkg;
      }
    } catch (_) {}

    await FlutterForegroundTask.saveData(key: 'my_package_name', value: myPkg);

    return await FlutterForegroundTask.startService(
      notificationTitle: 'Deep Work Active 😁',
      notificationText: 'Focus AI is tracking your session.',
      callback: startCallback,
    );
  }

  Future<bool> stop() async {
    return await FlutterForegroundTask.stopService();
  }
}
