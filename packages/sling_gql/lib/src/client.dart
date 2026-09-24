import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'accessor.dart';
import 'cache/cache.dart';
import 'selection.dart';

/// Error returned by the GraphQL endpoint (transport or `errors[]`).
class SlingException implements Exception {
  SlingException(this.message, {this.graphqlErrors = const [], this.statusCode});

  final String message;
  final List<Map<String, Object?>> graphqlErrors;
  final int? statusCode;

  @override
  String toString() => 'SlingException: $message';
}

/// Builds the root accessor of an operation for a given recorder.
typedef RootFactory<Q extends Accessor> = Q Function(Recorder recorder);

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
  });

  final SlingClient<Q> client;

  /// Invoked when data relevant to this scope changed and it should re-run.
  final void Function() onChanged;

  /// How this scope asks the client to flush (see [FlushScheduler]).
  final FlushScheduler scheduler;

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
  Completer<void>? _settled;

  /// Completes when the fetch this scope is waiting on has landed (or failed).
  Future<void> get whenSettled =>
      _awaiting ? (_settled ??= Completer<void>()).future : Future.value();

  /// True while a fetch containing selections from this scope is pending.
  bool get isLoading => _awaiting;

  /// True if the last run touched data that is not in the cache.
  bool get hasMissingData => _hadMiss;

  /// The last error from a fetch this scope took part in.
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
    final result = body(client.rootFactory(this));
    if (!_hadMiss) {
      // Fully served from cache: any previous error is moot.
      _error = null;
    }
    return result;
  }

  /// Re-fetches everything this scope selected during its last run.
  Future<void> refetch() {
    _error = null;
    _awaiting = true;
    client._enqueue(_root, force: true);
    client._schedule(this);
    return whenSettled;
  }

  @override
  void onMiss(Selection leaf) {
    _hadMiss = true;
    // Error state is sticky until `refetch()` so a failing query does not
    // loop: build → miss → fetch → fail → rebuild → miss → …
    if (_error != null) return;
    client._enqueueLeaf(leaf);
    _awaiting = true;
    client._schedule(this);
  }

  @override
  void onWrite(CacheWrite write) => client._onWrite(write);

  void dispose() => client._scopes.remove(this);

  void _settle(Object? error) {
    _awaiting = false;
    _error = error;
    _settled?.complete();
    _settled = null;
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

/// Batches selections into a single GraphQL document per microtask, fetches
/// them over HTTP, writes results into the cache and notifies scopes.
class SlingClient<Q extends Accessor> {
  SlingClient({
    required this.endpoint,
    required this.rootFactory,
    Cache? cache,
    http.Client? httpClient,
    this.headers = const {},
    this.onOperation,
  })  : cache = cache ?? Cache(),
        _http = httpClient ?? http.Client();

  final Uri endpoint;
  final RootFactory<Q> rootFactory;
  final Cache cache;
  final Map<String, String> headers;
  final http.Client _http;

  /// Debug hook: called with every document sent to the endpoint.
  final void Function(PrintedOperation op)? onOperation;

  final Set<QueryScope<Q>> _scopes = {};

  Selection _pending = Selection.root('query');
  Selection? _inflight;
  Set<QueryScope<Q>> _pendingScopes = {};
  bool _flushScheduled = false;

  /// Query document that last failed; suppresses automatic retry loops.
  String? _failedDocument;

  QueryScope<Q> createScope({
    required void Function() onChanged,
    FlushScheduler scheduler = microtaskScheduler,
  }) {
    final scope = QueryScope<Q>(this, onChanged: onChanged, scheduler: scheduler);
    _scopes.add(scope);
    return scope;
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
  Future<T> mutateWith<M extends Accessor, T>(
    RootFactory<M> root,
    T Function(M mutation) body, {
    void Function()? optimistic,
  }) async {
    final journal = <CacheWrite>[];
    if (optimistic != null) {
      _journal = journal;
      try {
        optimistic();
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
    try {
      (touched, error) = await _send('mutation', scope.root, op);
    } catch (e) {
      _rollback(journal);
      rethrow;
    }
    if (error != null) {
      _notify(touched.union(_rollback(journal)));
      throw error;
    }
    _notify(touched);

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

  void _enqueueLeaf(Selection leaf) {
    if (_inflight?.covers(_singleton(leaf)) ?? false) return;
    _pending.ensurePath(leaf);
  }

  void _enqueue(Selection tree, {bool force = false}) {
    if (force) _failedDocument = null;
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
      }
      return;
    }

    final op = PrintedOperation.from(tree);
    if (op.document == _failedDocument) {
      // Same document already failed: surface the error without a round trip.
      for (final s in scopes) {
        s._settle(_lastError);
        s.onChanged();
      }
      return;
    }

    _inflight = tree;
    _inflightScopes.addAll(scopes);
    onOperation?.call(op);

    Object? error;
    Set<String> touched = {};
    try {
      (touched, error) = await _send('query', tree, op);
      if (error != null) {
        _failedDocument = op.document;
        _lastError = error;
      } else {
        _failedDocument = null;
      }
    } catch (e) {
      error = e;
      _failedDocument = op.document;
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
        s.onChanged();
      }
    } else {
      _notify(touched, always: waiters);
    }
  }

  Set<QueryScope<Q>> _inflightScopes = {};
  Object? _lastError;

  /// Rebuilds every scope that read one of the [touched] dependency keys
  /// (`ROOT_QUERY.launches_x`, `Launch:launch-181.name`, …), plus [always].
  void _notify(Set<String> touched, {Set<QueryScope<Q>> always = const {}}) {
    for (final scope in _scopes.toList()) {
      if (always.contains(scope) || scope.deps.intersection(touched).isNotEmpty) {
        scope.onChanged();
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
      PrintedOperation op) async {
    final response = await _http.post(
      endpoint,
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode({'query': op.document, 'variables': op.variables}),
    );
    if (response.statusCode >= 400) {
      throw SlingException('HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    final json = jsonDecode(response.body) as Map<String, Object?>;
    final errors = (json['errors'] as List?)?.cast<Map<String, Object?>>() ?? const [];
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
