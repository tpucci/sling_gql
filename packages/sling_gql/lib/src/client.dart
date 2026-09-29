import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'accessor.dart';
import 'cache/cache.dart';
import 'selection.dart';

/// Error returned by the GraphQL endpoint (transport or `errors[]`).
class SlingException implements Exception {
  SlingException(
    this.message, {
    this.graphqlErrors = const [],
    this.statusCode,
  });

  final String message;
  final List<Map<String, Object?>> graphqlErrors;
  final int? statusCode;

  @override
  String toString() => 'SlingException: $message';
}

/// Builds the root accessor of an operation for a given recorder.
typedef RootFactory<Q extends Accessor> = Q Function(Recorder recorder);

/// The generator's single per-schema convenience: bundles the query,
/// mutation and subscription root factories so app code never has to name
/// `Mutation.root` by hand — `SlingScope(schema: slingSchema, ...)` resolves
/// `QueryBuilder` (via the client's `rootFactory`), `MutationBuilder` (via
/// `SlingScope.mutationRootOf`) and `SubscriptionBuilder` (via
/// `SlingScope.subscriptionRootOf`) from it.
///
/// Also carries the facts the runtime must agree on with the generated code:
/// [keyField] (`--key-field`). `SlingClient(schema: slingSchema)` builds its
/// default cache from it, so the two never have to be kept in sync by hand.
class SlingSchema<Q extends Accessor, M extends Accessor> {
  const SlingSchema({
    required this.query,
    this.mutation,
    this.subscription,
    this.keyField = 'id',
  });

  final RootFactory<Q> query;

  /// The generated `Mutation.root`, when the schema has a mutation type.
  final RootFactory<M>? mutation;

  /// The key field the generator was run with (`--key-field`, default
  /// `id`): keyed types were decided by it, and keyed selections must fetch
  /// it. See [Normalization.keyField].
  final String keyField;

  /// The cache normalization matching the generated code.
  Normalization get normalization => Normalization(keyField: keyField);

  /// The generated `Subscription.root`, when the schema has a subscription
  /// type.
  final RootFactory<Accessor>? subscription;
}

/// True when asserts are enabled (debug builds and tests).
bool get _assertsEnabled {
  var enabled = false;
  assert(enabled = true);
  return enabled;
}

/// A scope caused a *second* round trip right after its first one landed:
/// the rebuild triggered by that response read fields the first request did
/// not select. Typical causes are a read inside an `if` on fetched data, a
/// read inside a callback, or a missing `prepare`.
///
/// Reported through [SlingClient.onWaterfall] in debug mode. Requests caused
/// by `refetch()` or by a rebuild the app triggered itself (`setState` after a
/// tap, e.g. paginating) are not waterfalls and are never reported.
class WaterfallWarning {
  WaterfallWarning({required this.scope, required this.fields});

  /// `debugLabel` of the scope, or a generated `QueryScope#n`.
  final String scope;

  /// Field paths that caused the extra request, e.g. `me.friends(…).age`.
  final List<String> fields;

  static const hint =
      'read the field unconditionally at the top of build, or prepare it';

  @override
  String toString() =>
      'sling_gql: waterfall in $scope — a second request was needed for '
      '${fields.join(', ')}. Fix: $hint.';
}

/// Decides *when* pending selections are flushed into one request.
///
/// Selections are accumulated until [flush] runs; everything recorded in the
/// meantime — by any scope — goes into the same document.
typedef FlushScheduler = void Function(void Function() flush);

/// Flushes on the next microtask. Right for imperative code and tests.
/// Flutter widgets should use `frameEndScheduler` (see `widgets.dart`): the
/// initial build and lazily built children (slivers) run in different
/// event-loop tasks, so a microtask would split one frame into two requests.
void microtaskScheduler(void Function() flush) => scheduleMicrotask(flush);

/// How a scope combines the cache and the network.
///
/// Independent of `maxAge`: a stale-while-revalidate window applies on top
/// of any policy (see [QueryScope.maxAge]).
enum FetchPolicy {
  /// Read from the cache; fetch only what is missing. The default.
  cacheFirst,

  /// Read from the cache *and* refetch the whole selection in the
  /// background on the scope's first run (a screen opening), so it shows
  /// cached data at once and fresh data as soon as it lands. Later rebuilds
  /// behave like [cacheFirst].
  cacheAndNetwork,

  /// Ignore the cache until this scope's own request has landed: the first
  /// runs read skeletons and everything selected is fetched, even if cached.
  /// The response is written to the shared cache as usual, and from then on
  /// the scope reads like [cacheFirst].
  networkOnly,
}

/// A scope in which selections are recorded, one per widget build.
///
/// The scope owns the selection tree recorded during its last run, so it can
/// be re-fetched wholesale (`refetch`) and so the client knows which scopes to
/// notify when data lands.
class QueryScope<Q extends Accessor> implements Recorder {
  QueryScope(
    this.client, {
    required this.onChanged,
    this.scheduler = microtaskScheduler,
    String? debugLabel,
    FetchPolicy? fetchPolicy,
    Duration? maxAge,
  }) : debugLabel = debugLabel ?? 'QueryScope#${++_lastId}',
       fetchPolicy = fetchPolicy ?? client.fetchPolicy,
       maxAge = maxAge ?? client.maxAge,
       _bypassCache =
           (fetchPolicy ?? client.fetchPolicy) == FetchPolicy.networkOnly;

  static int _lastId = 0;

  final SlingClient<Q> client;

  /// How this scope combines cache and network (see [FetchPolicy]).
  /// Defaults to [SlingClient.fetchPolicy].
  final FetchPolicy fetchPolicy;

  /// Stale-while-revalidate window. When set, a run whose data was last
  /// fetched from the server longer ago than this (or never: hydrated
  /// snapshots, optimistic writes) keeps rendering the cached values and
  /// refetches the whole selection in the background; [isStale] is true
  /// meanwhile. `null` (the default, from [SlingClient.maxAge]) means cached
  /// data never expires: only [refetch] gets fresh data.
  ///
  /// Freshness is per dependency key (`Launch:launch-181.name`): a field is
  /// fresh if *some* response wrote it within the window, whichever screen
  /// asked for it.
  final Duration? maxAge;

  /// True while [FetchPolicy.networkOnly] is still waiting for its first
  /// successful response: reads come back `missing` so everything selected
  /// is fetched.
  bool _bypassCache;
  late final _BypassCache _bypass = _BypassCache(client.cache);

  /// Invoked when data relevant to this scope changed and it should re-run.
  final void Function() onChanged;

  /// How this scope asks the client to flush (see [FlushScheduler]).
  final FlushScheduler scheduler;

  /// Names this scope in [WaterfallWarning]s.
  final String debugLabel;

  @override
  String get operation => 'query';

  @override
  Cache get cache => _bypassCache ? _bypass : client.cache;

  Selection _root = Selection.root('query');
  @override
  Selection get root => _root;

  Set<String> _deps = {};

  /// Dependency keys read during the last run (and by accessors created in
  /// it afterwards). A scope rebuilds when a write touches any of them.
  @override
  Set<String> get deps => _deps;

  bool _hadMiss = false;
  bool _awaiting = false;
  bool _stale = false;
  int _runCount = 0;
  Object? _error;

  /// The pending fetch was not caused by misses (revalidation, cache-and-
  /// network, [refetch]): the scope renders cached data meanwhile, and an
  /// error from it must stay visible even though nothing is missing.
  bool _backgroundFetch = false;
  bool _errorIsBackground = false;

  /// When [_error] was set; used to expire it once `retryFailedAfter` elapses.
  DateTime? _errorAt;
  Completer<void>? _settled;

  /// Requests this scope took part in. A waterfall is a request after the
  /// first one.
  int _requestCount = 0;

  /// Set when the client asked this scope to re-run (a response landed or a
  /// write touched its deps); consumed by the next [run]. A rebuild the app
  /// triggered itself (`setState` after user input) does not set it.
  bool _rebuildFromClient = false;

  /// True while misses are attributable to a client-triggered rebuild: from
  /// that [run] until the next one, so reads by lazily built children and by
  /// callbacks bound to that build count too.
  bool _missesAreWaterfall = false;
  final List<Selection> _waterfallLeaves = [];

  /// Completes when the fetch this scope is waiting on has landed (or failed).
  Future<void> get whenSettled =>
      _awaiting ? (_settled ??= Completer<void>()).future : Future.value();

