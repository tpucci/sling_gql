import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../date_format.dart';
import '../generated/schema.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import 'demo_harness.dart';

/// Guide: Pagination. Pages of five launches: "Load more" fetches the next
/// page only; "Refresh" refetches every loaded page in one request.
class PaginationDemo extends StatelessWidget {
  const PaginationDemo({super.key});

  @override
  Widget build(BuildContext context) => const DemoHarness(child: LaunchPages());
}

// #region pages
class LaunchPages extends StatelessWidget {
  const LaunchPages({super.key});

  @override
  Widget build(BuildContext context) {
    return PaginatedQueryBuilder<Query, Launch>(
      // Runs for every loaded page, in the same build: one selection.
      page: (query, after) {
        final page = query.launches(first: 5, after: after);
        return ConnectionPage(
          nodes: page?.nodes,
          hasNextPage: page?.pageInfo?.hasNextPage,
          endCursor: page?.pageInfo?.endCursor,
          totalCount: page?.totalCount,
        );
      },
      builder: (context, state) => Column(
        children: [
          Expanded(
            child: ListView(
              children: [for (final launch in state.items) LaunchLine(launch)],
            ),
          ),
          Row(
            children: [
              CupertinoButton(
                onPressed: state.hasMore ? state.loadMore : null,
                child: Text(
                  'Load more (${state.items.length} / '
                  '${state.totalCount ?? '…'})',
                ),
              ),
              CupertinoButton(
                onPressed: state.refetch,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// #endregion

class LaunchLine extends StatelessWidget {
  const LaunchLine(this.launch, {super.key});
  final Launch launch;

  @override
  Widget build(BuildContext context) {
    final name = launch.name;
    final date = launch.date;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: SkeletonText(name, width: 160)),
          SkeletonText(
            date == null ? null : formatDate(date),
            width: 80,
            style: const TextStyle(color: kColorTextSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
