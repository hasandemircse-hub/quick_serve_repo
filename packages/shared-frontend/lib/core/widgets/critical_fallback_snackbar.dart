import 'package:flutter/material.dart';

import '../network/api_client.dart';

void showCriticalFallbackSnackBar(
  BuildContext context, {
  required String actionLabel,
  required Object error,
  VoidCallback? onRetry,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final message = apiErrorMessage(error);
  messenger.showSnackBar(
    SnackBar(
      content: Text('$actionLabel başarısız: $message'),
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 4),
      action: onRetry == null
          ? null
          : SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: onRetry,
            ),
    ),
  );
}
