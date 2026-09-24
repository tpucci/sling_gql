import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'accessor.dart';
import 'client.dart';

/// Provides a [SlingClient] to the widget tree.
class SlingScope<Q extends Accessor> extends StatelessWidget {
  const SlingScope({super.key, required this.client, required this.child});

  final SlingClient<Q> client;
  final Widget child;

  /// The client, typed with its query root.
  static SlingClient<Q> of<Q extends Accessor>(BuildContext context) {
    final client = clientOf(context);
    assert(client is SlingClient<Q>, 'SlingScope above provides $client, not SlingClient<$Q>');
    return client as SlingClient<Q>;
  }

  /// The client without knowing its query root type — enough for mutations.
  static SlingClient<Accessor> clientOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_InheritedClient>();
    assert(scope != null, 'No SlingScope found above this widget');
    return scope!.client;
  }

  @override
  Widget build(BuildContext context) => _InheritedClient(client: client, child: child);
}

class _InheritedClient extends InheritedWidget {
  const _InheritedClient({required this.client, required super.child});

  final SlingClient<Accessor> client;

  @override
  bool updateShouldNotify(_InheritedClient oldWidget) => client != oldWidget.client;
}

/// Flushes at the end of the current (or next) frame, after layout, so that
/// children built lazily by slivers and lists are part of the same request as
/// their parents. Used by [QueryBuilder].
void frameEndScheduler(void Function() flush) {
  final binding = SchedulerBinding.instance;
  binding.addPostFrameCallback((_) => flush());
  binding.ensureVisualUpdate(); // no-op while a frame is already in progress
}

/// Read-only view of a [QueryScope]'s status, handed to builders.
class QueryState {
  const QueryState._(this._scope);

  final QueryScope _scope;

  /// A fetch containing this widget's selections is in flight.
  bool get isLoading => _scope.isLoading;

  /// The last run read data that is not (yet) cached — skeleton values were
  /// returned. Convenient for showing placeholders.
  bool get hasMissingData => _scope.hasMissingData;

  Object? get error => _scope.error;

  /// Re-fetch everything this widget selected in its last build.
  Future<void> refetch() => _scope.refetch();
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
  const QueryBuilder({super.key, required this.builder, this.prepare});

  final QueryWidgetBuilder<Q> builder;

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
        scheduler: frameEndScheduler,
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
      return widget.builder(context, query, QueryState._(scope));
    });
  }
}

/// Runs a mutation: records the fields read in [body], sends it, returns the
/// value [body] computes from the response. Resolves to `null` on failure
/// (the error is on [MutationState.error]).
typedef Mutate<M extends Accessor> = Future<T?> Function<T>(
  T Function(M mutation) body, {
  void Function()? optimistic,
});

/// Status of the last mutation run by a [MutationBuilder].
class MutationState {
  const MutationState._(this.isLoading, this.error);

  final bool isLoading;
  final Object? error;
}

typedef MutationWidgetBuilder<M extends Accessor> = Widget Function(
  BuildContext context,
  Mutate<M> mutate,
  MutationState state,
);

/// The `useMutation()` equivalent. Hands the builder a typed `mutate`
/// function and the loading/error state of the last call:
///
/// ```dart
/// MutationBuilder<Mutation>(
///   root: Mutation.root,
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
/// The response is normalized into the shared cache, so the widgets reading
/// the returned entities — here every copy of the launch — rebuild on their own.
class MutationBuilder<M extends Accessor> extends StatefulWidget {
  const MutationBuilder({super.key, required this.root, required this.builder});

  /// The generated `Mutation.root` constructor.
  final RootFactory<M> root;

  final MutationWidgetBuilder<M> builder;

  @override
  State<MutationBuilder<M>> createState() => _MutationBuilderState<M>();
}

class _MutationBuilderState<M extends Accessor> extends State<MutationBuilder<M>> {
  bool _loading = false;
  Object? _error;

  Future<T?> _mutate<T>(T Function(M mutation) body, {void Function()? optimistic}) async {
    final client = SlingScope.clientOf(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      return await client.mutateWith(widget.root, body, optimistic: optimistic);
    } catch (e) {
      _error = e;
      return null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _mutate, MutationState._(_loading, _error));
}