  /// True while a fetch containing selections from this scope is pending.
  bool get isLoading => _awaiting;

  /// True if the last run touched data that is not in the cache.
  bool get hasMissingData => _hadMiss;

  /// True when the last run rendered cached data older than [maxAge] (or
  /// never fetched from the server); a background refetch is in flight or
  /// blocked by a sticky [error]. Always false without a [maxAge].
  bool get isStale => _stale;

  /// The last error from a fetch this scope took part in.
  ///
  /// **Sticky until [refetch].** Once a request this scope took part in
  /// fails, [error] stays set — even though the scope's fields are still
  /// `missing` and every rebuild reads them again — so the client does not
  /// re-send the same failing document forever: without this, a failing
  /// query would loop build → miss → fetch → fail → rebuild → miss → …
  /// Call [refetch] to clear it and try again (a pull-to-refresh gesture is
  /// the natural trigger). See also `SlingClient.retryFailedAfter` for
  /// automatic retries after a cooldown instead of forever-sticky errors.
  Object? get error => _error;

  /// Runs [body] with a fresh selection tree, returning its result.
  ///
  /// Accessors created inside [body] stay bound to this scope, so reads made
  /// later in the same frame (e.g. by child widgets that received an accessor)
  /// are still recorded and fetched in the same batch.
  T run<T>(T Function(Q root) body) {
    _root = Selection.root('query');
    _deps = {};
    _hadMiss = false;
    _missesAreWaterfall = _rebuildFromClient && _requestCount > 0;
    _rebuildFromClient = false;
    // What [body] sees through `isStale` / `isLoading`: the previous run's
    // values, since this run's are only known once its reads are.
    final staleSeen = _stale;
    final result = body(client.rootFactory(this));
    final firstRun = _runCount++ == 0;
    final maxAge = this.maxAge;
    _stale = maxAge != null && client._isStale(_allDeps, maxAge);
    if (!_hadMiss && !_stale && !_errorIsBackground) {
      // Fully served from fresh cache: an error from a miss-driven fetch is
      // moot (a background one stays until `refetch`, see `error`).
      _error = null;
      _errorAt = null;
    }
    final wantsNetwork =
        _stale || (firstRun && fetchPolicy == FetchPolicy.cacheAndNetwork);
    // A miss already schedules a fetch of the missing leaves; a stale or
    // cache-and-network run adds the *whole* selection to it. Sticky errors
    // block it like they block misses, so a failing server cannot loop.
    var backgroundStarted = false;
    if (wantsNetwork && !_awaiting && !_errorBlocksFetch()) {
      client._enqueue(_root);
      _awaiting = true;
      _backgroundFetch = !_hadMiss;
      client._schedule(this);
      backgroundStarted = true;
    }
    // The body rendered flags that turned out wrong for this run (stale data
    // found, a background refresh started, or data fresh again after one):
    // run once more so what is shown matches. Deferred — this is usually a
    // widget build — and it cannot loop: the next run sees what it computes.
    if (_stale != staleSeen || backgroundStarted) {
      scheduleMicrotask(() {
        if (!_disposed) onChanged();
      });
    }
    return result;
  }

  /// Re-fetches like [refetch], unless every field read in the last run is
  /// within [maxAge], in which case nothing is sent and the future completes
  /// at once. Without a [maxAge] it is exactly [refetch]. The soft option for
  /// "refresh when this screen comes back into view".
  Future<void> revalidate() {
    final maxAge = this.maxAge;
    if (maxAge != null && !client._isStale(_allDeps, maxAge)) {
      return Future.value();
    }
    return refetch();
  }

  /// True when a sticky error must suppress a fetch (see [error]). Expires
  /// the error when `SlingClient.retryFailedAfter` has elapsed.
  bool _errorBlocksFetch() {
    if (_error == null) return false;
    final retryAfter = client.retryFailedAfter;
    final at = _errorAt;
    final expired =
        retryAfter != null &&
        at != null &&
        client._now().difference(at) >= retryAfter;
    if (!expired) return true;
    _error = null;
    _errorAt = null;
    _errorIsBackground = false;
    return false;
  }

  /// Re-fetches everything this scope selected during its last run.
  Future<void> refetch() {
    _error = null;
    _errorAt = null;
    _errorIsBackground = false;
    _awaiting = true;
    _backgroundFetch = !_hadMiss;
    client._enqueue(_root, force: true);
    client._schedule(this);
    return whenSettled;
  }

  @override
  void onMiss(Selection leaf) {
    _hadMiss = true;
    // Error state is sticky until `refetch()` (or `SlingClient.retryFailedAfter`
    // elapses) so a failing query does not loop:
    // build → miss → fetch → fail → rebuild → miss → …
    if (_errorBlocksFetch()) return;
    if (client._enqueueLeaf(leaf) && _missesAreWaterfall) {
      _waterfallLeaves.add(leaf);
    }
    _awaiting = true;
    _backgroundFetch = false;
    client._schedule(this);
  }

  @override
  void onWrite(CacheWrite write) => client._onWrite(write);

  /// Row scopes attached to this scope (see [row]).
  final Set<RowScope> _rows = {};

  /// Creates a [RowScope] under this scope: accessors bound to it record
  /// their dependencies there, so a write only re-runs that row
  /// ([onChanged]) rather than this scope. Dispose it with the row.
  RowScope row({required void Function() onChanged}) {
    final row = RowScope._(this, onChanged);
    _rows.add(row);
    client._rows.add(row);
    return row;
  }

  /// The query scope owning [recorder] (an accessor's `recorder`): itself,
  /// or the parent of a [RowScope]. `null` for other recorders (cache,
  /// mutation and subscription scopes).
  static QueryScope<Accessor>? ownerOf(Recorder recorder) => switch (recorder) {
    QueryScope() => recorder,
    RowScope() => recorder.parent,
    _ => null,
  };

  /// Own deps plus those of the rows attached, for freshness checks.
  Set<String> get _allDeps =>
      _rows.isEmpty ? _deps : {..._deps, for (final r in _rows) ...r._deps};

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    client._scopes.remove(this);
    for (final r in _rows.toList()) {
      r.dispose();
    }
  }

  void _settle(Object? error) {
    _awaiting = false;
    _error = error;
    _errorAt = error != null ? client._now() : null;
    _errorIsBackground = error != null && _backgroundFetch;
    _backgroundFetch = false;
    // network-only: the scope's own data has landed, read the cache from now on.
    if (error == null) _bypassCache = false;
    _settled?.complete();
    _settled = null;
  }

  void _changedByClient() {
    _rebuildFromClient = true;
    onChanged();
  }

  /// Called by the client when a request containing this scope's selections
  /// is about to be sent. Returns the warning to report, if this request is a
  /// waterfall.
  WaterfallWarning? _requestSent() {
    _requestCount++;
    if (_waterfallLeaves.isEmpty) return null;
    final fields = _waterfallLeaves.map(_fieldPath).toSet().toList();
    _waterfallLeaves.clear();
    return WaterfallWarning(scope: debugLabel, fields: fields);
  }

  /// `me.friends(…).age`: field names from the root, `(…)` marking
  /// arguments.
  static String _fieldPath(Selection leaf) {
    final parts = <String>[];
    Selection? node = leaf;
    while (node != null && !node.isRoot) {
      parts.insert(
        0,
        node.isFragment
            ? '(on ${node.typeCondition})'
            : node.args.isEmpty
            ? node.field
            : '${node.field}(…)',
      );
      node = node.parent;
    }
    return parts.join('.');
  }
}

/// A sub-scope of a [QueryScope] for one part of its tree — typically one row
/// of a long list — that rebuilds on its own (`SlingRow` is the widget form).
///
/// Accessors rebound to it ([bind]) read through the same cache and add to
/// the same selection tree as the parent's, and misses and writes go to the
/// parent (it still owns the request, loading and error state); only the
/// **dependency keys** are this scope's own. A write to `Launch:x.favorite`
/// then re-runs the one row that read it instead of the parent's whole
/// build — the parent depends only on what it read itself (the list).
///
/// A row keeps working through a parent rebuild: the parent hands it fresh
/// accessors, bound again on the row's next [run].
class RowScope implements Recorder {
  RowScope._(this.parent, this.onChanged);

  /// The query scope misses, writes, selections and fetch state belong to.
  final QueryScope<Accessor> parent;

