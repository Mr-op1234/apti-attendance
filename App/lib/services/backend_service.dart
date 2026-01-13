import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendService {
  // Production URL - Hugging Face Spaces
  static const String _baseUrl = 'https://itsmrop-apti-attendance.hf.space';
  static const Duration _pollInterval = Duration(seconds: 10);
  
  static Timer? _pollTimer;
  static bool _isPolling = false;
  static String? _currentSlotId;

  /// Start polling the backend for form status
  /// 
  /// [slotId] - The time slot to monitor (e.g., 'tue_930', 'fri_1110')
  static void startPolling({
    required String slotId,
    required Function() onFormOpen,
    required Function(String status) onStatusChange,
  }) {
    if (_isPolling) return;
    
    _isPolling = true;
    _currentSlotId = slotId;
    onStatusChange('Connecting...');
    
    // Initial check
    _checkFormStatus(slotId, onFormOpen, onStatusChange);
    
    // Start periodic polling
    _pollTimer = Timer.periodic(_pollInterval, (timer) {
      _checkFormStatus(slotId, onFormOpen, onStatusChange);
    });
  }

  /// Stop polling
  static void stopPolling() {
    _isPolling = false;
    _currentSlotId = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Check form status from backend for a specific slot
  static Future<void> _checkFormStatus(
    String slotId,
    Function() onFormOpen,
    Function(String status) onStatusChange,
  ) async {
    try {
      // Call the API with slot parameter
      final response = await http.get(
        Uri.parse('$_baseUrl/api/status?slot=$slotId'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Check the status from backend
        final String status = data['status'] ?? 'unknown';
        final bool? isOpen = data['is_open'];
        
        if (status == 'outside_slot') {
          // Slot is not active right now
          onStatusChange('Outside slot window');
        } else if (status == 'open' && isOpen == true) {
          // Form is open!
          onStatusChange('Form is OPEN!');
          onFormOpen();
        } else if (status == 'closed') {
          // Form is closed, slot is active
          onStatusChange('Monitoring - Form closed');
        } else if (status == 'error') {
          onStatusChange('Error checking form');
        } else {
          onStatusChange('Monitoring...');
        }
      } else {
        onStatusChange('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // For demo purposes, simulate a response
      // Remove this in production
      _simulateBackendResponse(slotId, onFormOpen, onStatusChange);
    }
  }

  /// Simulate backend response for testing when server is not available
  /// TODO: Remove this method in production
  static void _simulateBackendResponse(
    String slotId,
    Function() onFormOpen,
    Function(String status) onStatusChange,
  ) {
    // Check if we're in the right time window (simplified demo logic)
    final now = DateTime.now();
    final currentDay = now.weekday; // Monday=1, Sunday=7
    
    // Simulate slot checking
    bool isSlotActive = false;
    
    switch (slotId) {
      case 'tue_930':
      case 'tue_140':
      case 'tue_1110':
        isSlotActive = currentDay == 2; // Tuesday
        break;
      case 'fri_1110':
        isSlotActive = currentDay == 5; // Friday
        break;
    }
    
    if (isSlotActive) {
      onStatusChange('Monitoring (Demo)');
    } else {
      onStatusChange('Outside slot (Demo)');
    }
  }

  /// Get the current slot being monitored
  static String? getCurrentSlotId() => _currentSlotId;
  
  /// Check if currently polling
  static bool isCurrentlyPolling() => _isPolling;

  /// Manual trigger for testing purposes
  /// Call this method to simulate the form being opened
  static Function()? _demoCallback;
  
  static void setDemoCallback(Function() callback) {
    _demoCallback = callback;
  }
  
  static void triggerDemoAlarm() {
    _demoCallback?.call();
  }
}
