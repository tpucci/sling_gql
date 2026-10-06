import 'ref.dart';

/// What a [FieldPolicy] merge is told about the response it merges.
final class FieldMergeContext {
  const FieldMergeContext({required this.field, required this.args});

  /// The field name (not alias): `launches`.
  final String field;

  /// The arguments the page was requested with, as sent (JSON values: input
  /// objects are maps, enums their GraphQL name); `null` arguments left out.
  final Map<String, Object?> args;
}

/// Combines the value cached for a field with one a response brought, see
/// [FieldPolicy.merge].
typedef FieldMerge = Object? Function(
  Object? existing,
  Object? incoming,
  FieldMergeContext context,
);

/// How the cache stores one field: which arguments make an entry
/// ([keyArgs]) and, optionally, how a response is combined with what the
/// entry holds ([merge]).
///
/// Without a policy every argument set is its own entry and a response
/// replaces it (entities merging per field). Register policies with
/// `SlingClient(typePolicies:)`, keyed by the generated accessor class the
/// field is read through:
///
/// ```dart
/// SlingClient<Query>(
///   typePolicies: {
///     Query: TypePolicy(fields: {
///       'launches': RelayStylePagination(),           // one growing list
///       'search': FieldPolicy(keyArgs: ['text']),     // `limit` shares it
///     }),
///   },
/// )
/// ```
///
/// [merge] and the values it sees are in the cache's own format: entities
/// are references (`Ref` from `package:sling_gql/internal.dart`, equal when
/// their keys are), inline objects maps, lists lists. [existing] is `null`
/// when the entry is not cached yet. It must not be mutated: return a new
/// value. The result is then merged into the cache like any response —
/// only what differs touches its readers.
class FieldPolicy {
  const FieldPolicy({this.keyArgs, FieldMerge? merge})
    : _merge = merge; // ignore: prefer_initializing_formals

  /// The arguments that identify the cache entry: reads and responses with
  /// the same values for these share one entry whatever the other
  /// arguments are. `null`: every argument (the default without a policy).
  final List<String>? keyArgs;

  final FieldMerge? _merge;

  /// Whether responses go through [merge] (otherwise they replace the
  /// entry like without a policy, [keyArgs] only choosing the entry).
  bool get merges => _merge != null;

  /// Combines [existing] (the cached entry, `null` when absent) with
  /// [incoming] (one response for the field, already normalized), for the
  /// arguments in [context]. Pages of one request are merged one by one, in
  /// document order.
  Object? merge(Object? existing, Object? incoming, FieldMergeContext context) {
    final merge = _merge;
    return merge == null ? incoming : merge(existing, incoming, context);
  }

  /// Whether argument [name] is part of the cache key (see [keyArgs]).
  bool isKeyArg(String name) => keyArgs?.contains(name) ?? true;

  /// Whether the cached entry [existing] already holds what a read with
  /// [args] asks for. A read it does not cover is a miss: it renders a
  /// skeleton and is fetched with [args], then merged. Every read is
  /// covered by default.
  bool covers(Object? existing, Map<String, Object?> args) => true;

  /// Arguments that pick a page of the entry (`after`, `before`): a fetch
  /// of the whole selection (`refetch()`, `cacheAndNetwork`, a stale
  /// `maxAge`) sends the entry without them — its first page — so the
  /// entry starts over from there.
  Set<String> get pageArgs => const {};

  /// The values of [pageArgs] of each page [existing] holds (`{}` for the
  /// first page), or `null` when the policy has no pages. A field read
  /// *inside* a cached entry that is not cached yet (a row reading a new
  /// field) is then fetched for every page held, and written with [fill].
  List<Map<String, Object?>>? pages(Object? existing) => null;

  /// Writes the [pages] of a response fetched only for fields the cached
  /// entry [existing] lacks (see [pages]; already normalized, so their
  /// entities are written): never a merge — the entry keeps its pages.
  /// By default each page adds what the entry lacks ([addAbsent]).
  Object? fill(
    Object? existing,
    List<({Map<String, Object?> args, Object? value})> pages,
  ) {
    var value = existing;
    for (final page in pages) {
      value = addAbsent(value, page.value);
    }
    return value;
  }

  /// [existing] with what [incoming] has and it lacks, deeply: never
  /// replaces a value. Inline list elements are matched by their `cursor`
  /// (relay edges); other lists are kept as they are.
  static Object? addAbsent(Object? existing, Object? incoming) {
    if (existing is! Map<String, Object?>) return existing ?? incoming;
    if (incoming is! Map) return existing;
    final out = Map<String, Object?>.of(existing);
    for (final MapEntry(:key, :value) in incoming.entries) {
      final k = key as String;
      if (!out.containsKey(k)) {
        out[k] = value;
        continue;
      }
      final held = out[k];
      if (held is Map<String, Object?> && value is Map) {
        out[k] = addAbsent(held, value);
      } else if (held is List && value is List) {
        out[k] = _addAbsentByCursor(held, value);
      }
    }
    return out;
  }

