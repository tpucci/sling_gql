import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../network_log.dart';
import '../widgets/skeleton.dart';
import 'launch_screen.dart';

/// Cursor-paginated launch list.
///
/// What to look at (open the network log, top right):
/// - the header and the list are two independent [QueryBuilder]s, yet the
///   first frame produces ONE request;
/// - each page is `launches(first: 20, after: <cursor>)` — a distinct
///   argument set, hence a distinct alias and cache entry. "Load more" adds a
///   cursor and only the new page is fetched; pull-to-refresh refetches all
///   pages in one request.
class LaunchesScreen extends StatefulWidget {
  const LaunchesScreen({super.key});

  @override
  State<LaunchesScreen> createState() => _LaunchesScreenState();
}

class _LaunchesScreenState extends State<LaunchesScreen> {
  static const pageSize = 20;

  /// One entry per loaded page; `null` is the first page.
  final List<String?> _cursors = [null];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Launches'),
        trailing: NetworkLogButton(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: QueryBuilder<Query>(
                builder: (context, query, state) {
                  if (state.error != null) {
                    return _ErrorView(error: state.error!, onRetry: state.refetch);
                  }

                  final pages = [
                    for (final cursor in _cursors)
                      query.launches(first: pageSize, after: cursor),
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
                    slivers: [
                      CupertinoSliverRefreshControl(onRefresh: state.refetch),
                      SliverList.builder(
                        itemCount: launches.length,
                        itemBuilder: (context, i) => _LaunchRow(launches[i]),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: hasMore
                              ? CupertinoButton.filled(
                                  onPressed: () => setState(() => _cursors.add(endCursor)),
                                  child: Text(
                                    'Load more (${launches.length} / $total)',
                                  ),
                                )
                              : Center(
                                  child: state.isLoading
                                      ? const CupertinoActivityIndicator()
                                      : Text('${launches.length} launches'),
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
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(
                      company?.name,
                      width: 120,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    SkeletonText(
                      total == null ? null : '$total launches · $rate % success · CEO $ceo',
                      width: 240,
                      style: const TextStyle(fontSize: 13),
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

class _LaunchRow extends StatelessWidget {
  const _LaunchRow(this.launch);
  final Launch launch;

  @override
  Widget build(BuildContext context) {
    final status = launch.status;
    final date = launch.date;
    final rocketName = launch.rocket?.name;
    // Read here so the row depends on `Launch:<id>.favorite` and rebuilds when
    // the detail screen's mutation updates the entity.
    final favorite = launch.favorite ?? false;
    return CupertinoListTile(
      leading: launch.isSkeleton
          ? const SkeletonBox(width: 28, height: 28)
          : Icon(_statusIcon(status), color: _statusColor(status)),
      title: SkeletonText(launch.name, width: 160),
      subtitle: SkeletonText(
        date == null ? null : '${date.substring(0, 10)} · $rocketName',
        width: 200,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (favorite)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(CupertinoIcons.heart_fill, color: CupertinoColors.systemPink, size: 18),
            ),
          const CupertinoListTileChevron(),
        ],
      ),
      onTap: launch.id == null
          ? null
          : () => Navigator.of(context).push(
                CupertinoPageRoute<void>(builder: (_) => LaunchScreen(id: launch.id!)),
              ),
    );
  }
}

IconData _statusIcon(String? status) => switch (status) {
      LaunchStatus.SUCCESS => CupertinoIcons.checkmark_circle_fill,
      LaunchStatus.FAILURE => CupertinoIcons.xmark_circle_fill,
      LaunchStatus.PARTIAL_FAILURE => CupertinoIcons.exclamationmark_circle_fill,
      LaunchStatus.SCRUBBED => CupertinoIcons.pause_circle_fill,
      LaunchStatus.SCHEDULED => CupertinoIcons.clock_fill,
      _ => CupertinoIcons.question_circle,
    };

Color _statusColor(String? status) => switch (status) {
      LaunchStatus.SUCCESS => CupertinoColors.systemGreen,
      LaunchStatus.FAILURE => CupertinoColors.systemRed,
      LaunchStatus.PARTIAL_FAILURE => CupertinoColors.systemOrange,
      LaunchStatus.SCHEDULED => CupertinoColors.systemBlue,
      _ => CupertinoColors.systemGrey,
    };

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
                style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