  /// Invoked when a write touched one of this row's [deps].
  final void Function() onChanged;

  bool _disposed = false;

  @override
  String get operation => parent.operation;

  @override
  Selection get root => parent.root;

  @override
  Cache get cache => parent.cache;

  Set<String> _deps = {};

  /// Dependency keys read during the last [run] (and by accessors bound in
  /// it afterwards).
  @override
  Set<String> get deps => _deps;

  /// Rebinds [accessor] (an accessor handed out by the parent or by another
  /// row of it) to this scope, via its generated constructor [ctor].
  A bind<A extends Accessor>(
    A accessor,
    A Function(Recorder, Selection, List<Object>) ctor,
  ) => ctor(this, accessor.selection, accessor.path);

  /// Runs [body] with [accessor] bound to this scope and fresh [deps].
  T run<A extends Accessor, T>(
    A accessor,
    A Function(Recorder, Selection, List<Object>) ctor,
    T Function(A bound) body,
  ) {
    _deps = {};
    return body(bind(accessor, ctor));
  }

  @override
  void onMiss(Selection leaf) => parent.onMiss(leaf);

  @override
  void onWrite(CacheWrite write) => parent.onWrite(write);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    parent._rows.remove(this);
    parent.client._rows.remove(this);
  }
}

/// The cache a [FetchPolicy.networkOnly] scope reads through before its
/// first response: every read is a miss, every write goes to the real cache.
class _BypassCache implements Cache {
  _BypassCache(this._inner);

  final Cache _inner;

  @override
  Object? read(String operation, List<Object> path, {Set<String>? deps}) =>
      missing;

  @override
  Object? readField(
    String operation,
    List<Object> path,
    String field, {
    Set<String>? deps,
  }) => missing;

  @override
  bool hasEntity(String key) => false;

  @override
  Normalization get normalization => _inner.normalization;
  @override
  Set<String> write(String operation, List<Object> path, Object? value) =>
      _inner.write(operation, path, value);
  @override
  Set<String> remove(String operation, List<Object> path) =>
      _inner.remove(operation, path);
  @override
  Set<String> writeResponse(
    String operation,
    Map<String, Object?> data, {
    DateTime? at,
  }) => _inner.writeResponse(operation, data, at: at);
  @override
  DateTime? fetchedAt(String depKey) => _inner.fetchedAt(depKey);
  @override
  Set<String> evict(String key) => _inner.evict(key);
  @override
  Set<String> gc() => _inner.gc();
  @override
  Iterable<String> get entityKeys => _inner.entityKeys;
  @override
  Map<String, Object?>? entity(String key) => _inner.entity(key);
  @override
  Stream<Set<String>> get onChange => _inner.onChange;
  @override
  Map<String, Object?> get snapshot => _inner.snapshot;
  @override
  void clear() => _inner.clear();
}

/// Recorder for one `mutate` call. Misses are expected (nothing is cached
/// before the mutation runs) and never trigger a fetch.
class MutationScope implements Recorder {
  MutationScope(this.client);

  final SlingClient<Accessor> client;

  @override
  String get operation => 'mutation';

  @override
  final Selection root = Selection.root('mutation');

  @override
  Cache get cache => client.cache;

  @override
  final Set<String> deps = {};

  @override
  void onMiss(Selection leaf) {}

  @override
  void onWrite(CacheWrite write) => client._onWrite(write);
}

/// Typed, imperative access to the cache — outside a widget build, in an
/// `optimistic:` callback, after `await client.mutate(...)`. Get one from
/// [SlingClient.cacheScope]; the generator adds one method per keyed type
/// (`extension SlingCacheAccess on CacheScope<Query>`: `launch(id)`, …).
///
/// The accessors it hands out are the ordinary generated classes, bound to
/// this scope:
/// - **reads never fetch** — a field that is not cached reads as `null`
///   (objects as skeletons, see [Accessor.isSkeleton]) and nothing is sent;
/// - **writes** (generated setters, [CacheList] edits) go through the
///   normal write path: dependent scopes rebuild, and inside a mutation's
///   `optimistic` callback they are journaled and undone on failure.
///
/// A scope records nothing that outlives it: [deps] is always empty (it
/// never rebuilds) and misses are ignored. Scopes are cheap; take a fresh
/// one per use.
class CacheScope<Q extends Accessor> implements Recorder, ListLocator {
  CacheScope(this.client);

  final SlingClient<Q> client;

  @override
  String get operation => 'query';

  @override
  final Selection root = Selection.root('query');

  @override
  Cache get cache => client.cache;

  /// Always a fresh empty set: a cache scope never rebuilds.
  @override
  Set<String> get deps => <String>{};

  /// Reads through a cache scope never fetch.
  @override
  void onMiss(Selection leaf) {}

  @override
  void onWrite(CacheWrite write) => client._onWrite(write);

  /// Lists located by the selector [list] is currently running, if any.
  List<(List<Object>, List<Accessor>?)>? _located;

  @override
  void locateList(List<Object> path, List<Accessor>? value) =>
      _located?.add((path, value));

  /// The typed query root, reading from the cache only: `cacheScope.query.me`.
  /// Root fields that were never fetched read as skeletons — check
  /// [Accessor.isSkeleton] before writing through one, or the write creates
  /// a partial object the next fetch has to merge into.
  Q get query => client.rootFactory(this);

  /// The cached entity `typename:id` as a [T] (via [ctor], the generated
  /// constructor tear-off), or `null` when it is not in the cache — never a
  /// skeleton, and never a request. Keys are resolved with
  /// [Normalization.lookup], so with [Normalization.none] this is always
  /// `null`. Generated code wraps it: `cacheScope.launch('launch-181')`.
  T? entity<T extends Accessor>(
    String typename,
    Object id,
    T Function(Recorder, Selection, List<Object>) ctor,
  ) {
    final key = cache.normalization.lookup(typename, {
      cache.normalization.keyField: Arg('ID', id),
    });
    if (key == null || !cache.hasEntity(key)) return null;
    return ctor(this, root, [Ref(key)]);
  }

  /// The cached list [select] returns, for membership edits:
  ///
  /// ```dart
  /// client.cacheScope.list((q) => q.me?.favorites).prepend(launch);
  /// ```
  ///
  /// [select] must return a generated list getter/method as-is (not a
  /// `.where(...)`/`.toList()` copy); arguments address the cache entry
  /// exactly as in a widget (`q.launches(first: 20).nodes` is the first
  /// page only). The path to it may go through lookups and entities
  /// (`(q) => q.launch(id: x)?.crew`).
  CacheList<R> list<R extends Accessor>(List<R>? Function(Q query) select) {
    final located = _located = [];
    final List<R>? value;
    try {
      value = select(query);
    } finally {
      _located = null;
    }
    for (final (path, listValue) in located.reversed) {
      if (value == null ? listValue == null : identical(listValue, value)) {
        return CacheList<R>._(this, path);
      }
    }
    // `q.launch(id: x)?.crew` with no cached launch: nothing to edit.
    if (value == null) return CacheList<R>._(this, null);
    throw ArgumentError(
      'CacheScope.list: the selector must return a generated list field as-is, '
      'e.g. (q) => q.me?.favorites',
    );
  }

  /// Removes [entity] from the cache everywhere: its entity is dropped, every
  /// list that referenced it loses the element, and object fields pointing at
  /// it read as missing again (re-fetched on the next build). Dependent
  /// scopes rebuild. Returns `false` when it was not cached.
  ///
  /// Not journaled: an eviction inside a mutation's `optimistic` callback is
  /// **not** undone on failure — evict after the mutation succeeded.
  bool evict(Accessor entity) {
    final key = _entityKey(entity);
    if (key == null) return false;
    final touched = cache.evict(key);
    client._notify(touched);
    return touched.isNotEmpty;
  }

  /// Entity key of the object [entity] points at, or `null` when it is not
  /// cached or not a normalized entity.
  String? _entityKey(Accessor entity) {
    final path = entity.path;
    if (path.length == 1 && path.first is Ref) {
      final key = (path.first as Ref).key;
      return cache.hasEntity(key) ? key : null;
    }
    final value = cache.read(entity.recorder.operation, path);
    if (value is! Map<String, Object?>) return null;
    return cache.normalization.identify(value);
  }
}

