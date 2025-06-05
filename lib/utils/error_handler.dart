import 'package:flutter/material.dart';
import 'dart:async';
import 'event_bus.dart';

class ErrorHandler {
  static void handleError(
    BuildContext context,
    dynamic error, {
    String? title,
  }) {
    // Log error
    debugPrint('Error occurred: $error');

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );

    // Emit error event for global handling
    EventBus().emit(AppEvents.errorOccurred, {
      'error': error,
      'timestamp': DateTime.now(),
      'title': title,
    });
  }

  static Future<T> wrap<T>(
    BuildContext context,
    Future<T> Function() action, {
    String? errorTitle,
    bool showLoading = true,
    VoidCallback? onError,
  }) async {
    try {
      if (showLoading) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      if (showLoading && context.mounted) {
        Navigator.of(context).pop();
      }

      final result = await action();

      if (showLoading && context.mounted) {
        Navigator.of(context).pop();
      }

      return result;
    } catch (e) {
      if (showLoading && context.mounted) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        onError?.call();
      }

      rethrow;
    }
  }

  // Retry mechanism for database operations
  static Future<T> retryOperation<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts == maxAttempts) rethrow;
        await Future.delayed(delay * attempts);
      }
    }
    throw Exception('Operation failed after $maxAttempts attempts');
  }

  // Handle specific error types
  static String getErrorMessage(dynamic error) {
    if (error is TimeoutException) {
      return 'Operation timed out. Please try again.';
    } else if (error is NetworkException) {
      return 'Network error. Please check your connection.';
    } else if (error is DatabaseException) {
      return 'Database error. Please restart the app.';
    } else {
      return error.toString();
    }
  }
}

// Custom exceptions
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
  @override
  String toString() => message;
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => message;
}
