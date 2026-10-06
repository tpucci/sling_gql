import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

import 'support/test_schema.dart';

void main() {
  group('MockGraphQLServer subscriptions', () {
    test('a Stream field feeds client.subscribeWith, projected', () async {
      final changes = StreamController<Map<String, Object?>>();
      final server = MockGraphQLServer(
        subscription: {'userChanged': changes.stream},
      );
      final client = server.client(Query.root);

      final names = <String?>[];
      final sub = client.subscribeWith(
        Subscription.root,
        (s) => s.userChanged?.name,
      );
      sub.stream.listen(names.add);
      await Future<void>.delayed(Duration.zero);
      expect(server.openSubscriptions, 1);
      expect(server.lastRequest.type, 'subscription');
      expect(server.lastRequest.rootFields, {'userChanged'});
      expect(server.lastRequest.selects('userChanged.name'), isTrue);
      expect(server.lastRequest.selects('userChanged.age'), isFalse);

      changes.add(user('a', 'Bobby', age: 41));
      await Future<void>.delayed(Duration.zero);
      expect(names, ['Bobby']);
      expect(client.cache.entity('User:a')!['name'], 'Bobby');
      expect(
        client.cache.entity('User:a')!.containsKey('age'),
        isFalse,
        reason: 'projected to the selection',
      );

      await sub.cancel();
      expect(server.openSubscriptions, 0);
    });

    test('a resolver receives the arguments and returns the stream', () async {
      final server = MockGraphQLServer(
        subscription: {
          'userRenamed': (Map<String, Object?> args) =>
              Stream.value(user(args['id'] as String, 'Renamed')),
        },
      );
      final client = server.client(Query.root);
      final ids = await client
          .subscribeWith(Subscription.root, (s) => s.userRenamed(id: 'b')?.id)
          .stream
          .toList();
      expect(ids, ['b']);
      expect(server.lastRequest.variables, {'id': 'b'});
      expect(server.openSubscriptions, 0, reason: 'completed with the stream');
    });

    test(
      'a MockGraphQLError from a nested resolver becomes errors[]',
      () async {
        final server = MockGraphQLServer(
          subscription: {
            'userChanged': Stream.value({
              ...user('a', 'Bob'),
              'age': (Map<String, Object?> _) => throw MockGraphQLError('nope'),
            }),
          },
        );
        final client = server.client(Query.root);
        final errors = <Object>[];
        final values = <(String?, int?)>[];
        await client
            .subscribeWith(
              Subscription.root,
              (s) => (s.userChanged?.name, s.userChanged?.age),
            )
            .stream
            .handleError(errors.add)
            .forEach(values.add);
        expect(values, [('Bob', null)]);
        expect(errors.single, isA<SlingException>());
      },
    );

    test('unknown field and non-stream values are clear errors', () async {
      final server = MockGraphQLServer(subscription: {'userChanged': 42});
      final client = server.client(Query.root);
      await expectLater(
        client
            .subscribeWith(Subscription.root, (s) => s.userChanged?.name)
            .stream
            .toList(),
        throwsA(
          isA<SlingTransportException>().having(
            (e) => e.cause,
            'cause',
            isA<StateError>(),
          ),
        ),
      );
      final empty = MockGraphQLServer();
      final c2 = empty.client(Query.root);
      await expectLater(
        c2
            .subscribeWith(Subscription.root, (s) => s.userChanged?.name)
            .stream
            .toList(),
        throwsA(
          isA<SlingTransportException>().having(
            (e) => e.message,
            'message',
            contains('no subscription field "userChanged"'),
          ),
        ),
      );
    });

    testWidgets('SubscriptionBuilder + QueryBuilder end to end', (
      tester,
    ) async {
      final changes = StreamController<Map<String, Object?>>();
      final server = MockGraphQLServer(
        query: {'me': user('1', 'Ada')},
        subscription: {'userChanged': changes.stream},
      );
      final client = server.client(Query.root);
      await tester.pumpWidget(
        SlingScope<Query>(
          client: client,
          schema: slingSchema,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                QueryBuilder<Query>(
                  builder: (context, q, state) =>
                      Text(q.me.friends().map((f) => f.name ?? '…').join(',')),
                ),
                SubscriptionBuilder<Subscription>(
                  select: (s) => s.userChanged?.name,
                  builder: (context, s, state) =>
                      Text(s?.userChanged?.name ?? 'waiting'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpUntilSettled(client);
      expect(find.text('Bob,Cy'), findsOneWidget);
      expect(find.text('waiting'), findsOneWidget);
      expect(server.openSubscriptions, 1);

      changes.add(user('a', 'Bobby'));
      await tester.pump(Duration.zero);
      expect(find.text('Bobby,Cy'), findsOneWidget);
      expect(find.text('Bobby'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      expect(server.openSubscriptions, 0);
    });
  });
}
