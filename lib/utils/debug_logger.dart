/// Debug logging utility for development and troubleshooting.
/// Logs are printed to console in debug mode and can be extended for file logging in production.
class DebugLogger {
  static const String _prefix = '[MediTwin]';

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

  /// Log a debug message (verbose).
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('DEBUG', message, error, stackTrace);
  }

  static void _log(String level, String message, dynamic error, StackTrace? stackTrace) {
    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer('$_prefix [$level] $timestamp: $message');

    if (error != null) {
      buffer.write('\nError: $error');
    }

    if (stackTrace != null) {
      buffer.write('\nStackTrace: $stackTrace');
    }

    // In production, this could be sent to a crash reporting service
    // ignore: avoid_print
    print(buffer.toString());
  }
}
