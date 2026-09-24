import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../network_log.dart';
import '../theme.dart';
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
            // Each row is a LaunchRow child widget; its reads are recorded in
            // this scope too, so the whole tab is one request.
            final favorites = me?.favorites ?? const <Launch>[];

            if (state.error != null) {
              return _ErrorView(
                error: state.error!,
                onRetry: state.refetch,
              );
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
                if (favorites.isEmpty && !state.isLoading)
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
                ? const SkeletonBox(width: 28, height: 20)
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
                  style: const TextStyle(
                    fontSize: 13,
                    color: kColorAccent,
                  ),
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
