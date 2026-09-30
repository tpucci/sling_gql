import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../date_format.dart';
import '../generated/schema.dart';
import '../network_log.dart';
import '../number_format.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_icon.dart';

/// Launch detail.
///
/// - `prepare` is the screen's selection as a reusable function: the
///   [QueryBuilder] runs it, and [LaunchScreen.open] prefetches with it.
/// - `name`/`date`/`status`/`rocket.name` are NOT fetched again: the list
///   already wrote `Launch:<id>` and `Rocket:<id>` entities, and `launch(id:)`
///   is a `lookup` field that resolves straight to the entity. Only the fields
///   the list never selected go over the wire (open the network log).
/// - The heart runs `toggleFavorite` through a [MutationBuilder]. The write
///   is optimistic (`launch.favorite = !favorite`), the response is normalized
///   into the same `Launch:<id>` entity, so the star on the list row behind
///   this screen updates too — nobody tells the list; it just reads the entity.
/// - Rows open it with [LaunchScreen.open], which prefetches with
///   `client.resolve` before pushing the route.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key, required this.id});
  final String id;

  /// Pushes the detail screen for [id], starting its request first.
  ///
  /// `client.resolve` is the imperative query: it runs `prepare` on a
  /// throwaway scope and fetches what the cache misses — here on tap, before
  /// the route exists. The screen's own [QueryBuilder] builds a frame later,
  /// finds the same fields in flight and waits for that request instead of
  /// sending one: still one request, sent a frame earlier. Awaiting it
  /// before `push` would open the screen fully populated instead (a route
  /// "loader"), at the price of a tap that does nothing for a round trip.
  // #region open
  static void open(BuildContext context, String id) {
    SlingScope.of<Query>(context)
        .resolve((query) {
          final launch = query.launch(id: id);
          if (launch != null) _LaunchScreenState.prepare(launch);
        })
        // The screen surfaces a failure itself (its scope gets the error).
        .ignore();
    Navigator.of(context)
        .push(CupertinoPageRoute<void>(builder: (_) => LaunchScreen(id: id)));
  }
  // #endregion

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  /// Reusable selection ("fragment").
  static void prepare(Launch launch) {
    launch
      ..name
      ..date
      ..status
      ..details
      ..flightNumber
      ..favorite;
    launch.rocket
      ?..name
      ..description
      ..height?.meters
      ..mass?.kg
      ..successRatePct;
    launch.launchpad
      ?..fullName
      ..locality;
    for (final p in launch.payloads ?? const <Payload>[]) {
      p
        ..name
        ..type$
        ..orbit
        ..massKg
        ..customers;
    }
    for (final a in launch.crew ?? const <Astronaut>[]) {
      a
        ..name
        ..agency;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Launch'),
        trailing: NetworkLogButton(),
      ),
      child: SafeArea(
        child: QueryBuilder<Query>(
          prepare: (query) {
            final launch = query.launch(id: widget.id);
            if (launch != null) prepare(launch);
          },
          builder: (context, query, state) {
            final launch = query.launch(id: widget.id);
            if (launch == null) return const Center(child: Text('Not found'));
            final rocket = launch.rocket;
            final crew = launch.crew ?? const <Astronaut>[];
            final payloads = launch.payloads ?? const <Payload>[];
            final favorite = launch.favorite;
            final status = launch.status;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    // Follows Launch:<id>.status: a subscription event
                    // (schedule a launch, watch it fly) updates it live.
                    if (launch.isSkeleton)
                      const SkeletonBox.circle(size: 32)
                    else
                      StatusIcon(
                        status,
                        key: const ValueKey('detail-status'),
                        size: 32,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SkeletonText(
                        launch.name,
                        width: 220,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _FavoriteButton(launch: launch, favorite: favorite),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    SkeletonText(
                      launch.date?.let(
                        (d) =>
                            'Flight #${launch.flightNumber} · ${formatDate(d)} · ',
                      ),
                      width: 200,
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 13,
                      ),
                    ),
                    if (status != null)
                      Text(
                        status.graphqlName,
                        style: TextStyle(
                          color: statusColor(status),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (launch.isSkeleton || launch.details != null)
                  SkeletonText(
                    launch.details,
                    width: double.infinity,
                    maxLines: null,
                  ),
                const SizedBox(height: 24),
                const _Section('Rocket'),
                _Row('Name', rocket?.name),
                _Description(rocket?.description),
                _Row('Height', rocket?.height?.meters?.let((v) => '$v m')),
                _Row(
                  'Mass',
                  rocket?.mass?.kg?.let((v) => '${formatWhole(v)} kg'),
                ),
                _Row(
                  'Success rate',
                  rocket?.successRatePct?.let((v) => '$v %'),
                ),
                const SizedBox(height: 24),
                const _Section('Launchpad'),
                _Row('Site', launch.launchpad?.fullName),
                _Row('Locality', launch.launchpad?.locality),
                if (crew.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _Section('Crew'),
                  for (final a in crew)
                    _Item(a.name, a.agency, isSkeleton: a.isSkeleton),
                ],
                if (payloads.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _Section('Payloads'),
                  for (final p in payloads)
                    _Item(p.name, _payloadDetails(p), isSkeleton: p.isSkeleton),
                ],
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CupertinoActivityIndicator(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// `useMutation` in widget form. `mutate` records the fields read in its
/// body (`favorite`), sends `mutation { toggleFavorite(launchId:) { id favorite } }`
/// and merges the response into `Launch:<id>` — the list row's star follows.
///
/// The response cannot tell the cache that `me.favorites` gained or lost a
/// row; the `favorites` `ListRule` (see `list_rules.dart`) does that from
/// `launch.favorite` — for the optimistic write, then again for the
/// response — and is rolled back with the flag if the mutation fails. Only
/// `favoriteCount`, which no rule can derive, is adjusted here.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.launch, required this.favorite});
  final Launch launch;
  final bool? favorite;

  @override
  Widget build(BuildContext context) {
    final id = launch.id;
    final client = SlingScope.of<Query>(context);
    return MutationBuilder<Mutation>(
      builder: (context, mutate, state) => CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: id == null || favorite == null || state.isLoading
            ? null
            : () => mutate(
                (m) => m.toggleFavorite(launchId: id)?.favorite,
                optimistic: () {
                  final wasFavorite = favorite!;
                  launch.favorite = !wasFavorite;
                  final cache = client.cacheScope;
                  final me = cache.query.me;
                  // cacheScope reads never fetch. Me tab not loaded yet:
                  // it will fetch the fresh list itself.
                  if (me == null || me.isSkeleton) return;
                  final count = me.favoriteCount;
                  if (count != null) {
                    me.favoriteCount = count + (wasFavorite ? -1 : 1);
                  }
                },
              ),
        child: Icon(
          favorite ?? false ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
          color: state.error != null ? kColorTextSecondary : kColorCoral,
          size: 28,
        ),
      ),
    );
  }
}

String _payloadDetails(Payload p) {
  final mass = p.massKg;
  return [
    p.type$,
    p.orbit,
    if (mass != null) '${formatWhole(mass)} kg',
    p.customers?.join(', '),
  ].whereType<String>().join(' · ');
}

/// A two-line entry (crew member, payload): a name and muted details.
class _Item extends StatelessWidget {
  const _Item(this.title, this.subtitle, {required this.isSkeleton});
  final String? title;
  final String? subtitle;
  final bool isSkeleton;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonText(title, width: 160),
        const SizedBox(height: 2),
        SkeletonText(
          isSkeleton ? null : subtitle,
          width: 220,
          style: const TextStyle(
            color: CupertinoColors.systemGrey,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

/// The rocket's description: three lines, "More" to read the rest.
class _Description extends StatefulWidget {
  const _Description(this.text);
  final String? text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  static const _collapsedLines = 3;
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    if (text == null) return const SkeletonText(null, width: double.infinity);
    final style = DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: _expanded ? null : _collapsedLines,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            if (overflows || _expanded)
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Less' : 'More',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String? label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: SkeletonText(
            label,
            width: 60,
            style: const TextStyle(color: CupertinoColors.systemGrey),
          ),
        ),
        Expanded(child: SkeletonText(value, width: 140)),
      ],
    ),
  );
}

extension<T extends Object> on T {
  R let<R>(R Function(T) f) => f(this);
}
