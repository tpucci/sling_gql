import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../network_log.dart';
import '../theme.dart';
import '../widgets/launch_row.dart';
import '../widgets/skeleton.dart';

/// Cursor-paginated launch list.
///
/// What to look at (open the network log, top right):
/// - the header and the list are two independent [QueryBuilder]s, yet the
///   first frame produces ONE request;
/// - each page is `launches(first: 20, after: <cursor>)` — a distinct
///   argument set, hence a distinct alias and cache entry. "Load more" adds a
///   cursor and only the new page is fetched; pull-to-refresh refetches all
///   pages in one request.
/// - the status segments pass `filter: LaunchFilter(status: ...)` — a
///   different argument set → different alias → different cache entry. Coming
///   back to a segment you already visited is instant: its pages are cached.
///   The rows themselves are the same `Launch:<id>` entities in every segment.
class LaunchesScreen extends StatefulWidget {
  const LaunchesScreen({super.key});

  @override
  State<LaunchesScreen> createState() => _LaunchesScreenState();
}

/// Segment key for "All": `CupertinoSlidingSegmentedControl` needs non-null
/// keys, and `LaunchStatus.unknown` is never a filter value.
const _allSentinel = LaunchStatus.unknown;

class _LaunchesScreenState extends State<LaunchesScreen> {
  static const pageSize = 20;

  /// Segment values: `null` = All, otherwise a [LaunchStatus].
  static const _segments = <LaunchStatus?, String>{
    null: 'All',
    LaunchStatus.scheduled: 'Scheduled',
    LaunchStatus.success: 'Success',
    LaunchStatus.failure: 'Failure',
  };

  /// Selected status, `null` for all launches.
  LaunchStatus? _status;

  /// One entry per loaded page; `null` is the first page.
  List<String?> _cursors = [null];

  void _onSegmentChanged(LaunchStatus? status) {
    if (status == _status) return;
    setState(() {
      _status = status;
      _cursors = [null]; // reset pagination when the filter changes
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final filter = status == null ? null : LaunchFilter(status: status);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Launches'),
        trailing: NetworkLogButton(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CupertinoSlidingSegmentedControl<LaunchStatus>(
                groupValue: _status ?? _allSentinel,
                onValueChanged: (v) => _onSegmentChanged(v == _allSentinel ? null : v),
                children: {
                  for (final e in _segments.entries)
                    e.key ?? _allSentinel: Text(e.value, style: const TextStyle(fontSize: 13)),
                },
              ),
            ),
            Expanded(
              child: QueryBuilder<Query>(
                builder: (context, query, state) {
                  if (state.error != null) {
                    return _ErrorView(
                      error: state.error!,
                      onRetry: state.refetch,
                    );
                  }

                  final pages = [
                    for (final cursor in _cursors)
                      query.launches(
                        first: pageSize,
                        after: cursor,
                        filter: filter,
                      ),
                  ];
                  final launches = [
                    for (final page in pages) ...?page?.nodes,
                  ];
                  final last = pages.last;
                  final hasMore = last?.pageInfo?.hasNextPage ?? false;
                  // Read unconditionally: a field only read inside an `if`
                  // that depends on fetched data would cost a second round
                  // trip (the "waterfall" GQty warns about).
                  final total = last?.totalCount;
                  final endCursor = last?.pageInfo?.endCursor;

                  return CustomScrollView(
                    key: const ValueKey('launches-scroll'),
                    slivers: [
                      CupertinoSliverRefreshControl(onRefresh: state.refetch),
                      SliverList.builder(
                        itemCount: launches.length,
                        itemBuilder: (context, i) => LaunchRow(launches[i]),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: hasMore
                              ? CupertinoButton.filled(
                                  onPressed: () => setState(
                                    () => _cursors.add(endCursor),
                                  ),
                                  child: Text(
                                    'Load more (${launches.length} / $total)',
                                  ),
                                )
                              : Center(
                                  child: state.isLoading
                                      ? const CupertinoActivityIndicator()
                                      : Text(
                                          '${launches.length} launches',
                                          style: const TextStyle(
                                            color: kColorTextSecondary,
                                          ),
                                        ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      builder: (context, query, state) {
        final company = query.company;
        final stats = query.stats;
        // Select everything first (see LaunchesScreen for why).
        final total = stats?.totalLaunches;
        final rate = stats?.successRatePct;
        final ceo = company?.ceo;
        return Container(
          padding: const EdgeInsets.all(16),
          color: kColorSurface,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(
                      company?.name,
                      width: 120,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: kColorTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SkeletonText(
                      total == null
                          ? null
                          : '$total launches · $rate % success · CEO $ceo',
                      width: 240,
                      style: const TextStyle(
                        fontSize: 13,
                        color: kColorTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.isLoading) const CupertinoActivityIndicator(),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
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
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 13,
                ),
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
