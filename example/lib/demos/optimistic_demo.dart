import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../theme.dart';
import 'demo_harness.dart';

/// Guide: Mutations. The heart flips before the server answers; when the
/// server fails, it flips back on its own. A second widget reading the same
/// entity follows both.
class OptimisticDemo extends StatefulWidget {
  const OptimisticDemo({super.key});

  @override
  State<OptimisticDemo> createState() => _OptimisticDemoState();
}

enum _Server { succeeds, fails }

class _OptimisticDemoState extends State<OptimisticDemo> {
  var _server = _Server.succeeds;

  @override
  Widget build(BuildContext context) {
    return DemoHarness(
      latency: const Duration(milliseconds: 1500),
      failMutations: _server == _Server.fails,
      controls: DemoModes(
        values: _Server.values,
        value: _server,
        label: (s) => switch (s) {
          _Server.succeeds => 'Server succeeds',
          _Server.fails => 'Server fails',
        },
        onChanged: (s) => setState(() => _server = s),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [FavoriteCard(), SizedBox(height: 24), ElsewhereInTheApp()],
      ),
    );
  }
}

const _launchId = 'launch-181';

class FavoriteCard extends StatelessWidget {
  const FavoriteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      builder: (context, query, state) {
        final launch = query.launch(id: _launchId);
        final name = launch?.name;
        final favorite = launch?.favorite;
        if (launch == null || state.isSkeleton) return const Text('Loading…');
        return Row(
          children: [
            Expanded(child: Text(name ?? '')),
            FavoriteButton(launch: launch, favorite: favorite),
          ],
        );
      },
    );
  }
}

// #region heart
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.launch, this.favorite});
  final Launch launch;
  final bool? favorite;

  @override
  Widget build(BuildContext context) {
    final id = launch.id;
    return MutationBuilder<Mutation>(
      builder: (context, mutate, state) => Row(
        children: [
          Text(switch (state) {
            MutationState(isLoading: true) => 'sending…',
            MutationState(error: != null) => 'failed: rolled back',
            MutationState(data: != null) => 'confirmed',
            _ => '',
          }),
          CupertinoButton(
            onPressed: id == null || favorite == null || state.isLoading
                ? null
                : () => mutate(
                    (m) => m.toggleFavorite(launchId: id)?.favorite,
                    // Written to the cache now, undone if the server fails.
                    optimistic: () => launch.favorite = !favorite!,
                  ),
            child: Icon(
              favorite == true
                  ? CupertinoIcons.heart_fill
                  : CupertinoIcons.heart,
              color: kColorCoral,
            ),
          ),
        ],
      ),
    );
  }
}
// #endregion

/// Another widget reading `Launch:launch-181.favorite`: nobody tells it about
/// the mutation, it just reads the same entity.
class ElsewhereInTheApp extends StatelessWidget {
  const ElsewhereInTheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      builder: (context, query, state) {
        final favorite = query.launch(id: _launchId)?.favorite;
        return Text(
          'Elsewhere in the app: ${switch (favorite) {
            true => 'in your favourites',
            false => 'not a favourite',
            null => '…',
          }}',
          style: const TextStyle(color: kColorTextSecondary),
        );
      },
    );
  }
}
