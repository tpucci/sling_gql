import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import 'demo_harness.dart';

/// Guide: Batching & waterfalls. A header, a list and its rows — separate
/// widgets, each reading its own fields — cost one request. Switch the header
/// to "read inside a condition" and it costs two.
class BatchingDemo extends StatefulWidget {
  const BatchingDemo({super.key});

  @override
  State<BatchingDemo> createState() => _BatchingDemoState();
}

enum _Reads { top, conditional }

class _BatchingDemoState extends State<BatchingDemo> {
  var _reads = _Reads.top;

  @override
  Widget build(BuildContext context) {
    return DemoHarness(
      resetKey: _reads,
      controls: DemoModes(
        values: _Reads.values,
        value: _reads,
        label: (r) => switch (r) {
          _Reads.top => 'Read at the top',
          _Reads.conditional => 'Read inside a condition',
        },
        onChanged: (r) => setState(() => _reads = r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          switch (_reads) {
            _Reads.top => const HeaderReadAtTheTop(),
            _Reads.conditional => const HeaderReadInsideACondition(),
          },
          const SizedBox(height: 16),
          const Expanded(child: LaunchList()),
        ],
      ),
    );
  }
}

// #region top
class HeaderReadAtTheTop extends StatelessWidget {
  const HeaderReadAtTheTop({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      builder: (context, query, state) {
        // Read every field first...
        final total = query.stats?.totalLaunches;
        final rate = query.stats?.successRatePct;
        final ceo = query.company?.ceo;
        // ...then branch on the locals.
        return Text(
          total == null ? 'Loading…' : '$total launches · $rate % · CEO $ceo',
        );
      },
    );
  }
}
// #endregion

// #region conditional
class HeaderReadInsideACondition extends StatelessWidget {
  const HeaderReadInsideACondition({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      builder: (context, query, state) {
        final stats = query.stats;
        // successRatePct and ceo are only read once totalLaunches arrived:
        // they are only fetched then, in a second request.
        return Text(
          stats?.totalLaunches == null
              ? 'Loading…'
              : '${stats!.totalLaunches} launches · ${stats.successRatePct} % '
                    '· CEO ${query.company?.ceo}',
        );
      },
    );
  }
}
// #endregion

// #region list
class LaunchList extends StatelessWidget {
  const LaunchList({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      builder: (context, query, state) {
        final launches = query.launches(first: 6)?.nodes ?? const [];
        return ListView(
          children: [for (final launch in launches) LaunchTile(launch)],
        );
      },
    );
  }
}

/// Its own widget, reading its own fields: they join the list's request.
class LaunchTile extends StatelessWidget {
  const LaunchTile(this.launch, {super.key});
  final Launch launch;

  @override
  Widget build(BuildContext context) {
    final name = launch.name;
    final rocket = launch.rocket?.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text('${name ?? '…'} · ${rocket ?? '…'}'),
    );
  }
}
// #endregion