/// One cached list of keyed entities, addressed by [CacheScope.list] for
/// membership edits: `append` / `prepend` / `remove` a [Ref] to an entity.
///
/// Edits write the whole new list back through the normal write path, so
/// they notify exactly like a response replacing the list (the dependency
/// key of the field holding it) and are journaled like any `CacheWrite` — an
/// optimistic `prepend` is rolled back when the mutation fails.
///
/// Membership is set-like: adding an entity already in the list, or removing
/// one that is not, changes nothing and returns `false`. A list that is not
/// cached (never fetched, or a server `null`) is left alone — adding to it
/// would make a partial list look complete — and every edit returns `false`.
///
/// Each cached argument set is its own list: a paginated connection's pages
/// (`launches(first:, after:)`) and every filter are separate entries, and an
/// edit applies to the one entry you named. A filtered or paginated list is
/// usually better served by `refetchQueries`; `totalCount`-style siblings are
/// not adjusted either.
class CacheList<R extends Accessor> {
  CacheList._(this._scope, this.path);

  final CacheScope<Accessor> _scope;

  /// Where the list lives in the cache (see [Accessor.path]); `null` when the
  /// selector returned `null` before reaching a list field (its parent object
  /// is `null`), in which case every edit is a no-op.
  final List<Object>? path;

  Cache get _cache => _scope.cache;

  /// The cached elements, or `null` when the list is not cached.
  List<Object?>? get _items {
    final path = this.path;
    if (path == null) return null;
    final value = _cache.read(_scope.operation, path);
    return value is List ? value.cast<Object?>() : null;
  }

  /// True when the list itself is cached (a membership edit can apply).
  bool get isCached => _items != null;

  /// True when [entity] is an element of the cached list.
  bool contains(R entity) {
    final key = _scope._entityKey(entity);
    return key != null && (_items?.contains(Ref(key)) ?? false);
  }

  /// Adds [entity] at the end. See [CacheList] for when this is a no-op.
  bool append(R entity) => _insert(entity, atStart: false);

  /// Adds [entity] at the start. See [CacheList] for when this is a no-op.
  bool prepend(R entity) => _insert(entity, atStart: true);

  /// Removes every occurrence of [entity]. Returns `false` when it was not
  /// in the list (or the list is not cached).
  bool remove(R entity) {
    final items = _items;
    final key = _scope._entityKey(entity);
    if (items == null || key == null) return false;
    final ref = Ref(key);
    if (!items.contains(ref)) return false;
    _replace(items, [
      for (final e in items)
        if (e != ref) e,
    ]);
    return true;
  }

  bool _insert(R entity, {required bool atStart}) {
    final items = _items;
    final key = _scope._entityKey(entity);
    if (items == null) return false;
    if (key == null) {
      throw ArgumentError.value(
        entity,
        'entity',
        'is not a cached, normalized entity (it needs __typename and '
            '${_cache.normalization.keyField} in the cache)',
      );
    }
    final ref = Ref(key);
    if (items.contains(ref)) return false;
    _replace(items, atStart ? [ref, ...items] : [...items, ref]);
    return true;
  }

  void _replace(List<Object?> previous, List<Object?> next) {
    final path = this.path!; // non-null: `_items` was
    final operation = _scope.operation;
    final touched = _cache.write(operation, path, next);
    _scope.onWrite(
      CacheWrite(operation, path, List<Object?>.of(previous), touched),
    );
  }
}

/// Where a [ListRule] inserts an entity that newly belongs to a list.
enum ListPosition { prepend, append }

/// Keeps cached lists of entities consistent with the entities themselves:
/// *"`launches(filter:)` contains a launch iff its status matches the
/// filter"*, *"`me.favorites` contains a launch iff `launch.favorite`"*.
///
/// A response, a subscription event or an optimistic setter only writes the
/// entity (`Launch:<id>.status`); the filtered lists that should gain or
/// lose it are separate cache entries nobody told. With a rule, every time
/// an entity of [typename] changes, the client re-evaluates [belongs] for
/// every cached list under a [field] node it has sent (it remembers each
/// alias's arguments — the "Success" segment you visited earlier included)
/// and adds or removes the reference. Lists that are not cached are left
/// alone; edits go through the normal write path, so dependants rebuild and
/// an edit made while a mutation's `optimistic` callback runs is rolled
/// back with it.
///
/// ```dart
/// SlingClient<Query>(
///   listRules: [
///     ListRule<Launch>(
///       field: 'launches', items: 'nodes',        // a connection
///       typename: 'Launch', ctor: Launch.new,
///       belongs: (args, launch) {
///         final status = (args['filter'] as Map?)?['status'];
///         return status == null || launch.status?.graphqlName == status;
///       },
///       position: ListPosition.prepend,
///     ),
///     ListRule<Launch>(
///       field: 'favorites', typename: 'Launch', ctor: Launch.new,
///       belongs: (_, launch) => launch.favorite == true,
///     ),
///   ],
/// )
/// ```
///
/// [args] are the field's arguments as sent (JSON values: input objects are
/// maps, enums their GraphQL name). [belongs] reads the entity through a
/// non-fetching accessor: a field it needs that is not cached reads `null`
/// — only decide on fields every reader of the list selects.
///
/// **Query responses only remove.** A response's lists are the server's
/// word, and with pagination each page is one list: the 20 launches of page
/// two "belong" to `launches(first: 20)` as much as page one's do, yet must
/// not be added to it. So entities written by a query response can leave
/// lists they no longer belong to, but never join one. Insertions happen for
/// what the app or the server *pushes*: mutation responses, subscription
/// events, optimistic setters and `CacheScope` writes. Membership is
/// set-like; order beyond [position] and `totalCount`-style siblings are
/// not maintained — refetch when you need the server's view.
class ListRule<E extends Accessor> {
  const ListRule({
    required this.field,
    this.items,
    required this.typename,
    required this.ctor,
    required this.belongs,
    this.position = ListPosition.append,
  });

  /// Field name (not alias) of the node holding the list, anywhere in a
  /// document: `launches`, `favorites`.
  final String field;

  /// For connection-shaped fields, the sub-field holding the list
  /// (`nodes`); `null` when [field] is the list itself.
  final String? items;

  /// `__typename` of the entities the list holds.
  final String typename;

  /// The generated constructor tear-off, `Launch.new`.
  final E Function(Recorder, Selection, List<Object>) ctor;

  /// Whether [entity] belongs in the list selected with [args].
  final bool Function(Map<String, Object?> args, E entity) belongs;

  final ListPosition position;

  /// [belongs] with the entity typed; called by the client on the accessor
  /// [ctor] built (so the cast always holds).
  bool evaluate(Map<String, Object?> args, Accessor entity) =>
      belongs(args, entity as E);
}

/// Sends one HTTP request and returns its response. The single extension
/// point for auth headers / token refresh, retries, timeouts and logging:
///
/// ```dart
/// SlingClient<Query>(
///   endpoint: uri,
///   rootFactory: Query.root,
///   transport: (request) async {
///     request.headers['authorization'] = 'Bearer ${await token()}';
///     return http.Response.fromStream(await http.Client().send(request))
///         .timeout(const Duration(seconds: 10));
///   },
/// );
/// ```
///
/// The request is a finalized POST with `content-type` and
/// [SlingClient.headers] already applied; queries and mutations alike go
/// through it. An `http.Request` can be sent once: copy it before retrying.
typedef Transport = Future<http.Response> Function(http.Request request);

/// Opens one subscription and returns its results as they arrive: each
/// element is one GraphQL execution result (`{data, errors?}`), the stream
/// ends when the server completes the subscription, and a transport failure
/// is a stream error. The subscription is closed by cancelling the
/// subscription to the stream.
///
/// The request is a finalized POST like a query's, with
/// `accept: text/event-stream` and [SlingClient.headers] applied. The default
/// ([sseSubscriptionTransport]) speaks GraphQL over Server-Sent Events in
/// "distinct connections" mode (one HTTP request per subscription, what
/// graphql-yoga, Apollo Server and Hot Chocolate serve on the regular
/// endpoint). Wrap it to add auth, or replace it to use another protocol
/// (`graphql-ws`) — the client only ever sees decoded results:
///
/// ```dart
/// SlingClient<Query>(
///   endpoint: uri,
///   rootFactory: Query.root,
///   subscriptionTransport: (request) {
///     request.headers['authorization'] = 'Bearer $token';
///     return sseSubscriptionTransport(request);
///   },
/// );
/// ```
typedef SubscriptionTransport = Stream<Map<String, Object?>> Function(
  http.Request request,
);

