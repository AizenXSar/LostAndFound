import 'package:flutter/foundation.dart';

/// App logger utility - only logs in debug mode
class AppLogger {
  /// Log info messages (only in debug mode)
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[App] $message');
    }
  }

  /// Log error messages (always shown)
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[App Error] $message');
      if (error != null) debugPrint('[App Error] $error');
      if (stackTrace != null) debugPrint('[App Error] $stackTrace');
    }
  }

  /// Log warning messages (only in debug mode)
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('[App Warning] $message');
    }
  }

  /// Log debug messages (only in debug mode, for verbose logging)
  static void debug(String message) {
    if (kDebugMode) {
      // Only enable verbose debug logging if needed
      // Uncomment below to enable verbose debug logs
      // debugPrint('[App Debug] $message');
    }
  }
}

