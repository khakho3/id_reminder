import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:id_reminder/screens/welcome_screen.dart';

void main() {
  testWidgets('Welcome screen starts ID registration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    expect(find.text('ID Reminder'), findsOneWidget);
    expect(find.text('REGISTER MY ID'), findsOneWidget);
    expect(find.textContaining('Your ID details stay'), findsOneWidget);
  });
}
