import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'accessor.dart';
import 'auth.dart';
import 'cache/cache.dart';
import 'errors.dart';
import 'mutation_queue.dart';
import 'retry.dart';
import 'selection.dart';

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
/// [hash] identifies the generated code, for stores that outlive it.
class SlingSchema<Q extends Accessor, M extends Accessor> {
  const SlingSchema({
    required this.query,
    this.mutation,
    this.subscription,
    this.keyField = 'id',
    this.hash,
    this.fields,
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

  /// Fingerprint of the generated code this schema belongs to (the
  /// generator emits a 64-bit FNV-1a of its output, which covers the
  /// introspection it read, `--key-field`, `--scalar` mappings and the
  /// generator's own version); `null` for a hand-written schema.
  ///
  /// The runtime never reads it. A persisted cache stores it and, when the
  /// app starts with another hash, migrates its copy along [fields] (or
  /// drops it without them): cache aliases, keyed types and lookups may
  /// have changed with the code.
  final String? hash;

  /// The fields of the schema's object, interface and union types, by
  /// GraphQL type name, each with its signature: `'(id: ID!) Launch'`,
  /// `'[String!]!'` (arguments with their defaults, then the type). The
  /// query root is listed as `ROOT_QUERY`, its cache key. The generator
  /// emits it; `null` for a hand-written schema.
  ///
  /// The runtime never reads it. A persisted cache stores it next to [hash]
  /// and, when the hash changes, keeps the cached fields whose signature did
  /// not change instead of dropping everything.
  final Map<String, Map<String, String>>? fields;
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

/// One operation the client sent — a query batch, a mutation, or one
/// subscription connection — as dev tooling sees it: who asked for it
/// ([scopes]), what it selected ([rootFields], [fieldCount]) and how it went
/// ([duration], [bytes], [error]). Emitted on [SlingClient.requests] and
/// printed by [SlingClient.logRequests]; `SlingRequestOverlay` lists them.
///
/// Mutable until [isDone]: the same object is emitted again each time it
/// changes.
class SlingRequest {
  SlingRequest._({
    required this.id,
    required this.kind,
    required this.operation,
    required this.scopes,
    required this.rootFields,
    required this.fieldCount,
    required this.startedAt,
  });

  /// 1 for the first operation this client sent.
  final int id;

  /// `query`, `mutation` or `subscription`.
  final String kind;

  /// The printed document and variables.
  final PrintedOperation operation;

  /// Labels of the scopes whose selections are in the document, one per
  /// scope (repeated labels are distinct widgets of the same type): a
  /// `QueryBuilder`'s `debugLabel`, key or enclosing widget
  /// (`LaunchesScreen`), a `MutationBuilder`/`SubscriptionBuilder`'s
  /// enclosing widget, or the `debugLabel:` passed to `mutateWith` /
  /// `subscribeWith`. Empty when nobody named it (`resolve()`, a bare
  /// `client.mutate`).
  final List<String> scopes;

  /// Root field names (not aliases), in document order: `launches, company`.
  final List<String> rootFields;

  /// Fields the scopes read (leaves of the selection), without the
  /// `__typename`/key fields the printer adds.
  final int fieldCount;

  final DateTime startedAt;

  final Stopwatch _stopwatch = Stopwatch()..start();
  final Completer<SlingRequest> _done = Completer<SlingRequest>();
  void Function(SlingRequest)? _onChange;

  /// Time until the response was processed (a subscription: how long the
  /// connection stayed open); the time so far while pending.
  Duration get duration => _stopwatch.elapsed;

  /// Size of the response body; `null` until it arrived (and for
  /// subscriptions).
  int? get bytes => _bytes;
  int? _bytes;

  /// HTTP status of the response, when one arrived.
  int? get statusCode => _statusCode;
  int? _statusCode;

  /// Events received (subscriptions only).
  int get events => _events;
  int _events = 0;

  /// Why it failed: an HTTP or transport error, or the GraphQL `errors` (a
  /// [SlingGraphQLException]), partial ones included — whatever the
  /// `ErrorPolicy` of the scopes did with them.
  SlingException? get error => _error;
  SlingException? _error;

  /// Times it was sent: retries (`RetryPolicy`) and the replay after an
  /// auth refresh count; `1` for a request that went out once.
  int get attempts => _attempts;
  int _attempts = 0;

  bool get isDone => _done.isCompleted;

  /// Completes (never with an error) once the request is done.
  Future<SlingRequest> get done => _done.future;

  /// [scopes] with repeats folded: `LaunchesScreen, LaunchTile ×12`.
  String get scopeSummary {
    final counts = <String, int>{};
    for (final s in scopes) {
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return [
      for (final MapEntry(:key, :value) in counts.entries)
        value == 1 ? key : '$key ×$value',
    ].join(', ');
  }

  /// One line: `#3 query launches, company · 42 ms · 1.2 KB · 18 fields ←
  /// LaunchesScreen, LaunchTile ×12`, with `✗` and the error on failure.
  String get logLine {
    final ms = '${duration.inMilliseconds} ms';
    final bytes = _bytes;
    final parts = [
      '#$id $kind ${rootFields.join(', ')}',
      if (kind == 'subscription')
        '${_events == 1 ? '1 event' : '$_events events'}'
            '${isDone ? ' in $ms' : ', open'}'
      else if (!isDone)
        'pending'
      else
        ms,
      if (bytes != null) _formatBytes(bytes),
      fieldCount == 1 ? '1 field' : '$fieldCount fields',
      if (_attempts > 1) '$_attempts attempts',
    ];
    final error = _error;
    final problem = error == null ? '' : ' ✗ ${error.message}';
    final by = scopes.isEmpty ? '' : ' ← $scopeSummary';
    return '${parts.join(' · ')}$by$problem';
  }

  static String _formatBytes(int bytes) =>
      bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(1)} KB';

  void _sent() => _attempts++;

  void _response(int statusCode, int bytes) {
    _statusCode = statusCode;
    _bytes = bytes;
  }

  void _event() {
    _events++;
    _onChange?.call(this);
  }

  void _finish([SlingException? error]) {
    if (isDone) return;
    _stopwatch.stop();
    _error = error;
    _done.complete(this);
    _onChange?.call(this);
  }

  @override
  String toString() => 'sling_gql $logLine';
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
    ErrorPolicy? errorPolicy,
    Duration? timeout,
  }) : debugLabel = debugLabel ?? 'QueryScope#${++_lastId}',
       fetchPolicy = fetchPolicy ?? client.fetchPolicy,
       maxAge = maxAge ?? client.maxAge,
       errorPolicy = errorPolicy ?? client.errorPolicy,
       timeout = timeout ?? client.timeout,
       _bypassCache =
           (fetchPolicy ?? client.fetchPolicy) == FetchPolicy.networkOnly;

  static int _lastId = 0;

  final SlingClient<Q> client;

  /// What this scope does with GraphQL errors that come with data (see
  /// [ErrorPolicy]). Defaults to [SlingClient.errorPolicy].
  final ErrorPolicy errorPolicy;

  /// How long a request carrying this scope's selections may take before
  /// it is aborted with a [SlingTimeoutException] (per attempt, see
  /// [RetryPolicy]). Defaults to [SlingClient.timeout]; `null` waits
  /// forever. A batch shared with other scopes waits for the longest of
  /// their timeouts (none, if one of them has none).
  final Duration? timeout;

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

  @override
  Map<Type, TypePolicy> get typePolicies => client.typePolicies;

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
  SlingException? _error;

  /// The pending fetch was not caused by misses (revalidation, cache-and-
  /// network, [refetch]): the scope renders cached data meanwhile, and an
  /// error from it must stay visible even though nothing is missing.
  bool _backgroundFetch = false;
  bool _errorIsBackground = false;

  /// The error is a partial response's, kept under [ErrorPolicy.all]: the
  /// data is complete, the error stays until [refetch].
  bool _errorKeptWithData = false;

  /// The error is a partial response's, dropped under [ErrorPolicy.ignore]:
  /// [error] does not report it, but it still blocks re-fetching fields
  /// that stayed missing (pruned for another scope of the batch).
  bool _errorHidden = false;

  /// The pending fetch wants this scope's whole selection (revalidation,
  /// cache-and-network, [refetch]); merged at flush by [_enqueueWhole], so
  /// what children and rows read after [run] in the same frame is in it.
  bool _fetchWhole = false;

  /// [_root] plus the subtrees this scope's rows read through. A row that
  /// did not re-run since this scope's last [run] recorded its fields in the
  /// previous tree; without them a revalidation never refreshes the row's
  /// fields, they stay stale, and every run revalidates again (a request
  /// loop on a restored cache under `maxAge`).
  ///
  /// Paged policy entries are sent as their first page (see
  /// [FieldPolicy.pageArgs]): a refresh starts a merged list over.
  void _enqueueWhole() {
    client._pending.mergeFrom(_root, firstPages: true);
    for (final r in _rows) {
      for (final node in r._bound) {
        client._pending
            .ensurePath(node, firstPages: true)
            .mergeFrom(node, firstPages: true);
      }
    }
  }

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
  ///
  /// With [ErrorPolicy.ignore], the GraphQL errors of a partial response
  /// are not reported here.
  SlingException? get error => _errorHidden ? null : _error;

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
    if (!_hadMiss && !_stale && !_errorIsBackground && !_errorKeptWithData) {
      // Fully served from fresh cache: an error from a miss-driven fetch is
      // moot (a background one stays until `refetch`, see `error`, and so
      // does a partial response's under `ErrorPolicy.all`).
      _clearError();
    }
    final wantsNetwork =
        _stale || (firstRun && fetchPolicy == FetchPolicy.cacheAndNetwork);
    // A miss already schedules a fetch of the missing leaves; a stale or
    // cache-and-network run adds the *whole* selection to it. Sticky errors
    // block it like they block misses, so a failing server cannot loop.
    var backgroundStarted = false;
    if (wantsNetwork && !_awaiting && !_errorBlocksFetch()) {
      _fetchWhole = true;
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
    _clearError();
    return false;
  }

  void _clearError() {
    _error = null;
    _errorAt = null;
    _errorIsBackground = false;
    _errorKeptWithData = false;
    _errorHidden = false;
  }

  /// Re-fetches everything this scope selected during its last run.
  Future<void> refetch() {
    _clearError();
    _awaiting = true;
    _backgroundFetch = !_hadMiss;
    _fetchWhole = true;
    client._clearFailure();
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

  /// Detaches the scope: it is never notified again, and a request only it
  /// (or other disposed scopes) waited for is aborted and its response
  /// dropped.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    client._scopes.remove(this);
    for (final r in _rows.toList()) {
      r.dispose();
    }
    client._scopeDisposed();
  }

  void _settle(SlingException? error) {
    _awaiting = false;
    _error = error;
    _errorAt = error != null ? client._now() : null;
    _errorIsBackground = error != null && _backgroundFetch;
    final partial =
        error is SlingGraphQLException &&
        error.isPartial &&
        errorPolicy != ErrorPolicy.none;
    _errorKeptWithData = partial && errorPolicy == ErrorPolicy.all;
    _errorHidden = partial && errorPolicy == ErrorPolicy.ignore;
    _backgroundFetch = false;
    // network-only: the scope's own data has landed, read the cache from now on.
    if (error == null || partial) _bypassCache = false;
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

  @override
  Map<Type, TypePolicy> get typePolicies => parent.typePolicies;

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
  ) {
    _bound.add(accessor.selection);
    return ctor(this, accessor.selection, accessor.path);
  }

  /// The selection nodes of the accessors bound since the last [run]: where
  /// this row's reads went, for the parent's whole-selection fetches.
  final Set<Selection> _bound = {};

  /// Runs [body] with [accessor] bound to this scope and fresh [deps].
  T run<A extends Accessor, T>(
    A accessor,
    A Function(Recorder, Selection, List<Object>) ctor,
    T Function(A bound) body,
  ) {
    _deps = {};
    _bound.clear();
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
  Object? readListField(
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
  Set<String> gc({Iterable<String> retain = const []}) =>
      _inner.gc(retain: retain);
  @override
  Iterable<String> get entityKeys => _inner.entityKeys;
  @override
  Map<String, Object?>? entity(String key) => _inner.entity(key);
  @override
  T batch<T>(T Function() body) => _inner.batch(body);
  @override
  Stream<Set<String>> get onChange => _inner.onChange;
  @override
  int get version => _inner.version;
  @override
  CacheDelta changesSince(int version) => _inner.changesSince(version);
  @override
  void compact({required int upTo}) => _inner.compact(upTo: upTo);
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
  Map<Type, TypePolicy> get typePolicies => client.typePolicies;

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

  @override
  Map<Type, TypePolicy> get typePolicies => client.typePolicies;

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
  /// page only — or, with `RelayStylePagination` on the field, the merged
  /// list of every page). The path to it may go through lookups and entities
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
    return cache.batch(() {
      final touched = cache.evict(key);
      client._notify(touched);
      return touched.isNotEmpty;
    });
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
/// Each cached argument set is its own list — every filter, and every page
/// of a connection unless a [FieldPolicy] such as [RelayStylePagination]
/// merges them into one — and an edit applies to the one entry you named. A filtered or paginated list is
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
    _cache.batch(() {
      final touched = _cache.write(operation, path, next);
      _scope.onWrite(
        CacheWrite(operation, path, List<Object?>.of(previous), touched),
      );
    });
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
/// word, and without a merging policy each page is one list: the 20 launches of page
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

/// Sends one HTTP request and returns its response: the extension point for
/// logging, custom HTTP stacks and test doubles.
///
/// ```dart
/// SlingClient<Query>(
///   endpoint: uri,
///   rootFactory: Query.root,
///   transport: (request) async {
///     final response = await http.Response.fromStream(await _http.send(request));
///     log('${response.statusCode} ${request.body.length} B');
///     return response;
///   },
/// );
/// ```
///
/// Auth ([SlingClient.auth]), retries ([SlingClient.retry]) and timeouts
/// ([SlingClient.timeout]) are the client's: it calls the transport once per
/// attempt, with a fresh request each time. The request is a finalized
/// POST (an `http.AbortableRequest`: pass it on to an `http.Client` and a
/// timeout or a disposed scope aborts it) with `content-type`,
/// [SlingClient.headers] and the auth headers applied; queries and mutations
/// alike go through it. What it throws is classified by
/// [SlingException.from] (`http.ClientException` is a network error).
typedef Transport = Future<http.Response> Function(http.Request request);

/// Opens one subscription and returns its results as they arrive: each
/// element is one GraphQL execution result (`{data, errors?}`), the stream
/// ends when the server completes the subscription, and a transport failure
/// is a stream error. The subscription is closed by cancelling the
/// subscription to the stream.
///
/// The request is a finalized POST like a query's, with
/// `accept: text/event-stream`, [SlingClient.headers] and the
/// [SlingClient.auth] headers applied (an `http.AbortableRequest`, aborted
/// when the subscription closes). The default ([sseSubscriptionTransport])
/// speaks GraphQL over Server-Sent Events in "distinct connections" mode
/// (one HTTP request per subscription, what graphql-yoga, Apollo Server and
/// Hot Chocolate serve on the regular endpoint). Replace it to use another
/// protocol (`graphql-ws`) — the client only ever sees decoded results:
///
/// ```dart
/// SlingClient<Query>(
///   endpoint: uri,
///   rootFactory: Query.root,
///   subscriptionTransport: (request) => myWebSocketTransport(request),
/// );
/// ```
///
/// Stream errors are classified by [SlingException.from]; an
/// unauthenticated one ([SlingAuth.isUnauthenticated]) refreshes the
/// credentials and reopens the connection once.
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
          controller.addError(SlingException.from(e, st), st);
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
        var body = '';
        try {
          body = await response.stream.bytesToString();
        } catch (_) {
          // The status says enough.
        }
        if (controller.isClosed) {
          await close();
          return;
        }
        controller.addError(
          SlingHttpException.fromBody(response.statusCode, body),
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
              if (!controller.isClosed) {
                controller.addError(SlingException.from(e, st), st);
              }
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
  Map<Type, TypePolicy> get typePolicies => client.typePolicies;

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
    this.debugLabel,
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

  /// Names this subscription in [SlingRequest.scopes].
  final String? debugLabel;

  /// The dev-tooling record of the current connection, if anyone watches.
  SlingRequest? _record;

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
    if (_closed || !_listened || _upstream != null || _connecting) return;
    _retry?.cancel();
    _retry = null;
    _open();
  }

  /// Waiting for `SlingAuth.headers` or an auth refresh before connecting.
  bool _connecting = false;

  /// Aborts the current connection's request.
  Completer<void>? _abort;

  /// The auth generation the current connection's headers came from.
  int _authGeneration = 0;

  /// The connection was reopened after an auth refresh and has not had an
  /// event yet: another unauthenticated failure is final.
  bool _authReplayed = false;

  void _open() {
    if (_closed) return;
    _listened = true;
    _client._subscriptions.add(this);
    final auth = _client.auth;
    if (auth == null) {
      _connect(const {});
      return;
    }
    final generation = _client._authGeneration;
    final FutureOr<Map<String, String>> headers;
    try {
      headers = auth.headers();
    } catch (e, st) {
      _fail(SlingAuthException(e), st);
      return;
    }
    if (headers is Map<String, String>) {
      _connect(headers, generation);
      return;
    }
    _connecting = true;
    headers.then(
      (headers) {
        _connecting = false;
        if (!_closed) _connect(headers, generation);
      },
      onError: (Object e, StackTrace st) {
        _connecting = false;
        _fail(SlingAuthException(e), st);
      },
    );
  }

  void _connect(Map<String, String> authHeaders, [int generation = 0]) {
    _authGeneration = generation;
    _client.onOperation?.call(operation);
    _record = _client._track('subscription', operation, _scope.root, [
      ?debugLabel,
    ]);
    _record?._sent();
    final abort = _abort = Completer<void>();
    final request = _client._request(operation, abortTrigger: abort.future)
      ..headers.addAll(authHeaders)
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
        final error = SlingException.from(e, st);
        if (_unauthenticated(error)) return;
        _fail(error, st);
      },
      onDone: _close,
      cancelOnError: true,
    );
    onStatusChanged?.call();
  }

  /// Reports [error] on the stream and treats the connection as dropped.
  void _fail(SlingException error, [StackTrace? st]) {
    if (_closed) return;
    if (!_controller.isClosed) _controller.addError(error, st);
    _record?._finish(error);
    _dropped();
  }

  /// Drops the connection without scheduling anything.
  void _disconnect() {
    final upstream = _upstream;
    _upstream = null;
    upstream?.cancel();
    final abort = _abort;
    _abort = null;
    if (abort != null && !abort.isCompleted) abort.complete();
  }

  /// When [error] means the credentials were rejected: refreshes them
  /// (single-flight with every other request) and reopens the connection
  /// once; a second rejection is a [SlingAuthException]. Returns `false`
  /// for any other error.
  bool _unauthenticated(SlingException error) {
    final auth = _client.auth;
    if (_closed || auth == null || !auth.isUnauthenticated(error)) {
      return false;
    }
    _disconnect();
    _record?._finish(error);
    if (_authReplayed) {
      _fail(SlingAuthException(error));
      return true;
    }
    _authReplayed = true;
    _connecting = true;
    onStatusChanged?.call();
    _client
        ._refreshAuth(auth, _authGeneration)
        .then(
          (_) {
            _connecting = false;
            _open();
          },
          onError: (Object e, StackTrace st) {
            _connecting = false;
            _fail(SlingException.from(e, st), st);
          },
        );
    return true;
  }

  /// The connection failed: schedule a reopen, or end the stream.
  void _dropped() {
    if (_closed) return;
    _disconnect();
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
    final errors = SlingGraphQLError.listFromJson(json['errors']);
    final data = json['data'];
    if (data is! Map<String, Object?>) {
      final error = SlingGraphQLException(
        errors,
        message: errors.isEmpty ? 'Empty event' : null,
      );
      if (_unauthenticated(error)) return;
      _eventCount++;
      _record?._event();
      _controller.addError(error);
      return;
    }
    _eventCount++;
    _record?._event();
    _authReplayed = false;
    _client._serverReached();
    for (final e in errors) {
      SlingClient._prune(data, e.path);
    }
    final cache = _client.cache;
    cache.batch(() {
      final touched = cache.writeResponse(
        'subscription',
        operation.toCacheKeys(data),
        at: _client._now(),
      );
      _client._notify(touched);
      _client._countWrite();
    });
    if (errors.isNotEmpty) {
      _controller.addError(SlingGraphQLException(errors, isPartial: true));
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
    final abort = _abort;
    _abort = null;
    if (abort != null && !abort.isCompleted) abort.complete();
    _client._subscriptions.remove(this);
    _record?._finish();
    // The payloads live on in the entities they referenced; the root fields
    // would only pin them.
    final cache = _client.cache;
    cache.batch(() {
      final touched = <String>{};
      for (final alias in _scope.root.childAliases) {
        touched.addAll(cache.remove('subscription', [alias]));
      }
      _client._notify(touched);
    });
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
    this.typePolicies = const {},
    this.subscriptionRetryAfter,
    this.gcAfterWrites = 100,
    this.logRequests = false,
    this.errorPolicy = ErrorPolicy.none,
    this.timeout,
    this.retry = const RetryPolicy(),
    this.auth,
    MutationQueueStore? mutationQueue,
    this.mutationQueueBackoff = const RetryPolicy(
      initialDelay: Duration(seconds: 1),
      maxDelay: Duration(minutes: 5),
    ),
    // Clock behind `retryFailedAfter` and `maxAge`; only worth overriding in
    // tests.
    DateTime Function() now = DateTime.now,
    // Source of `RetryPolicy.jitter`; only worth overriding in tests.
    Random? random,
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
       _now = now,
       _random = random ?? Random(),
       mutationQueue = mutationQueue ?? InMemoryMutationQueueStore() {
    _restoreQueue();
  }

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

  /// Default [ErrorPolicy] for scopes, [resolve] and [mutateWith] calls that
  /// do not set their own: what to do with GraphQL errors that come with
  /// data. [ErrorPolicy.none] (prune and fail) by default.
  final ErrorPolicy errorPolicy;

  /// Default time limit of one attempt of a query batch or a mutation,
  /// after which it is aborted with a [SlingTimeoutException] (retried like
  /// a network error by [retry]). `null` (the default) waits as long as the
  /// transport does. Per call: `QueryBuilder(timeout:)`, [createScope],
  /// [resolve], [mutateWith]. Subscriptions have none: they stay open.
  final Duration? timeout;

  /// How query batches are retried (see [RetryPolicy]): by default three
  /// attempts for network errors, timeouts and 5xx, with exponential
  /// backoff and jitter. [RetryPolicy.none] reports the first failure.
  /// Mutations are never retried unless the call passes `retry:`;
  /// subscriptions use [subscriptionRetryAfter].
  ///
  /// Retries happen inside one fetch, before any scope sees an error: the
  /// scopes stay [QueryScope.isLoading] meanwhile, and the sticky error —
  /// and [retryFailedAfter]'s cooldown — start from the final failure.
  final RetryPolicy retry;

  /// Adds credentials to every request and refreshes them once on an
  /// unauthenticated response (see [SlingAuth]). `null`: no auth handling
  /// (static tokens can go in [headers]).
  final SlingAuth? auth;

  final Random _random;

  /// Where `mutateWith(offline: true)` calls wait for the network, persisted
  /// so they survive the app being killed (see [MutationQueueStore]): an
  /// [InMemoryMutationQueueStore] by default, `SqflitePersistence
  /// .mutationQueue` to keep them in the cache's database. What it holds
  /// when the client is created is replayed first.
  final MutationQueueStore mutationQueue;

  /// The waits between replays of the queued mutations while the server
  /// stays unreachable (see [mutateWith]'s `offline`): only its delays are
  /// used ([RetryPolicy.initialDelay], [RetryPolicy.multiplier],
  /// [RetryPolicy.maxDelay], [RetryPolicy.jitter]) — the queue retries until
  /// the server answers. By default 1 s, doubling up to 5 min.
  final RetryPolicy mutationQueueBackoff;

  /// Offline mutations not landed yet, oldest first: [_queue]'s head is
  /// being sent or waits for the network.
  final List<_QueuedCall> _queue = [];

  /// The head of [_queue] failed to reach the server: the queue waits for
  /// [_queueTimer], [replayQueue] or any successful request.
  bool _queueWaiting = false;

  /// Consecutive replays that found the server unreachable (the backoff
  /// step).
  int _queueFailures = 0;
  Timer? _queueTimer;

  /// Set while the queue is being sent, completed when it stops.
  Completer<void>? _queueDrain;

  /// [mutationQueue]'s [MutationQueueStore.load] has not completed yet:
  /// nothing is sent before what it holds.
  bool _queueLoading = false;
  bool _disposed = false;

  final StreamController<QueuedMutationFailure> _queuedMutationFailed =
      StreamController<QueuedMutationFailure>.broadcast(sync: true);

  /// Queued mutations that failed for good when they were replayed: the
  /// server answered with an error (a non-network failure), the entry was
  /// dropped from [mutationQueue] and its optimistic writes rolled back.
  /// The only report of a mutation queued by an earlier run of the app;
  /// in-session calls also fail their `mutateWith` future.
  Stream<QueuedMutationFailure> get onQueuedMutationFailed =>
      _queuedMutationFailed.stream;

  /// The offline mutations not landed yet, oldest first: queued ones and
  /// the one being sent.
  List<QueuedMutation> get queuedMutations => [
    for (final call in _queue) call.mutation,
  ];

  void _restoreQueue() {
    final loaded = mutationQueue.load();
    if (loaded is List<QueuedMutation>) {
      _restored(loaded);
    } else {
      // Calls made meanwhile wait behind what the store had.
      _queueLoading = true;
      loaded.then(_restored, onError: (Object _) => _restored(const []));
    }
  }

  void _restored(List<QueuedMutation> entries) {
    _queueLoading = false;
    if (_disposed) return;
    // A store that loads asynchronously may list the calls added meanwhile.
    final added = {for (final call in _queue) call.mutation.id};
    _queue.insertAll(0, [
      for (final m in entries)
        if (!added.contains(m.id)) _restoredCall(m),
    ]);
    if (_queue.isEmpty) return;
    // Replayed once the code creating the client has run (and wired its
    // listeners).
    scheduleMicrotask(() {
      if (_queueTimer == null && _queueDrain == null) unawaited(replayQueue());
    });
  }

  /// Sends the queued mutations now, oldest first and one at a time (see
  /// [mutateWith]'s `offline`), instead of waiting for the next backoff
  /// timer or successful request — e.g. when the app knows it is back
  /// online. Completes when the queue is empty, or when the server is still
  /// unreachable (the queue then waits again).
  Future<void> replayQueue() {
    _queueTimer?.cancel();
    _queueTimer = null;
    _queueWaiting = false;
    return _drainQueue();
  }

  /// A request reached the server: a waiting queue is replayed now.
  void _serverReached() {
    if (!_queueWaiting || _queueDrain != null || _queue.isEmpty) return;
    unawaited(replayQueue());
  }

  Future<void> _drainQueue() {
    if (_queueDrain case final running?) return running.future;
    if (_queue.isEmpty || _queueWaiting || _queueLoading || _disposed) {
      return Future.value();
    }
    final done = _queueDrain = Completer<void>();
    _sendQueue().whenComplete(() {
      _queueDrain = null;
      done.complete();
    });
    return done.future;
  }

  Future<void> _sendQueue() async {
    while (_queue.isNotEmpty && !_disposed) {
      final call = _queue.first;
      onOperation?.call(call.op);
      final record = _track('mutation', call.op, call.tree, [?call.debugLabel]);
      _mutationsInFlight++;
      _Received? received;
      SlingException? failure;
      try {
        received = await _execute(
          call.op,
          record: record,
          timeout: call.timeout ?? timeout,
          retry: call.retry ?? RetryPolicy.none,
        );
      } on SlingException catch (e) {
        failure = e;
      }
      if (_disposed) return;
      if (failure != null && failure.isNetworkUnreachable) {
        // Not sent: everything in the queue waits for the network.
        record?._finish(failure);
        _mutationsInFlight--;
        _queueWaiting = true;
        _queueFailures++;
        _queueTimer = Timer(
          mutationQueueBackoff.delayFor(_queueFailures, _random),
          () {
            _queueTimer = null;
            unawaited(replayQueue());
          },
        );
        for (final c in _queue) {
          c.markQueued();
        }
        _checkIdle();
        return;
      }
      _queue.removeAt(0);
      _queueFailures = 0;
      unawaited(mutationQueue.remove(call.mutation.id));
      try {
        call.land(record, received, failure);
      } on SlingException catch (e) {
        if (call.queued && !_queuedMutationFailed.isClosed) {
          _queuedMutationFailed.add(QueuedMutationFailure(call.mutation, e));
        }
      }
    }
  }

  /// Queues an offline call (see [mutateWith]) and sends it when its turn
  /// comes; completes with its outcome.
  Future<T> _mutateOffline<M extends Accessor, T>(
    RootFactory<M> root,
    T Function(M mutation) body,
    MutationScope scope,
    PrintedOperation op,
    List<CacheWrite> journal, {
    required Iterable<String>? refetchQueries,
    required String? debugLabel,
    required ErrorPolicy policy,
    required Duration? timeout,
    required RetryPolicy? retry,
    required void Function()? onQueued,
  }) {
    final outcome = Completer<T>();
    final now = _now();
    final mutation = QueuedMutation(
      id:
          '${now.microsecondsSinceEpoch.toRadixString(36)}-'
          '${_random.nextInt(1 << 32).toRadixString(36)}',
      document: op.document,
      variables: op.variables,
      createdAt: now,
      rollback: encodeRollback(journal),
      refetchQueries: [...?refetchQueries],
      renamesFields: op.renamesFields,
    );
    final call = _QueuedCall(
      mutation,
      op,
      scope.root,
      journal,
      debugLabel: debugLabel,
      timeout: timeout,
      retry: retry,
      onQueued: onQueued,
      land: (record, received, failure) {
        try {
          outcome.complete(
            _landMutation(
              op,
              record,
              received,
              failure,
              journal,
              policy: policy,
              rootAliases: scope.root.childAliases,
              refetchQueries: refetchQueries,
              result: () => body(root(scope)),
            ),
          );
        } catch (e, st) {
          outcome.completeError(e, st);
          if (e is SlingException) rethrow; // reported if it was queued
        }
      },
    );
    _queue.add(call);
    unawaited(mutationQueue.add(mutation));
    if (_queueWaiting) {
      call.markQueued();
    } else {
      unawaited(_drainQueue());
    }
    return outcome.future;
  }

  /// A [QueuedMutation] restored from [mutationQueue], replayed without
  /// the closure that recorded it.
  _QueuedCall _restoredCall(QueuedMutation mutation) {
    final op = PrintedOperation(mutation.document, mutation.variables);
    final journal = decodeRollback(mutation.rollback);
    return _QueuedCall(
      mutation,
      op,
      Selection.root('mutation'),
      journal,
      queued: true,
      land: (record, received, failure) => _landMutation<void>(
        op,
        record,
        received,
        failure,
        journal,
        policy: errorPolicy,
        writeResponse: !mutation.renamesFields,
        refetchQueries: mutation.refetchQueries,
        result: () {},
      ),
    );
  }

  /// Bumped by each successful [SlingAuth.refresh]: a request sent with
  /// headers from an older generation replays without refreshing again.
  int _authGeneration = 0;
  Future<void>? _authRefresh;
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
    String? debugLabel,
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
      debugLabel: debugLabel,
    );
  }

  /// Prints one [SlingRequest.logLine] per operation once it is done:
  /// `sling_gql #3 query launches · 42 ms · 1.2 KB · 18 fields ←
  /// LaunchesScreen`. Off by default; for a custom sink, listen to
  /// [requests] and await [SlingRequest.done] instead.
  final bool logRequests;

  final StreamController<SlingRequest> _requests =
      StreamController<SlingRequest>.broadcast(sync: true);
  int _lastRequestId = 0;

  /// Every operation sent (query batches, mutations, subscription
  /// connections) as a [SlingRequest]: emitted when it is sent and again
  /// each time it changes (response processed, subscription event,
  /// connection closed). Records are only built while someone listens (or
  /// [logRequests] is on), so this costs nothing otherwise.
  /// `SlingRequestOverlay` is the in-app view of it.
  Stream<SlingRequest> get requests => _requests.stream;

  /// A record for [op], or `null` when nobody is watching.
  SlingRequest? _track(
    String kind,
    PrintedOperation op,
    Selection tree,
    List<String> scopes,
  ) {
    if (!logRequests && !_requests.hasListener) {
      _lastRequestId++;
      return null;
    }
    var leaves = 0;
    void count(Selection s) {
      if (s.isLeaf) {
        leaves++;
      } else {
        s.children.forEach(count);
      }
    }

    tree.children.forEach(count);
    final record = SlingRequest._(
      id: ++_lastRequestId,
      kind: kind,
      operation: op,
      scopes: scopes,
      rootFields: [
        for (final c in tree.children)
          if (!c.isFragment) c.field,
      ],
      fieldCount: leaves,
      startedAt: _now(),
    );
    record._onChange = (r) {
      if (!_requests.isClosed) _requests.add(r);
    };
    if (logRequests) record.done.then(_printRequest);
    _requests.add(record);
    return record;
  }

  // ignore: avoid_print
  static void _printRequest(SlingRequest r) => print(r);

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
  /// It starts from the final failure, once [retry] gave up.
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

  /// How many server responses (query responses, mutation results,
  /// subscription events) the client writes before it runs [gc] on its
  /// own, at the next moment it [isIdle]. `null` turns the automatic sweep
  /// off; call [gc] yourself then (e.g. on app pause).
  final int? gcAfterWrites;

  int _writesSinceGc = 0;

  void _countWrite() {
    _writesSinceGc++;
    _maybeGc();
  }

  void _maybeGc() {
    final every = gcAfterWrites;
    if (every == null || _writesSinceGc < every || !isIdle) return;
    gc();
  }

  /// Removes the cache entities nothing can reach any more — dropped from a
  /// replaced list, orphaned by an evicted parent or a removed mutation
  /// root — and returns their keys. Unlike `cache.gc()`, entities a live
  /// scope or row read (a detail screen resolved through a `launch(id:)`
  /// lookup, say) are kept even when no root references them, so nothing on
  /// screen loses its data. Runs by itself every [gcAfterWrites] responses.
  ///
  /// While a mutation is in flight the sweep is skipped (an optimistic
  /// rollback may put back references to collected entities) and returns
  /// an empty set.
  Set<String> gc() {
    if (_mutationsInFlight > 0) return const {};
    _writesSinceGc = 0;
    final retain = <String>{};
    void addEntities(Set<String> deps) {
      for (final dep in deps) {
        final dot = dep.lastIndexOf('.');
        if (dot > 0) retain.add(dep.substring(0, dot));
      }
    }

    for (final s in _scopes) {
      addEntities(s._deps);
    }
    for (final r in _rows) {
      addEntities(r._deps);
    }
    for (final call in _queue) {
      retain.addAll(rollbackEntities(call.journal));
    }
    return cache.gc(retain: retain);
  }

  /// How the cache stores particular fields, by the generated accessor
  /// class they are read through and field name: which arguments make an
  /// entry and how responses merge into it (see [FieldPolicy]).
  /// [RelayStylePagination] keeps every page of a connection in one
  /// growing list:
  ///
  /// ```dart
  /// SlingClient<Query>(
  ///   typePolicies: {
  ///     Query: TypePolicy(fields: {'launches': RelayStylePagination()}),
  ///   },
  /// )
  /// ```
  ///
  /// The key is the accessor's exact class: a policy on `Launch` does not
  /// apply to the same field read through an interface accessor (`Node`),
  /// register it under each class the field is read through.
  final Map<Type, TypePolicy> typePolicies;

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
          final path = c.cachePath;
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
    ErrorPolicy? errorPolicy,
    Duration? timeout,
  }) {
    final scope = QueryScope<Q>(
      this,
      onChanged: onChanged,
      scheduler: scheduler,
      debugLabel: debugLabel,
      fetchPolicy: fetchPolicy,
      maxAge: maxAge,
      errorPolicy: errorPolicy,
      timeout: timeout,
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
  /// `sling_gql_test`) loop on exactly that. Offline mutations waiting in
  /// the queue for the network do not count; one being sent does.
  bool get isIdle =>
      !_flushScheduled && _inflight == null && _mutationsInFlight == 0;

  /// Completes once [isIdle] is true (immediately if it already is).
  Future<void> get whenIdle =>
      isIdle ? Future.value() : (_idle ??= Completer<void>()).future;

  void _checkIdle() {
    if (!isIdle) return;
    _maybeGc();
    _idle?.complete();
    _idle = null;
  }

  /// Imperative one-shot: runs [body] against a throwaway scope, fetches what
  /// is missing, and resolves once the cache is populated. Useful for
  /// `prepare`-style prefetching or tests. [fetchPolicy] / [maxAge] default
  /// to the client's: `resolve(body, fetchPolicy: FetchPolicy.networkOnly)`
  /// is "fetch this now, whatever the cache has".
  ///
  /// Throws the [SlingException] the fetch failed with. [errorPolicy]
  /// (default [SlingClient.errorPolicy]) decides about a partial response:
  /// [ErrorPolicy.none] throws its [SlingGraphQLException],
  /// [ErrorPolicy.all] throws it with [SlingGraphQLException.data] set to
  /// [body]'s value, [ErrorPolicy.ignore] returns that value. [timeout]
  /// defaults to [SlingClient.timeout].
  Future<T> resolve<T>(
    T Function(Q root) body, {
    FetchPolicy? fetchPolicy,
    Duration? maxAge,
    ErrorPolicy? errorPolicy,
    Duration? timeout,
  }) async {
    final scope = createScope(
      onChanged: () {},
      fetchPolicy: fetchPolicy,
      maxAge: maxAge,
      errorPolicy: errorPolicy,
      timeout: timeout,
    );
    try {
      scope.run(body);
      await scope.whenSettled;
      final error = scope.error;
      if (error == null) {
        final result = scope.run(body);
        return result;
      }
      if (error is SlingGraphQLException &&
          error.isPartial &&
          scope.errorPolicy == ErrorPolicy.all) {
        throw error.withData(scope.run(body));
      }
      throw error;
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
  /// `errors`): the future rejects with a [SlingGraphQLException] carrying
  /// [SlingException.errors], [body] is not run again and
  /// [refetchQueries] are not refetched. The cache still takes what the
  /// server resolved: the optimistic writes are undone first, then the
  /// resolved fields are written over them (the server's values win), while
  /// errored paths are pruned and keep their pre-mutation value. Widgets
  /// showing the resolved entities rebuild as on success. An HTTP or
  /// transport error, or a response without `data`, writes nothing.
  ///
  /// [errorPolicy] (default [SlingClient.errorPolicy]) changes the partial
  /// case: with [ErrorPolicy.all] or [ErrorPolicy.ignore] the call counts as
  /// landed — the response is written as sent (`null`s at errored paths
  /// included), optimistic writes are not undone, [refetchQueries] run and
  /// [body] computes the value; `ignore` returns it, `all` throws the
  /// [SlingGraphQLException] with the value in [SlingGraphQLException.data].
  ///
  /// [timeout] (default [SlingClient.timeout]) limits each attempt.
  /// Mutations are sent once: a timed-out or dropped mutation may still have
  /// been applied by the server. Pass [retry] to opt in for mutations that
  /// are safe to repeat.
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
  ///
  /// [offline] queues the call when the server cannot be reached
  /// ([SlingException.isNetworkUnreachable]) instead of failing it:
  /// - its optimistic writes **stay applied** while it waits, and [onQueued]
  ///   is called (once) — `MutationBuilder` shows it as
  ///   `MutationState.isQueued`;
  /// - the returned future **stays pending** until the call is finally sent:
  ///   it completes as above, with [body]'s value once the response landed,
  ///   or with the error of a replay the server rejected (optimistic writes
  ///   rolled back, [onQueuedMutationFailed] notified). If the client is
  ///   disposed (or the app killed) first, it never completes;
  /// - queued calls are sent again in order, one at a time — after the next
  ///   request of any kind that reaches the server, on [replayQueue], and on
  ///   timers backing off along [mutationQueueBackoff];
  /// - the call is in [mutationQueue] from the moment it is sent until it
  ///   lands or fails for good: the printed document, its variables (as they
  ///   were at the call) and the undo log of its optimistic writes. A later
  ///   run of the app with the same store replays it — **at least once**: a
  ///   call the server applied just before the app was killed is sent
  ///   again — and still rolls its optimistic writes back if the server
  ///   then rejects it (reported on [onQueuedMutationFailed] only). [body]
  ///   is not run for a restored call; its response is cached like any
  ///   other (unless [QueuedMutation.renamesFields]).
  ///
  /// An offline call made while others wait is queued behind them (sent in
  /// order); calls without [offline] are sent at once as usual. A call
  /// killed mid-flight *without* [offline] leaves its optimistic writes in a
  /// persisted cache until a response for those fields overwrites them.
  Future<T> mutateWith<M extends Accessor, T>(
    RootFactory<M> root,
    T Function(M mutation) body, {
    void Function()? optimistic,
    Iterable<String>? refetchQueries,
    String? debugLabel,
    ErrorPolicy? errorPolicy,
    Duration? timeout,
    RetryPolicy? retry,
    bool offline = false,
    void Function()? onQueued,
  }) async {
    final policy = errorPolicy ?? this.errorPolicy;
    final journal = <CacheWrite>[];
    if (optimistic != null) {
      // One cache change for the whole callback (see `Cache.batch`).
      cache.batch(() {
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
      });
    }

    final scope = MutationScope(this);
    body(root(scope));
    final op = PrintedOperation.from(scope.root);
    if (offline) {
      return _mutateOffline(
        root,
        body,
        scope,
        op,
        journal,
        refetchQueries: refetchQueries,
        debugLabel: debugLabel,
        policy: policy,
        timeout: timeout,
        retry: retry,
        onQueued: onQueued,
      );
    }
    onOperation?.call(op);
    final record = _track('mutation', op, scope.root, [?debugLabel]);

    _Received? received;
    SlingException? failure;
    _mutationsInFlight++;
    try {
      received = await _execute(
        op,
        record: record,
        timeout: timeout ?? this.timeout,
        retry: retry ?? RetryPolicy.none,
      );
    } on SlingException catch (e) {
      failure = e;
    }
    return _landMutation(
      op,
      record,
      received,
      failure,
      journal,
      policy: policy,
      rootAliases: scope.root.childAliases,
      refetchQueries: refetchQueries,
      result: () => body(root(scope)),
    );
  }

  /// Ends a mutation that was in flight (counted in [_mutationsInFlight]):
  /// writes its response, or rolls back its optimistic [journal] and throws
  /// [failure]; returns [result] computed once the response is cached.
  /// [rootAliases] are the root fields written under `ROOT_MUTATION` (the
  /// response's when `null`); without [writeResponse] nothing is written
  /// (a restored call whose response keys cannot be mapped back).
  T _landMutation<T>(
    PrintedOperation op,
    SlingRequest? record,
    _Received? received,
    SlingException? failure,
    List<CacheWrite> journal, {
    required ErrorPolicy policy,
    Iterable<String>? rootAliases,
    Iterable<String>? refetchQueries,
    bool writeResponse = true,
    required T Function() result,
  }) {
    var written = const <String>[];
    // From here on everything is synchronous: one cache change for the
    // response, the rollback, list rules and the root removal.
    return cache.batch(() {
      Set<String> touched;
      SlingGraphQLException? partial;
      try {
        // The request failed: rethrown below, after the rollback.
        if (failure != null) throw failure;
        final data = received!.data;
        if (received.errors.isNotEmpty) {
          partial = SlingGraphQLException(received.errors, isPartial: true);
          if (policy == ErrorPolicy.none) {
            for (final e in received.errors) {
              _prune(data, e.path);
            }
          }
        }
        record?._finish(partial);
        // Partial failure: undo the optimistic writes *before* writing the
        // fields that resolved, so the server's values win over the rollback.
        final undone = partial != null && policy == ErrorPolicy.none
            ? _rollback(journal)
            : const <String>{};
        touched = const {};
        if (writeResponse) {
          try {
            final cached = op.toCacheKeys(data);
            written = [...(rootAliases ?? cached.keys)];
            touched = cache.writeResponse('mutation', cached, at: _now());
          } catch (e, st) {
            throw SlingTransportException(
              e,
              st,
              'Could not cache the response: $e',
            );
          }
          _writesSinceGc++;
        }
        touched = touched.union(undone);
      } on SlingException catch (e) {
        record?._finish(e);
        _notify(_rollback(journal));
        rethrow;
      } finally {
        _mutationsInFlight--;
        _checkIdle();
      }
      if (partial != null && policy == ErrorPolicy.none) {
        _removeMutationRoot(written);
        _notify(touched);
        throw partial;
      }
      _notify(touched);

      if (refetchQueries != null && refetchQueries.isNotEmpty) {
        final names = refetchQueries.toSet();
        for (final s in _scopes.toList()) {
          if (s.root.children.any((c) => names.contains(c.field))) {
            s.refetch(); // fire-and-forget; errors surface on the scope
          }
        }
      }

      final value = result();
      _removeMutationRoot(written);
      if (partial != null && policy == ErrorPolicy.all) {
        throw partial.withData(value);
      }
      return value;
    });
  }

  /// The payload lives on in the entities it referenced; the root fields
  /// would only pin them in memory.
  void _removeMutationRoot(Iterable<String> aliases) {
    for (final alias in aliases) {
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
    if (_insideMergedField(leaf)) {
      _pending.ensureFillPath(leaf, _cachedPages);
    } else {
      _pending.ensurePath(leaf);
    }
    // A merged entry (or one of its pages) is fetched: with whatever its
    // readers selected by the time the request leaves (see `_doFlush`).
    if (leaf.policy?.merges ?? false) _entryFetches.add(leaf);
    return true;
  }

  /// Policy fields missed since the last flush (see [_enqueueLeaf]).
  final List<Selection> _entryFetches = [];

  static bool _insideMergedField(Selection leaf) {
    for (var n = leaf.parent; n != null; n = n.parent) {
      if (n.policy?.merges ?? false) return true;
    }
    return false;
  }

  /// For [Selection.ensureFillPath]: the pages the cached entry of the
  /// policy field [ancestor] holds — `null` when the entry does not cover
  /// [ancestor]'s own arguments (that page is being fetched, not filled),
  /// an empty list (fill with its own arguments) when no entry can be
  /// read at its cache path (not fetched yet, or reached through a lookup).
  List<Map<String, Object?>>? _cachedPages(Selection ancestor) {
    final policy = ancestor.policy!;
    final value = cache.read('query', ancestor.cachePath);
    if (value is! Map) return const [];
    if (!policy.covers(value, ancestor.argValues)) return null;
    return policy.pages(value) ?? const [];
  }

  /// Forgets the failed document, so [refetch] may send it again.
  void _clearFailure() {
    _failedDocument = null;
    _failedAt = null;
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
    // Whole-selection fetches (refetch, cache-and-network, a stale
    // `maxAge`): the scope's tree plus its rows' subtrees, merged now so
    // reads recorded after run() in this frame are included.
    for (final scope in _pendingScopes) {
      if (!scope._fetchWhole) continue;
      scope._fetchWhole = false;
      scope._enqueueWhole();
    }
    // A merged entry's fetch selects what every argument set of it read
    // (the rows read through the first page, not through the next one).
    for (final leaf in _entryFetches) {
      final target = _pending.ensurePath(leaf);
      for (final sibling in leaf.sameEntry) {
        target.mergeFrom(sibling);
      }
    }
    _entryFetches.clear();
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
        if (s._disposed) continue;
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
    if (scopes.every((s) => s._disposed)) {
      // Everyone who asked is gone (a screen popped before its first frame
      // ended): nothing to send.
      _checkIdle();
      return;
    }

    final cancel = _inflightCancel = _CancelToken();
    _inflight = tree;
    _rememberLists(tree);
    _inflightScopes.addAll(scopes);
    for (final s in scopes) {
      final warning = s._requestSent();
      if (warning != null && warnOnWaterfall) onWaterfall(warning);
    }
    onOperation?.call(op);
    final record = _track('query', op, tree, [
      for (final s in scopes) s.debugLabel,
    ]);

    _Received? received;
    SlingException? error;
    try {
      received = await _execute(
        op,
        record: record,
        timeout: _batchTimeout(scopes),
        retry: retry,
        cancel: cancel,
      );
    } on SlingException catch (e) {
      error = e;
    }
    if (identical(_inflightCancel, cancel)) _inflightCancel = null;
    if (cancel.isCancelled) {
      _abandon(record);
      return;
    }
    // Synchronous from here: one cache change for the response, list-rule
    // edits and an automatic gc (see `Cache.batch`).
    cache.batch(() => _land(op, record, received, error));
  }

  /// The longest timeout of [scopes]; `null` (no limit) if one has none.
  Duration? _batchTimeout(Set<QueryScope<Q>> scopes) {
    Duration? longest;
    for (final s in scopes) {
      final t = s.timeout;
      if (t == null) return null;
      if (longest == null || t > longest) longest = t;
    }
    return longest ?? timeout;
  }

  /// Cancels the in-flight query batch when every scope waiting for it has
  /// been disposed: the request is aborted and its response dropped.
  void _scopeDisposed() {
    final cancel = _inflightCancel;
    if (cancel == null || cancel.isCancelled) return;
    if (_inflightScopes.every((s) => s._disposed)) cancel.cancel();
  }

  /// Ends a cancelled batch without writing anything. A scope that joined
  /// it after the cancellation re-runs and fetches again.
  void _abandon(SlingRequest? record) {
    record?._finish(const SlingCancelledException());
    _inflight = null;
    final waiters = _inflightScopes;
    _inflightScopes = {};
    for (final s in waiters) {
      if (s._disposed) continue;
      s._settle(null);
      s._changedByClient();
    }
    _checkIdle();
  }

  /// Writes a flush's response (when it came) and settles the scopes that
  /// waited for it. Errored paths are pruned unless every live scope that
  /// selected their root field keeps them ([ErrorPolicy.all] / `ignore`).
  void _land(
    PrintedOperation op,
    SlingRequest? record,
    _Received? received,
    SlingException? error,
  ) {
    _inflight = null;
    final waiters = {
      for (final s in _inflightScopes)
        if (!s._disposed) s,
    };
    _inflightScopes = {};
    Set<String> touched = {};
    try {
      if (received != null) {
        final data = received.data;
        if (received.errors.isNotEmpty) {
          error = SlingGraphQLException(received.errors, isPartial: true);
          for (final e in received.errors) {
            if (!_keepsErroredPath(e.path, waiters)) _prune(data, e.path);
          }
        }
        touched = cache.writeResponse(
          'query',
          op.toCacheKeys(data),
          at: _now(),
        );
        _writesSinceGc++; // swept once the flush settles (`_checkIdle`)
      }
      if (error != null) {
        _failedDocument = op.document;
        _failedAt = _now();
        _lastError = error;
      } else {
        _failedDocument = null;
        _failedAt = null;
      }
    } catch (e, st) {
      error = SlingTransportException(
        e,
        st,
        'Could not cache the response: $e',
      );
      _failedDocument = op.document;
      _failedAt = _now();
      _lastError = error;
    }
    record?._finish(error);

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

  /// Whether the `null` the server put at [path] is cached as sent rather
  /// than pruned: some scope of the batch selected its root field, and none
  /// that did uses [ErrorPolicy.none].
  static bool _keepsErroredPath(
    List<Object>? path,
    Set<QueryScope<Accessor>> scopes,
  ) {
    if (path == null || path.isEmpty) return false;
    final alias = path.first;
    var selected = false;
    for (final s in scopes) {
      if (!s.root.childAliases.contains(alias)) continue;
      if (s.errorPolicy == ErrorPolicy.none) return false;
      selected = true;
    }
    return selected;
  }

  Set<QueryScope<Q>> _inflightScopes = {};
  _CancelToken? _inflightCancel;
  SlingException? _lastError;

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

  /// Removes the value at a GraphQL error `path` (aliases and list indices)
  /// from a response so it is not written to the cache.
  static void _prune(Map<String, Object?> data, List<Object>? path) {
    if (path == null || path.isEmpty) return;
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

  http.Request _request(PrintedOperation op, {Future<void>? abortTrigger}) =>
      http.AbortableRequest('POST', endpoint, abortTrigger: abortTrigger)
        ..headers.addAll({'content-type': 'application/json', ...headers})
        ..body = jsonEncode({'query': op.document, 'variables': op.variables});

  /// Sends [op] until it succeeds or [retry] gives up: each attempt goes
  /// through [_authorized]. Returns the response's `data` (response keys,
  /// errored paths not yet pruned) and `errors`; throws the final
  /// [SlingException] (a [SlingCancelledException] once [cancel] fired).
  Future<_Received> _execute(
    PrintedOperation op, {
    required SlingRequest? record,
    required Duration? timeout,
    required RetryPolicy retry,
    _CancelToken? cancel,
  }) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final received = await _authorized(op, record, timeout, cancel);
        _serverReached();
        return received;
      } on SlingCancelledException {
        rethrow;
      } on SlingException catch (e) {
        if (attempt >= retry.maxAttempts || !retry.retryIf(e)) rethrow;
        await _backoff(retry.delayFor(attempt, _random), cancel);
      }
    }
  }

  /// Waits [delay], or throws [SlingCancelledException] when [cancel] fires
  /// first.
  static Future<void> _backoff(Duration delay, _CancelToken? cancel) {
    final done = Completer<void>();
    final timer = Timer(delay, done.complete);
    cancel?.whenCancelled.then((_) {
      timer.cancel();
      if (!done.isCompleted) {
        done.completeError(const SlingCancelledException());
      }
    });
    return done.future;
  }

  /// One attempt with [auth]'s headers; on an unauthenticated answer,
  /// refreshes (single-flight) and replays once.
  Future<_Received> _authorized(
    PrintedOperation op,
    SlingRequest? record,
    Duration? timeout,
    _CancelToken? cancel,
  ) async {
    final auth = this.auth;
    if (auth == null) return _sendOnce(op, record, timeout, cancel, const {});
    for (var replay = false; ; replay = true) {
      final generation = _authGeneration;
      final Map<String, String> authHeaders;
      try {
        authHeaders = await auth.headers();
      } catch (e) {
        throw SlingAuthException(e);
      }
      SlingException rejected;
      try {
        final received = await _sendOnce(
          op,
          record,
          timeout,
          cancel,
          authHeaders,
        );
        if (received.errors.isEmpty) return received;
        rejected = SlingGraphQLException(received.errors, isPartial: true);
        if (!auth.isUnauthenticated(rejected)) return received;
      } on SlingCancelledException {
        rethrow;
      } on SlingException catch (e) {
        if (!auth.isUnauthenticated(e)) rethrow;
        rejected = e;
      }
      if (replay) throw SlingAuthException(rejected);
      await _refreshAuth(auth, generation);
      if (cancel?.isCancelled ?? false) throw const SlingCancelledException();
    }
  }

  /// Refreshes [auth] unless a refresh finished since [generation] (the
  /// caller's headers are already outdated: it just replays). Concurrent
  /// callers share one [SlingAuth.refresh]. Throws [SlingAuthException]
  /// when it fails.
  Future<void> _refreshAuth(SlingAuth auth, int generation) {
    if (generation != _authGeneration) return Future.value();
    return _authRefresh ??= () async {
      try {
        await auth.refresh();
        _authGeneration++;
      } catch (e) {
        throw SlingAuthException(e);
      } finally {
        _authRefresh = null;
      }
    }();
  }

  /// One HTTP round trip through [transport], aborted after [timeout] or
  /// when [cancel] fires.
  Future<_Received> _sendOnce(
    PrintedOperation op,
    SlingRequest? record,
    Duration? timeout,
    _CancelToken? cancel,
    Map<String, String> authHeaders,
  ) async {
    if (cancel?.isCancelled ?? false) throw const SlingCancelledException();
    final abort = Completer<void>();
    final request = _request(op, abortTrigger: abort.future)
      ..headers.addAll(authHeaders);
    final outcome = Completer<http.Response>();
    void fail(SlingException error) {
      if (!outcome.isCompleted) outcome.completeError(error);
      if (!abort.isCompleted) abort.complete();
    }

    final timer = timeout == null
        ? null
        : Timer(timeout, () => fail(SlingTimeoutException(timeout)));
    cancel?.whenCancelled.then((_) => fail(const SlingCancelledException()));
    record?._sent();
    Future<http.Response> sent;
    try {
      sent = transport(request);
    } catch (e, st) {
      sent = Future.error(e, st);
    }
    sent.then(
      (response) {
        if (!outcome.isCompleted) outcome.complete(response);
      },
      onError: (Object e, StackTrace st) {
        if (!outcome.isCompleted) {
          outcome.completeError(SlingException.from(e, st), st);
        }
      },
    );
    final http.Response response;
    try {
      response = await outcome.future;
    } finally {
      timer?.cancel();
    }
    record?._response(response.statusCode, response.bodyBytes.length);
    if (response.statusCode >= 400) {
      throw SlingHttpException.fromBody(response.statusCode, response.body);
    }
    final Object? json;
    try {
      json = jsonDecode(response.body);
    } on FormatException catch (e, st) {
      throw SlingTransportException(
        e,
        st,
        'Invalid JSON response (HTTP ${response.statusCode})',
      );
    }
    if (json is! Map<String, Object?>) {
      throw SlingTransportException(
        json ?? 'null',
        null,
        'Not a GraphQL response (HTTP ${response.statusCode})',
      );
    }
    final errors = SlingGraphQLError.listFromJson(json['errors']);
    final data = json['data'];
    if (data is! Map<String, Object?>) throw SlingGraphQLException(errors);
    return _Received(data, errors);
  }

  /// Closes every open subscription, aborts the query batch in flight, stops
  /// replaying the mutation queue (what it holds stays in [mutationQueue];
  /// the futures of queued calls never complete) and closes the HTTP
  /// client.
  void dispose() {
    _disposed = true;
    _queueTimer?.cancel();
    _queueTimer = null;
    for (final s in _subscriptions.toList()) {
      s.cancel();
    }
    _inflightCancel?.cancel();
    _requests.close();
    _queuedMutationFailed.close();
    _http.close();
  }
}

/// A response that came with `data`: the data under response keys (errored
/// paths not pruned yet) and the GraphQL errors next to it.
class _Received {
  _Received(this.data, this.errors);

  final Map<String, Object?> data;
  final List<SlingGraphQLError> errors;
}

/// One offline mutation in `SlingClient._queue`: what is persisted
/// ([mutation]) and what this run of the app still has of the call.
class _QueuedCall {
  _QueuedCall(
    this.mutation,
    this.op,
    this.tree,
    this.journal, {
    required this.land,
    this.debugLabel,
    this.timeout,
    this.retry,
    this.onQueued,
    this.queued = false,
  });

  final QueuedMutation mutation;
  final PrintedOperation op;

  /// The recorded selection, for the request log (empty once restored).
  final Selection tree;

  /// The optimistic writes to undo on a final failure.
  final List<CacheWrite> journal;
  final String? debugLabel;
  final Duration? timeout;
  final RetryPolicy? retry;
  final void Function()? onQueued;

  /// Writes the response (or rolls back) and completes the call; throws the
  /// [SlingException] it failed with. Decrements `_mutationsInFlight`.
  final void Function(
    SlingRequest? record,
    _Received? received,
    SlingException? failure,
  )
  land;

  /// The call waited for the network at least once (restored calls did).
  bool queued;

  void markQueued() {
    if (queued) return;
    queued = true;
    onQueued?.call();
  }
}

/// Fired once to abandon a query batch (every waiting scope was disposed,
/// or the client was).
class _CancelToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}
