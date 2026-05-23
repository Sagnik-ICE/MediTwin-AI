import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';

import 'constants/app_constants.dart';
import 'firebase_options.dart';
import 'providers/app_state.dart';
import 'screens/admin_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/doctor_shell.dart';
import 'screens/main_shell.dart';
import 'services/ai_service.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_logo.dart';

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
      child: MaterialApp(
        title: 'MediTwin AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        themeMode: ThemeMode.light,
        home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _minimumSplashDone = false;
  Object? _bootError;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final appState = context.read<AppState>();

    try {
      if (!appState.initialized) {
        await appState.init();
      }
    } catch (e, st) {
      _recordFatalError(e, st);
      _bootError = e;
    }

    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) {
      return;
    }

    setState(() => _minimumSplashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (_bootError != null) {
          return _BootErrorScreen(error: _bootError.toString());
        }

        if (!appState.initialized || !_minimumSplashDone) {
          return const _SplashVisual();
        }

        if (!appState.loggedIn) {
          return const AuthScreen();
        }

        if (appState.isDoctor) {
          return const DoctorShell();
        }

        final isAdminUser = appState.isAdmin || appState.profile.accountType.toLowerCase() == 'admin';
        if (isAdminUser) {
          return const AdminShell();
        }

        return const MainShell();
      },
    );
  }
}

class _SplashVisual extends StatefulWidget {
  const _SplashVisual();

  @override
  State<_SplashVisual> createState() => _SplashVisualState();
}

class _SplashVisualState extends State<_SplashVisual> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: Center(
          child: FadeTransition(
            opacity: _controller,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 96),
                const SizedBox(height: 16),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.onBrand,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.tagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.onBrand.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unable to start MediTwin AI',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(error),
            ],
          ),
        ),
      ),
    );
  }
}
