import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../theme.dart';
import 'demo_harness.dart';

/// Guide: Batching & waterfalls, `prepare`. A launch with its payloads behind
/// "Show payloads". Without `prepare`, showing them costs a second request;
/// with it, they came with the first one.
class PrepareDemo extends StatefulWidget {
  const PrepareDemo({super.key});

  @override
  State<PrepareDemo> createState() => _PrepareDemoState();
}

enum _Mode { without, withPrepare }

class _PrepareDemoState extends State<PrepareDemo> {
  var _mode = _Mode.without;

  @override
  Widget build(BuildContext context) {
    return DemoHarness(
      resetKey: _mode,
      controls: DemoModes(
        values: _Mode.values,
        value: _mode,
        label: (m) => switch (m) {
          _Mode.without => 'Without prepare',
          _Mode.withPrepare => 'With prepare',
        },
        onChanged: (m) => setState(() => _mode = m),
      ),
      child: switch (_mode) {
        _Mode.without => const LaunchWithoutPrepare(),
        _Mode.withPrepare => const LaunchWithPrepare(),
      },
    );
  }
}

const _launchId = 'launch-181';

/// The screen, with a collapsed section. Only the `prepare:` line differs
/// between the two modes.
class _Screen extends StatefulWidget {
  const _Screen({this.prepare});
  final void Function(Query query)? prepare;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      prepare: widget.prepare,
      builder: (context, query, state) {
        final launch = query.launch(id: _launchId);
        final name = launch?.name;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name ?? 'Loading…',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Hide payloads' : 'Show payloads'),
            ),
            // Only read once expanded: without prepare, that read is the
            // first time anything asks for payloads.
            if (_expanded)
              for (final p in launch?.payloads ?? const <Payload>[])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${p.name ?? '…'} · ${p.orbit ?? '…'}',
                    style: const TextStyle(color: kColorTextSecondary),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class LaunchWithoutPrepare extends StatelessWidget {
  const LaunchWithoutPrepare({super.key});

  @override
  Widget build(BuildContext context) => const _Screen();
}

// #region prepare
class LaunchWithPrepare extends StatelessWidget {
  const LaunchWithPrepare({super.key});

  @override
  Widget build(BuildContext context) => _Screen(
    // Read now what the collapsed section will show: it is part of the
    // first request, and expanding costs nothing.
    prepare: (query) {
      final payloads = query.launch(id: _launchId)?.payloads;
      for (final p in payloads ?? const <Payload>[]) {
        p
          ..name
          ..orbit;
      }
    },
  );
}
// #endregion
