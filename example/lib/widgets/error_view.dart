import 'package:flutter/cupertino.dart';

/// Shown by a screen's [QueryBuilder] when `state.error` is set (sticky until
/// `refetch()`); a hint plus a retry button that calls it.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle, size: 40),
          const SizedBox(height: 8),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            'Is the mock API running? `cd mock-api && npm start`',
            style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
