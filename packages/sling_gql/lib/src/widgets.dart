import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'accessor.dart';
import 'client.dart';
import 'errors.dart';
import 'retry.dart';
import 'pagination.dart';
import 'request_overlay.dart';
import 'selection.dart';

/// Debug-mode name for a sling widget's scope: the type of the nearest
/// enclosing app widget (`LaunchesScreen`), found by walking up to the
/// [SlingScope] past render/proxy widgets and sling's own. `null` in release
/// builds (type names are minified there), when the widget sits right
/// under the [SlingScope], or when there is none.
String? debugOwnerLabel(BuildContext context) {
  var enabled = false;
  assert(enabled = true);
  if (!enabled) return null;
  String? found;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is SlingScope) return false;
    if (widget is! StatelessWidget && widget is! StatefulWidget) return true;
    if (widget is QueryBuilder ||
        widget is SlingRow ||
        widget is MutationBuilder ||
        widget is SubscriptionBuilder ||
        widget is PaginatedQueryBuilder ||
        widget is SlingRequestOverlay ||
        widget is Builder ||
        widget is StatefulBuilder) {
      return true;
    }
    final name = '${widget.runtimeType}';
    final generic = name.indexOf('<');
    found = generic < 0 ? name : name.substring(0, generic);
    return false;
  });
  return found;
}

/// Provides a [SlingClient] to the widget tree.
///
/// [MutationBuilder] and [SubscriptionBuilder] resolve their roots from here
/// when they aren't given an explicit `root:`: from [schema] (the generated
/// `slingSchema` constant) or, without one, from the client's own
/// `SlingClient.schema`, if it was built from one.
class SlingScope<Q extends Accessor> extends StatelessWidget {
  const SlingScope({
    super.key,
    required this.client,
    required this.child,
    this.schema,
  });

  /// The client every sling widget below uses.
  final SlingClient<Q> client;

  final Widget child;

  /// The generated `slingSchema` constant, for the mutation and
  /// subscription roots of the builders below that don't set `root:`
  /// themselves. Defaults to `client.schema`.
  final SlingSchema<Q, Accessor>? schema;

  /// The client, typed with its query root.
  static SlingClient<Q> of<Q extends Accessor>(BuildContext context) {
    final client = clientOf(context);
    assert(
      client is SlingClient<Q>,
      'SlingScope above provides $client, not SlingClient<$Q>',
    );
    return client as SlingClient<Q>;
  }

  /// The client without knowing its query root type — enough for mutations.
  static SlingClient<Accessor> clientOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_InheritedClient>();
    assert(scope != null, 'No SlingScope found above this widget');
    return scope!.client;
  }

  /// The mutation root provided by the nearest [SlingScope]'s [schema] (or
  /// its client's). Used by [MutationBuilder] when it isn't
  /// given an explicit `root:`.
  static RootFactory<M> mutationRootOf<M extends Accessor>(
    BuildContext context,
  ) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_InheritedClient>();
    assert(scope != null, 'No SlingScope found above this widget');
    final root = scope!.mutationRoot;
    assert(
      root != null && root is RootFactory<M>,
      root == null
          ? 'MutationBuilder<$M> has no root: and the nearest SlingScope has '
                'no schema: (nor a client built with one) — pass one of them.'
          : 'SlingScope above provides a mutation root for a different type '
                'than $M — check schema: matches MutationBuilder<$M>.',
    );
    return root as RootFactory<M>;
  }

  /// The subscription root provided by the nearest [SlingScope]'s [schema].
  /// Used by [SubscriptionBuilder] when it isn't given an explicit `root:`.
  static RootFactory<S> subscriptionRootOf<S extends Accessor>(
    BuildContext context,
  ) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_InheritedClient>();
    assert(scope != null, 'No SlingScope found above this widget');
    final root = scope!.subscriptionRoot;
    assert(
      root != null && root is RootFactory<S>,
      root == null
          ? 'SubscriptionBuilder<$S> has no root: and the nearest SlingScope '
                'was not given a schema: with a subscription root — pass one '
                'of the two.'
          : 'SlingScope above provides a subscription root for a different '
                'type than $S — check schema: matches SubscriptionBuilder<$S>.',
    );
    return root as RootFactory<S>;
  }

  @override
  Widget build(BuildContext context) => _InheritedClient(
    client: client,
    mutationRoot: (schema ?? client.schema)?.mutation,
    subscriptionRoot: (schema ?? client.schema)?.subscription,
    child: child,
  );
}

