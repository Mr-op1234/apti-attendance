import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/notification_service.dart';
import '../services/backend_service.dart';
import '../services/foreground_task_service.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? selectedSlot;
  String selectedSlotLabel = '';
  String selectedSlotDay = '';
  bool isMonitoring = false;
  bool isAlarmActive = false;
  bool alarmAcknowledged = false; // Prevents re-triggering after user stops alarm
  String connectionStatus = 'Initializing...';
  String? customAlarmName;

  // Time slots configuration
  final Map<String, Map<String, String>> timeSlots = {
    'tue_930': {'label': '9:30 - 11:10 AM', 'day': 'Tuesday'},
    'fri_1110': {'label': '11:10 AM - 12:50 PM', 'day': 'Friday'},
    'tue_140': {'label': '1:40 - 3:20 PM', 'day': 'Tuesday'},
    'tue_1110': {'label': '11:10 - 12:50 PM', 'day': 'Tuesday'},
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettingsAndStart();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume monitoring when app comes back to foreground
    if (state == AppLifecycleState.resumed && selectedSlot != null && !isAlarmActive) {
      _startMonitoring();
    }
  }

  Future<void> _loadSettingsAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    final slot = prefs.getString('selected_slot');
    
    // Load custom alarm name
    final alarmName = await NotificationService.getCustomAlarmName();
    
    if (slot != null && timeSlots.containsKey(slot)) {
      setState(() {
        selectedSlot = slot;
        selectedSlotLabel = timeSlots[slot]!['label']!;
        selectedSlotDay = timeSlots[slot]!['day']!;
        customAlarmName = alarmName;
      });
      
      // Auto-start monitoring
      _startMonitoring();
    }
  }

  Future<void> _startMonitoring() async {
    if (selectedSlot == null) return;
    if (isMonitoring) return; // Already monitoring

    setState(() {
      isMonitoring = true;
      connectionStatus = 'Starting background service...';
    });

    // Start foreground service for reliable background execution
    final started = await ForegroundTaskService.startMonitoring();
    
    if (started) {
      setState(() {
        connectionStatus = 'Monitoring (background active)';
      });
    }

    // Also start in-app polling for UI updates
    BackendService.startPolling(
      slotId: selectedSlot!,
      onFormOpen: _triggerAlarm,
      onStatusChange: (status) {
        if (mounted) {
          setState(() {
            connectionStatus = status;
            
            // Reset acknowledged flag when form closes (allows re-trigger next time)
            if (status.contains('closed') || status.contains('Outside')) {
              alarmAcknowledged = false;
            }
          });
        }
      },
    );
  }

  Future<void> _stopMonitoring() async {
    BackendService.stopPolling();
    await ForegroundTaskService.stopMonitoring();
    setState(() {
      isMonitoring = false;
      connectionStatus = 'Paused';
    });
  }

  void _triggerAlarm() {
    // Don't trigger if already acknowledged
    if (alarmAcknowledged) return;
    
    setState(() {
      isAlarmActive = true;
      connectionStatus = 'Form is OPEN!';
    });
    NotificationService.showAlarmNotification(
      title: '📋 Form is OPEN!',
      body: 'The attendance form is now accepting responses. Tap to open.',
    );
    NotificationService.playAlarm();
  }

  void _stopAlarm() {
    NotificationService.stopAlarm();
    setState(() {
      isAlarmActive = false;
      alarmAcknowledged = true; // Prevent re-triggering until form closes
      connectionStatus = 'Acknowledged - Waiting for form to close';
    });
    // Continue monitoring to detect when form closes (resets for next time)
    // Monitoring continues, but alarm won't trigger due to alarmAcknowledged flag
  }

  Future<void> _changeSlot() async {
    // Stop monitoring first
    _stopMonitoring();
    
    // Clear the saved slot
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_slot');
    
    // Navigate to setup screen (check mounted after async)
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'APTI Attendance',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _changeSlot,
            icon: const Icon(Icons.settings, color: Colors.white54),
            tooltip: 'Change Time Slot',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current slot info card
              _buildSlotInfoCard(),
              
              const SizedBox(height: 20),
              
              // Status card
              _buildStatusCard(),
              
              const SizedBox(height: 20),
              
              // Alarm sound settings
              _buildAlarmSoundCard(),
              
              const Spacer(),
              
              // Alarm action button (only shown when alarm is active)
              if (isAlarmActive) _buildAlarmButton(),
              
              // Monitoring toggle
              if (!isAlarmActive) _buildMonitoringToggle(),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),  // Close WithForegroundTask
    );
  }

  Widget _buildSlotInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withAlpha(40),
            const Color(0xFF6C63FF).withAlpha(20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withAlpha(60),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'YOUR SLOT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            selectedSlotLabel,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                selectedSlotDay,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    
    if (isAlarmActive) {
      statusColor = const Color(0xFFCF6679);
      statusIcon = Icons.alarm_on;
      statusTitle = 'FORM OPEN!';
    } else if (isMonitoring) {
      if (connectionStatus.contains('Outside')) {
        statusColor = Colors.amber;
        statusIcon = Icons.schedule;
        statusTitle = 'WAITING';
      } else {
        statusColor = const Color(0xFF03DAC6);
        statusIcon = Icons.wifi;
        statusTitle = 'MONITORING';
      }
    } else {
      statusColor = Colors.white38;
      statusIcon = Icons.pause_circle;
      statusTitle = 'PAUSED';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withAlpha(80),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 32),
              const SizedBox(width: 12),
              Text(
                statusTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            connectionStatus,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          if (isAlarmActive)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Tap the button below to stop the alarm',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withAlpha(140),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlarmButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        onPressed: _stopAlarm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFCF6679),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.stop, size: 28),
        label: const Text(
          'STOP ALARM',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMonitoringToggle() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Background Monitoring',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withAlpha(200),
            ),
          ),
        ),
        Switch(
          value: isMonitoring,
          onChanged: (value) {
            if (value) {
              _startMonitoring();
            } else {
              _stopMonitoring();
            }
          },
          activeTrackColor: const Color(0xFF6C63FF),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white54;
          }),
        ),
      ],
    );
  }
  Widget _buildAlarmSoundCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note, color: Colors.white54, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Alarm Sound',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  customAlarmName ?? 'Default Alarm',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Preview button
              IconButton(
                onPressed: () async {
                  await NotificationService.previewAlarm();
                  // Stop after 3 seconds
                  Future.delayed(const Duration(seconds: 3), () {
                    NotificationService.stopPreview();
                  });
                },
                icon: const Icon(Icons.play_circle_outline),
                color: const Color(0xFF6C63FF),
                tooltip: 'Preview',
              ),
              // Change button
              TextButton(
                onPressed: _pickAlarmSound,
                child: const Text(
                  'Change',
                  style: TextStyle(color: Color(0xFF6C63FF)),
                ),
              ),
            ],
          ),
          if (customAlarmName != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _removeCustomAlarm,
              child: Text(
                'Reset to default',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(120),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAlarmSound() async {
    final result = await NotificationService.pickCustomAlarmSound();
    if (result != null) {
      setState(() {
        customAlarmName = result['name'];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alarm set to: ${result['name']}'),
            backgroundColor: const Color(0xFF6C63FF),
          ),
        );
      }
    }
  }

  Future<void> _removeCustomAlarm() async {
    await NotificationService.removeCustomAlarm();
    setState(() {
      customAlarmName = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset to default alarm'),
          backgroundColor: Color(0xFF03DAC6),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Don't stop monitoring on dispose - let it run
    super.dispose();
  }
}
