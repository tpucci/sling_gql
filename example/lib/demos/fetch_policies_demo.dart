import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../theme.dart';
import '../widgets/status_icon.dart';
import 'demo_harness.dart';

/// Guide: Fetch policies & freshness. Open and close the same widget under
/// each policy, change the launch "on the server" in between, and watch
/// what gets rendered and what gets sent.
class FetchPoliciesDemo extends StatefulWidget {
  const FetchPoliciesDemo({super.key});

  @override
  State<FetchPoliciesDemo> createState() => _FetchPoliciesDemoState();
}

enum Policy { cacheFirst, cacheAndNetwork, maxAge }

class _FetchPoliciesDemoState extends State<FetchPoliciesDemo> {
  var _policy = Policy.cacheFirst;

  @override
  Widget build(BuildContext context) {
    return DemoHarness(
      resetKey: _policy,
      controls: DemoModes(
        values: Policy.values,
        value: _policy,
        label: (p) => switch (p) {
          Policy.cacheFirst => 'cacheFirst',
          Policy.cacheAndNetwork => 'cacheAndNetwork',
          Policy.maxAge => 'maxAge: 5 s',
        },
        onChanged: (p) => setState(() => _policy = p),
      ),
      child: _Screen(policy: _policy),
    );
  }
}

class _Screen extends StatefulWidget {
  const _Screen({required this.policy});
  final Policy policy;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  var _open = true;
  var _serverStatus = 'SUCCESS';

  Future<void> _changeOnServer() async {
    _serverStatus = _serverStatus == 'SUCCESS' ? 'FAILURE' : 'SUCCESS';
    await DemoHarness.of(context).changeOnServer(
      'mutation { updateLaunchStatus(id: "$launchId", status: $_serverStatus)'
      ' { id } }',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 34),
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? 'Close' : 'Open'),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 34),
              onPressed: _changeOnServer,
              child: const Text(
                'Change it on the server',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_open)
          LaunchCard(policy: widget.policy)
        else
          const Text(
            'Closed. The cache keeps the data.',
            style: TextStyle(color: kColorTextSecondary),
          ),
      ],
    );
  }
}

const launchId = 'launch-181';

// #region card
class LaunchCard extends StatelessWidget {
  const LaunchCard({super.key, required this.policy});
  final Policy policy;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      fetchPolicy: policy == Policy.cacheAndNetwork
          ? FetchPolicy.cacheAndNetwork
          : FetchPolicy.cacheFirst,
      maxAge: policy == Policy.maxAge ? const Duration(seconds: 5) : null,
      builder: (context, query, state) {
        final launch = query.launch(id: launchId);
        final name = launch?.name;
        final status = launch?.status;
        if (state.isSkeleton) return const Text('Loading…');
        return Row(
          children: [
            StatusIcon(status),
            const SizedBox(width: 8),
            Text('$name · ${status?.graphqlName}'),
            const Spacer(),
            if (state.isStale)
              const Text('stale, refreshing…')
            else if (state.isLoading)
              const Text('refreshing…'),
          ],
        );
      },
    );
  }
}
// #endregion