/// The nearest [SlingScope]'s client, or `null` without one.
SlingClient<Accessor>? maybeSlingClientOf(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_InheritedClient>()?.client;

class _InheritedClient extends InheritedWidget {
  const _InheritedClient({
    required this.client,
    this.mutationRoot,
    this.subscriptionRoot,
    required super.child,
  });

  final SlingClient<Accessor> client;
  final RootFactory<Accessor>? mutationRoot;
  final RootFactory<Accessor>? subscriptionRoot;

  @override
  bool updateShouldNotify(_InheritedClient oldWidget) =>
      client != oldWidget.client ||
      mutationRoot != oldWidget.mutationRoot ||
      subscriptionRoot != oldWidget.subscriptionRoot;
}

/// Flushes at the end of the current (or next) frame, after layout, so that
/// children built lazily by slivers and lists are part of the same request as
/// their parents. The default `QueryBuilder.scheduler`.
void frameEndScheduler(void Function() flush) {
  final binding = SchedulerBinding.instance;
  binding.addPostFrameCallback((_) => flush());
  binding.ensureVisualUpdate(); // no-op while a frame is already in progress
}

/// Read-only view of a [QueryScope]'s status, handed to builders.
class QueryState {
  /// A view of [scope]. [QueryBuilder] makes one per build; public for
  /// adapters that run a [QueryScope] themselves (`sling_gql_hooks`).
  const QueryState(this._scope);

  final QueryScope _scope;

  /// A fetch containing this widget's selections is in flight.
  ///
  /// This does *not* imply [hasMissingData] is true: a write to one field can
  /// cause a re-fetch of the whole selection while everything else is
  /// already cached and rendering for real, e.g. after [refetch].
  bool get isLoading => _scope.isLoading;

  /// The last run read data that is not (yet) cached — skeleton values were
  /// returned. Convenient for showing placeholders.
  bool get hasMissingData => _scope.hasMissingData;

  /// True on the very first paint: [hasMissingData] and [isLoading] are both
  /// true, i.e. every accessor is still returning skeleton values *and* the
  /// request to fill them is in flight. Use this to gate a whole-widget
  /// skeleton (`state.isSkeleton ? Skeleton() : …`) instead of checking
  /// individual fields or list lengths — see "the three meanings of null" and
  /// "never branch on list length while loading" in `guides/getting-started`.
  bool get isSkeleton => hasMissingData && isLoading;

  /// The last build rendered cached data older than the scope's `maxAge`
  /// (or never fetched from the server) and a background refetch is on its
  /// way — stale-while-revalidate. Always false without a `maxAge`. Pair
  /// with [isLoading] for a subtle "refreshing" indicator.
  bool get isStale => _scope.isStale;

  /// The last error from a request this widget took part in.
  ///
  /// **Sticky until [refetch].** A failing query does not retry itself on
  /// every rebuild — that would loop build → miss → fetch → fail → rebuild →
  /// miss → … — so [error] stays set until you call [refetch] (bind it to
  /// pull-to-refresh, a retry button, `state.error != null` in an
  /// `ErrorView`). `SlingClient(retryFailedAfter:)` adds an automatic retry
  /// after a cooldown instead, for transient failures.
  ///
  /// A [SlingException]: switch over it to tell an offline device
  /// ([SlingNetworkException]) from a server error. Under
  /// [ErrorPolicy.all] it can be set while every field has its data.
  SlingException? get error => _scope.error;

  /// Re-fetch everything this widget selected in its last build. Clears
  /// [error] immediately and resolves once the new attempt has landed (or
  /// failed again).
  Future<void> refetch() => _scope.refetch();

  /// Like [refetch], but a no-op when everything this widget read is within
  /// its `maxAge`. Bind it to "screen became visible again" style triggers
  /// where a hard refetch would be wasteful.
  Future<void> revalidate() => _scope.revalidate();
}

typedef QueryWidgetBuilder<Q extends Accessor> = Widget Function(
  BuildContext context,
  Q query,
  QueryState state,
);

/// The `useQuery()` equivalent: gives the builder a typed root accessor and
/// records every field read during the build. Missing fields are fetched in a
/// single batched request per frame (shared with every other [QueryBuilder]
/// building in the same frame), then the widget rebuilds with real data.
class QueryBuilder<Q extends Accessor> extends StatefulWidget {
  const QueryBuilder({
    super.key,
    required this.builder,
    this.prepare,
    this.debugLabel,
    this.fetchPolicy,
    this.maxAge,
    this.errorPolicy,
    this.timeout,
    this.scheduler = frameEndScheduler,
  });

  final QueryWidgetBuilder<Q> builder;

  /// What this widget does with GraphQL errors that come with data (see
  /// [ErrorPolicy]); defaults to `SlingClient.errorPolicy`. Read when the
  /// scope is created.
  final ErrorPolicy? errorPolicy;

  /// Time limit of a request carrying this widget's selections (see
  /// `QueryScope.timeout`); defaults to `SlingClient.timeout`. Read when
  /// the scope is created.
  final Duration? timeout;

  /// When this widget's misses are flushed into a request (see
  /// [FlushScheduler]). The default, [frameEndScheduler], waits for the end
  /// of the frame so lazily built children (slivers, `ListView.builder`)
  /// join their parent's request — keep it for anything rendered in a frame.
  ///
  /// [microtaskScheduler] flushes on the next microtask instead, without
  /// waiting for a frame: right when no frame is coming (a widget test that
  /// never pumps, a headless `WidgetsBinding`), or for a one-off widget
  /// whose build is known to record everything. It splits a screen into
  /// several requests when children build in a later task (slivers do).
  ///
  /// The first scheduler of a batch wins: scopes recording into a batch
  /// already scheduled by another scope join it. Read when the scope is
  /// created (first build); changing it later has no effect.
  final FlushScheduler scheduler;

  /// How this widget combines cache and network (see [FetchPolicy]);
  /// defaults to `SlingClient.fetchPolicy`. `cacheAndNetwork` shows cached
  /// data and refreshes it once when the widget mounts; `networkOnly`
  /// shows skeletons until its own request lands. Read when the widget's
  /// scope is created (first build); changing it later has no effect.
  final FetchPolicy? fetchPolicy;

  /// Stale-while-revalidate window for this widget (see `QueryScope.maxAge`);
  /// defaults to `SlingClient.maxAge`. Read when the scope is created.
  final Duration? maxAge;

  /// Names this widget's scope in dev-mode waterfall warnings
  /// (see `SlingClient.onWaterfall`) and in `SlingRequest.scopes` (the
  /// request overlay). Defaults to the widget's [key] when set, then
  /// (debug builds) the type of the enclosing widget (`LaunchesScreen`),
  /// otherwise a generated `QueryScope#n`.
  final String? debugLabel;

  /// Optional selection function run *in addition to* the builder, so fields
  /// hidden behind conditionals are fetched in the first round trip instead
  /// of causing waterfalls.
  final void Function(Q query)? prepare;

  @override
  State<QueryBuilder<Q>> createState() => _QueryBuilderState<Q>();
}

class _QueryBuilderState<Q extends Accessor> extends State<QueryBuilder<Q>> {
  QueryScope<Q>? _scope;
  SlingClient<Q>? _client;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = SlingScope.of<Q>(context);
    if (client != _client) {
      _scope?.dispose();
      _client = client;
      _scope = client.createScope(
        onChanged: _onChanged,
        scheduler: widget.scheduler,
        debugLabel:
            widget.debugLabel ??
            widget.key?.toString() ??
            debugOwnerLabel(context),
        fetchPolicy: widget.fetchPolicy,
        maxAge: widget.maxAge,
        errorPolicy: widget.errorPolicy,
        timeout: widget.timeout,
      );
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scope?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope!;
    return scope.run((query) {
      widget.prepare?.call(query);
      return widget.builder(context, query, QueryState(scope));
    });
  }
}

typedef RowWidgetBuilder<T extends Accessor> = Widget Function(
  BuildContext context,
  T value,
);

/// Rebuilds on its own when the data *it* read changes — one row of a long
/// list, a card, any subtree of a [QueryBuilder] that should not rebuild its
/// parent (and every sibling) when one entity changes.
///
/// ```dart
/// QueryBuilder<Query>(
///   builder: (context, q, state) => ListView(children: [
///     for (final launch in q.launches()?.nodes ?? const <Launch>[])
///       SlingRow(launch, ctor: Launch.new,
///           builder: (context, launch) => LaunchRow(launch)),
///   ]),
/// )
/// ```
///
/// [value] is an accessor the enclosing [QueryBuilder] handed out; [builder]
/// receives the same object rebound to the row's own scope (via [ctor], the
/// generated constructor tear-off). Every field read through it — in
/// [builder] or in widgets it creates — is a dependency of the row only: a
/// write to `Launch:x.favorite` (a mutation, a subscription event, an
/// optimistic setter) rebuilds this row, not the list. Fetching is
/// unchanged: misses go to the enclosing query's batched request, and its
/// `QueryState` still reports loading and errors.
///
/// The parent keeps depending on what it read itself (the list), so rows
/// are added and removed as before. Read the row's fields only through the
/// accessor [builder] receives: reads through the parent's copy (`launch`
/// in the parent's closure) still land on the parent.
///
/// An accessor not handed out by a query (a `client.cacheScope` one, a
/// mutation result) is passed through unscoped.
class SlingRow<T extends Accessor> extends StatefulWidget {
  const SlingRow(
    this.value, {
    super.key,
    required this.ctor,
    required this.builder,
  });

  final T value;

  /// The generated constructor tear-off of [T] (`Launch.new`).
  final T Function(Recorder, Selection, List<Object>) ctor;

  final RowWidgetBuilder<T> builder;

  @override
  State<SlingRow<T>> createState() => _SlingRowState<T>();
}

class _SlingRowState<T extends Accessor> extends State<SlingRow<T>> {
  RowScope? _row;

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _row?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final owner = QueryScope.ownerOf(value.recorder);
    if (owner == null) return widget.builder(context, value);
    var row = _row;
    if (row == null || row.parent != owner) {
      row?.dispose();
      row = _row = owner.row(onChanged: _onChanged);
    }
    return row.run(
      value,
      widget.ctor,
      (bound) => widget.builder(context, bound),
    );
  }
}

