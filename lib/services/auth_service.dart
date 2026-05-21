import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import '../utils/debug_logger.dart';

/// Firebase authentication service for user login, registration, and session management.
/// Handles Firebase initialization with platform-specific configuration (Web uses DefaultFirebaseOptions).
/// Provides safe fallback behavior when Firebase is unavailable.
class AuthService {
  bool _firebaseInitialized = false;
  String? _firebaseInitError;
  bool _isAdmin = false;


  Future<void> initializeFirebase() async {
    if (_firebaseInitialized) {
      return;
    }

    if (Firebase.apps.isNotEmpty) {
      _firebaseInitialized = true;
      _firebaseInitError = null;
      return;
    }

    try {
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } on UnsupportedError {
        await Firebase.initializeApp();
      }
      _firebaseInitialized = true;
      _firebaseInitError = null;
    } on FirebaseException catch (e) {
      _firebaseInitialized = false;
      _firebaseInitError = e.message ?? e.code;
    } on AssertionError catch (e) {
      _firebaseInitialized = false;
      final raw = e.toString();
      if (kIsWeb && raw.contains('FirebaseOptions cannot be null')) {
        _firebaseInitError =
            'Firebase Web config is missing. Run flutterfire configure and use generated firebase_options.dart, or run on Android/iOS.';
      } else {
        _firebaseInitError = raw;
      }
    } catch (e) {
      _firebaseInitialized = false;
      _firebaseInitError = e.toString();
    }
  }

  bool get canUseFirebase => _firebaseInitialized;

  String? get firebaseInitError => _firebaseInitError;

  String? get currentUserId {
    if (!_firebaseInitialized) {
      return null;
    }
    return FirebaseAuth.instance.currentUser?.uid;
  }

  String? get currentUserEmail {
    if (!_firebaseInitialized) {
      return null;
    }
    return FirebaseAuth.instance.currentUser?.email;
  }

  bool get isLoggedIn => currentUserId != null;

  bool get isAdmin => _isAdmin;

  Future<void> refreshClaims() async {
    if (!_firebaseInitialized) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isAdmin = false;
      return;
    }
    try {
      final result = await user.getIdTokenResult(true);
      _isAdmin = (result.claims?['admin'] as bool?) ?? false;
    } catch (e) {
      DebugLogger.warning('Failed to refresh auth claims', e);
      _isAdmin = false;
    }
  }

  /// Authenticate with email and password.
  /// Returns null on success, or an error message string on failure.
  /// Automatically retries Firebase initialization if needed.
  Future<String?> login({required String email, required String password}) async {
    if (!_firebaseInitialized) {
      await initializeFirebase();
    }

    if (!_firebaseInitialized) {
      final error = 'Firebase is unavailable. ${_firebaseInitError ?? 'Initialization failed.'} Ensure you run on Android/iOS with Firebase config files in place.';
      DebugLogger.warning('Login attempted with unavailable Firebase: $error');
      return error;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      await refreshClaims();
      DebugLogger.info('User logged in: $email');
      return null;
    } on FirebaseAuthException catch (e) {
      final message = _professionalAuthMessage(e.code, fallback: 'Sign in failed. Please verify your credentials and try again.');
      DebugLogger.warning('Login failed for $email: ${e.code}', e);
      return message;
    } catch (e) {
      DebugLogger.error('Unexpected login error for $email', e);
      return 'Login failed';
    }
  }

  /// Create a new user account with email and password.
  /// Returns null on success, or an error message string on failure.
  /// Automatically retries Firebase initialization if needed.
  Future<String?> register({required String email, required String password}) async {
    if (!_firebaseInitialized) {
      await initializeFirebase();
    }

    if (!_firebaseInitialized) {
      final error = 'Firebase is unavailable. ${_firebaseInitError ?? 'Initialization failed.'} Ensure you run on Android/iOS with Firebase config files in place.';
      DebugLogger.warning('Registration attempted with unavailable Firebase: $error');
      return error;
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      await refreshClaims();
      DebugLogger.info('User registered: $email');
      return null;
    } on FirebaseAuthException catch (e) {
      final message = _professionalAuthMessage(e.code, fallback: 'Account creation failed. Please check the details and try again.');
      DebugLogger.warning('Registration failed for $email: ${e.code}', e);
      return message;
    } catch (e) {
      DebugLogger.error('Unexpected registration error for $email', e);
      return 'Registration failed';
    }
  }

  /// Create a Firebase Auth user on a secondary app so the current admin session stays intact.
  /// Returns the created user's uid on success, or an error message on failure.
  Future<String?> provisionUserAccount({required String email, required String password}) async {
    if (!_firebaseInitialized) {
      await initializeFirebase();
    }

    if (!_firebaseInitialized) {
      final error = 'Firebase is unavailable. ${_firebaseInitError ?? 'Initialization failed.'} Ensure you run on Android/iOS with Firebase config files in place.';
      DebugLogger.warning('Secondary account provisioning attempted with unavailable Firebase: $error');
      return error;
    }

    FirebaseApp? secondaryApp;
    try {
      try {
        secondaryApp = Firebase.app('admin-provisioning');
      } on FirebaseException {
        secondaryApp = await Firebase.initializeApp(name: 'admin-provisioning', options: DefaultFirebaseOptions.currentPlatform);
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user?.uid;
      await secondaryAuth.signOut();
      return uid;
    } on FirebaseAuthException catch (e) {
      final message = _professionalAuthMessage(e.code, fallback: 'Account creation failed. Please check the details and try again.');
      DebugLogger.warning('Secondary account provisioning failed for $email: ${e.code}', e);
      return message;
    } catch (e) {
      DebugLogger.error('Unexpected secondary account provisioning error for $email', e);
      return 'Account creation failed';
    } finally {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {
          // Ignore cleanup errors.
        }
      }
    }
  }

  /// Sign out the current user and clear authentication state.
  Future<void> logout() async {
    if (_firebaseInitialized) {
      try {
        await FirebaseAuth.instance.signOut();
        _isAdmin = false;
        DebugLogger.info('User logged out');
      } catch (e) {
        DebugLogger.error('Logout error', e);
      }
    }
  }

  /// Send a password reset email to the given address.
  /// Returns null on success or an error message string on failure.
  Future<String?> sendPasswordReset({required String email}) async {
    if (!_firebaseInitialized) {
      await initializeFirebase();
    }

    if (!_firebaseInitialized) {
      return 'Firebase is unavailable. Cannot send password reset.';
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      DebugLogger.info('Password reset email sent: $email');
      return null;
    } on FirebaseAuthException catch (e) {
      DebugLogger.warning('sendPasswordReset failed for $email: ${e.code}', e);
      return e.message ?? 'Failed to send password reset email';
    } catch (e) {
      DebugLogger.error('Unexpected sendPasswordReset error', e);
      return 'Failed to send password reset email';
    }
  }

  /// Attempts to delete the current authenticated user account.
  /// Returns null on success or an error message string on failure.
  Future<String?> deleteCurrentUser() async {
    if (!_firebaseInitialized) {
      await initializeFirebase();
    }

    if (!_firebaseInitialized) {
      return 'Firebase is unavailable. Cannot delete account.';
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return 'No authenticated user';
    }

    try {
      await user.delete();
      DebugLogger.info('User account deleted');
      return null;
    } on FirebaseAuthException catch (e) {
      DebugLogger.warning('deleteCurrentUser failed: ${e.code}', e);
      return e.message ?? 'Failed to delete account. Reauthentication may be required.';
    } catch (e) {
      DebugLogger.error('Unexpected deleteCurrentUser error', e);
      return 'Failed to delete account';
    }
  }

  /// Reauthenticate the current user with email/password, then delete the account.
  /// This handles Firebase's recent-login requirement for sensitive deletes.
  Future<String?> reauthenticateAndDeleteWithPassword({required String password}) async {
    if (!_firebaseInitialized) {
      await initializeFirebase();
    }

    if (!_firebaseInitialized) {
      return 'Firebase is unavailable. Cannot delete account.';
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      return 'No authenticated account is available for deletion.';
    }

    try {
      final credential = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(credential);
      await user.delete();
      DebugLogger.info('User account deleted after reauthentication');
      return null;
    } on FirebaseAuthException catch (e) {
      DebugLogger.warning('reauthenticateAndDeleteWithPassword failed: ${e.code}', e);
      if (e.code == 'wrong-password') {
        return 'The password did not match. Please try again.';
      }
      if (e.code == 'requires-recent-login') {
        return 'Please sign in again and retry account deletion.';
      }
      return e.message ?? 'Failed to delete account';
    } catch (e) {
      DebugLogger.error('Unexpected reauthenticateAndDeleteWithPassword error', e);
      return 'Failed to delete account';
    }
  }

  Future<String?> reauthenticateAndUpdatePassword({required String currentPassword, required String newPassword}) async {
    if (!_firebaseInitialized) {
      await initializeFirebase();
    }

    if (!_firebaseInitialized) {
      return 'Firebase is unavailable. Cannot update password.';
    }

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      return 'No authenticated account is available.';
    }

    try {
      final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      DebugLogger.info('User password updated');
      return null;
    } on FirebaseAuthException catch (e) {
      DebugLogger.warning('reauthenticateAndUpdatePassword failed: ${e.code}', e);
      if (e.code == 'wrong-password') {
        return 'The current password is incorrect.';
      }
      if (e.code == 'requires-recent-login') {
        return 'Please sign in again and retry the password change.';
      }
      return e.message ?? 'Failed to update password';
    } catch (e) {
      DebugLogger.error('Unexpected reauthenticateAndUpdatePassword error', e);
      return 'Failed to update password';
    }
  }

  Future<String?> signInWithGoogle() async {
    // Google Sign-In has been removed from this build per configuration.
    // If you want to re-enable it later, implement platform-specific
    // sign-in flows and add the `google_sign_in` package back to pubspec.
    return 'Google sign-in is disabled in this build.';
  }

  String _professionalAuthMessage(String code, {required String fallback}) {
    switch (code) {
      case 'wrong-password':
        return 'The password you entered is incorrect.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account matches that email address.';
      case 'user-disabled':
        return 'This account is disabled. Contact support if this is unexpected.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'account-exists-with-different-credential':
        return 'That email is already linked to another sign-in method.';
      case 'invalid-credential':
        return 'Invalid authentication credential. Please try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled for the project.';
      case 'sign_in_failed':
        return 'Sign-in failed. Check your authentication provider setup.';
      default:
        return fallback;
    }
  }
}
