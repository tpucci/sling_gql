import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:http/http.dart' as http;
import 'package:sling_gql/sling_gql.dart';

import 'mock_latency.dart';
import 'theme.dart';
import 'widgets/cache_stats.dart';

/// One operation the client sent, as [SlingClient.requests] reports it
/// (timing, size, error, the widgets that asked for it), plus the response
/// body [NetworkLog.transport] saw.
class LogEntry {
  LogEntry(this.request, this.number);

  final SlingRequest request;

  /// 1 for the first request (or subscription) of the session.
  final int number;

  PrintedOperation get operation => request.operation;
  DateTime get sentAt => request.startedAt;
  String get document => operation.document;
  Map<String, Object?> get variables => operation.variables;

  /// `query`, `mutation` or `subscription`.
  String get type => request.kind;

  /// The root fields, by name (not alias): `company · stats · launches`.
  List<String> get rootFields => request.rootFields;

  /// The widgets whose reads are in the document:
  /// `LaunchesScreen, LaunchRow ×20`.
  String get scopes => request.scopeSummary;

  Duration? get duration => request.isDone ? request.duration : null;
  int? get statusCode => request.statusCode;
  int? get bytes => request.bytes;
  String? responseBody;

  bool get isDone => request.isDone;

  /// HTTP error, transport failure or GraphQL `errors`.
  String? get problem => switch (request.error) {
    null => null,
    SlingException(:final message) => message,
    final e => '$e',
  };
}

/// Keeps every GraphQL operation the client sent, newest first. The whole
/// point of the PoC is to *see* what the widgets produce.
///
/// Subscriptions are long-lived connections, not round trips: they go to
/// [subscriptions], so [entries] keeps counting requests.
class NetworkLog extends ChangeNotifier {
  final List<LogEntry> entries = [];
  final List<LogEntry> subscriptions = [];
  final Map<SlingRequest, LogEntry> _byRequest = {};

  /// Records every operation [client] sends from now on. Call it before the
  /// first request (right after building the client).
  StreamSubscription<SlingRequest> attach(SlingClient<Accessor> client) =>
      client.requests.listen((request) {
        if (!_byRequest.containsKey(request)) {
          final list = request.kind == 'subscription' ? subscriptions : entries;
          final entry = LogEntry(request, list.length + 1);
          _byRequest[request] = entry;
          list.insert(0, entry);
        }
        notifyListeners();
      });

  /// Wraps a [Transport] to keep each request's response body on its entry.
  Transport transport(Transport next) => (request) async {
    final entry = _pendingFor(request);
    final response = await next(request);
    entry?.responseBody = response.body;
    return response;
  };

  /// The oldest request still waiting whose document is [request]'s.
  LogEntry? _pendingFor(http.Request request) {
    final Object? query;
    try {
      query = (jsonDecode(request.body) as Map)['query'];
    } on FormatException {
      return null;
    }
    for (final entry in entries.reversed) {
      if (!entry.isDone && entry.document == query) return entry;
    }
    return null;
  }

  void clear() {
    entries.clear();
    subscriptions.clear();
    _byRequest.clear();
    notifyListeners();
  }
}

class NetworkLogScope extends InheritedNotifier<NetworkLog> {
  const NetworkLogScope({
    super.key,
    required NetworkLog log,
    required super.child,
  }) : super(notifier: log);

  static NetworkLog of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NetworkLogScope>()!.notifier!;
}

String _plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : many ?? '${one}s'}';

/// Nav-bar button with the request count; opens the log.
class NetworkLogButton extends StatelessWidget {
  const NetworkLogButton({super.key});