/// Runs a mutation: records the fields read in [body], sends it, returns the
/// value [body] computes from the response. Resolves to `null` on failure
/// (the error is on [MutationState.error]). The named arguments are
/// `SlingClient.mutateWith`'s; with `offline: true` a call the server cannot
/// be reached for is queued ([MutationState.isQueued]) and resolves once it
/// is replayed.
typedef Mutate<M extends Accessor> = Future<T?> Function<T>(
  T Function(M mutation) body, {
  void Function()? optimistic,
  Iterable<String>? refetchQueries,
  ErrorPolicy? errorPolicy,
  Duration? timeout,
  RetryPolicy? retry,
  bool offline,
});

/// Status of the last mutation run by a [MutationBuilder].
///
/// Describes the *latest* `mutate` call only: when calls overlap, an earlier
/// one finishing later does not overwrite the state of a newer one.
class MutationState {
  /// [MutationBuilder] builds one per build; public for adapters that call
  /// `SlingClient.mutateWith` themselves (`sling_gql_hooks`).
  const MutationState({
    this.isLoading = false,
    this.isQueued = false,
    this.error,
    this.data,
  });

  /// A `mutate` call is in flight.
  final bool isLoading;

  /// The last call (`offline: true`) could not reach the server and waits
  /// in the client's mutation queue, its optimistic writes applied (see
  /// `SlingClient.mutateWith`). [isLoading] is false meanwhile; once it is
  /// replayed the state shows its [data] or [error] like any call.
  final bool isQueued;

