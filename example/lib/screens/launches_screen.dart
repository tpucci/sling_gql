import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../network_log.dart';
import '../theme.dart';
import 'schedule_launch_screen.dart';
import '../widgets/error_view.dart';
import '../widgets/launch_row.dart';
import '../widgets/skeleton.dart';

/// Cursor-paginated launch list.
///
/// What to look at (open the network log, top right):
/// - the header and the list are two independent [QueryBuilder]s, yet the
///   first frame produces ONE request;
/// - each page is `launches(first: 20, after: <cursor>)`, merged by
///   `RelayStylePagination` (see `type_policies.dart`) into ONE cached list
///   per filter. "Load more" fetches only the next page (the
///   [PaginationController] holds its cursor while it loads);
///   pull-to-refresh refetches the first page, which starts the list over.
///   [PaginatedQueryBuilder] reads the merged list in one build.
/// - the status segments pass `filter: LaunchFilter(status: ...)` — a key
///   argument of the policy → a different merged list. Coming back to a
///   segment you already visited is instant: its list is cached with every
///   page it had. The rows themselves are the same `Launch:<id>` entities in
///   every segment.
/// - [_LiveStatus] keeps a `launchStatusChanged` subscription open (SSE).
///   Each event is normalized into `Launch:<id>` like any response, so the
///   row's status icon updates without the list knowing a subscription
///   exists. The + button opens [ScheduleLaunchScreen]: schedule a launch and
///   the server flies it (`SCHEDULED → IN_FLIGHT → SUCCESS | FAILURE`) while
///   you watch the row.
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
  static const placeholderRows = 8;

  /// Segment values: `null` = All, otherwise a [LaunchStatus].
  static const _segments = <LaunchStatus?, String>{
    null: 'All',
    LaunchStatus.scheduled: 'Scheduled',
    LaunchStatus.success: 'Success',
    LaunchStatus.failure: 'Failure',
    LaunchStatus.scrubbed: 'Scrubbed',
  };

  /// Selected status, `null` for all launches.
  LaunchStatus? _status;

  /// The page being loaded; lives here so a segment change can reset it.
  final _pagination = PaginationController();

  void _onSegmentChanged(LaunchStatus? status) {
    if (status == _status) return;
    setState(() => _status = status);
    _pagination.reset(); // forget a page loading for the previous filter
  }

  @override
  void dispose() {
    _pagination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final filter = status == null ? null : LaunchFilter(status: status);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          key: const ValueKey('schedule-launch'),
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => const ScheduleLaunchScreen(),
            ),
          ),
          child: const Icon(CupertinoIcons.add),
        ),
        middle: const Text('Launches'),
        trailing: const NetworkLogButton(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const _Header(),
            const _LiveStatus(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CupertinoSlidingSegmentedControl<LaunchStatus>(
                groupValue: _status ?? _allSentinel,
                onValueChanged: (v) =>
                    _onSegmentChanged(v == _allSentinel ? null : v),
                children: {
                  for (final e in _segments.entries)
                    e.key ?? _allSentinel: Text(
                      e.value,
                      style: const TextStyle(fontSize: 13),
                    ),
                },
              ),
            ),
            Expanded(
              child: PaginatedQueryBuilder<Query, Launch>(
                controller: _pagination,
                // Runs for the merged list (and the page being loaded),
                // every build. Read every field
                // here, unconditionally: a field only read inside an `if`
                // that depends on fetched data would cost a second round
                // trip (the "waterfall" GQty warns about).
                page: (query, after) {
                  final page = query.launches(
                    first: pageSize,
                    after: after,
                    filter: filter,
                  );
                  return ConnectionPage(
                    nodes: page?.nodes,
                    hasNextPage: page?.pageInfo?.hasNextPage,
                    endCursor: page?.pageInfo?.endCursor,
                    totalCount: page?.totalCount,
                  );
                },
                builder: (context, state) {
                  if (state.error != null) {
                    return ErrorView(
                      error: state.error!,
                      onRetry: state.refetch,
                    );
                  }

                  final launches = state.items;
                  final loading =
                      state.hasMissingData &&
                      launches.length == 1 &&
                      launches.first.isSkeleton;

                  return CustomScrollView(
                    key: const ValueKey('launches-scroll'),
                    slivers: [
                      CupertinoSliverRefreshControl(onRefresh: state.refetch),
                      // While the first page loads, the list holds one
                      // skeleton launch; show it as a screenful of rows.
                      SliverList.builder(
                        itemCount: loading ? placeholderRows : launches.length,
                        itemBuilder: (context, i) => loading
                            ? LaunchRow(launches.first, placeholderIndex: i)
                            : LaunchRow(launches[i]),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: state.hasMore
                              ? CupertinoButton.filled(
                                  onPressed: state.loadMore,
                                  child: Text(
                                    'Load more (${launches.length} / ${state.totalCount})',
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

/// `useSubscription` in widget form, twice — a subscription selects one root
/// field. `select` records the document once; the stream opens on mount and
/// closes on unmount; every event is normalized into `Launch:<id>` before
/// anything here runs, which is why the rows update without being told.
///
/// - `launchStatusChanged`: the banner narrates it; the row icons follow the
///   entity (schedule a launch with the + button and watch the sequence),
///   and the segments follow too: `listRules` (see `list_rules.dart`) move
///   the launch between the cached `launches(filter:)` lists as its status
///   changes.
/// - `launchScheduled`: a new entity is not *in* any cached list yet; the
///   same rule puts it at the top of "All" and "Scheduled". Nothing here
///   edits the cache — `onEvent` only updates the banner.
class _LiveStatus extends StatefulWidget {
  const _LiveStatus();

  @override
  State<_LiveStatus> createState() => _LiveStatusState();
}

class _LiveStatusState extends State<_LiveStatus> {
  String? _message;

  @override
  Widget build(BuildContext context) {
    return SubscriptionBuilder<Subscription>(
      select: (s) => s.launchScheduled
        ?..name
        ..status
        ..date
        ..favorite
        ..rocket?.name,
      onEvent: (s) => setState(
        () => _message =
            '${s.launchScheduled?.name} scheduled — T-minus a few seconds',
      ),
      builder: (context, _, scheduled) => SubscriptionBuilder<Subscription>(
        select: (s) => s.launchStatusChanged
          ?..name
          ..status
          ..upcoming,
        onEvent: (s) {
          final launch = s.launchStatusChanged;
          setState(
            () => _message = '${launch?.name} → ${launch?.status?.graphqlName}',
          );
        },
        builder: (context, _, state) {
          // Green: both connected. Coral: a connection dropped — the client
          // reopens it (`subscriptionRetryAfter`); tapping retries now.
          final connected = state.isConnected && scheduled.isConnected;
          final reconnecting = state.isReconnecting || scheduled.isReconnecting;
          final text = reconnecting
              ? 'Live: connection lost — reconnecting… (tap to retry now)'
              : 'Live: ${_message ?? 'waiting for a status change…'}';
          return GestureDetector(
            key: const ValueKey('live-status'),
            behavior: HitTestBehavior.opaque,
            onTap: reconnecting
                ? () {
                    state.reconnect();
                    scheduled.reconnect();
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: kColorSurface,
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.circle_fill,
                    size: 8,
                    color: reconnecting
                        ? kColorCoral
                        : connected
                        ? CupertinoColors.activeGreen
                        : kColorTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 12,
                        color: kColorTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
