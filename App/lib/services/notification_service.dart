import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isAlarmPlaying = false;
  
  // Keys for SharedPreferences
  static const String _customAlarmPathKey = 'custom_alarm_path';
  static const String _customAlarmNameKey = 'custom_alarm_name';

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request notification permission for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap - stop alarm
    stopAlarm();
  }

  static Future<void> showAlarmNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Alarm Notifications',
      channelDescription: 'Notifications for form status alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          'stop_alarm',
          'Stop Alarm',
          showsUserInterface: true,
        ),
      ],
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

  /// Play the alarm sound (custom or default)
  static Future<void> playAlarm() async {
    if (_isAlarmPlaying) return;
    
    _isAlarmPlaying = true;
    
    // Set loop mode
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    
    // Check for custom alarm sound
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(_customAlarmPathKey);
    
    try {
      if (customPath != null && customPath.isNotEmpty) {
        // Check if custom file exists
        final file = File(customPath);
        if (await file.exists()) {
          // Play custom alarm
          await _audioPlayer.play(DeviceFileSource(customPath), volume: 1.0);
          return;
        }
      }
      
      // Play default alarm from assets
      await _audioPlayer.play(AssetSource('alarm.mp3'), volume: 1.0);
    } catch (e) {
      // If any error, try playing default
      try {
        await _audioPlayer.play(AssetSource('alarm.mp3'), volume: 1.0);
      } catch (e2) {
        // If default also fails, just vibrate via notification
        _isAlarmPlaying = false;
      }
    }
  }

  /// Stop the alarm
  static Future<void> stopAlarm() async {
    _isAlarmPlaying = false;
    await _audioPlayer.stop();
    await _notifications.cancel(0);
  }

  /// Pick a custom alarm sound from device
  static Future<Map<String, String>?> pickCustomAlarmSound() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        
        // Copy file to app's documents directory for persistence
        final appDir = await getApplicationDocumentsDirectory();
        final newPath = '${appDir.path}/custom_alarm.mp3';
        
        // Copy the file
        final sourceFile = File(filePath);
        await sourceFile.copy(newPath);
        
        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_customAlarmPathKey, newPath);
        await prefs.setString(_customAlarmNameKey, fileName);
        
        return {
          'path': newPath,
          'name': fileName,
        };
      }
    } catch (e) {
      // Handle error silently
    }
    return null;
  }

  /// Get the current custom alarm name (if set)
  static Future<String?> getCustomAlarmName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customAlarmNameKey);
  }

  /// Check if a custom alarm is set
  static Future<bool> hasCustomAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_customAlarmPathKey);
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      return await file.exists();
    }
    return false;
  }

  /// Remove custom alarm and use default
  static Future<void> removeCustomAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_customAlarmPathKey);
    
    // Delete the copied file if it exists
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore deletion errors
      }
    }
    
    await prefs.remove(_customAlarmPathKey);
    await prefs.remove(_customAlarmNameKey);
  }

  /// Preview the current alarm sound
  static Future<void> previewAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(_customAlarmPathKey);
    
    // Stop any existing playback
    await _audioPlayer.stop();
    
    // Don't loop for preview
    await _audioPlayer.setReleaseMode(ReleaseMode.release);
    
    try {
      if (customPath != null && customPath.isNotEmpty) {
        final file = File(customPath);
        if (await file.exists()) {
          await _audioPlayer.play(DeviceFileSource(customPath), volume: 1.0);
          return;
        }
      }
      await _audioPlayer.play(AssetSource('alarm.mp3'), volume: 1.0);
    } catch (e) {
      // Ignore preview errors
    }
  }

  /// Stop preview
  static Future<void> stopPreview() async {
    await _audioPlayer.stop();
  }

  static Future<void> showSimpleNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'status_channel',
      'Status Notifications',
      channelDescription: 'Status update notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      1,
      title,
      body,
      notificationDetails,
    );
  }
}