  /// Why the last call failed (network, HTTP, GraphQL errors, …), or
  /// `null`. Cleared when the next call starts. `mutate` itself never throws
  /// a [SlingException]: it resolves to `null` and puts it here. Under
  /// [ErrorPolicy.all] a partial response sets both [error] and [data].
  final SlingException? error;

  /// What the body returned for the last call that succeeded (or landed
  /// partially under [ErrorPolicy.all]), computed from
  /// the cache after the response landed — the same value that call's
  /// `mutate` future resolved to. Kept while a new call is loading (no
  /// flicker), cleared when a call fails; `null` before the first call.
  ///
  /// Untyped because every `mutate` call may return a different type: cast
  /// it (`state.data as bool?`), or use the awaited value of `mutate`.
  final Object? data;
}

typedef MutationWidgetBuilder<M extends Accessor> = Widget Function(
  BuildContext context,
  Mutate<M> mutate,
  MutationState state,
);

/// The `useMutation()` equivalent. Hands the builder a typed `mutate`
/// function and the loading/error/data state of the last call:
///
/// ```dart
/// MutationBuilder<Mutation>(
///   builder: (context, mutate, state) => CupertinoButton(
///     onPressed: state.isLoading
///         ? null
///         : () => mutate(
///               (m) => m.toggleFavorite(launchId: id)?.favorite,
///               optimistic: () => launch.favorite = !favorite,
///             ),
///     child: Icon(favorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart),
///   ),
/// )
/// ```
///
/// The mutation root is resolved from the nearest [SlingScope] (its
/// `schema:`, or its client's) unless [root] is given explicitly, which
/// always wins.
///
/// The response is normalized into the shared cache, so the widgets reading
/// the returned entities — here every copy of the launch — rebuild on their own.
///
/// `mutate` resolves to the body's value, or to `null` when the call fails —
/// it never throws; the exception is in [MutationState.error] (the optimistic
/// writes are already rolled back). A partial GraphQL error is a failure too,
/// though the fields that resolved are cached (see `SlingClient.mutateWith`).
/// Tell a failure from a `null` result by `state.error`, or call
/// `client.mutate` directly to get the exception.
class MutationBuilder<M extends Accessor> extends StatefulWidget {
  const MutationBuilder({
    super.key,
    this.root,
    required this.builder,
    this.debugLabel,
  });

