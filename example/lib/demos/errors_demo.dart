import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../date_format.dart';
import '../generated/schema.dart';
import '../widgets/error_view.dart';
import '../widgets/skeleton.dart';
import 'demo_harness.dart';

/// Guide: Loading states & errors. Placeholders while loading, then data or
/// an error. The error is sticky: rebuilding does not send the failing
/// request again, only Retry (`state.refetch`) does.
class ErrorsDemo extends StatefulWidget {
  const ErrorsDemo({super.key});

  @override
  State<ErrorsDemo> createState() => _ErrorsDemoState();
}

enum _Server { ok, fails }

class _ErrorsDemoState extends State<ErrorsDemo> {
  var _server = _Server.ok;
  var _builds = 0;

  @override
  Widget build(BuildContext context) {
    return DemoHarness(
      latency: const Duration(milliseconds: 1200),
      // Flipping it does not restart the demo: the next request sees it.
      failRequests: _server == _Server.fails,
      controls: DemoModes(
        values: _Server.values,
        value: _server,
        label: (s) => switch (s) {
          _Server.ok => 'Server OK',
          _Server.fails => 'Server fails',
        },
        onChanged: (s) => setState(() => _server = s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LaunchCard(builds: _builds),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _builds++),
            child: const Text('Rebuild the widget'),
          ),
        ],
      ),
    );
  }
}

const _launchId = 'launch-181';

// #region card
class LaunchCard extends StatelessWidget {
  const LaunchCard({super.key, required this.builds});

  /// Changes on "Rebuild the widget", so the builder runs again.
  final int builds;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      builder: (context, query, state) {
        final launch = query.launch(id: _launchId);
        final name = launch?.name;
        final date = launch?.date;
        final rocket = launch?.rocket?.name;
        if (state.error != null) {
          // Sticky: rebuilding lands here again without a new request.
          return ErrorView(error: state.error!, onRetry: state.refetch);
        }
        // No loading branch: null fields render as placeholders.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonText(
              name,
              width: 180,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SkeletonText(
              date == null ? null : '${formatDate(date)} · $rocket',
              width: 150,
            ),
          ],
        );
      },
    );
  }
}
// #endregion
