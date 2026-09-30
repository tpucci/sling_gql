import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_hooks/sling_gql_hooks.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

import 'support/test_schema.dart';

/// [useSlingSubscription] behaves like a [SubscriptionBuilder]: opens at the
/// end of the first frame, rebuilds per event, closes with the widget, and
/// the events reach the queries showing the same entities.
void main() {
  late StreamController<Map<String, Object?>> changes;
  late MockGraphQLServer server;

  setUp(() {
    server = MockGraphQLServer(
      query: {
        'me': {
          ...user('1', 'Ada'),
          'friends': [user('a', 'Bob'), user('b', 'Cy')],
        },
      },
      subscription: {
        'userChanged': () {
          changes = StreamController();
          return changes.stream;
        },
      },
    );
  });

  Widget app(SlingClient<Query> client, Widget child) => SlingScope<Query>(
    client: client,
    schema: slingSchema,
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );

  testWidgets('opens after the first frame, rebuilds per event, closes on '
      'unmount', (tester) async {
    final client = server.client(Query.root);
    final states = <SubscriptionState>[];
    await tester.pumpWidget(
      app(
        client,
        HookBuilder(
          builder: (context) {
            final (s, state) = useSlingSubscription<Subscription>(
              (s) => s.userChanged?.name,
            );
            states.add(state);
            return Text(s?.userChanged?.name ?? 'waiting');
          },
        ),
      ),
    );
    expect(find.text('waiting'), findsOneWidget);
    expect(states.last.isActive, isFalse, reason: 'not yet, in that build');
    await tester.pump(Duration.zero);
    expect(server.openSubscriptions, 1);
    expect(server.lastRequest.type, 'subscription');
    expect(server.lastRequest.selects('userChanged.name'), isTrue);
    await tester.pump();
    expect(states.last.isActive, isTrue);
    expect(states.last.hasEvent, isFalse);

    changes.add(user('a', 'Bobby'));
    await tester.pump(Duration.zero);
    expect(find.text('Bobby'), findsOneWidget);
    expect(states.last.eventCount, 1);

    changes.add(user('b', 'Cyrus'));
    await tester.pump(Duration.zero);
    expect(find.text('Cyrus'), findsOneWidget);

    await tester.pumpWidget(app(client, const SizedBox()));
    await tester.pump(Duration.zero);
    expect(server.openSubscriptions, 0);
    expect(client.activeSubscriptions, 0);
  });

  testWidgets('an event rebuilds the useSlingQuery showing the entity', (
    tester,
  ) async {
    final client = server.client(Query.root);
    await tester.pumpWidget(
      app(
        client,
        Column(
          children: [
            HookBuilder(
              builder: (context) {
                final (names, _) = useSlingQuery(
                  (Query q) => q.me.friends().map((f) => f.name ?? '…'),
                );
                return Text(names.join(','));
              },
            ),
            HookBuilder(
              builder: (context) {
                useSlingSubscription<Subscription>((s) => s.userChanged?.name);
                return const SizedBox();
              },
            ),
          ],
        ),
      ),
    );
    await tester.pumpUntilSettled(client);
    expect(find.text('Bob,Cy'), findsOneWidget);

    changes.add(user('a', 'Bobby'));
    await tester.pump(Duration.zero);
    expect(find.text('Bobby,Cy'), findsOneWidget);
  });

  testWidgets('onEvent runs before the rebuild, with the event', (
    tester,
  ) async {
    final client = server.client(Query.root);
    final seen = <String>[];
    await tester.pumpWidget(
      app(
        client,
        HookBuilder(
          builder: (context) {
            final (s, _) = useSlingSubscription<Subscription>(
              (s) => s.userChanged?.name,
              onEvent: (s) => seen.add('event:${s.userChanged?.name}'),
            );
            seen.add('build:${s?.userChanged?.name}');
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump(Duration.zero);
    await tester.pump();
    seen.clear();
    changes.add(user('a', 'Bobby'));
    await tester.pump(Duration.zero);
    expect(seen, ['event:Bobby', 'build:Bobby']);
  });

  testWidgets('completion ends it; a drop reconnects after retryAfter', (
    tester,
  ) async {
    // A raw transport: connection drops are transport errors.
    late StreamController<Map<String, Object?>> events;
    var connections = 0;
    final client = SlingClient<Query>(
      endpoint: Uri.parse('http://mock/graphql'),
      schema: slingSchema,
      httpClient: server.httpClient,
      subscriptionTransport: (_) {
        connections++;
        events = StreamController();
        return events.stream;
      },
    );
    addTearDown(client.dispose);
    late SubscriptionState last;
    await tester.pumpWidget(
      app(
        client,
        HookBuilder(
          builder: (context) {
            last = useSlingSubscription<Subscription>(
              (s) => s.userChanged?.name,
              retryAfter: const Duration(seconds: 5),
            ).$2;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    expect(last.isConnected, isTrue);

    events.addError(StateError('gone'));
    await tester.pump(Duration.zero);
    expect(last.isActive, isTrue);
    expect(last.isConnected, isFalse);
    expect(last.isReconnecting, isTrue);
    expect(last.error, isA<StateError>());
    expect(connections, 1);

    await tester.pump(const Duration(seconds: 5));
    expect(connections, 2);
    expect(last.isConnected, isTrue);
    expect(last.isReconnecting, isFalse);

    events.addError(StateError('gone again'));
    await tester.pump(Duration.zero);
    last.retry();
    await tester.pump();
    expect(connections, 3);
    expect(last.isConnected, isTrue);

    events.add({
      'data': {
        'userChanged': {'__typename': 'User', 'id': 'a', 'name': 'Bobby'},
      },
    });
    await tester.pump(Duration.zero);
    expect(last.error, isNull, reason: 'cleared by the next event');
    expect(last.eventCount, 1);

    await events.close();
    await tester.pump(Duration.zero);
    expect(last.isActive, isFalse, reason: 'a server complete ends it');
  });

  testWidgets('an explicit root works without a schema on SlingScope', (
    tester,
  ) async {
    final client = server.client(Query.root);
    await tester.pumpWidget(
      SlingScope<Query>(
        client: client,
        child: HookBuilder(
          builder: (context) {
            useSlingSubscription<Subscription>(
              (s) => s.userChanged?.name,
              root: Subscription.root,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump(Duration.zero);
    expect(server.openSubscriptions, 1);
  });
}
