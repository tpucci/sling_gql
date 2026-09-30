import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sling_gql/sling_gql.dart';

import 'debug_label.dart';

/// The [QueryBuilder] of a [HookWidget]: runs [select] in this widget's own
/// [QueryScope] on every build and returns what it computed, with the
/// scope's [QueryState].
///
/// ```dart
/// class LaunchTile extends HookWidget {
///   const LaunchTile({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final (launch, state) = useSlingQuery(
///       (Query q) => q.latestLaunch?..name..rocket?.name,
///     );
///     return ListTile(
///       title: Text(launch?.name ?? '…'),
///       subtitle: Text(launch?.rocket?.name ?? '…'),
///     );
///   }
/// }
/// ```
///
/// Every field read inside [select] is recorded, fetched in the frame's
/// batched request (at the end of the frame, like [QueryBuilder]) and
/// becomes a dependency: the widget rebuilds when a response, a mutation, a
/// subscription event or an optimistic write touches it.
///
/// **Read in [select] what the build needs.** [select] is what
/// [QueryBuilder]'s `builder` is: the run whose reads decide
/// [QueryState.hasMissingData], `maxAge` staleness, what `cacheAndNetwork`
/// refetches and whether a sticky error still applies. Accessors it returns
/// stay bound to the scope — reading more fields through them later in
/// `build` (or in child widgets) still fetches them, like a [QueryBuilder]'s
/// children do — but those reads are not part of that bookkeeping. The
/// cascade (`q.latestLaunch?..name..rocket?.name`) reads fields and returns
/// the object; a record (`(q.me.name, q.me.age)`) returns the values.
///
/// [fetchPolicy], [maxAge] and [scheduler] are [QueryBuilder]'s and, like
/// there, are read once, when the scope is created (first build, or when the
/// [SlingScope] above provides another client). [debugLabel] names the scope
/// in `SlingRequest.scopes` and waterfall warnings; it defaults to this
/// widget's key, then (debug builds) its type — inside a [HookBuilder], the
/// enclosing widget's.
///
/// Needs a `SlingScope<Q>` above. The scope is disposed with the widget.
(T, QueryState) useSlingQuery<Q extends Accessor, T>(
  T Function(Q query) select, {
  FetchPolicy? fetchPolicy,
  Duration? maxAge,
  String? debugLabel,
  FlushScheduler scheduler = frameEndScheduler,
}) => use(
  _SlingQueryHook<Q, T>(
    select,
    fetchPolicy: fetchPolicy,
    maxAge: maxAge,
    debugLabel: debugLabel,
    scheduler: scheduler,
  ),
);

class _SlingQueryHook<Q extends Accessor, T> extends Hook<(T, QueryState)> {
  const _SlingQueryHook(
    this.select, {
    this.fetchPolicy,
    this.maxAge,
    this.debugLabel,
    required this.scheduler,
  });

  final T Function(Q query) select;
  final FetchPolicy? fetchPolicy;
  final Duration? maxAge;
  final String? debugLabel;
  final FlushScheduler scheduler;

  @override
  _SlingQueryHookState<Q, T> createState() => _SlingQueryHookState<Q, T>();
}

class _SlingQueryHookState<Q extends Accessor, T>
    extends HookState<(T, QueryState), _SlingQueryHook<Q, T>> {
  SlingClient<Q>? _client;
  QueryScope<Q>? _scope;
  bool _disposed = false;

  void _onChanged() {
    if (!_disposed) setState(() {});
  }

  @override
  (T, QueryState) build(BuildContext context) {
    final client = SlingScope.of<Q>(context);
    if (client != _client) {
      _scope?.dispose();
      _client = client;
      _scope = client.createScope(
        onChanged: _onChanged,
        scheduler: hook.scheduler,
        debugLabel:
            hook.debugLabel ??
            context.widget.key?.toString() ??
            debugHookOwnerLabel(context),
        fetchPolicy: hook.fetchPolicy,
        maxAge: hook.maxAge,
      );
    }
    final scope = _scope!;
    return (scope.run(hook.select), QueryState(scope));
  }

  @override
  void dispose() {
    _disposed = true;
    _scope?.dispose();
  }

  @override
  String get debugLabel => 'useSlingQuery<$Q>';
}