  @override
  Widget build(BuildContext context) {
    final log = NetworkLogScope.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (_) => const NetworkLogScreen()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 18),
          const SizedBox(width: 4),
          Text(
            _plural(log.entries.length, 'request'),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

enum _Section { requests, subscriptions, tools }

/// Requests · Subscriptions · Dev tools (mock latency, cache).
class NetworkLogScreen extends StatefulWidget {
  const NetworkLogScreen({super.key});

  @override
  State<NetworkLogScreen> createState() => _NetworkLogScreenState();
}

class _NetworkLogScreenState extends State<NetworkLogScreen> {
  var _section = _Section.requests;
  var _showAdded = false;

  @override
  Widget build(BuildContext context) {
    final log = NetworkLogScope.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Network'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: log.entries.isEmpty && log.subscriptions.isEmpty
              ? null
              : log.clear,
          child: const Text('Clear'),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: CupertinoSlidingSegmentedControl<_Section>(
                groupValue: _section,
                onValueChanged: (s) {
                  if (s != null) setState(() => _section = s);
                },
                children: {
                  _Section.requests: _segment(
                    'Requests (${log.entries.length})',
                  ),
                  _Section.subscriptions: _segment(
                    'Subscriptions (${log.subscriptions.length})',
                  ),
                  _Section.tools: _segment('Dev tools'),
                },
              ),
            ),
            Expanded(
              child: switch (_section) {
                _Section.requests => _OperationList(
                  entries: log.entries,
                  empty: 'No request yet.',
                  showAdded: _showAdded,
                  onShowAdded: (v) => setState(() => _showAdded = v),
                ),
                _Section.subscriptions => _OperationList(
                  entries: log.subscriptions,
                  empty: 'No subscription open.',
                  showAdded: _showAdded,
                  onShowAdded: (v) => setState(() => _showAdded = v),
                ),
                _Section.tools => const _DevTools(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(label, style: const TextStyle(fontSize: 13)),
  );
}

class _OperationList extends StatelessWidget {
  const _OperationList({
    required this.entries,
    required this.empty,
    required this.showAdded,
    required this.onShowAdded,
  });

  final List<LogEntry> entries;
  final String empty;
  final bool showAdded;
  final ValueChanged<bool> onShowAdded;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(empty, style: const TextStyle(color: kColorTextSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: entries.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Row(
            children: [
              const Expanded(
                child: Text(
                  'Show what sling_gql adds (__typename, aliases)',
                  style: TextStyle(fontSize: 13, color: kColorTextSecondary),
                ),
              ),
              CupertinoSwitch(value: showAdded, onChanged: onShowAdded),
            ],
          );
        }
        final entry = entries[i - 1];
        return _EntryTile(
          key: ObjectKey(entry),
          entry: entry,
          showAdded: showAdded,
        );
      },
    );
  }
}

/// One line per operation; tap for the document, variables and response.
class _EntryTile extends StatefulWidget {
  const _EntryTile({super.key, required this.entry, required this.showAdded});
  final LogEntry entry;
  final bool showAdded;

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final problem = e.problem;
    final isSubscription = e.type == 'subscription';
    final events = e.request.events == 1
        ? '1 event'
        : '${e.request.events} events';
    final result = isSubscription
        ? '${e.isDone ? 'closed' : 'open'} · $events'
        : !e.isDone
        ? 'sending…'
        : [
            if (e.duration != null) '${e.duration!.inMilliseconds} ms',
            if (e.bytes != null) _size(e.bytes!),
          ].join(' · ');
    final vars = e.variables.isEmpty ? null : jsonEncode(e.variables);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: kColorSurface,
          borderRadius: BorderRadius.circular(10),
          border: problem == null ? null : Border.all(color: kColorCoral),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${e.number}',
                  style: const TextStyle(
                    color: kColorTextSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                _TypeBadge(e.type),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.rootFields.join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _expanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 14,
                  color: kColorTextSecondary,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [_time(e.sentAt), result, ?vars].join(' · '),
              style: const TextStyle(fontSize: 12, color: kColorTextSecondary),
              maxLines: _expanded ? null : 1,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            if (e.scopes.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '\u2190 ${e.scopes}',
                style: const TextStyle(fontSize: 12, color: kColorAccent),
                maxLines: _expanded ? null : 1,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
            ],
            if (problem != null) ...[
              const SizedBox(height: 4),
              Text(
                problem,
                style: const TextStyle(fontSize: 12, color: kColorCoral),
              ),
            ],
            if (_expanded) ...[
              const SizedBox(height: 8),
              _Code(
                widget.showAdded ? e.document : readableDocument(e.document),
              ),
              if (e.responseBody case final body?) ...[
                const SizedBox(height: 8),
                const Text(
                  'Response',
                  style: TextStyle(fontSize: 12, color: kColorTextSecondary),
                ),
                const SizedBox(height: 4),
                _Code(_pretty(body)),
              ],
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: e.document)),
                child: const Text(
                  'Copy document',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.type);
  final String type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      'mutation' => kColorCoral,
      'subscription' => CupertinoColors.systemGreen,
      _ => CupertinoColors.systemBlue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(type, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

/// The document as the widgets read it: without the `__typename`s the
/// printer adds for the cache, and without the aliases it gives fields with
/// arguments (`launch_1ov936k1qddray: launch(…)`) or read in several
/// fragments (`name__Launch: name`).
String readableDocument(String document) => document
    .split('\n')
    .where((line) => line.trim() != '__typename')
    .map(
      (line) => line
          .replaceAllMapped(_hashAlias, (m) => '')
          .replaceAllMapped(_fragmentAlias, (m) => ''),
    )
    .join('\n');

final _hashAlias = RegExp(r'\b(\w+)_[0-9a-z]{6,}: (?=\1\b)');
final _fragmentAlias = RegExp(r'\b(\w+)__\w+: (?=\1\b)');

String _pretty(String body) {
  try {
    final text = const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
    return text.length > 4000 ? '${text.substring(0, 4000)}\n…' : text;
  } on FormatException {
    return body;
  }
}

String _size(int bytes) =>
    bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(1)} KB';

String _time(DateTime t) =>
    [t.hour, t.minute, t.second].map((v) => '$v'.padLeft(2, '0')).join(':');

/// Mock latency (to watch skeletons) and a live view of the cache.
class _DevTools extends StatelessWidget {
  const _DevTools();

  @override
  Widget build(BuildContext context) {
    final latency = MockLatencyScope.maybeOf(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (latency != null) ...[
          const Text(
            'Mock API latency',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Slow the network down to watch the loading placeholders.',
            style: TextStyle(fontSize: 12, color: kColorTextSecondary),
          ),
          const SizedBox(height: 8),
          MockLatencyPicker(latency: latency),
          const SizedBox(height: 24),
        ],
        const CacheStats(),
      ],
    );
  }
}

class _Code extends StatelessWidget {
  const _Code(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: kColorBackground,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: 11,
        height: 1.35,
        color: kColorTextPrimary,
      ),
    ),
  );
}