/// The default [SubscriptionTransport]: sends [request] with [client] (or a
/// fresh `http.Client` closed with the stream) and decodes the
/// `text/event-stream` body. `next` events (and unnamed `data:` lines) carry
/// one JSON execution result each; `complete` ends the stream.
Stream<Map<String, Object?>> sseSubscriptionTransport(
  http.Request request, {
  http.Client? client,
}) {
  final owned = client == null;
  final http.Client c = client ?? http.Client();
  late StreamController<Map<String, Object?>> controller;
  StreamSubscription<String>? lines;

  Future<void> close() async {
    await lines?.cancel();
    lines = null;
    if (owned) c.close();
  }

  controller = StreamController<Map<String, Object?>>(
    onListen: () async {
      final http.StreamedResponse response;
      try {
        response = await c.send(request);
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
          await controller.close();
        }
        await close();
        return;
      }
      if (controller.isClosed) {
        // Cancelled while connecting.
        await close();
        return;
      }
      if (response.statusCode >= 400) {
        controller.addError(
          SlingException(
            'HTTP ${response.statusCode}',
            statusCode: response.statusCode,
          ),
        );
        await controller.close();
        await close();
        return;
      }
      var event = '';
      final data = StringBuffer();
      var hasData = false;
      void dispatch() {
        final name = event;
        final payload = data.toString();
        final had = hasData;
        event = '';
        data.clear();
        hasData = false;
        if (name == 'complete') {
          lines?.cancel();
          lines = null;
          controller.close();
          return;
        }
        if (name != '' && name != 'next') return; // ping, unknown events
        if (!had || payload.trim().isEmpty) return;
        final json = jsonDecode(payload);
        if (json is Map<String, Object?>) controller.add(json);
      }

      lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (controller.isClosed) return;
              if (line.isEmpty) {
                dispatch();
              } else if (line.startsWith(':')) {
                // comment / keep-alive
              } else if (line.startsWith('event:')) {
                event = line.substring(6).trim();
              } else if (line.startsWith('data:')) {
                var value = line.substring(5);
                if (value.startsWith(' ')) value = value.substring(1);
                if (hasData) data.write('\n');
                data.write(value);
                hasData = true;
              }
            },
            onError: (Object e, StackTrace st) {
              if (!controller.isClosed) controller.addError(e, st);
            },
            onDone: () {
              dispatch();
              if (!controller.isClosed) controller.close();
              close();
            },
            cancelOnError: true,
          );
    },
    onCancel: close,
  );
  return controller.stream;
}

/// Recorder for one [SlingClient.subscribeWith] call. The body runs once to
/// record the selection (misses are expected and never fetch); the same
/// scope is then used to compute each event's value from the cache.
class SubscriptionScope implements Recorder {
  SubscriptionScope(this.client);

  final SlingClient<Accessor> client;

  @override
  String get operation => 'subscription';

  @override
  final Selection root = Selection.root('subscription');

  @override
  Cache get cache => client.cache;

  @override
  final Set<String> deps = {};

  @override
  void onMiss(Selection leaf) {}

  @override
  void onWrite(CacheWrite write) => client._onWrite(write);
}

/// A live subscription opened by [SlingClient.subscribeWith] (generated code:
/// `client.subscribe(...)`).
///
/// [stream] yields the value the body computes from the cache after each
/// event was written to it; partial GraphQL errors are stream errors that do
/// **not** end the stream (the fields that resolved are still written). A
/// server `complete` ends it. A transport failure (the connection dropped,
/// the server is down) is a stream error and, with a [retryAfter], the
/// connection is reopened after that delay — again and again until it
/// holds — while the stream stays open ([isReconnecting] meanwhile);
/// without one it ends the stream. [reconnect] retries at once. Cancel the
/// stream subscription — or call [cancel] — to close the connection;
/// nothing keeps it open otherwise.
class SlingSubscription<T> {
  SlingSubscription._(
    this._client,
    this._scope,
    this._compute,
    this.operation, {
    required this.retryAfter,
  }) {
    // Sync: values are added from the transport's own async events, so
    // listeners see them in the same turn as the cache write and the scopes'
    // notifications.
    _controller = StreamController<T>(
      onListen: _open,
      onCancel: _close,
      sync: true,
    );
  }

  final SlingClient<Accessor> _client;
  final SubscriptionScope _scope;

  /// Runs the body against the scope: the event's value, read from the cache.
  final T Function() _compute;

  /// The printed document and variables the subscription was opened with.
  final PrintedOperation operation;

  /// Delay before reopening the connection after a transport failure;
  /// `null` (the default) ends the stream instead. See
  /// [SlingClient.subscriptionRetryAfter].
  final Duration? retryAfter;

  late final StreamController<T> _controller;
  StreamSubscription<Map<String, Object?>>? _upstream;
  Timer? _retry;
  bool _closed = false;
  bool _listened = false;
  int _eventCount = 0;

  /// The connection dropped and a retry is pending (see [retryAfter]).
  bool get isReconnecting => _retry != null;

  /// Called when [isConnected] / [isReconnecting] change (the connection
  /// opened, dropped, or was reopened) — what a widget rebuilds on.
  void Function()? onStatusChanged;

  /// Each event's value, computed from the cache (see [SlingSubscription]).
  /// Single-subscription: the connection opens on `listen`.
  Stream<T> get stream => _controller.stream;

  /// True from `listen` until the stream ended or [cancel] was called
  /// (including while [isReconnecting]).
  bool get isActive => _listened && !_closed;

  /// Connection currently open (events can arrive).
  bool get isConnected => _upstream != null && !_closed;

  /// Events received so far.
  int get eventCount => _eventCount;

  /// Closes the connection and the stream.
  Future<void> cancel() => _close();

  /// Reopens the connection now if it dropped (a retry button); a no-op
  /// while connected or after [cancel].
  void reconnect() {
    if (_closed || !_listened || _upstream != null) return;
    _retry?.cancel();
    _retry = null;
    _open();
  }

  void _open() {
    if (_closed) return;
    _listened = true;
    _client._subscriptions.add(this);
    _client.onOperation?.call(operation);
    final request = _client._request(operation)
      ..headers['accept'] = 'text/event-stream';
    Stream<Map<String, Object?>> results;
    try {
      results = _client.subscriptionTransport(request);
    } catch (e, st) {
      // A transport failing synchronously (a mock rejecting the document)
      // is a stream error like an asynchronous one.
      results = Stream.error(e, st);
    }
    _upstream = results.listen(
      _onResult,
      onError: (Object e, StackTrace st) {
        if (!_controller.isClosed) _controller.addError(e, st);
        _dropped();
      },
      onDone: _close,
      cancelOnError: true,
    );
    onStatusChanged?.call();
  }

  /// The connection failed: schedule a reopen, or end the stream.
  void _dropped() {
    if (_closed) return;
    final upstream = _upstream;
    _upstream = null;
    upstream?.cancel();
    final after = retryAfter;
    if (after == null) {
      _close();
      return;
    }
    _retry = Timer(after, () {
      _retry = null;
      _open();
    });
    onStatusChanged?.call();
  }

  void _onResult(Map<String, Object?> json) {
    if (_closed) return;
    _eventCount++;
    final errors =
        (json['errors'] as List?)?.cast<Map<String, Object?>>() ?? const [];
    final data = json['data'] as Map<String, Object?>?;
    if (data == null) {
      _controller.addError(
        SlingException(
          errors.isEmpty
              ? 'Empty event'
              : errors.map((e) => e['message']).join('\n'),
          graphqlErrors: errors,
        ),
      );
      return;
    }
    for (final e in errors) {
      SlingClient._prune(data, e['path']);
    }
    final touched = _client.cache.writeResponse(
      'subscription',
      operation.toCacheKeys(data),
      at: _client._now(),
    );
    _client._notify(touched);
    if (errors.isNotEmpty) {
      _controller.addError(
        SlingException(
          errors.map((e) => e['message']).join('\n'),
          graphqlErrors: errors,
        ),
      );
    }
    _controller.add(_compute());
  }

