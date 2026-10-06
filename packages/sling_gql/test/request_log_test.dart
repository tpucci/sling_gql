import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// Answers `me` (under whatever alias the document uses) and `rename`;
/// `fail` makes the next response an HTTP 500.
class _Server {
  var fail = false;
  late final http.Client http_ = MockClient((req) async {
    if (fail) return http.Response('boom', 500);
    final query = (jsonDecode(req.body) as Map)['query'] as String;
    if (query.startsWith('mutation')) {
      final alias = RegExp(r'(rename_\w+): rename').firstMatch(query)!;
      return http.Response(
        jsonEncode({
          'data': {
            alias.group(1): {'__typename': 'User', 'id': '1', 'name': 'Bo'},
          },
        }),
        200,
      );
    }
    return http.Response(jsonEncode({'data': meWithFriends()}), 200);
  });
}

SlingClient<Query> _client(_Server server, {bool logRequests = false}) =>
    SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      httpClient: server.http_,
      logRequests: logRequests,
      retry: RetryPolicy.none,
    );

void main() {
  test(
    'a query batch is one record: fields, bytes, duration, scopes',
    () async {
      final client = _client(_Server());
      final seen = <SlingRequest>[];
      client.requests.listen(seen.add);

      final header = client.createScope(onChanged: () {}, debugLabel: 'Header');
      final list = client.createScope(onChanged: () {}, debugLabel: 'List');
      header.run((q) => q.me.name);
      list.run((q) => q.me.friends().map((f) => f.name).toList());
      await Future.wait([header.whenSettled, list.whenSettled]);

      final request = seen.first;
      expect(seen.toSet(), {request}, reason: 'emitted on send and on done');
      expect(seen, hasLength(2));
      expect(request.id, 1);
      expect(request.kind, 'query');
      expect(request.scopes, ['Header', 'List']);
      expect(request.rootFields, ['me']);
      expect(request.fieldCount, 2, reason: 'me.name, me.friends.name');
      expect(request.isDone, isTrue);
      expect(request.statusCode, 200);
      expect(request.bytes, jsonEncode({'data': meWithFriends()}).length);
      expect(request.error, isNull);
      expect(await request.done, same(request));
      expect(
        request.logLine,
        matches(
          RegExp(r'^#1 query me · \d+ ms · \d+ B · 2 fields ← Header, List$'),
        ),
      );
    },
  );

  test('repeated labels are folded in scopeSummary', () async {
    final client = _client(_Server());
    final seen = <SlingRequest>[];
    client.requests.listen(seen.add);
    final scopes = [
      for (var i = 0; i < 3; i++)
        client.createScope(onChanged: () {}, debugLabel: 'Tile'),
      client.createScope(onChanged: () {}, debugLabel: 'Screen'),
    ];
    for (final s in scopes) {
      s.run((q) => q.me.name);
    }
    await scopes.first.whenSettled;
    expect(seen.first.scopeSummary, 'Tile ×3, Screen');
  });

  test('a failed request carries the error', () async {
    final server = _Server()..fail = true;
    final client = _client(server);
    final seen = <SlingRequest>[];
    client.requests.listen(seen.add);
    final scope = client.createScope(onChanged: () {}, debugLabel: 'Me');
    scope.run((q) => q.me.name);
    await scope.whenSettled;

    final request = seen.last;
    expect(request.isDone, isTrue);
    expect(request.statusCode, 500);
    expect(request.error, isA<SlingException>());
    expect(request.logLine, endsWith('← Me ✗ HTTP 500'));
  });

  test('mutations are records, named by debugLabel', () async {
    final client = _client(_Server());
    final seen = <SlingRequest>[];
    client.requests.listen(seen.add);
    await client.mutateWith(
      Mutation.root,
      (m) => m.rename(id: '1', name: 'Bo')?.name,
      debugLabel: 'RenameButton',
    );
    final request = seen.last;
    expect(request.kind, 'mutation');
    expect(request.rootFields, ['rename']);
    expect(request.scopes, ['RenameButton']);
    expect(request.isDone, isTrue);
  });

  test('subscriptions: one record per connection, events counted', () async {
    late StreamController<Map<String, Object?>> events;
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      httpClient: _Server().http_,
      subscriptionTransport: (_) =>
          (events = StreamController<Map<String, Object?>>()).stream,
    );
    final seen = <SlingRequest>[];
    client.requests.listen(seen.add);
    final sub = client.subscribeWith(
      Subscription.root,
      (s) => s.userChanged?.name,
      debugLabel: 'LiveName',
    );
    final alias = RegExp(r'\{\s*(\w+)')
        .firstMatch(sub.operation.document)!
        .group(1)!;
    final listener = sub.stream.listen((_) {});
    final request = seen.single;
    expect(request.kind, 'subscription');
    expect(request.scopes, ['LiveName']);
    expect(request.logLine, contains('0 events, open'));

    events.add({
      'data': {
        alias: {'__typename': 'User', 'id': '1', 'name': 'Ada'},
      },
    });
    await Future<void>.delayed(Duration.zero);
    expect(request.events, 1);
    expect(seen, hasLength(2));

    await listener.cancel();
    expect(request.isDone, isTrue);
    expect(request.logLine, contains('1 event in'));
  });

  test('no listener, no records; ids still count every request', () async {
    final client = _client(_Server());
    final first = client.createScope(onChanged: () {});
    first.run((q) => q.me.name);
    await first.whenSettled;

    final seen = <SlingRequest>[];
    client.requests.listen(seen.add);
    await first.refetch();
    expect(seen.first.id, 2);
  });

  test('logRequests prints one line per request once done', () async {
    final printed = <String>[];
    await runZoned(
      () async {
        final client = _client(_Server(), logRequests: true);
        final scope = client.createScope(onChanged: () {}, debugLabel: 'Me');
        scope.run((q) => q.me.name);
        await scope.whenSettled;
        await Future<void>.delayed(Duration.zero);
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => printed.add(line),
      ),
    );
    expect(printed, hasLength(1));
    expect(printed.single, startsWith('sling_gql #1 query me · '));
    expect(printed.single, endsWith('← Me'));
  });

  group('QueryBuilder labels', () {
    testWidgets('default to the enclosing widget, below the SlingScope', (
      tester,
    ) async {
      final client = _client(_Server());
      final seen = <SlingRequest>[];
      client.requests.listen(seen.add);
      await tester.pumpWidget(
        SlingScope<Query>(
          client: client,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Column(children: [_ProfileHeader(), _ProfileHeader()]),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpUntilIdle(client);

      expect(seen.first.scopes, ['_ProfileHeader', '_ProfileHeader']);
      expect(seen.first.scopeSummary, '_ProfileHeader ×2');
    });

    testWidgets('MutationBuilder: the enclosing widget, or debugLabel', (
      tester,
    ) async {
      final client = _client(_Server());
      final seen = <SlingRequest>[];
      client.requests.listen(seen.add);
      await tester.pumpWidget(
        SlingScope<Query>(
          client: client,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                _RenameButton(),
                _RenameButton(label: 'Named'),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('rename').first);
      await tester.tap(find.text('rename').last);
      await tester.pumpUntilIdle(client);

      expect(
        [for (final r in seen.toSet()) r.scopes],
        [
          ['_RenameButton'],
          ['Named'],
        ],
      );
    });
  });

  group('SlingRequestOverlay', () {
    Future<SlingClient<Query>> pumpOverlay(
      WidgetTester tester, {
      _Server? server,
      bool enabled = true,
    }) async {
      final client = _client(server ?? _Server());
      await tester.pumpWidget(
        SlingScope<Query>(
          client: client,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SlingRequestOverlay(
              enabled: enabled,
              child: const _ProfileHeader(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpUntilIdle(client);
      return client;
    }

    final chip = find.byKey(const ValueKey('sling-request-overlay-chip'));
    final panel = find.byKey(const ValueKey('sling-request-overlay-panel'));

    testWidgets('chip counts requests; the panel lists them with scopes', (
      tester,
    ) async {
      await pumpOverlay(tester);
      expect(find.text('Ada'), findsOneWidget);
      expect(find.textContaining('⇅ 1 req · #1 '), findsOneWidget);

      await tester.tap(chip);
      await tester.pump();
      expect(panel, findsOneWidget);
      expect(find.textContaining('#1 query me · '), findsOneWidget);
      expect(find.text('   ← _ProfileHeader'), findsOneWidget);

      // Tap a line for its document.
      await tester.tap(find.textContaining('#1 query me'));
      await tester.pump();
      expect(find.textContaining('__typename'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(find.text('No request yet.'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pump();
      expect(panel, findsNothing);
      expect(find.textContaining('⇅ 0 req'), findsOneWidget);
    });

    testWidgets('errors show on the line', (tester) async {
      await pumpOverlay(tester, server: _Server()..fail = true);
      await tester.tap(chip);
      await tester.pump();
      expect(find.text('   ✗ HTTP 500'), findsOneWidget);
    });

    testWidgets('disabled: just the child, no records', (tester) async {
      final client = await pumpOverlay(tester, enabled: false);
      expect(chip, findsNothing);
      expect(find.text('Ada'), findsOneWidget);
      expect(client.requests.isBroadcast, isTrue);
    });
  });
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) => QueryBuilder<Query>(
    builder: (context, q, state) => Text(q.me.name ?? '…'),
  );
}

class _RenameButton extends StatelessWidget {
  const _RenameButton({this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => MutationBuilder<Mutation>(
    debugLabel: label,
    builder: (context, mutate, state) => GestureDetector(
      onTap: () => mutate((m) => m.rename(id: '1', name: 'Bo')?.name),
      child: const Text('rename'),
    ),
  );
}

extension on WidgetTester {
  /// Pumps until the client has no request in flight.
  Future<void> pumpUntilIdle(SlingClient<Query> client) async {
    for (var i = 0; i < 20 && !client.isIdle; i++) {
      await runAsync(() => Future<void>.delayed(Duration.zero));
      await pump();
    }
    await pump();
  }
}
