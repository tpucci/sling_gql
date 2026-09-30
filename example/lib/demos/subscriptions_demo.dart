import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../theme.dart';
import '../widgets/status_icon.dart';
import 'demo_harness.dart';

/// Guide: Subscriptions. A banner subscribed to `launchStatusChanged`, above
/// a list that knows nothing about it. Change a status on the server: the
/// event updates the banner and the row, with no request.
class SubscriptionsDemo extends StatelessWidget {
  const SubscriptionsDemo({super.key});

  @override
  Widget build(BuildContext context) => const DemoHarness(child: _Screen());
}

const _launchId = 'launch-181';

class _Screen extends StatefulWidget {
  const _Screen();

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  static const _statuses = ['SUCCESS', 'FAILURE', 'SCHEDULED'];
  var _next = 0;

  Future<void> _changeOnServer() async {
    final status = _statuses[_next];
    _next = (_next + 1) % _statuses.length;
    await DemoHarness.of(context).changeOnServer(
      'mutation { updateLaunchStatus(id: "$_launchId", status: $status)'
      ' { id } }',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LiveBanner(),
        const SizedBox(height: 12),
        const Expanded(child: StatusList()),
        CupertinoButton(
          onPressed: _changeOnServer,
          child: const Text('Change a status on the server'),
        ),
      ],
    );
  }
}

// #region banner
class LiveBanner extends StatelessWidget {
  const LiveBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return SubscriptionBuilder<Subscription>(
      // Records the document once; the stream opens after the first frame.
      select: (s) => s.launchStatusChanged
        ?..name
        ..status,
      builder: (context, subscription, state) {
        final launch = subscription?.launchStatusChanged;
        return Text(switch ((state.isConnected, launch)) {
          (false, _) => 'Connecting…',
          (true, null) => 'Live: waiting for a status change…',
          (true, final l?) => 'Live: ${l.name} → ${statusLabel(l.status)}',
        }, style: const TextStyle(color: CupertinoColors.systemGreen));
      },
    );
  }
}
// #endregion

/// A plain query: no subscription in sight. Its rows follow the events
/// because they read the same `Launch:<id>` entities.
class StatusList extends StatelessWidget {
  const StatusList({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      builder: (context, query, state) {
        final launches = query.launches(first: 4)?.nodes ?? const <Launch>[];
        return ListView(
          children: [
            for (final launch in launches)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    StatusIcon(launch.status, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(launch.name ?? '…')),
                    Text(
                      statusLabel(launch.status),
                      style: const TextStyle(
                        fontSize: 13,
                        color: kColorTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
