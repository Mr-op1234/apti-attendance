// Basic Flutter widget test for APTI Attendance App

import 'package:flutter_test/flutter_test.dart';

import 'package:apti_attendance_app/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame (setup not complete = show setup screen)
    await tester.pumpWidget(const AptiAttendanceApp(setupComplete: false));

    // Verify that the setup screen welcome text is displayed
    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('APTI Attendance'), findsOneWidget);
  });
}
