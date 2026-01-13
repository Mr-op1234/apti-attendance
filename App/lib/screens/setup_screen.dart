import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? selectedSlot;

  // Time slots configuration
  final List<Map<String, String>> timeSlots = [
    {'id': 'tue_930', 'label': '9:30 - 11:10 AM', 'day': 'Tuesday'},
    {'id': 'fri_1110', 'label': '11:10 AM - 12:50 PM', 'day': 'Friday'},
    {'id': 'tue_140', 'label': '1:40 - 3:20 PM', 'day': 'Tuesday'},
    {'id': 'tue_1110', 'label': '11:10 - 12:50 PM', 'day': 'Tuesday'},
  ];

  Future<void> _completeSetup() async {
    if (selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot'),
          backgroundColor: Color(0xFFCF6679),
        ),
      );
      return;
    }

    // Save the selected slot
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_slot', selectedSlot!);
    await prefs.setBool('setup_complete', true);

    // Navigate to home screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // Welcome header
              const Text(
                'Welcome to',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'APTI Attendance',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Select your class time slot. You\'ll receive an alarm when the attendance form opens during this slot.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha(180),
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Time slot selection
              const Text(
                'Choose Your Time Slot',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              
              // Time slot cards
              Expanded(
                child: ListView.builder(
                  itemCount: timeSlots.length,
                  itemBuilder: (context, index) {
                    final slot = timeSlots[index];
                    final isSelected = selectedSlot == slot['id'];
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedSlot = slot['id'];
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFF6C63FF).withAlpha(40)
                              : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected 
                                ? const Color(0xFF6C63FF)
                                : Colors.white12,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Radio indicator
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected 
                                      ? const Color(0xFF6C63FF)
                                      : Colors.white38,
                                  width: 2,
                                ),
                                color: isSelected 
                                    ? const Color(0xFF6C63FF)
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            
                            // Slot info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slot['label']!,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: Colors.white.withAlpha(140),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        slot['day']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withAlpha(140),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withAlpha(50),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF6C63FF),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You can change this later in settings',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withAlpha(180),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: selectedSlot != null ? _completeSetup : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF6C63FF).withAlpha(50),
                    disabledForegroundColor: Colors.white38,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
