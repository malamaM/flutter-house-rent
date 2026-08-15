import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/screens/login/login.dart';
import 'package:house_rent/theme/app_theme.dart';

void main() {
  testWidgets('sign-in screen presents the core account actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const SignInScreen()),
    );

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
