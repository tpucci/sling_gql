import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

import 'support/test_schema.dart';

void main() {
  group('MockGraphQLServer', () {
    test(
      'answers under the document alias, projecting selected fields',
      () async {
        final server = MockGraphQLServer(
          query: {
            'me': user('1', 'Ada', age: 36),
            'user': (Map<String, Object?> args) =>
                args['id'] == 'a' ? user('a', 'Bob', age: 41) : null,
          },
        );
        final client = server.client(Query.root);

        final (name, friends, bobAge, nobody) = await client.resolve(
          (q) => (
            q.me.name,
            q.me.friends(limit: 1).map((f) => f.name).toList(),
            q.user(id: 'a')?.age,
            q.user(id: 'zzz'),
          ),
        );
        expect(name, 'Ada');
        expect(friends, ['Bob'], reason: 'the resolver saw limit: 1');
        expect(bobAge, 41);
        expect(nobody, isNull);

        expect(server.requests, hasLength(1));
        final req = server.lastRequest;
        expect(req.type, 'query');
        expect(req.rootFields, {'me', 'user'});
        expect(req.selects('me.friends.name'), isTrue);
        expect(req.selects('me.age'), isFalse, reason: 'not read');

        // Only what was selected is in the response — check the cache entity.
        final ada = client.cache.entity('User:1')!;
        expect(ada.containsKey('name'), isTrue);
        expect(ada.containsKey('age'), isFalse);
      },
    );

    test(
      'mutations resolve against the mutation map and update the cache',
      () async {
        final store = {'1': user('1', 'Ada')};
        final server = MockGraphQLServer(
          query: {'me': () => store['1']},
          mutation: {
            'rename': (Map<String, Object?> args) {
              final u = store[args['id']]!;
              u['name'] = args['name'];
              return u;
            },
          },
        );
        final client = server.client(Query.root);
        await client.resolve((q) => q.me.name);

        final renamed = await client.mutateWith(
          Mutation.root,
          (m) => m.rename(id: '1', name: 'Grace')?.name,
        );
        expect(renamed, 'Grace');
        expect(client.cacheScope.query.me.name, 'Grace');
        expect(server.requests.map((r) => r.type), ['query', 'mutation']);
      },
    );

    test(
      'MockGraphQLError from a resolver becomes errors[] with a path',
      () async {
        final server = MockGraphQLServer(
          query: {
            'me': user('1', 'Ada'),
            'user': (Map<String, Object?> _) => throw MockGraphQLError('nope'),
          },
        );
        final result = await server.execute(
          'query { me { __typename id name } u: user(id: "x") { id } }',
        );
        expect(result['data'], {
          'me': {'__typename': 'User', 'id': '1', 'name': 'Ada'},
          'u': null,
        });
        expect(result['errors'], [
          {
            'message': 'nope',
            'path': ['u'],
          },
        ]);

        // Through the client: partial data is cached, the error surfaces.
        final client = server.client(Query.root);
        await expectLater(
          client.resolve((q) => (q.me.name, q.user(id: 'x')?.name)),
          throwsA(isA<SlingException>()),
        );
        expect(client.cacheScope.query.me.name, 'Ada');
      },
    );

    test(
      'unknown fields and missing __typename fail the test, not silently',
      () {
        final server = MockGraphQLServer(
          query: {
            'me': {'id': '1', 'name': 'Ada'},
          },
        );
        expect(
          () => server.execute('{ nope { id } }'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('no query field "nope"'),
            ),
          ),
        );
        expect(
          () => server.execute('{ me { __typename id } }'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('__typename'),
            ),
          ),
        );
        expect(
          () => server.execute('{ me { id email } }'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('no field "email"'),
            ),
          ),
        );
      },
    );

    test('DateTime values are sent as ISO-8601 strings', () async {
      final server = MockGraphQLServer(
        query: {'now': DateTime.utc(2026, 1, 2, 3, 4, 5)},
      );
      final result = await server.execute('{ now }');
      expect(result['data'], {'now': '2026-01-02T03:04:05.000Z'});
    });

    test('transport and httpClient both route to the server', () async {
      final server = MockGraphQLServer(query: {'me': user('1', 'Ada')});
      final viaTransport = SlingClient<Query>(
        endpoint: Uri.parse('http://x/graphql'),
        rootFactory: Query.root,
        transport: server.transport,
      );
      addTearDown(viaTransport.dispose);
      expect(await viaTransport.resolve((q) => q.me.name), 'Ada');
      expect(server.requests, hasLength(1));
    });
  });
}
