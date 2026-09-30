import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:sling_gql/sling_gql.dart';

import 'debug_label.dart';

/// The [SubscriptionBuilder] of a [HookWidget]: keeps a subscription open
/// while the widget is mounted and returns the root accessor bound to the
/// cache (`null` before the first event) with the [SubscriptionState].
///
/// ```dart
/// class LiveStatus extends HookWidget {
///   const LiveStatus({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final (s, state) = useSlingSubscription(
///       (Subscription s) => s.launchStatusChanged?..status..name,
///     );
///     return Row(children: [
///       if (state.isActive) const LiveDot(),
///       Text(s?.launchStatusChanged?.name ?? 'waiting…'),
///     ]);
///   }
/// }
/// ```
///
/// Same contract as [SubscriptionBuilder]: [select] runs once to record the
/// document; the connection opens at the end of the first frame (so
/// [SubscriptionState.isActive] is false during that build); every event is
/// normalized into the shared cache — the queries showing the same entities
/// rebuild on their own — then [onEvent] runs and this widget rebuilds. A
/// dropped connection is reopened after [retryAfter] (default:
/// `SlingClient.subscriptionRetryAfter`), or ends the subscription without
/// one. The connection closes when the widget is disposed.
///
/// The root is [root], or the nearest [SlingScope]'s `schema:`. Changing
/// [select] does not reopen the subscription; give the widget a new [Key]
/// for a new one. [debugLabel] names it in `SlingRequest.scopes`; it
/// defaults (debug builds) to this widget's type.
(S?, SubscriptionState) useSlingSubscription<S extends Accessor>(
  void Function(S subscription) select, {
  RootFactory<S>? root,
  void Function(S subscription)? onEvent,
  Duration? retryAfter,
  String? debugLabel,
}) => use(
  _SlingSubscriptionHook<S>(
    select,
    root: root,
    onEvent: onEvent,
    retryAfter: retryAfter,
    debugLabel: debugLabel,
  ),
);

class _SlingSubscriptionHook<S extends Accessor>
    extends Hook<(S?, SubscriptionState)> {
  const _SlingSubscriptionHook(
    this.select, {
    this.root,
    this.onEvent,
    this.retryAfter,
    this.debugLabel,
  });

  final void Function(S subscription) select;
  final RootFactory<S>? root;
  final void Function(S subscription)? onEvent;
  final Duration? retryAfter;
  final String? debugLabel;

  @override
  _SlingSubscriptionHookState<S> createState() =>
      _SlingSubscriptionHookState<S>();
}

class _SlingSubscriptionHookState<S extends Accessor>
    extends HookState<(S?, SubscriptionState), _SlingSubscriptionHook<S>> {
  SlingClient<Accessor>? _client;
  SlingSubscription<S>? _subscription;
  StreamSubscription<S>? _listener;
  S? _latest;
  bool _active = false;
  Object? _error;
  bool _disposed = false;

  void _rebuild() {
    if (!_disposed) setState(() {});
  }

  void _open(BuildContext context, SlingClient<Accessor> client) {
    final root = hook.root ?? SlingScope.subscriptionRootOf<S>(context);
    final sub = client.subscribeWith<S, S>(
      root,
      (s) {
        hook.select(s);
        return s;
      },
      retryAfter: hook.retryAfter,
      debugLabel: hook.debugLabel ?? debugHookOwnerLabel(context),
    );
    _subscription = sub;
    sub.onStatusChanged = _rebuild;
    // Opening a connection is a side effect: not during build.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _subscription != sub) return;
      _listener = sub.stream.listen(
        (s) {
          hook.onEvent?.call(s);
          if (_disposed) return;
          setState(() {
            _latest = s;
            _error = null;
          });
        },
        onError: (Object e) {
          if (!_disposed) setState(() => _error = e);
        },
        onDone: () {
          if (!_disposed) setState(() => _active = false);
        },
      );
      _active = true; // onStatusChanged rebuilt us
    });
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
  (S?, SubscriptionState) build(BuildContext context) {
    final client = SlingScope.clientOf(context);
    if (client != _client) {
      _close();
      _client = client;
      _open(context, client);
    }
    final sub = _subscription;
    return (
      _latest,
      SubscriptionState(
        isActive: _active && (sub?.isActive ?? false),
        isConnected: sub?.isConnected ?? false,
        isReconnecting: sub?.isReconnecting ?? false,
        eventCount: sub?.eventCount ?? 0,
        error: _error,
        retry: () {
          _subscription?.reconnect();
          _rebuild();
        },
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _close();
  }

  @override
  String get debugLabel => 'useSlingSubscription<$S>';
}