  static List<Object?> _addAbsentByCursor(
    List<Object?> held,
    List<Object?> incoming,
  ) {
    final byCursor = <Object, Map>{
      for (final e in incoming)
        if (e is Map && e['cursor'] != null) e['cursor'] as Object: e,
    };
    if (byCursor.isEmpty) return held;
    return [
      for (final e in held)
        if (e is Map<String, Object?> && byCursor[e['cursor']] != null)
          addAbsent(e, byCursor[e['cursor']])
        else
          e,
    ];
  }
}

/// The field policies of one type, by field name. See [FieldPolicy].
class TypePolicy {
  const TypePolicy({this.fields = const {}});

  final Map<String, FieldPolicy> fields;
}

/// A cursor connection (`first`/`after`, `last`/`before`) cached as one
/// growing list, the way Apollo's `relayStylePagination` does: every page
/// of `launches(first: 20, after: …, filter: …)` is merged into the entry
/// of `launches(filter: …)`, whose `nodes` / `edges` hold all pages loaded
/// so far, in order.
///
/// - A page *after* a cursor is appended (an `edges` cursor already held
///   cuts the list there first); a page *before* one is prepended.
///   `pageInfo` follows: `endCursor` / `hasNextPage` from the last page,
///   `startCursor` / `hasPreviousPage` from the first.
/// - A page without `after`/`before` (the first page, what a refetch
///   sends) replaces the entry: a refresh starts the list over.
/// - Other fields (`totalCount`) take the latest page's value.
/// - A read with `after: c` is a miss until the page after `c` was merged
///   (the entry remembers which pages it holds), so asking for the next
///   page fetches exactly that page while the loaded ones stay on screen.
///
/// [keyArgs] defaults to every argument except `first`, `after`, `last`
/// and `before`.
class RelayStylePagination extends FieldPolicy {
  const RelayStylePagination({super.keyArgs});

  /// Where the entry records the pages it holds, in the order they were
  /// merged: `[]` for the first page, `["after", "c20"]`, `["before", "c1"]`
  /// (lists, which a merge replaces element by element; a map would keep
  /// stale keys). Kept with the entry (persisted with it); no GraphQL field
  /// can be named so, so no accessor ever reads it.
  static const pagesKey = '__pages';

  static const _paginationArgs = {'first', 'after', 'last', 'before'};

  @override
  bool get merges => true;

  @override
  bool isKeyArg(String name) =>
      keyArgs?.contains(name) ?? !_paginationArgs.contains(name);

  @override
  Set<String> get pageArgs => const {'after', 'before'};

  /// The page [args] select, in the [pagesKey] format.
  static List<Object?> _page(Map<String, Object?> args) => switch (args) {
    {'after': final after?} => ['after', after],
    {'before': final before?} => ['before', before],
    _ => const [],
  };

  static bool _samePage(Object? held, List<Object?> page) =>
      held is List &&
      held.length == page.length &&
      (page.isEmpty || (held[0] == page[0] && held[1] == page[1]));

  @override
  bool covers(Object? existing, Map<String, Object?> args) {
    final page = _page(args);
    if (page.isEmpty) return true;
    if (existing is! Map) return false;
    final held = existing[pagesKey];
    return held is List && held.any((p) => _samePage(p, page));
  }

  @override
  List<Map<String, Object?>>? pages(Object? existing) {
    final held = existing is Map ? existing[pagesKey] : null;
    if (held is! List) return const [{}];
    return [
      for (final p in held)
        if (p is List) {if (p.length == 2) p[0] as String: p[1]},
    ];
  }

  /// Adds what the entry lacks ([FieldPolicy.fill]) and, when [fetched]
  /// holds every page the entry holds, drops the entities no page returned
  /// any more (deleted, moved past the loaded pages, or put in by a
  /// `ListRule` and not on any page): their fields could never be filled,
  /// and the entry would be fetched again and again.
  @override
  Object? fill(
    Object? existing,
    List<({Map<String, Object?> args, Object? value})> fetched,
  ) {
    final filled = super.fill(existing, fetched);
    final held = pages(existing);
    if (filled is! Map || held == null) return filled;
    final refetched = [for (final page in fetched) _page(page.args)];
    final everyPage = held.every(
      (h) => refetched.any((p) => _samePage(_page(h), p)),
    );
    if (!everyPage) return filled;
    // Per list, the entities the pages returned (`null`: no page had it).
    Set<Ref>? returned(String list, Object? Function(Object?) entity) {
      Set<Ref>? out;
      for (final page in fetched) {
        final value = page.value;
        final items = value is Map ? value[list] : null;
        if (items is! List) continue;
        out ??= {};
        for (final e in items) {
          if (entity(e) case final Ref ref) out.add(ref);
        }
      }
      return out;
    }

    Object? node(Object? edge) => edge is Map ? edge['node'] : null;
    final out = <String, Object?>{
      for (final e in filled.entries) e.key as String: e.value,
    };
    for (final (list, entity) in [
      ('nodes', (Object? e) => e),
      ('edges', node),
    ]) {
      final keep = returned(list, entity);
      final items = out[list];
      if (keep == null || items is! List) continue;
      // Only entities can be told apart across pages; inline elements stay.
      out[list] = [
        for (final e in items)
          if (entity(e) is! Ref || keep.contains(entity(e))) e,
      ];
    }
    return out;
  }

