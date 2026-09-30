import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../theme.dart';
import 'demo_harness.dart';

/// Guide: Caching. One launch, stored once: the detail card opened from the
/// list costs no request, and renaming it updates both. With [SlingRow] only
/// the renamed row rebuilds; with plain rows, the whole list does.
class CachingDemo extends StatefulWidget {
  const CachingDemo({super.key});

  @override
  State<CachingDemo> createState() => _CachingDemoState();
}

enum _Rows { slingRow, plain }

class _CachingDemoState extends State<CachingDemo> {
  var _rows = _Rows.slingRow;

  @override
  Widget build(BuildContext context) {
    return DemoHarness(
      resetKey: _rows,
      controls: DemoModes(
        values: _Rows.values,
        value: _rows,
        label: (r) => switch (r) {
          _Rows.slingRow => 'SlingRow',
          _Rows.plain => 'Plain rows',
        },
        onChanged: (r) => setState(() => _rows = r),
      ),
      child: _Screen(slingRows: _rows == _Rows.slingRow),
    );
  }
}

const _firstId = 'launch-181';

class _Screen extends StatefulWidget {
  const _Screen({required this.slingRows});
  final bool slingRows;

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  /// How many times each row was built, shown on the row.
  final _builds = <String, int>{};

  // Built once: the buttons below live in their own widget, so opening the
  // detail does not rebuild the list and skew the counts.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: LaunchList(slingRows: widget.slingRows, builds: _builds),
      ),
      const _Controls(),
    ],
  );
}

class _Controls extends StatefulWidget {
  const _Controls();

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  var _detail = false;
  var _renamed = false;

  void _rename() {
    // A cache write, like an optimistic update: no request.
    final launch = SlingScope.of<Query>(context).cacheScope.launch(_firstId);
    final name = launch?.name;
    if (launch == null || name == null) return;
    launch.name = _renamed ? name.replaceAll(' ✨', '') : '$name ✨';
    _renamed = !_renamed;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => setState(() => _detail = !_detail),
            child: Text(_detail ? 'Close detail' : 'Open the first launch'),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: _rename,
            child: const Text('Rename it'),
          ),
        ],
      ),
      if (_detail) const DetailCard(),
    ],
  );
}

// #region rows
class LaunchList extends StatelessWidget {
  const LaunchList({super.key, required this.slingRows, required this.builds});
  final bool slingRows;
  final Map<String, int> builds;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      builder: (context, query, state) {
        final launches = query.launches(first: 5)?.nodes ?? const <Launch>[];
        return ListView(
          children: [
            for (final launch in launches)
              slingRows
                  // Its own dependencies: a write to this launch rebuilds
                  // this row only.
                  ? SlingRow(
                      launch,
                      ctor: Launch.new,
                      builder: (context, launch) => LaunchTile(launch, builds),
                    )
                  // Reads land on the list's scope: any write to any row
                  // rebuilds the whole list.
                  : LaunchTile(launch, builds),
          ],
        );
      },
    );
  }
}
// #endregion

class LaunchTile extends StatelessWidget {
  const LaunchTile(this.launch, this.builds, {super.key});
  final Launch launch;
  final Map<String, int> builds;

  @override
  Widget build(BuildContext context) {
    final id = launch.id;
    final name = launch.name;
    final count = id == null ? 0 : builds[id] = (builds[id] ?? 0) + 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(name ?? '…')),
          Text(
            'built $count×',
            style: const TextStyle(fontSize: 12, color: kColorTextSecondary),
          ),
        ],
      ),
    );
  }
}

// #region detail
class DetailCard extends StatelessWidget {
  const DetailCard({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      builder: (context, query, state) {
        // `launch(id:)` is a lookup: it finds the Launch:launch-181 the list
        // already stored, so reading its name costs no request.
        final name = query.launch(id: _firstId)?.name;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kColorSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Detail: ${name ?? '…'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}
// #endregion
