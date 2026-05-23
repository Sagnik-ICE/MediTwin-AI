import 'package:flutter/foundation.dart';

/// Lightweight logging utility for MediTwin.
///
/// Goals:
/// - Keep useful development logs.
/// - Avoid noisy stack traces during normal app testing.
/// - Avoid printing sensitive values such as emails, local URLs, long IDs, and tokens.
/// - Disable logs in release builds unless this is intentionally extended later.
class DebugLogger {
  static const String _prefix = '[MediTwin]';

  /// Set to true temporarily while debugging a hard crash.
  /// Keep false for normal development because Flutter/Firestore stack traces are noisy.
  static const bool _showStackTraces = false;

  /// Log an informational message.
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('INFO', message, error, stackTrace);
  }

  /// Log a warning message.
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('WARN', message, error, stackTrace);
  }

  /// Log an error message.
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('ERROR', message, error, stackTrace);
  }

  /// Log a debug message.
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('DEBUG', message, error, stackTrace);
  }

  static void _log(
    String level,
    String message,
    dynamic error,
    StackTrace? stackTrace,
  ) {
    if (!kDebugMode) return;

    final timestamp = DateTime.now().toIso8601String();
    final safeMessage = _redact(message);
    final buffer = StringBuffer('$_prefix [$level] $timestamp: $safeMessage');

    if (error != null) {
      buffer.write('\nError: ${_redact(error.toString())}');
    }

    if (_showStackTraces && stackTrace != null) {
      buffer.write('\nStackTrace: ${_redact(stackTrace.toString())}');
    }

    // ignore: avoid_print
    print(buffer.toString());
  }

  static String _redact(String input) {
    var output = input;

    // Email addresses.
    output = output.replaceAll(
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
      '[email]',
    );

    // Localhost or LAN AI URLs, Firebase console links, and other URLs.
    output = output.replaceAll(
      RegExp(r'https?:\/\/[^\s)]+', caseSensitive: false),
      '[url]',
    );

    // Firebase-style long IDs or tokens. Keep short words untouched.
    output = output.replaceAll(
      RegExp(r'\b[A-Za-z0-9_-]{24,}\b'),
      '[id]',
    );

    // Common key/value secrets.
    output = output.replaceAll(
      RegExp(r'(api[_-]?key|token|password|secret)\s*[:=]\s*[^\s,;]+', caseSensitive: false),
      r'$1=[redacted]',
    );

    return output;
  }
}
