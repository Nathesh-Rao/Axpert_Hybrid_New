import 'package:flutter/material.dart';

import '../data/services/log/crash_reporting_service.dart';

/// Available before sign-in so support can correlate an installation remotely.
class SupportIdButton extends StatelessWidget {
  const SupportIdButton({super.key});

  @override
  Widget build(BuildContext context) {
    final id = CrashReportingService.supportId;
    if (id == null) return const SizedBox.shrink();
    return TextButton(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Support ID'),
          content: SelectableText(id),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
      child: const Text('Support ID'),
    );
  }
}
