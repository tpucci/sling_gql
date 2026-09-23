import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'accessor.dart';
import 'client.dart';

/// Provides a [SlingClient] to the widget tree.
class SlingScope<Q extends Accessor> extends InheritedWidget {
  const SlingScope({super.key, required this.client, required super.child});

  final SlingClient<Q> client;

  static SlingClient<Q> of<Q extends Accessor>(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SlingScope<Q>>();
    assert(scope != null, 'No SlingScope<$Q> found above this widget');
    return scope!.client;
  }

  @override
  bool updateShouldNotify(SlingScope<Q> oldWidget) => client != oldWidget.client;
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