  /// Names this widget's mutations in `SlingRequest.scopes` (the request
  /// overlay). Defaults (debug builds) to the type of the enclosing widget.
  final String? debugLabel;

  /// The generated `Mutation.root` constructor. Optional: when omitted, it is
  /// resolved from the nearest [SlingScope] via [SlingScope.mutationRootOf].
  final RootFactory<M>? root;

  final MutationWidgetBuilder<M> builder;

  @override
  State<MutationBuilder<M>> createState() => _MutationBuilderState<M>();
}

class _MutationBuilderState<M extends Accessor>
    extends State<MutationBuilder<M>> {
  bool _loading = false;
  bool _queued = false;
  SlingException? _error;
  Object? _data;
  // Incremented per `mutate` call; only the latest call updates the state.
  int _call = 0;
  RootFactory<M>? _root;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _root = widget.root ?? SlingScope.mutationRootOf<M>(context);
  }

  @override
  void didUpdateWidget(MutationBuilder<M> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.root != oldWidget.root) {
      _root = widget.root ?? SlingScope.mutationRootOf<M>(context);
    }
  }

  Future<T?> _mutate<T>(
    T Function(M mutation) body, {
    void Function()? optimistic,
    Iterable<String>? refetchQueries,
    ErrorPolicy? errorPolicy,
    Duration? timeout,
    RetryPolicy? retry,
    bool offline = false,
  }) async {
    final client = SlingScope.clientOf(context);
    final call = ++_call;
    setState(() {
      _loading = true;
      _queued = false;
      _error = null;
    });
    void settle(void Function() update) {
      if (!mounted || call != _call) return;
      setState(() {
        update();
        _loading = false;
        _queued = false;
      });
    }

    try {
      final result = await client.mutateWith(
        _root!,
        body,
        optimistic: optimistic,
        refetchQueries: refetchQueries,
        debugLabel: widget.debugLabel ?? debugOwnerLabel(context),
        errorPolicy: errorPolicy,
        timeout: timeout,
        retry: retry,
        offline: offline,
        onQueued: () {
          if (!mounted || call != _call) return;
          setState(() {
            _loading = false;
            _queued = true;
          });
        },
      );
      settle(() => _data = result);
      return result;
    } on SlingException catch (e) {
      // `ErrorPolicy.all`: the call landed, with errors.
      final landed =
          e is SlingGraphQLException &&
          e.isPartial &&
          (errorPolicy ?? client.errorPolicy) == ErrorPolicy.all;
      final data = landed ? e.data as T : null;
      settle(() {
        _error = e;
        _data = data;
      });
      return data;
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _mutate,
    MutationState(
      isLoading: _loading,
      isQueued: _queued,
      error: _error,
      data: _data,
    ),
  );
}

