import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// [SubscriptionBuilder]: opens on mount, closes on unmount, rebuilds with
/// each event, and the cache write reaches the [QueryBuilder]s next to it.
void main() {
  late StreamController<Map<String, Object?>> events;
  late List<PrintedOperation> operations;
  var opened = 0;
  var cancelled = 0;

  SlingClient<Query> client() {
    operations = [];
    opened = 0;
    cancelled = 0;
    final c = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: mockGraphQL((_, _) => meWithFriends()),
      onOperation: operations.add,
      subscriptionTransport: (_) {
        opened++;
        events = StreamController(onCancel: () => cancelled++);
        return events.stream;
      },
    );
    addTearDown(c.dispose);
    return c;
  }

  String alias() =>
      RegExp(r'\{\s*(\w+)').firstMatch(operations.last.document)!.group(1)!;

  void emit(String id, String name) => events.add({
    'data': {
      alias(): {'__typename': 'User', 'id': id, 'name': name},
    },
  });

  Widget app(SlingClient<Query> client, Widget child) => SlingScope<Query>(
    client: client,
    schema: slingSchema,
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );

  testWidgets('opens on mount, rebuilds per event, closes on unmount', (
    tester,
  ) async {
    final c = client();
    final states = <SubscriptionState>[];
    await tester.pumpWidget(
      app(
        c,
        SubscriptionBuilder<Subscription>(
          select: (s) => s.userChanged?.name,
          builder: (context, s, state) {
            states.add(state);
            return Text(s?.userChanged?.name ?? 'waiting');
          },
        ),
      ),
    );
    expect(opened, 1, reason: 'opened at the end of the first frame');
    expect(operations.single.document, startsWith('subscription'));
    expect(find.text('waiting'), findsOneWidget);
    expect(states.last.isActive, isFalse, reason: 'not yet, in that build');
    await tester.pump();
    expect(states.last.isActive, isTrue);
    expect(states.last.hasEvent, isFalse);

    emit('a', 'Bobby');
    // `pump()` draws before flushing microtasks; elapsing flushes first.
    await tester.pump(Duration.zero);
    expect(find.text('Bobby'), findsOneWidget);
    expect(states.last.eventCount, 1);

    emit('b', 'Cyrus');
    await tester.pump(Duration.zero);
    expect(find.text('Cyrus'), findsOneWidget);

    await tester.pumpWidget(app(c, const SizedBox()));
    expect(cancelled, 1);
    expect(c.activeSubscriptions, 0);
  });

  testWidgets('an event updates the QueryBuilder showing the same entity', (
    tester,
  ) async {
    final c = client();
    await tester.pumpWidget(
      app(
        c,
        Column(
          children: [
            QueryBuilder<Query>(
              builder: (context, q, state) =>
                  Text(q.me.friends().map((f) => f.name ?? '…').join(',')),
            ),
            SubscriptionBuilder<Subscription>(
              select: (s) => s.userChanged?.name,
              builder: (context, s, state) => const SizedBox(),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Bob,Cy'), findsOneWidget);

    emit('a', 'Bobby');
    await tester.pump(Duration.zero);
    expect(find.text('Bobby,Cy'), findsOneWidget);
  });

  testWidgets('onEvent runs before the rebuild, with the event', (
    tester,
  ) async {
    final c = client();
    final seen = <String>[];
    await tester.pumpWidget(
      app(
        c,
        SubscriptionBuilder<Subscription>(
          select: (s) => s.userChanged?.name,
          onEvent: (s) => seen.add('event:${s.userChanged?.name}'),
          builder: (context, s, state) {
            seen.add('build:${s?.userChanged?.name}');
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    seen.clear();
    emit('a', 'Bobby');
    await tester.pump(Duration.zero);
    expect(seen, ['event:Bobby', 'build:Bobby']);
  });

  testWidgets('server completion flips isActive; errors surface', (
    tester,
  ) async {
    final c = client();
    SubscriptionState? last;
    await tester.pumpWidget(
      app(
        c,
        SubscriptionBuilder<Subscription>(
          select: (s) => s.userChanged?.name,
          builder: (context, s, state) {
            last = state;
            return const SizedBox();
          },
        ),
      ),
    );
    events.add({
      'errors': [
        {'message': 'boom'},
      ],
    });
    await tester.pump(Duration.zero);
    expect(last!.error, isA<SlingException>());
    expect(last!.isActive, isTrue);

    await events.close();
    await tester.pump(Duration.zero);
    expect(last!.isActive, isFalse);
  });

  testWidgets('a dropped connection reconnects after retryAfter; retry() '
      'does it now', (tester) async {
    final c = client();
    SubscriptionState? last;
    await tester.pumpWidget(
      app(
        c,
        SubscriptionBuilder<Subscription>(
          select: (s) => s.userChanged?.name,
          retryAfter: const Duration(seconds: 5),
          builder: (context, s, state) {
            last = state;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    expect(last!.isConnected, isTrue);

    events.addError(StateError('gone'));
    await tester.pump(Duration.zero);
    expect(last!.isActive, isTrue);
    expect(last!.isConnected, isFalse);
    expect(last!.isReconnecting, isTrue);
    expect(
      last!.error,
      isA<SlingTransportException>().having(
        (e) => e.cause,
        'cause',
        isA<StateError>(),
      ),
    );
    expect(opened, 1);

    await tester.pump(const Duration(seconds: 5));
    expect(opened, 2);
    expect(last!.isConnected, isTrue);
    expect(last!.isReconnecting, isFalse);

    events.addError(StateError('gone again'));
    await tester.pump(Duration.zero);
    last!.retry();
    await tester.pump();
    expect(opened, 3);
    expect(last!.isConnected, isTrue);

    emit('a', 'Bobby');
    await tester.pump(Duration.zero);
    expect(last!.error, isNull, reason: 'cleared by the next event');

    await tester.pumpWidget(app(c, const SizedBox()));
    expect(c.activeSubscriptions, 0);
  });

  testWidgets('an explicit root: wins over the scope', (tester) async {
    final c = client();
    await tester.pumpWidget(
      SlingScope<Query>(
        client: c,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SubscriptionBuilder<Subscription>(
            root: Subscription.root,
            select: (s) => s.userChanged?.name,
            builder: (context, s, state) => const SizedBox(),
          ),
        ),
      ),
    );
    expect(opened, 1);
  });

  testWidgets('no root anywhere is an assertion', (tester) async {
    final c = client();
    await tester.pumpWidget(
      SlingScope<Query>(
        client: c,
        child: SubscriptionBuilder<Subscription>(
          select: (s) => s.userChanged?.name,
          builder: (context, s, state) => const SizedBox(),
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });
}
