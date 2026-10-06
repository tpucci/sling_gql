import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sling_gql/sling_gql.dart';

import 'debug_label.dart';

/// The [MutationBuilder] of a [HookWidget]: a typed `mutate` function and
/// the [MutationState] of its latest call.
///
/// ```dart
/// class FavoriteButton extends HookWidget {
///   const FavoriteButton({super.key, required this.launch});
///   final Launch launch;
///
///   @override
///   Widget build(BuildContext context) {
///     final favorite = launch.favorite ?? false;
///     final (mutate, state) = useSlingMutation<Mutation>();
///     return CupertinoButton(
///       onPressed: state.isLoading
///           ? null
///           : () => mutate(
///                 (m) => m.toggleFavorite(launchId: launch.id!)?.favorite,
///                 optimistic: () => launch.favorite = !favorite,
///               ),
///       child: Icon(favorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart),
///     );
///   }
/// }
/// ```
///
/// Same contract as [MutationBuilder]: `mutate` records the fields [body]
/// reads, sends the mutation at once (never batched), normalizes the
/// response into the shared cache — widgets showing the returned entities
/// rebuild on their own — and resolves to the body's value computed from the
/// cache, or to `null` on failure (it never throws a [SlingException]; it is
/// on [MutationState.error], optimistic writes are rolled back; under
/// [ErrorPolicy.all] a partial response sets both [MutationState.data] and
/// the error). Its named arguments are `SlingClient.mutateWith`'s. The state
/// describes the latest call only; this widget rebuilds when it changes.
///
/// `mutate` is the same function across builds (safe as a `useCallback` /
/// `useEffect` key). The mutation root is [root], or the nearest
/// [SlingScope]'s (`mutationRoot:` / `schema:`). [debugLabel] names the
/// calls in `SlingRequest.scopes`; it defaults (debug builds) to this
/// widget's type.
(Mutate<M>, MutationState) useSlingMutation<M extends Accessor>({
  RootFactory<M>? root,
  String? debugLabel,
}) {
  final hook = use(_SlingMutationHook<M>(root: root, debugLabel: debugLabel));
  return (hook.mutate, hook.state);
}

/// What the hook builds. Not the `(Mutate<M>, MutationState)` record
/// itself: the Dart VM (3.13) mis-substitutes `M` into `Mutate<M>`'s own
/// type parameter when a generic function type appears in a supertype's type
/// argument (`Hook<(Mutate<M>, …)>`), failing `HookState`'s runtime checks.
class _SlingMutationValue<M extends Accessor> {
  const _SlingMutationValue(this.mutate, this.state);

  final Mutate<M> mutate;
  final MutationState state;
}

class _SlingMutationHook<M extends Accessor>
    extends Hook<_SlingMutationValue<M>> {
  const _SlingMutationHook({this.root, this.debugLabel});

  final RootFactory<M>? root;
  final String? debugLabel;

  @override
  _SlingMutationHookState<M> createState() => _SlingMutationHookState<M>();
}

class _SlingMutationHookState<M extends Accessor>
    extends HookState<_SlingMutationValue<M>, _SlingMutationHook<M>> {
  bool _loading = false;
  SlingException? _error;
  Object? _data;
  // Incremented per `mutate` call; only the latest call updates the state.
  int _call = 0;
  bool _disposed = false;

  // Resolved on each build, like MutationBuilder's dependencies.
  late SlingClient<Accessor> _client;
  late RootFactory<M> _root;
  String? _label;

  Future<T?> _mutate<T>(
    T Function(M mutation) body, {
    void Function()? optimistic,
    Iterable<String>? refetchQueries,
    ErrorPolicy? errorPolicy,
    Duration? timeout,
    RetryPolicy? retry,
  }) async {
    final call = ++_call;
    setState(() {
      _loading = true;
      _error = null;
    });
    void settle(void Function() update) {
      if (_disposed || call != _call) return;
      setState(() {
        update();
        _loading = false;
      });
    }

    try {
      final result = await _client.mutateWith(
        _root,
        body,
        optimistic: optimistic,
        refetchQueries: refetchQueries,
        debugLabel: _label,
        errorPolicy: errorPolicy,
        timeout: timeout,
        retry: retry,
      );
      settle(() => _data = result);
      return result;
    } on SlingException catch (e) {
      // `ErrorPolicy.all`: the call landed, with errors.
      final landed =
          e is SlingGraphQLException &&
          e.isPartial &&
          (errorPolicy ?? _client.errorPolicy) == ErrorPolicy.all;
      final data = landed ? e.data as T : null;
      settle(() {
        _error = e;
        _data = data;
      });
      return data;
    }
  }

  @override
  _SlingMutationValue<M> build(BuildContext context) {
    _client = SlingScope.clientOf(context);
    _root = hook.root ?? SlingScope.mutationRootOf<M>(context);
    _label = hook.debugLabel ?? debugHookOwnerLabel(context);
    return _SlingMutationValue<M>(
      _mutate,
      MutationState(isLoading: _loading, error: _error, data: _data),
    );
  }

  @override
  void dispose() => _disposed = true;

  @override
  String get debugLabel => 'useSlingMutation<$M>';
}
