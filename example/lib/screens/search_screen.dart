import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../date_format.dart';
import '../generated/schema.dart';
import '../network_log.dart';
import '../theme.dart';
import '../widgets/error_view.dart';
import '../widgets/skeleton.dart';
import 'launch_screen.dart';

/// Search tab: `query.search(text:)` returns `[SearchResult!]!`, a union of
/// `Launch | Rocket | Astronaut`.
///
/// Each hit goes through the generated `when(...)`. Every branch reads the
/// fields it shows *inside the branch* (into a [_Hit]) rather than in a
/// child widget: on the skeleton every branch runs once, so the first build
/// records all three inline fragments and one request answers whichever
/// types come back. A branch that only returned a widget reading its fields
/// later would cost a second round trip for each type it did not render.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _text = '';
  Timer? _debounce;

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _text = value.trim());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Search'),
        trailing: NetworkLogButton(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: CupertinoSearchTextField(
                placeholder: 'Launches, rockets, astronauts',
                onChanged: _onChanged,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  setState(() => _text = v.trim());
                },
              ),
            ),
            Expanded(
              child: _text.isEmpty
                  ? const _Hint('Type a name, e.g. "falcon" or "crew".')
                  : _Results(text: _text),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Query>(
      debugLabel: 'Search',
      builder: (context, query, state) {
        final hits = (query.search(text: text) ?? const <SearchResult>[])
            .map(_hitOf)
            .toList();

        if (state.error != null) {
          return ErrorView(error: state.error!, onRetry: state.refetch);
        }
        if (hits.isEmpty && !state.isSkeleton) {
          return _Hint('Nothing matches "$text".');
        }
        return ListView.builder(
          itemCount: hits.length,
          itemBuilder: (context, i) => _HitTile(hits[i]),
        );
      },
    );
  }

  /// One branch per union member; each reads everything its tile shows.
  static _Hit _hitOf(SearchResult result) =>
      result.when(
        // Locals first: a read behind `date == null ? …` would only be
        // recorded once `date` arrived (the usual no-waterfall rule).
        launch: (l) {
          final (name, id, date, rocket) = (
            l.name,
            l.id,
            l.date,
            l.rocket?.name,
          );
          return _Hit(
            icon: CupertinoIcons.rocket,
            title: name,
            subtitle: date == null
                ? null
                : 'Launch · ${formatDate(date)} · $rocket',
            launchId: id,
          );
        },
        rocket: (r) {
          final (name, stages, success) = (r.name, r.stages, r.successRatePct);
          return _Hit(
            icon: CupertinoIcons.flame,
            title: name,
            subtitle: stages == null
                ? null
                : 'Rocket · $stages stages · $success% success',
          );
        },
        astronaut: (a) {
          final (name, agency, flights) = (a.name, a.agency, a.flights);
          return _Hit(
            icon: CupertinoIcons.person,
            title: name,
            subtitle: agency == null
                ? null
                : 'Astronaut · $agency · $flights flights',
          );
        },
      ) ??
      // A member type added to the schema after this app was built.
      const _Hit(icon: CupertinoIcons.question, title: '?', subtitle: '');
}

/// What a tile shows, whatever the member type. `null` text = skeleton.
class _Hit {
  const _Hit({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.launchId,
  });

  final IconData icon;
  final String? title;
  final String? subtitle;
  final String? launchId;
}

class _HitTile extends StatelessWidget {
  const _HitTile(this.hit);
  final _Hit hit;

  @override
  Widget build(BuildContext context) {
    final launchId = hit.launchId;
    return CupertinoListTile(
      leading: hit.title == null
          ? const SkeletonBox.circle(size: 28)
          : Icon(hit.icon, color: kColorAccent),
      title: SkeletonText(hit.title, width: 160),
      subtitle: SkeletonText(hit.subtitle, width: 200),
      trailing: launchId == null ? null : const CupertinoListTileChevron(),
      onTap: launchId == null
          ? null
          : () => LaunchScreen.open(context, launchId),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: kColorTextSecondary),
      ),
    ),
  );
}
