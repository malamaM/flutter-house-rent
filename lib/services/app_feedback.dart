import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

class AppFeedback {
  AppFeedback._();

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static String messageFor(Object error,
      {String fallback = 'Something went wrong. Please try again.'}) {
    if (error is TimeoutException) {
      return 'This is taking longer than expected. Check your connection and try again.';
    }
    if (error is SocketException) {
      return 'You appear to be offline. Check your connection and try again.';
    }
    if (error is FormatException) {
      return 'Haven Zambia received an unexpected response. Please try again.';
    }
    final raw =
        error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (raw.isEmpty || raw.contains('SocketException')) return fallback;
    return raw;
  }

  static void success(String message) => _show(message, isError: false);

  static void error(Object error,
          {String fallback = 'Something went wrong. Please try again.',
          VoidCallback? retry}) =>
      _show(messageFor(error, fallback: fallback), isError: true, retry: retry);

  static void _show(String message,
      {required bool isError, VoidCallback? retry}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_rounded,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ]),
        action: retry == null
            ? null
            : SnackBarAction(label: 'Retry', onPressed: retry),
      ));
  }
}

class AppErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  const AppErrorView({
    super.key,
    this.title = 'We hit a snag',
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off_rounded,
                    size: 46, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again')),
                ],
              ]),
            ),
          ),
        ),
      );
}