  Future<void> _close() {
    if (_closed) return Future.value();
    _closed = true;
    _retry?.cancel();
    _retry = null;
    final up = _upstream;
    _upstream = null;
    _client._subscriptions.remove(this);
    // The payloads live on in the entities they referenced; the root fields
    // would only pin them.
    final touched = <String>{};
    for (final alias in _scope.root.childAliases) {
      touched.addAll(_client.cache.remove('subscription', [alias]));
    }
    _client._notify(touched);
    final done = _controller.isClosed ? null : _controller.close();
    return Future.wait([?up?.cancel(), ?done]);
  }
}

/// Batches selections into a single GraphQL document per microtask, fetches
/// them over HTTP, writes results into the cache and notifies scopes.
class SlingClient<Q extends Accessor> {
  SlingClient({
    required this.endpoint,
    RootFactory<Q>? rootFactory,
    this.schema,
    Cache? cache,
    http.Client? httpClient,
    Transport? transport,
    SubscriptionTransport? subscriptionTransport,
    this.headers = const {},
    this.onOperation,
    bool? warnOnWaterfall,
    void Function(WaterfallWarning warning)? onWaterfall,
    this.retryFailedAfter,
    this.fetchPolicy = FetchPolicy.cacheFirst,
    this.maxAge,
    Iterable<ListRule<Accessor>> listRules = const [],
    this.subscriptionRetryAfter,
    // Clock behind `retryFailedAfter` and `maxAge`; only worth overriding in
    // tests.
    DateTime Function() now = DateTime.now,
  }) : assert(
         rootFactory != null || schema != null,
         'SlingClient: pass schema: (the generated slingSchema) or '
         'rootFactory:.',
       ),
       assert(
         schema == null ||
             cache == null ||
             cache.normalization.keyField.isEmpty ||
             cache.normalization.keyField == schema.keyField,
         'SlingClient: the cache normalizes on '
         '"${cache.normalization.keyField}" but the code was generated '
         'with --key-field ${schema.keyField}. Build the cache with '
         'Cache(normalization: slingSchema.normalization) or regenerate.',
       ),
       rootFactory = rootFactory ?? schema!.query,
       cache =
           cache ??
           Cache(normalization: schema?.normalization ?? const Normalization()),
       _listRules = List.of(listRules),
       _http = httpClient ?? http.Client(),
       // ignore: prefer_initializing_formals
       _transport = transport,
       // ignore: prefer_initializing_formals
       _subscriptionTransport = subscriptionTransport,
       warnOnWaterfall = warnOnWaterfall ?? _assertsEnabled,
       onWaterfall = onWaterfall ?? _printWaterfall,
       // ignore: prefer_initializing_formals
       _now = now;

  final Uri endpoint;
  final RootFactory<Q> rootFactory;

  /// The generated `slingSchema`, when the client was built from it.
  /// Supplies [rootFactory], the default [cache]'s key field, and the
  /// mutation/subscription roots of a `SlingScope` that is not given its
  /// own `schema:`.
  final SlingSchema<Q, Accessor>? schema;

  final Cache cache;

  /// Static headers added to every request (before [transport] sees it).
  final Map<String, String> headers;
  final http.Client _http;
  final Transport? _transport;

  /// The [Transport] every request goes through; sends over [httpClient]
  /// (or a default `http.Client`) unless one was passed in.
  Transport get transport => _transport ?? _sendWithHttpClient;

  Future<http.Response> _sendWithHttpClient(http.Request request) async =>
      http.Response.fromStream(await _http.send(request));

  final SubscriptionTransport? _subscriptionTransport;

  /// The [SubscriptionTransport] every subscription goes through; GraphQL
  /// over SSE on [httpClient] ([sseSubscriptionTransport]) unless one was
  /// passed in.
  SubscriptionTransport get subscriptionTransport =>
      _subscriptionTransport ??
      (request) => sseSubscriptionTransport(request, client: _http);

  final Set<SlingSubscription<Object?>> _subscriptions = {};

  /// Subscriptions currently open (listened to and not yet closed).
  int get activeSubscriptions => _subscriptions.length;

  /// Opens a subscription. [body] runs once, now, to *record* the selection
  /// (every field read becomes part of the document; nothing is fetched),
  /// then once per event, after the event was written to the cache, to
  /// compute the value the returned stream yields:
  ///
  /// ```dart
  /// final sub = client.subscribeWith(
  ///   Subscription.root,
  ///   (s) => s.launchStatusChanged?..status..name,
  /// );
  /// sub.stream.listen((launch) => print('${launch?.name}: ${launch?.status}'));
  /// ```
  ///
  /// Every event is normalized into the shared cache like a query response
  /// and notifies the scopes reading the touched entities — the launch
  /// above updates in every list row and detail screen showing it,
  /// whether or not anyone listens to the stream's values. The connection
  /// opens on `listen` and closes when the stream subscription is cancelled
  /// (or [SlingSubscription.cancel]). Generated code exposes this as
  /// `client.subscribe(...)` with the schema's `Subscription` type bound;
  /// `SubscriptionBuilder` is the widget form.
  SlingSubscription<T> subscribeWith<S extends Accessor, T>(
    RootFactory<S> root,
    T Function(S subscription) body, {
    Duration? retryAfter,
  }) {
    final scope = SubscriptionScope(this);
    body(root(scope));
    final op = PrintedOperation.from(scope.root);
    return SlingSubscription<T>._(
      this,
      scope,
      () => body(root(scope)),
      op,
      retryAfter: retryAfter ?? subscriptionRetryAfter,
    );
  }

  /// Debug hook: called with every document sent to the endpoint.
  final void Function(PrintedOperation op)? onOperation;

  /// Whether scopes that need a second round trip right after their first
  /// response are reported through [onWaterfall]. Defaults to `true` in debug
  /// builds (asserts enabled), `false` otherwise.
  final bool warnOnWaterfall;

  /// Sink for [WaterfallWarning]s; prints them by default.
  final void Function(WaterfallWarning warning) onWaterfall;

  /// How long a failed document stays sticky (see [QueryScope.error]) before
  /// it is retried automatically on the next miss. `null` (the default)
  /// means sticky forever — only an explicit `refetch()` retries. Set this to
  /// give transient failures (a flaky connection, a cold server) a chance to
  /// heal themselves without the user pulling to refresh; the clock is
  /// checked lazily, on the next miss for that document, not on a timer.
  final Duration? retryFailedAfter;

  /// Default [FetchPolicy] for scopes that do not set their own
  /// (`QueryBuilder(fetchPolicy:)`, [resolve], [createScope]).
  final FetchPolicy fetchPolicy;

  /// Default stale-while-revalidate window for every scope (see
  /// [QueryScope.maxAge]); `null` means cached data never expires.
  final Duration? maxAge;

  /// Clock used by [retryFailedAfter] and [maxAge]; overridable for tests.
  final DateTime Function() _now;

  /// Default for [subscribeWith]'s `retryAfter`: how long a subscription
  /// waits before reopening a dropped connection (server restarted, network
  /// blip). `null` (the default) means a dropped connection ends the
  /// stream; `SubscriptionBuilder` then shows `isActive == false` until it
  /// is remounted. A few seconds is right for most apps; the retry repeats
  /// until the connection holds.
  final Duration? subscriptionRetryAfter;

  final List<ListRule<Accessor>> _listRules;

  /// Rules keeping cached lists in sync with their entities (see
  /// [ListRule]). Add more with [addListRule].
  List<ListRule<Accessor>> get listRules => List.unmodifiable(_listRules);

  void addListRule(ListRule<Accessor> rule) => _listRules.add(rule);

  /// Every list node sent so far that a rule cares about, by field name:
  /// alias path of the list → the node's arguments. Filled from each
  /// document as it goes out, so lists cached from screens no longer on
  /// screen are still reachable.
  final Map<String, Map<String, (List<String>, Map<String, Object?>)>>
  _knownLists = {};

  void _rememberLists(Selection root) {
    if (_listRules.isEmpty) return;
    void walk(Selection node) {
      for (final c in node.children) {
        for (final rule in _listRules) {
          if (c.isFragment || rule.field != c.field) continue;
          final path = c.aliasPath;
          if (rule.items != null) path.add(rule.items!);
          _knownLists.putIfAbsent(rule.field, () => {})[path.join('/')] = (
            path,
            {for (final e in c.args.entries) e.key: e.value.value},
          );
        }
        walk(c);
      }
    }

    walk(root);
  }

  bool _applyingRules = false;

