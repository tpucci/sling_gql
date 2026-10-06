import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../in_browser_api.dart';

// #region error-view
/// Shown by a screen's [QueryBuilder] when `state.error` is set (sticky until
/// `refetch()`); what went wrong plus a retry button that calls it.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final SlingException error;
  final Future<void> Function() onRetry;

  /// The sealed error type says what to tell the user.
  String get _summary => switch (error) {
    SlingNetworkException() => 'No connection to the server.',
    SlingTimeoutException() => 'The server took too long to answer.',
    SlingHttpException(:final statusCode) => 'Server error ($statusCode).',
    SlingAuthException() => 'Please sign in again.',
    SlingGraphQLException(:final errors) =>
      errors.isEmpty ? error.message : errors.first.message,
    SlingCancelledException() || SlingTransportException() => error.message,
  };

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle, size: 40),
          const SizedBox(height: 8),
          Text(_summary, textAlign: TextAlign.center),
          // On iOS the API is `npm start` on the Mac; on the web it runs in
          // the page, so there is nothing to start.
          if (!mockApiInBrowser) ...[
            const SizedBox(height: 8),
            const Text(
              'Is the mock API running? `cd mock-api && npm start`',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13),
            ),
          ],
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
// #endregion
