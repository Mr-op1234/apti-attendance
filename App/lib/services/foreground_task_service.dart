import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// Foreground Task Handler for background monitoring
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MonitoringTaskHandler());
}

class MonitoringTaskHandler extends TaskHandler {
  // Production URL - Hugging Face Spaces
  static const String _baseUrl = 'https://itsmrop-apti-attendance.hf.space';
  String? _slotId;
  bool _alarmTriggered = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Load saved slot
    final prefs = await SharedPreferences.getInstance();
    _slotId = prefs.getString('selected_slot');
    _alarmTriggered = false;
    print('[ForegroundTask] Started monitoring slot: $_slotId');
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    if (_slotId == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/status?slot=$_slotId'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String status = data['status'] ?? 'unknown';
        final bool? isOpen = data['is_open'];
        
        // Update notification with current status
        FlutterForegroundTask.updateService(
          notificationTitle: 'APTI Attendance',
          notificationText: 'Status: $status',
        );
        
        // Check if form opened
        if (status == 'open' && isOpen == true && !_alarmTriggered) {
          _alarmTriggered = true;
          // Trigger alarm via notification service
          await NotificationService.showAlarmNotification(
            title: '📋 Form is OPEN!',
            body: 'The attendance form is now accepting responses!',
          );
          await NotificationService.playAlarm();
        }
        
        // Reset trigger when form closes
        if (status == 'closed' || status == 'outside_slot') {
          _alarmTriggered = false;
        }
      }
    } catch (e) {
      print('[ForegroundTask] Error: $e');
      FlutterForegroundTask.updateService(
        notificationTitle: 'APTI Attendance',
        notificationText: 'Connection error - retrying...',
      );
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('[ForegroundTask] Destroyed');
  }

  @override
  void onReceiveData(Object data) {
    // Handle data from main isolate if needed
    if (data is Map) {
      if (data['action'] == 'stopAlarm') {
        NotificationService.stopAlarm();
        FlutterForegroundTask.updateService(
          notificationTitle: 'APTI Attendance',
          notificationText: 'Alarm acknowledged - waiting for form to close',
        );
      }
    }
  }

  @override
  void onNotificationPressed() {
    // User tapped the notification - stop alarm
    NotificationService.stopAlarm();
  }
}

/// Service to manage foreground task
class ForegroundTaskService {
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'apti_monitoring',
        channelName: 'Attendance Monitoring',
        channelDescription: 'Monitors attendance form status',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000), // Every 10 seconds
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> startMonitoring() async {
    // Check if already running
    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    // Request permissions
    final notificationPermission = 
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Request battery optimization exemption
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    // Start foreground service
    await FlutterForegroundTask.startService(
      notificationTitle: 'APTI Attendance',
      notificationText: 'Monitoring attendance form...',
      callback: startCallback,
    );
    
    // Check if started successfully
    return await FlutterForegroundTask.isRunningService;
  }

  static Future<bool> stopMonitoring() async {
    await FlutterForegroundTask.stopService();
    // Return true if stopped (no longer running)
    return !(await FlutterForegroundTask.isRunningService);
  }

  static Future<bool> isRunning() async {
    return FlutterForegroundTask.isRunningService;
  }

  static void sendStopAlarm() {
    FlutterForegroundTask.sendDataToTask({'action': 'stopAlarm'});
  }
}