  /// Re-evaluates the list rules for every entity among [touched]
  /// (`Launch:launch-1.status` → `Launch:launch-1`). Returns the keys the
  /// resulting list edits touched.
  Set<String> _applyListRules(
    String operation,
    Set<String> touched, {
    required bool insert,
  }) {
    if (_listRules.isEmpty || _applyingRules) return const {};
    _applyingRules = true;
    try {
      final entities = <String>{};
      for (final key in touched) {
        final dot = key.lastIndexOf('.');
        if (dot > 0) entities.add(key.substring(0, dot));
      }
      final out = <String>{};
      final scope = CacheScope<Q>(this);
      for (final rule in _listRules) {
        final lists = _knownLists[rule.field];
        if (lists == null) continue;
        for (final key in entities) {
          if (!key.startsWith('${rule.typename}:')) continue;
          final entity = cache.entity(key);
          if (entity == null) continue;
          final id = entity[cache.normalization.keyField];
          if (id == null) continue;
          final accessor = rule.ctor(scope, scope.root, [Ref(key)]);
          final ref = Ref(key);
          for (final (path, args) in lists.values) {
            final value = cache.read(operation, path);
            if (value is! List) continue;
            final items = value.cast<Object?>();
            final has = items.contains(ref);
            final wants = rule.evaluate(args, accessor);
            if (has == wants || (wants && !insert)) continue;
            final next = !wants
                ? [
                    for (final e in items)
                      if (e != ref) e,
                  ]
                : rule.position == ListPosition.prepend
                ? [ref, ...items]
                : [...items, ref];
            final written = cache.write(operation, path, next);
            _journal?.add(
              CacheWrite(operation, path, List<Object?>.of(items), written),
            );
            out.addAll(written);
          }
        }
      }
      return out;
    } finally {
      _applyingRules = false;
    }
  }

  /// True when any of [deps] was last fetched longer than [maxAge] ago, or
  /// never fetched from the server.
  bool _isStale(Set<String> deps, Duration maxAge) {
    if (deps.isEmpty) return false;
    final now = _now();
    for (final dep in deps) {
      final at = cache.fetchedAt(dep);
      if (at == null || now.difference(at) > maxAge) return true;
    }
    return false;
  }

  // `print`, not `debugPrint`: client.dart stays free of Flutter imports.
  // ignore: avoid_print
  static void _printWaterfall(WaterfallWarning warning) => print(warning);

  final Set<QueryScope<Q>> _scopes = {};
  final Set<RowScope> _rows = {};

  Selection _pending = Selection.root('query');
  Selection? _inflight;
  Set<QueryScope<Q>> _pendingScopes = {};
  bool _flushScheduled = false;

  /// Query document that last failed; suppresses automatic retry loops
  /// (forever, unless [retryFailedAfter] is set — see [_failedAt]).
  String? _failedDocument;

  /// When [_failedDocument] failed; used to expire it once [retryFailedAfter]
  /// has elapsed.
  DateTime? _failedAt;

  QueryScope<Q> createScope({
    required void Function() onChanged,
    FlushScheduler scheduler = microtaskScheduler,
    String? debugLabel,
    FetchPolicy? fetchPolicy,
    Duration? maxAge,
  }) {
    final scope = QueryScope<Q>(
      this,
      onChanged: onChanged,
      scheduler: scheduler,
      debugLabel: debugLabel,
      fetchPolicy: fetchPolicy,
      maxAge: maxAge,
    );
    _scopes.add(scope);
    return scope;
  }

  /// Typed, non-fetching access to the cache (see [CacheScope]): read or
  /// write entities and root fields outside a widget build, and edit list
  /// membership after a mutation. Each access returns a fresh scope.
  ///
  /// ```dart
  /// final cache = client.cacheScope;
  /// cache.launch('launch-181')?.favorite = true; // generated per keyed type
  /// final name = cache.query.me?.name; // root fields, from the cache only
  /// cache.list((q) => q.me?.favorites).prepend(cache.launch('launch-181')!);
  /// ```
  CacheScope<Q> get cacheScope => CacheScope<Q>(this);

  int _mutationsInFlight = 0;
  Completer<void>? _idle;

  /// True when the client has nothing in progress: no flush scheduled, no
  /// query request in flight, no mutation awaiting its response. Scopes can
  /// still be about to *rebuild* (their `onChanged` ran, the frame has not)
  /// — pump a frame and check again. Test helpers (`pumpUntilSettled` in
  /// `sling_gql_test`) loop on exactly that.
  bool get isIdle =>
      !_flushScheduled && _inflight == null && _mutationsInFlight == 0;

  /// Completes once [isIdle] is true (immediately if it already is).
  Future<void> get whenIdle =>
      isIdle ? Future.value() : (_idle ??= Completer<void>()).future;

  void _checkIdle() {
    if (!isIdle) return;
    _idle?.complete();
    _idle = null;
  }

  /// Imperative one-shot: runs [body] against a throwaway scope, fetches what
  /// is missing, and resolves once the cache is populated. Useful for
  /// `prepare`-style prefetching or tests. [fetchPolicy] / [maxAge] default
  /// to the client's: `resolve(body, fetchPolicy: FetchPolicy.networkOnly)`
  /// is "fetch this now, whatever the cache has".
  Future<T> resolve<T>(
    T Function(Q root) body, {
    FetchPolicy? fetchPolicy,
    Duration? maxAge,
  }) async {
    final scope = createScope(
      onChanged: () {},
      fetchPolicy: fetchPolicy,
      maxAge: maxAge,
    );
    try {
      scope.run(body);
      await scope.whenSettled;
      if (scope.error != null) throw scope.error!;
      final result = scope.run(body);
      return result;
    } finally {
      scope.dispose();
    }
  }

  /// Runs a mutation. [body] is executed twice: once to *record* the
  /// selection (every field read becomes part of the document, nothing is
  /// fetched), and once the response has been written to the cache, to
  /// compute the return value from it.
  ///
  /// ```dart
  /// final favorite = await client.mutateWith(
  ///   Mutation.root,
  ///   (m) => m.toggleFavorite(launchId: id)?.favorite,
  ///   optimistic: () => launch.favorite = !launch.favorite!,
  /// );
  /// ```
  ///
  /// The response is normalized like any query response, so every widget
  /// showing the returned entities rebuilds. [optimistic] runs synchronously
  /// before the request; the writes it makes through generated setters are
  /// journaled and undone if the mutation fails. Generated code exposes this
  /// as `client.mutate(...)` with the schema's `Mutation` type bound.
  ///
  /// Any GraphQL error fails the call, partial ones included (`data` *and*
  /// `errors`): the future rejects with a [SlingException] carrying
  /// [SlingException.graphqlErrors], [body] is not run again and
  /// [refetchQueries] are not refetched. The cache still takes what the
  /// server resolved: the optimistic writes are undone first, then the
  /// resolved fields are written over them (the server's values win), while
  /// errored paths are pruned and keep their pre-mutation value. Widgets
  /// showing the resolved entities rebuild as on success. An HTTP or
  /// transport error, or a response without `data`, writes nothing.
  ///
  /// [refetchQueries] names root **query** field names (`'me'`, `'launches'`
  /// — not aliases, so arguments and aliasing do not matter) to refetch once
  /// the mutation has succeeded and written its response: every live
  /// [QueryScope] whose last run selected a child with that field name is
  /// [QueryScope.refetch]ed. This is the simple alternative to a write policy
  /// (see `guides/mutations` § refetchQueries) for the common "a list needs a
  /// new/removed row" case. Refetches are fire-and-forget — the returned
  /// future completes once the mutation itself lands, not once the refetches
  /// do; their errors surface on the affected scopes' `state.error` as usual.
  Future<T> mutateWith<M extends Accessor, T>(
    RootFactory<M> root,
    T Function(M mutation) body, {
    void Function()? optimistic,
    Iterable<String>? refetchQueries,
  }) async {
    final journal = <CacheWrite>[];
    if (optimistic != null) {
      _journal = journal;
      try {
        optimistic();
      } catch (_) {
        _journal = null;
        // Nothing is sent: undo the writes made before the throw.
        _notify(_rollback(journal));
        rethrow;
      } finally {
        _journal = null;
      }
    }

    final scope = MutationScope(this);
    body(root(scope));
    final op = PrintedOperation.from(scope.root);
    onOperation?.call(op);

    Set<String> touched;
    SlingException? error;
    _mutationsInFlight++;
    try {
      final Map<String, Object?> data;
      (data, error) = await _receive(op);
      // Partial failure: undo the optimistic writes *before* writing the
      // fields that resolved, so the server's values win over the rollback.
      final undone = error == null ? const <String>{} : _rollback(journal);
      touched = cache.writeResponse('mutation', data, at: _now());
      touched = touched.union(undone);
    } catch (e) {
      _notify(_rollback(journal));
      rethrow;
    } finally {
      _mutationsInFlight--;
      _checkIdle();
    }
    if (error != null) {
      _removeMutationRoot(scope.root);
      _notify(touched);
      throw error;
    }
    _notify(touched);

    if (refetchQueries != null && refetchQueries.isNotEmpty) {
      final names = refetchQueries.toSet();
      for (final s in _scopes.toList()) {
        if (s.root.children.any((c) => names.contains(c.field))) {
          s.refetch(); // fire-and-forget; errors surface on the scope as usual
        }
      }
    }

    final result = body(root(scope));
    _removeMutationRoot(scope.root);
    return result;
  }

