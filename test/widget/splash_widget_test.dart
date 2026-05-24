import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meditwin_ai/screens/splash_screen.dart';
import 'package:meditwin_ai/providers/app_state.dart';
import 'package:meditwin_ai/constants/app_constants.dart';

class FakeAppState extends ChangeNotifier implements AppState {
  @override
  bool initialized = true;

  @override
  bool darkMode = false;

  @override
  bool loggedIn = false;

  @override
  bool isAdmin = false;

  @override
  bool onboardingCompleted = false;

  // Below are unused members required by the interface; provide minimal implementations.
  @override
  // ignore: override_on_non_overriding_member
  String? get currentUserEmail => null;

  @override
  // ignore: override_on_non_overriding_member
  bool get isMainAdmin => false;

  @override
  // Methods not used by the splash test
  Future<void> init() async {}

  // The rest of AppState members are not referenced in this test; provide no-op implementations as needed by the type system.
  @override
  // ignore: missing_return
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('SplashScreen shows app name and tagline', (WidgetTester tester) async {
    final fake = FakeAppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: fake,
        child: const MaterialApp(home: SplashScreen()),
      ),
    );

    // Allow frames to render
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text(AppConstants.tagline), findsOneWidget);
  });
}
