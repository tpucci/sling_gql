import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../network_log.dart';
import '../theme.dart';
import '../widgets/error_view.dart';
import '../widgets/launch_row.dart';
import '../widgets/skeleton.dart';

/// Profile / Me tab.
///
/// Reads `query.me` — `Viewer` with avatar initials, name, agency, favourite
/// count, and the favourites list. Uses [LaunchRow] for each favourite so the
/// heart and the entity-level dependency are shared.
///
/// Known limitation: after `toggleFavorite` on the detail screen the
/// `me.favorites` list does not update until pull-to-refresh. This is a
/// documented roadmap item (write policies: add/remove a ref in a list).
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Me'),
        trailing: NetworkLogButton(),
      ),
      child: SafeArea(
        child: QueryBuilder<Query>(
          builder: (context, query, state) {
            final me = query.me;
            // Read all scalar fields unconditionally (no-waterfall rule).
            final initials = me?.avatarInitials;
            final name = me?.name;
            final agency = me?.agency;
            final count = me?.favoriteCount;
            // Each row is a LaunchRow (a SlingRow): its reads join this scope's
            // request, so the whole tab is one request, but a favourite
            // toggled elsewhere rebuilds only that row.
            final favorites = me?.favorites ?? const <Launch>[];

            if (state.error != null) {
              return ErrorView(error: state.error!, onRetry: state.refetch);
            }

            return CustomScrollView(
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: state.refetch),
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    initials: initials,
                    name: name,
                    agency: agency,
                    favoriteCount: count,
                    isLoading: state.isLoading,
                  ),
                ),
                SliverList.builder(
                  itemCount: favorites.length,
                  itemBuilder: (context, i) => LaunchRow(favorites[i]),
                ),
                if (favorites.isEmpty && !state.isSkeleton)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No favourites yet.\nTap the ♡ on a launch to add one.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kColorTextSecondary),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initials,
    required this.name,
    required this.agency,
    required this.favoriteCount,
    required this.isLoading,
  });

  final String? initials;
  final String? name;
  final String? agency;
  final int? favoriteCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: kColorSurface,
      child: Row(
        children: [
          // Circular avatar with gradient background and initials.
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: kAvatarGradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: initials == null
                ? const SkeletonBox(width: 28, height: 12)
                : Text(
                    initials!,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(
                  name,
                  width: 140,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: kColorTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                SkeletonText(
                  agency,
                  width: 100,
                  style: const TextStyle(
                    fontSize: 13,
                    color: kColorTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                SkeletonText(
                  favoriteCount == null
                      ? null
                      : '$favoriteCount favourite${favoriteCount == 1 ? '' : 's'}',
                  width: 80,
                  style: const TextStyle(fontSize: 13, color: kColorAccent),
                ),
              ],
            ),
          ),
          if (isLoading) const CupertinoActivityIndicator(),
        ],
      ),
    );
  }
}
