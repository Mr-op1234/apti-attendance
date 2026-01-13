import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/foreground_task_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await NotificationService.initialize();
  await ForegroundTaskService.init();
  
  // Check if user has completed setup
  final prefs = await SharedPreferences.getInstance();
  final String? savedSlot = prefs.getString('selected_slot');
  final bool setupComplete = savedSlot != null && savedSlot.isNotEmpty;
  
  runApp(AptiAttendanceApp(setupComplete: setupComplete));
}

class AptiAttendanceApp extends StatelessWidget {
  final bool setupComplete;
  
  const AptiAttendanceApp({super.key, required this.setupComplete});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APTI Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        // Minimal dark theme
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        primaryColor: const Color(0xFF6C63FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF03DAC6),
          surface: Color(0xFF1A1A1A),
          error: Color(0xFFCF6679),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1A1A1A),
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D0D),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      // Show setup screen if first time, otherwise go to home
      home: setupComplete ? const HomeScreen() : const SetupScreen(),
    );
  }
}