/// Status of a [SubscriptionBuilder]'s connection.
class SubscriptionState {
  /// [SubscriptionBuilder] builds one per build; public for adapters that
  /// call `SlingClient.subscribeWith` themselves (`sling_gql_hooks`).
  const SubscriptionState({
    required this.isActive,
    required this.isConnected,
    required this.isReconnecting,
    required this.eventCount,
    required this.error,
    required this.reconnect,
  });

  /// The subscription is alive: connected, or waiting to reconnect. False
  /// before the first frame, after a server `complete`, and after a
  /// transport failure without a `retryAfter`.
  final bool isActive;

  /// The connection is open: events can arrive right now.
  final bool isConnected;

  /// The connection dropped and a reopen is scheduled (`retryAfter`).
  final bool isReconnecting;

  /// Events received so far; `0` until the first one lands.
  final int eventCount;

  /// The last error — a partial GraphQL error on an event, or the transport
  /// failure that dropped the connection; cleared by the next event.
  final SlingException? error;

  /// Reopens a dropped connection now (a "reconnect" button). A no-op while
  /// connected.
  final void Function() reconnect;

  /// At least one event has been written to the cache.
  bool get hasEvent => eventCount > 0;
}

typedef SubscriptionWidgetBuilder<S extends Accessor> = Widget Function(
  BuildContext context,
  S? subscription,
  SubscriptionState state,
);