  /// The payload lives on in the entities it referenced; the root fields
  /// would only pin them in memory.
  void _removeMutationRoot(Selection root) {
    for (final alias in root.childAliases) {
      cache.remove('mutation', [alias]);
    }
  }

  List<CacheWrite>? _journal;

  void _onWrite(CacheWrite write) {
    _journal?.add(write);
    _notify(write.touched);
  }

  Set<String> _rollback(List<CacheWrite> journal) {
    final touched = <String>{};
    for (final write in journal.reversed) {
      touched.addAll(write.undo(cache));
    }
    journal.clear();
    return touched;
  }

  /// Adds [leaf] to the next request. Returns `false` when an in-flight
  /// request already covers it (no new request will be caused).
  bool _enqueueLeaf(Selection leaf) {
    if (_inflight?.covers(_singleton(leaf)) ?? false) return false;
    _pending.ensurePath(leaf);
    return true;
  }

  void _enqueue(Selection tree, {bool force = false}) {
    if (force) {
      _failedDocument = null;
      _failedAt = null;
    }
    _pending.mergeFrom(tree);
  }

  static Selection _singleton(Selection leaf) {
    final root = Selection.root('query');
    root.ensurePath(leaf);
    return root;
  }

  void _schedule(QueryScope<Q> scope) {
    _pendingScopes.add(scope);
    if (_flushScheduled) return; // first scheduler of the batch wins
    _flushScheduled = true;
    scope.scheduler(_doFlush);
  }

  Future<void> _doFlush() async {
    final tree = _pending;
    final scopes = _pendingScopes;
    _pending = Selection.root('query');
    _pendingScopes = {};
    _flushScheduled = false;

    if (tree.isLeaf) {
      if (_inflight != null) {
        // Everything was covered by an in-flight request; those scopes will
        // be notified when it lands.
        _inflightScopes.addAll(scopes);
      } else {
        // Nothing to fetch (e.g. refetch on a scope that never ran).
        for (final s in scopes) {
          s._settle(null);
        }
        _checkIdle();
      }
      return;
    }

    final op = PrintedOperation.from(tree);
    final failedAt = _failedAt;
    final expired =
        retryFailedAfter != null &&
        failedAt != null &&
        _now().difference(failedAt) >= retryFailedAfter!;
    if (op.document == _failedDocument && !expired) {
      // Same document already failed: surface the error without a round trip.
      for (final s in scopes) {
        s._waterfallLeaves.clear();
        s._settle(_lastError);
        s._changedByClient();
      }
      _checkIdle();
      return;
    }
    if (expired) {
      // Cooldown elapsed since the last failure: give it a fresh try.
      _failedDocument = null;
      _failedAt = null;
    }

    _inflight = tree;
    _rememberLists(tree);
    _inflightScopes.addAll(scopes);
    for (final s in scopes) {
      final warning = s._requestSent();
      if (warning != null && warnOnWaterfall) onWaterfall(warning);
    }
    onOperation?.call(op);

    Object? error;
    Set<String> touched = {};
    try {
      (touched, error) = await _send('query', op);
      if (error != null) {
        _failedDocument = op.document;
        _failedAt = _now();
        _lastError = error;
      } else {
        _failedDocument = null;
        _failedAt = null;
      }
    } catch (e) {
      error = e;
      _failedDocument = op.document;
      _failedAt = _now();
      _lastError = e;
    }

    _inflight = null;
    final waiters = _inflightScopes;
    _inflightScopes = {};
    for (final s in waiters) {
      s._settle(error);
    }
    if (error != null) {
      for (final s in waiters) {
        s._changedByClient();
      }
    } else {
      _notify(touched, always: waiters, insert: false);
    }
    _checkIdle();
  }

  Set<QueryScope<Q>> _inflightScopes = {};
  Object? _lastError;

  /// Rebuilds every scope that read one of the [touched] dependency keys
  /// (`ROOT_QUERY.launches_x`, `Launch:launch-181.name`, …), plus [always].
  ///
  /// Iterates [touched] (a handful of keys per write) and probes each scope's
  /// deps, rather than walking every scope's deps (~1k keys for a list screen).
  /// [insert] is false for query responses: list rules then only remove
  /// (see [ListRule]).
  void _notify(
    Set<String> touched, {
    Set<QueryScope<Q>> always = const {},
    bool insert = true,
  }) {
    if (_listRules.isNotEmpty) {
      final edits = _applyListRules('query', touched, insert: insert);
      if (edits.isNotEmpty) touched = touched.union(edits);
    }
    for (final scope in _scopes.toList()) {
      if (always.contains(scope) || touched.any(scope.deps.contains)) {
        scope._changedByClient();
      }
    }
    for (final row in _rows.toList()) {
      if (touched.any(row._deps.contains)) row.onChanged();
    }
  }

  /// POSTs [op] and writes `data` under [operation]'s root; see [_receive]
  /// for partial failures.
  Future<(Set<String>, SlingException?)> _send(
    String operation,
    PrintedOperation op,
  ) async {
    final (data, error) = await _receive(op);
    return (cache.writeResponse(operation, data, at: _now()), error);
  }

  /// POSTs [op] and returns `data` keyed by cache aliases. On partial failure
  /// the fields that resolved are kept, the `null`s the server put at errored
  /// paths are pruned (they are not real nulls), and the error is returned
  /// alongside.
  Future<(Map<String, Object?>, SlingException?)> _receive(
    PrintedOperation op,
  ) async {
    final (data, errors) = await _post(op);
    SlingException? error;
    if (errors.isNotEmpty) {
      for (final e in errors) {
        _prune(data, e['path']);
      }
      error = SlingException(
        errors.map((e) => e['message']).join('\n'),
        graphqlErrors: errors,
      );
    }
    return (op.toCacheKeys(data), error);
  }

  /// Removes the value at a GraphQL error `path` (aliases and list indices)
  /// from a response so it is not written to the cache.
  static void _prune(Map<String, Object?> data, Object? path) {
    if (path is! List || path.isEmpty) return;
    Object? node = data;
    for (var i = 0; i < path.length - 1; i++) {
      final key = path[i];
      node = switch (node) {
        Map() => node[key],
        List() when key is int && key < node.length => node[key],
        _ => null,
      };
      if (node == null) return;
    }
    final last = path.last;
    if (node is Map) node.remove(last);
    if (node is List && last is int && last < node.length) node[last] = null;
  }

  http.Request _request(PrintedOperation op) => http.Request('POST', endpoint)
    ..headers.addAll({'content-type': 'application/json', ...headers})
    ..body = jsonEncode({'query': op.document, 'variables': op.variables});

  Future<(Map<String, Object?>, List<Map<String, Object?>>)> _post(
    PrintedOperation op,
  ) async {
    final response = await transport(_request(op));
    if (response.statusCode >= 400) {
      throw SlingException(
        'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    final json = jsonDecode(response.body) as Map<String, Object?>;
    final errors =
        (json['errors'] as List?)?.cast<Map<String, Object?>>() ?? const [];
    final data = json['data'] as Map<String, Object?>?;
    if (data == null) {
      throw SlingException(
        errors.isEmpty ? 'Empty response' : errors.first['message'].toString(),
        graphqlErrors: errors,
      );
    }
    return (data, errors);
  }

  /// Closes every open subscription and the HTTP client.
  void dispose() {
    for (final s in _subscriptions.toList()) {
      s.cancel();
    }
    _http.close();
  }
}
