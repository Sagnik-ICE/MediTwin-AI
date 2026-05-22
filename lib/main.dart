import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_state.dart';
import 'screens/splash_screen.dart';
import 'services/ai_service.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

bool _crashlyticsEnabled = false;

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await _initializeFirebaseAndCrashlytics();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _recordFlutterFatal(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _recordFatalError(error, stack);
      return true;
    };

    runApp(const MediTwinApp());
  }, (error, stack) {
    _recordFatalError(error, stack);
  });
}

Future<void> _initializeFirebaseAndCrashlytics() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      _crashlyticsEnabled = true;
    }
  } catch (_) {
    // Keep the app running even if Firebase/Crashlytics is unavailable in this build.
    _crashlyticsEnabled = false;
  }
}

bool _canUseCrashlytics() {
  return _crashlyticsEnabled;
}

void _recordFlutterFatal(FlutterErrorDetails details) {
  if (!_canUseCrashlytics()) {
    return;
  }
  try {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  } catch (_) {
    // Never let crash reporting crash the app.
  }
}

void _recordFatalError(Object error, StackTrace stack) {
  if (!_canUseCrashlytics()) {
    return;
  }
  try {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  } catch (_) {
    // Never let crash reporting crash the app.
  }
}

class MediTwinApp extends StatelessWidget {
  const MediTwinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(
        storageService: StorageService(),
        aiService: AiService(),
        authService: AuthService(),
        firestoreService: FirestoreService(),
      ),
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'MediTwin AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            themeMode: ThemeMode.light,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
