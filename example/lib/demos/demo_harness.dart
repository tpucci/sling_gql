import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:sling_gql/sling_gql.dart';

import '../generated/schema.dart';
import '../in_browser_api.dart';
import '../main.dart' show endpoint;
import '../mock_latency.dart';
import '../theme.dart';

/// Frame of one concept demo (the website embeds them after each guide):
/// the demo's own [SlingClient] — a fresh, empty cache every time it
/// restarts — above a panel listing every request it sent.
///
/// The harness restarts when [resetKey] changes (a demo's mode switch) or
/// on "Run again", so each run starts from nothing and the request count is
/// the demo's alone.
class DemoHarness extends StatefulWidget {
  const DemoHarness({
    super.key,
    required this.child,
    this.controls,
    this.resetKey,
    this.latency = const Duration(milliseconds: 800),
    this.failMutations = false,
    this.failRequests = false,
  });

  final Widget child;

  /// Mode switches shown above the demo.
  final Widget? controls;

  /// Restart with a fresh client when this changes.
  final Object? resetKey;

  /// Mock API latency per request, long enough to see loading states.
  final Duration latency;

  /// Answer mutations with HTTP 503 (after [latency]) instead of sending
  /// them, to show an optimistic write being rolled back.
  final bool failMutations;

  /// Answer every request (queries too) with HTTP 503. Read on each request,
  /// so flipping it takes effect without a restart.
  final bool failRequests;

  static DemoHarnessState of(BuildContext context) =>
      context.findAncestorStateOfType<DemoHarnessState>()!;

  @override
  State<DemoHarness> createState() => DemoHarnessState();
}

class DemoHarnessState extends State<DemoHarness> {
  late SlingClient<Query> _client;
  final List<PrintedOperation> _requests = [];
  int _run = 0;

  /// The client of the current run (tests wait on it).
  SlingClient<Query> get client => _client;

  /// What the current run sent, newest first (tests read it).
  List<PrintedOperation> get requests => List.unmodifiable(_requests);

  @override
  void initState() {
    super.initState();
    _client = _createClient();
  }

  @override
  void didUpdateWidget(DemoHarness oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey) restart();
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  /// Throws the cache away and runs the demo again.
  void restart() {
    setState(() {
      _client.dispose();
      _requests.clear();
      _run++;
      _client = _createClient();
    });
  }

  /// Sends [document] straight to the mock API, bypassing this demo's client
  /// (so its cache does not know): "someone else changed the data".
  Future<void> changeOnServer(String document) async {
    final client = mockApiHttpClient();
    try {
      await client.post(
        Uri.parse(endpoint),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'query': document}),
      );
    } finally {
      client.close();
    }
  }

  SlingClient<Query> _createClient() {
    final httpClient = mockApiHttpClient();
    return SlingClient<Query>(
      endpoint: Uri.parse(endpoint),
      schema: slingSchema,
      httpClient: httpClient,
      transport: (request) async {
        if (widget.failRequests ||
            (widget.failMutations && _isMutation(request))) {
          await Future<void>.delayed(widget.latency);
          return http.Response('Service unavailable', 503);
        }
        request.headers[MockLatencyController.header] =
            '${widget.latency.inMilliseconds}';
        return http.Response.fromStream(await httpClient.send(request));
      },
      onOperation: (op) {
        if (mounted) setState(() => _requests.insert(0, op));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  if (widget.controls != null)
                    Expanded(child: widget.controls!),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    onPressed: restart,
                    child: const Icon(CupertinoIcons.refresh, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: SlingScope<Query>(
                key: ValueKey(_run),
                client: _client,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: widget.child,
                ),
              ),
            ),
            Container(height: 1, color: kColorHairline),
            Expanded(
              flex: 2,
              child: _RequestPanel(
                [
                  for (final op in _requests)
                    if (!op.document.startsWith('subscription')) op,
                ],
                subscriptions: _requests
                    .where((op) => op.document.startsWith('subscription'))
                    .length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestPanel extends StatelessWidget {
  const _RequestPanel(this.requests, {this.subscriptions = 0});
  final List<PrintedOperation> requests;

  /// Open subscriptions: connections, not requests.
  final int subscriptions;

  @override
  Widget build(BuildContext context) {
    final n = requests.length;
    return Container(
      color: kColorBarBackground,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            n == 1 ? '1 request' : '$n requests',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kColorAccent,
            ),
          ),
          if (subscriptions > 0)
            Text(
              subscriptions == 1
                  ? '1 subscription open'
                  : '$subscriptions subscriptions open',
              style: const TextStyle(fontSize: 12, color: kColorTextSecondary),
            ),
          for (final (i, op) in requests.indexed) ...[
            const SizedBox(height: 8),
            Text(
              '#${n - i}',
              style: const TextStyle(fontSize: 12, color: kColorTextSecondary),
            ),
            Text(
              op.document,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 11,
                color: kColorTextPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A segmented control over [values], for the demos' mode switches.
class DemoModes<T extends Object> extends StatelessWidget {
  const DemoModes({
    super.key,
    required this.values,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T) label;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => CupertinoSlidingSegmentedControl<T>(
    groupValue: value,
    onValueChanged: (v) {
      if (v != null) onChanged(v);
    },
    children: {
      for (final v in values)
        v: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(label(v), style: const TextStyle(fontSize: 12)),
        ),
    },
  );
}

bool _isMutation(http.Request request) {
  final query = (jsonDecode(request.body) as Map)['query'];
  return query is String && query.trimLeft().startsWith('mutation');
}
