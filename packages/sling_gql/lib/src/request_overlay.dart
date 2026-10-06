import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'accessor.dart';
import 'client.dart';
import 'widgets.dart';

/// Dev overlay listing every operation the client sends, one line each, with
/// the widgets that asked for it:
///
/// ```text
/// #3 query launches, company · 42 ms · 1.2 KB · 18 fields
///    ← LaunchesScreen, LaunchTile ×12
/// ```
///
/// A small chip (request count, last duration, red on error) floats over
/// [child]; tap it for the list, tap a line for its document. Wrap the app
/// below its [SlingScope] — `CupertinoApp(builder: (context, child) =>
/// SlingRequestOverlay(child: child!))` — or pass [client].
///
/// Requests are attributed to the scopes whose selections are in the
/// document (see [SlingRequest.scopes]): name a `QueryBuilder` with
/// `debugLabel:` when its enclosing widget is not telling enough.
///
/// Off unless [enabled] (default: debug builds): then it is [child] and
/// nothing else, and the client builds no records.
class SlingRequestOverlay extends StatefulWidget {
  const SlingRequestOverlay({
    super.key,
    required this.child,
    this.client,
    this.enabled = kDebugMode,
    this.capacity = 100,
    this.alignment = AlignmentDirectional.bottomStart,
    this.margin = const EdgeInsets.fromLTRB(8, 8, 8, 96),
  });

  final Widget child;

  /// The client to watch; defaults to the nearest [SlingScope]'s.
  final SlingClient<Accessor>? client;

  final bool enabled;

  /// Requests kept, newest first; older ones are dropped.
  final int capacity;

  /// Where the chip sits. The default keeps it clear of tab bars and of
  /// the middle of list rows.
  final AlignmentGeometry alignment;

  /// Space between the chip and the safe area's edges.
  final EdgeInsets margin;

  @override
  State<SlingRequestOverlay> createState() => _SlingRequestOverlayState();
}

class _SlingRequestOverlayState extends State<SlingRequestOverlay> {
  SlingClient<Accessor>? _client;
  StreamSubscription<SlingRequest>? _subscription;
  final List<SlingRequest> _requests = [];
  final Set<SlingRequest> _known = {};
  final Set<SlingRequest> _expanded = {};
  var _open = false;
  var _rebuildScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watch();
  }

  @override
  void didUpdateWidget(SlingRequestOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _watch();
  }

  void _watch() {
    final client = widget.enabled
        ? widget.client ?? maybeSlingClientOf(context)
        : null;
    if (client == _client) return;
    _subscription?.cancel();
    _subscription = null;
    _client = client;
    _clear();
    if (client != null) _subscription = client.requests.listen(_onRequest);
  }

  void _onRequest(SlingRequest request) {
    if (_known.add(request)) {
      _requests.insert(0, request);
      while (_requests.length > widget.capacity) {
        final dropped = _requests.removeLast();
        _known.remove(dropped);
        _expanded.remove(dropped);
      }
    }
    _markNeedsBuild();
  }

  /// Requests are emitted synchronously, possibly while a frame is being
  /// built (a flush in a post-frame callback is fine, a build is not).
  void _markNeedsBuild() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks) {
      setState(() {});
      return;
    }
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _clear() {
    _requests.clear();
    _known.clear();
    _expanded.clear();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_client == null) return widget.child;
    final padding = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
    final overlay = Stack(
      children: [
        widget.child,
        if (_open)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height:
                (MediaQuery.maybeSizeOf(context)?.height ?? 600) * 0.5 +
                padding.bottom,
            child: _panel(padding),
          )
        else
          Positioned.fill(
            child: Padding(
              padding: padding + widget.margin,
              child: Align(alignment: widget.alignment, child: _chip()),
            ),
          ),
      ],
    );
    return DefaultTextStyle(
      style: _text,
      child: Directionality.maybeOf(context) == null
          ? Directionality(textDirection: TextDirection.ltr, child: overlay)
          : overlay,
    );
  }

  Widget _chip() {
    final last = _requests.firstOrNull;
    final failed = last?.error != null;
    final label = [
      _requests.length == 1 ? '1 req' : '${_requests.length} req',
      if (last != null)
        last.isDone || last.kind == 'subscription'
            ? '#${last.id} ${last.duration.inMilliseconds} ms'
            : '#${last.id} …',
    ].join(' · ');
    return GestureDetector(
      key: const ValueKey('sling-request-overlay-chip'),
      onTap: () => setState(() => _open = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: failed ? _error : _border),
        ),
        child: Text('⇅ $label', style: _text),
      ),
    );
  }

  Widget _panel(EdgeInsets padding) => Container(
    key: const ValueKey('sling-request-overlay-panel'),
    padding: EdgeInsets.only(bottom: padding.bottom),
    decoration: const BoxDecoration(
      color: _background,
      border: Border(top: BorderSide(color: _border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'sling_gql · ${_requests.length} requests',
                  style: _text.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              _button('Clear', () => setState(_clear)),
              _button('Close', () => setState(() => _open = false)),
            ],
          ),
        ),
        Expanded(
          child: _requests.isEmpty
              ? Center(child: Text('No request yet.', style: _dim))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: _requests.length,
                  itemBuilder: (context, i) => _row(_requests[i]),
                ),
        ),
      ],
    ),
  );

  Widget _button(String label, VoidCallback onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(label, style: _text.copyWith(color: _accent)),
    ),
  );

  Widget _row(SlingRequest r) {
    final expanded = _expanded.contains(r);
    final error = r.error;
    final line = r.logLine;
    // `#3 query launches · 42 ms · … ← scopes ✗ error`: the head on the
    // first line, attribution and error on their own.
    final arrow = line.indexOf(' ← ');
    final cross = line.indexOf(' ✗ ');
    final headEnd = arrow >= 0 ? arrow : (cross >= 0 ? cross : line.length);
    return GestureDetector(
      key: ObjectKey(r),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (!_expanded.remove(r)) _expanded.add(r);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _border, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line.substring(0, headEnd)),
            if (r.scopes.isNotEmpty)
              Text('   ← ${r.scopeSummary}', style: _scopes),
            if (error != null)
              Text(
                '   ✗ ${error.message}',
                style: _text.copyWith(color: _error),
              ),
            if (expanded) ...[
              const SizedBox(height: 4),
              Text(r.operation.document, style: _dim),
              if (r.operation.variables.isNotEmpty)
                Text('${r.operation.variables}', style: _dim),
            ],
          ],
        ),
      ),
    );
  }
}

const _background = Color(0xF0101418);
const _border = Color(0xFF3A4048);
const _accent = Color(0xFF6CB6FF);
const _error = Color(0xFFFF6B6B);
const _text = TextStyle(
  color: Color(0xFFE6E6E6),
  fontSize: 11,
  height: 1.35,
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Courier'],
  decoration: TextDecoration.none,
  fontWeight: FontWeight.normal,
);
final _dim = _text.copyWith(color: const Color(0xFF9AA0A6));
final _scopes = _text.copyWith(color: _accent);