  @override
  Object? merge(Object? existing, Object? incoming, FieldMergeContext context) {
    final page = _page(context.args);
    if (incoming is! Map) return page.isEmpty ? incoming : existing;
    if (existing is! Map || page.isEmpty) {
      return <String, Object?>{
        for (final e in incoming.entries) e.key as String: e.value,
        pagesKey: [page],
      };
    }
    final after = page.isNotEmpty && page[0] == 'after' ? page[1] : null;
    final before = page.isNotEmpty && page[0] == 'before' ? page[1] : null;
    // Where the incoming page goes, from the cursors of the held edges:
    // after the edge with cursor [after] (the end when not found), before
    // the one with cursor [before] (the start when not found).
    final edges = existing['edges'];
    int? cut;
    if (edges is List) {
      final at = edges.indexWhere(
        (e) => e is Map && e['cursor'] == (after ?? before),
      );
      if (at >= 0) cut = after != null ? at + 1 : at;
    }
    final heldLength = edges is List ? edges.length : null;

    List<Object?>? splice(Object? held, Object? added) {
      if (added is! List) return held is List ? held : null;
      final list = held is List ? held : const <Object?>[];
      // A cut found in `edges` applies to `nodes` when they line up.
      final at = cut != null && list.length == heldLength ? cut : null;
      return after != null
          ? [...list.take(at ?? list.length), ...added]
          : [...added, ...list.skip(at ?? 0)];
    }

    final out = <String, Object?>{
      for (final e in existing.entries) e.key as String: e.value,
    };
    for (final MapEntry(:key, :value) in incoming.entries) {
      out[key as String] = switch (key) {
        'edges' || 'nodes' => splice(existing[key], value),
        'pageInfo' => _pageInfo(existing[key], value, forward: after != null),
        _ => value,
      };
    }
    final held = switch (existing[pagesKey]) {
      final List<Object?> list => list,
      _ => const <Object?>[],
    };
    // A page merged again after a held cursor cut the pages merged after it
    // off the list: forget them too, they are no longer covered.
    final at = held.indexWhere((p) => _samePage(p, page));
    final truncated = after != null && cut != null && cut < heldLength!;
    out[pagesKey] = [
      if (at >= 0 && truncated)
        ...held.take(at)
      else
        for (final p in held)
          if (!_samePage(p, page)) p,
      page,
    ];
    return out;
  }

  /// `pageInfo` of the merged list: the far end from the new page, the near
  /// end kept; a `null` cursor (an empty page) keeps the held one.
  static Object? _pageInfo(
    Object? held,
    Object? added, {
    required bool forward,
  }) {
    if (added is! Map) return held;
    if (held is! Map) return added;
    final out = <String, Object?>{
      for (final e in held.entries) e.key as String: e.value,
    };
    final (cursor, more) = forward
        ? ('endCursor', 'hasNextPage')
        : ('startCursor', 'hasPreviousPage');
    for (final MapEntry(:key, :value) in added.entries) {
      final k = key as String;
      if (k == 'startCursor' || k == 'endCursor') {
        if (k == cursor && value != null) out[k] = value;
        if (!out.containsKey(k)) out[k] = value;
      } else if (k == 'hasNextPage' || k == 'hasPreviousPage') {
        if (k == more || !out.containsKey(k)) out[k] = value;
      } else {
        out[k] = value;
      }
    }
    return out;
  }
}

/// A response value for a field with a merging [FieldPolicy], put in place
/// of the raw value in the data handed to `Cache.writeResponse` (by
/// `PrintedOperation.toCacheKeys`): the [pages] of one request to merge
/// into the entry, in order.
final class PolicyWrite {
  PolicyWrite(this.policy, this.field);

  final FieldPolicy policy;

  /// The field name, for [FieldMergeContext.field].
  final String field;

  /// One per response key mapped to the entry: the arguments it was sent
  /// with, its value, and whether it only fills absent fields
  /// ([FieldPolicy.fill]) rather than merging a page.
  final List<({Map<String, Object?> args, Object? value, bool fill})> pages =
      [];

  @override
  String toString() =>
      'PolicyWrite($field, ${[for (final p in pages) p.args]})';
}
