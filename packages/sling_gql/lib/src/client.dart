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

/// The generator's single per-schema convenience: bundles the query and
/// mutation root factories so app code never has to name `Mutation.root` by
/// hand — `SlingScope(schema: slingSchema, ...)` resolves both `QueryBuilder`
/// (via the client's `rootFactory`) and `MutationBuilder` (via
/// `SlingScope.mutationRootOf`) from it.
class SlingSchema<Q extends Accessor, M extends Accessor> {
  const SlingSchema({required this.query, required this.mutation});

  final RootFactory<Q> query;
  final RootFactory<M> mutation;
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

/// A scope in which selections are recorded — one per widget build.
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
  }) : debugLabel = debugLabel ?? 'QueryScope#${++_lastId}';

  static int _lastId = 0;

  final SlingClient<Q> client;

  /// Invoked when data relevant to this scope changed and it should re-run.
  final void Function() onChanged;

  /// How this scope asks the client to flush (see [FlushScheduler]).
  final FlushScheduler scheduler;

  /// Names this scope in [WaterfallWarning]s.
  final String debugLabel;

  @override
  String get operation => 'query';

  @override
  Cache get cache => client.cache;

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
  Object? _error;

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
    final result = body(client.rootFactory(this));
    if (!_hadMiss) {
      // Fully served from cache: any previous error is moot.
      _error = null;
      _errorAt = null;
    }
    return result;
  }

  /// Re-fetches everything this scope selected during its last run.
  Future<void> refetch() {
    _error = null;
    _errorAt = null;
    _awaiting = true;
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
    if (_error != null) {
      final retryAfter = client.retryFailedAfter;
      final at = _errorAt;
      final expired =
          retryAfter != null &&
          at != null &&
          client._now().difference(at) >= retryAfter;
      if (!expired) return;
      _error = null;
      _errorAt = null;
    }
    if (client._enqueueLeaf(leaf) && _missesAreWaterfall) {
      _waterfallLeaves.add(leaf);
    }
    _awaiting = true;
    client._schedule(this);
  }

  @override
  void onWrite(CacheWrite write) => client._onWrite(write);

  void dispose() => client._scopes.remove(this);

  void _settle(Object? error) {
    _awaiting = false;
    _error = error;
    _errorAt = error != null ? client._now() : null;
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
      parts.insert(0, node.args.isEmpty ? node.field : '${node.field}(…)');
      node = node.parent;
    }
    return parts.join('.');
  }
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

/// Batches selections into a single GraphQL document per microtask, fetches
/// them over HTTP, writes results into the cache and notifies scopes.
class SlingClient<Q extends Accessor> {
  SlingClient({
    required this.endpoint,
    required this.rootFactory,
    Cache? cache,
    http.Client? httpClient,
    Transport? transport,
    this.headers = const {},
    this.onOperation,
    bool? warnOnWaterfall,
    void Function(WaterfallWarning warning)? onWaterfall,
    this.retryFailedAfter,
    // Clock behind `retryFailedAfter`; only worth overriding in tests.
    DateTime Function() now = DateTime.now,
  }) : cache = cache ?? Cache(),
       _http = httpClient ?? http.Client(),
       // ignore: prefer_initializing_formals
       _transport = transport,
       warnOnWaterfall = warnOnWaterfall ?? _assertsEnabled,
       onWaterfall = onWaterfall ?? _printWaterfall,
       // ignore: prefer_initializing_formals
       _now = now;

  final Uri endpoint;
  final RootFactory<Q> rootFactory;
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

  /// Clock used by [retryFailedAfter]; overridable for tests.
  final DateTime Function() _now;

  // `print`, not `debugPrint`: client.dart stays free of Flutter imports.
  // ignore: avoid_print
  static void _printWaterfall(WaterfallWarning warning) => print(warning);

  final Set<QueryScope<Q>> _scopes = {};

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
  }) {
    final scope = QueryScope<Q>(
      this,
      onChanged: onChanged,
      scheduler: scheduler,
      debugLabel: debugLabel,
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
  /// `prepare`-style prefetching or tests.
  Future<T> resolve<T>(T Function(Q root) body) async {
    final scope = createScope(onChanged: () {});
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
      (touched, error) = await _send('mutation', scope.root, op);
    } catch (e) {
      _notify(_rollback(journal));
      rethrow;
    } finally {
      _mutationsInFlight--;
      _checkIdle();
    }
    if (error != null) {
      _notify(touched.union(_rollback(journal)));
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
    // The payload lives on in the entities it referenced; the root fields
    // would only pin them in memory.
    for (final alias in scope.root.childAliases) {
      cache.remove('mutation', [alias]);
    }
    return result;
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
    _inflightScopes.addAll(scopes);
    for (final s in scopes) {
      final warning = s._requestSent();
      if (warning != null && warnOnWaterfall) onWaterfall(warning);
    }
    onOperation?.call(op);

    Object? error;
    Set<String> touched = {};
    try {
      (touched, error) = await _send('query', tree, op);
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
      _notify(touched, always: waiters);
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
  void _notify(Set<String> touched, {Set<QueryScope<Q>> always = const {}}) {
    for (final scope in _scopes.toList()) {
      if (always.contains(scope) || touched.any(scope.deps.contains)) {
        scope._changedByClient();
      }
    }
  }

  /// POSTs [op] and writes `data` under [operation]'s root. On partial
  /// failure the fields that resolved are kept, the `null`s the server put at
  /// errored paths are pruned (they are not real nulls), and the error is
  /// returned alongside the touched keys.
  Future<(Set<String>, SlingException?)> _send(
    String operation,
    Selection tree,
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
    return (cache.writeResponse(operation, tree, data), error);
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

  Future<(Map<String, Object?>, List<Map<String, Object?>>)> _post(
    PrintedOperation op,
  ) async {
    final request = http.Request('POST', endpoint)
      ..headers.addAll({'content-type': 'application/json', ...headers})
      ..body = jsonEncode({'query': op.document, 'variables': op.variables});
    final response = await transport(request);
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

  void dispose() => _http.close();
}