/// Keeps a subscription open while mounted. [select] runs once to record
/// the selection (read every field you want in the document, like `prepare`
/// on a [QueryBuilder]); the stream opens on mount and every event is
/// normalized into the shared cache like a query response — the
/// [QueryBuilder]s showing the same entities rebuild on their own.
///
/// [builder] runs on mount and after each event, with `subscription` bound
/// to the cache (`null` before the first event): read the event's fields
/// through it (`subscription?.launchStatusChanged?.status`) or ignore it and
/// just return the child when the cache write is all you want.
///
/// ```dart
/// SubscriptionBuilder<Subscription>(
///   select: (s) => s.launchStatusChanged?..status..name,
///   builder: (context, s, state) => Row(children: [
///     if (state.isActive) const LiveDot(),
///     Text(s?.launchStatusChanged?.name ?? 'waiting…'),
///   ]),
/// )
/// ```
///
/// [onEvent] runs on each event, before the rebuild and outside `build`:
/// the place for side effects such as a list-membership edit
/// (`client.cacheScope.list((q) => q.launches()?.nodes).prepend(launch)`)
/// or a snackbar.
///
/// The connection opens at the end of the first frame (like a query's
/// flush), so [SubscriptionState.isActive] is false during that build. A
/// dropped connection is reopened after [retryAfter] (default:
/// `SlingClient.subscriptionRetryAfter`) — [SubscriptionState.reconnect] does
/// it at once — or ends the subscription when there is none.
///
/// The root is resolved from the nearest [SlingScope]'s `schema:` unless
/// [root] is given. Changing [select] does not reopen the subscription;
/// use a [Key] to get a new one.
class SubscriptionBuilder<S extends Accessor> extends StatefulWidget {
  const SubscriptionBuilder({
    super.key,
    this.root,
    required this.select,
    required this.builder,
    this.onEvent,
    this.retryAfter,
    this.debugLabel,
  });

  /// Names this subscription in `SlingRequest.scopes` (the request
  /// overlay). Defaults (debug builds) to the type of the enclosing widget.
  final String? debugLabel;

  /// Delay before reopening a dropped connection; defaults to
  /// `SlingClient.subscriptionRetryAfter`. Read when the subscription is
  /// created.
  final Duration? retryAfter;

  /// The generated `Subscription.root` constructor. Optional: when omitted,
  /// it is resolved from the nearest [SlingScope] via
  /// [SlingScope.subscriptionRootOf].
  final RootFactory<S>? root;

  /// Records the document: every field read here is selected.
  final void Function(S subscription) select;

  final SubscriptionWidgetBuilder<S> builder;

  /// Called with the root accessor after each event was written to the
  /// cache, before this widget rebuilds.
  final void Function(S subscription)? onEvent;

  @override
  State<SubscriptionBuilder<S>> createState() => _SubscriptionBuilderState<S>();
}

class _SubscriptionBuilderState<S extends Accessor>
    extends State<SubscriptionBuilder<S>> {
  SlingClient<Accessor>? _client;
  SlingSubscription<S>? _subscription;
  StreamSubscription<S>? _listener;
  S? _latest;
  bool _active = false;
  SlingException? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = SlingScope.clientOf(context);
    if (client != _client) {
      _close();
      _client = client;
      final root = widget.root ?? SlingScope.subscriptionRootOf<S>(context);
      final sub = client.subscribeWith<S, S>(
        root,
        (s) {
          widget.select(s);
          return s;
        },
        retryAfter: widget.retryAfter,
        debugLabel: widget.debugLabel ?? debugOwnerLabel(context),
      );
      _subscription = sub;
      sub.onStatusChanged = () {
        if (mounted) setState(() {});
      };
      // Opening a connection is a side effect: not during build.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _subscription != sub) return;
        _listener = sub.stream.listen(
          (s) {
            widget.onEvent?.call(s);
            if (!mounted) return;
            setState(() {
              _latest = s;
              _error = null;
            });
          },
          onError: (Object e, StackTrace st) {
            if (mounted) setState(() => _error = SlingException.from(e, st));
          },
          onDone: () {
            if (mounted) setState(() => _active = false);
          },
        );
        _active = true; // onStatusChanged rebuilt us
      });
    }
  }

  void _close() {
    _listener?.cancel();
    _listener = null;
    _subscription = null;
    _latest = null;
    _active = false;
    _error = null;
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _latest,
    SubscriptionState(
      isActive: _active && (_subscription?.isActive ?? false),
      isConnected: _subscription?.isConnected ?? false,
      isReconnecting: _subscription?.isReconnecting ?? false,
      eventCount: _subscription?.eventCount ?? 0,
      error: _error,
      reconnect: () {
        _subscription?.reconnect();
        if (mounted) setState(() {});
      },
    ),
  );
}
