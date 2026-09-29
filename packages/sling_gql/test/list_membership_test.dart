import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/internal.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// A root list field with arguments, as the generator would emit it on
/// `Query` for `users(limit: Int): [User!]!`.
extension on Query {
  List<User>? users({int? limit}) =>
      list('users', User.new, args: {'limit': Arg('Int', limit)}, keyed: true);
}

String _usersAlias(int limit) =>
    Selection.root('query').child('users', {'limit': Arg('Int', limit)}).alias;

Map<String, Object?> _user(String id, String name) => {
  '__typename': 'User',
  'id': id,
  'name': name,
};

/// `CacheScope.list` / `CacheList` / `CacheScope.evict` (TODO #14): list
/// membership edits after a mutation, with the notification and journaling
/// semantics of any other cache write.
void main() {
  late List<PrintedOperation> sent;
  late SlingClient<Query> client;
  var mutationFails = false;

  setUp(() {
    sent = [];
    mutationFails = false;
    client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      onOperation: sent.add,
      httpClient: MockClient((req) async {
        final query = (jsonDecode(req.body) as Map)['query'] as String;
        if (mutationFails) return http.Response('boom', 500);
        final alias = RegExp(r'(rename\w*): rename')
            .firstMatch(query)
            ?.group(1);
        return http.Response(
          jsonEncode({
            'data': {alias ?? 'rename': _user('c', 'Dee')},
          }),
          200,
        );
      }),
    );
    // Seed the cache as earlier queries would have: `me { friends }`,
    // `users(limit: 2)`, `users(limit: 3)` and a lone `User:c`.
    client.cache.writeResponse('query', {
      ...meWithFriends(),
      _usersAlias(2): [_user('a', 'Bob'), _user('b', 'Cy')],
      _usersAlias(3): [_user('a', 'Bob')],
      'lone': _user('c', 'Dee'),
    });
    sent.clear();
  });

  List<String?> names(List<User>? users) => [
    for (final u in users ?? <User>[]) u.name,
  ];

  group('root list with arguments', () {
    test('append / prepend / remove edit exactly the named argument set', () {
      final cache = client.cacheScope;
      final dee = cache.user('c')!;
      final users2 = cache.list((q) => q.users(limit: 2));

      expect(users2.isCached, isTrue);
      expect(users2.contains(dee), isFalse);
      expect(users2.append(dee), isTrue);
      expect(names(cache.query.users(limit: 2)), ['Bob', 'Cy', 'Dee']);
      expect(users2.remove(dee), isTrue);
      expect(users2.prepend(dee), isTrue);
      expect(names(cache.query.users(limit: 2)), ['Dee', 'Bob', 'Cy']);
      expect(users2.contains(dee), isTrue);

      expect(names(cache.query.users(limit: 3)), [
        'Bob',
      ], reason: 'another argument set is another cache entry');
      expect(sent, isEmpty);
    });

    test('dependent scopes rebuild once per edit; other lists do not', () {
      var changes2 = 0;
      var changes3 = 0;
      client
          .createScope(onChanged: () => changes2++)
          .run((q) => names(q.users(limit: 2)));
      client
          .createScope(onChanged: () => changes3++)
          .run((q) => names(q.users(limit: 3)));

      final cache = client.cacheScope;
      cache.list((q) => q.users(limit: 2)).prepend(cache.user('c')!);

      expect(changes2, 1);
      expect(changes3, 0);
    });

    test('membership is set-like: re-adding or removing an absent entity is a no-op', () {
      var changes = 0;
      client
          .createScope(onChanged: () => changes++)
          .run((q) => names(q.users(limit: 2)));
      final cache = client.cacheScope;
      final users2 = cache.list((q) => q.users(limit: 2));

      expect(users2.append(cache.user('a')!), isFalse);
      expect(users2.prepend(cache.user('b')!), isFalse);
      expect(users2.remove(cache.user('c')!), isFalse);
      expect(changes, 0);
      expect(names(cache.query.users(limit: 2)), ['Bob', 'Cy']);
    });

    test('a list that is not cached is left alone', () {
      final cache = client.cacheScope;
      final users9 = cache.list((q) => q.users(limit: 9));

      expect(users9.isCached, isFalse);
      expect(users9.append(cache.user('c')!), isFalse);
      expect(
        client.cache.read('query', [_usersAlias(9)]),
        missing,
        reason: 'no partial one-element list was created',
      );
    });

    test('the selector must return the generated list itself', () {
      expect(
        () => client.cacheScope.list((q) => q.users(limit: 2)!.toList()),
        throwsArgumentError,
      );
    });

    test('an entity that is not normalized cannot be added', () {
      final cache = client.cacheScope;
      final skeleton = cache.query.user(id: 'nobody')!;
      expect(skeleton.isSkeleton, isTrue);
      expect(
        () => cache.list((q) => q.users(limit: 2)).append(skeleton),
        throwsArgumentError,
      );
    });
  });

  group('nested entity list', () {
    test('through a root object: me.friends', () {
      var changes = 0;
      client
          .createScope(onChanged: () => changes++)
          .run((q) => names(q.me.friends()));
      final cache = client.cacheScope;

      expect(
        cache.list((q) => q.me.friends()).prepend(cache.user('c')!),
        isTrue,
      );

      expect(changes, 1);
      expect(names(cache.query.me.friends()), ['Dee', 'Bob', 'Cy']);
      expect(client.cache.entity('User:1')!['friends'], [
        const Ref('User:c'),
        const Ref('User:a'),
        const Ref('User:b'),
      ]);
    });

    test('through a lookup that resolves to the entity: user(id:).friends', () {
      final cache = client.cacheScope;
      final friends = cache.list((q) => q.user(id: '1')?.friends());

      expect(friends.path, [const Ref('User:1'), 'friends']);
      expect(friends.remove(cache.user('a')!), isTrue);
      expect(names(cache.query.me.friends()), ['Cy']);
    });

    test('a null parent gives a list handle whose edits are no-ops', () {
      client.cache.writeResponse('query', {
        Selection.root('query').child('user', {'id': Arg('ID!', 'gone')}).alias:
            null,
      });
      final cache = client.cacheScope;
      final friends = cache.list((q) => q.user(id: 'gone')?.friends());

      expect(friends.isCached, isFalse);
      expect(friends.append(cache.user('c')!), isFalse);
    });
  });

  group('inside a mutation', () {
    test(
      'an optimistic prepend is rolled back when the mutation fails',
      () async {
        var changes = 0;
        client
            .createScope(onChanged: () => changes++)
            .run((q) => names(q.me.friends()));
        mutationFails = true;

        final result = client.mutateWith(
          Mutation.root,
          (m) => m.rename(id: 'c', name: 'Dee')?.name,
          optimistic: () {
            final cache = client.cacheScope;
            cache.list((q) => q.me.friends()).prepend(cache.user('c')!);
          },
        );
        expect(names(client.cacheScope.query.me.friends()), [
          'Dee',
          'Bob',
          'Cy',
        ]);
        expect(changes, 1, reason: 'the optimistic edit notifies');
        await expectLater(result, throwsA(isA<SlingException>()));

        expect(names(client.cacheScope.query.me.friends()), ['Bob', 'Cy']);
        expect(changes, 2, reason: 'the rollback notifies');
      },
    );

    test('an optimistic callback that throws undoes its earlier edits, sends nothing', () async {
      final cache = client.cacheScope;
      final skeleton = cache.query.user(id: 'nobody')!;

      await expectLater(
        client.mutateWith(
          Mutation.root,
          (m) => m.rename(id: 'c', name: 'Dee')?.name,
          optimistic: () {
            final friends = cache.list((q) => q.me.friends());
            friends.prepend(cache.user('c')!);
            friends.append(skeleton); // not an entity: throws
          },
        ),
        throwsArgumentError,
      );

      expect(names(cache.query.me.friends()), ['Bob', 'Cy']);
      expect(sent, isEmpty);
    });

    test('an optimistic prepend stays when the mutation succeeds', () async {
      await client.mutateWith(
        Mutation.root,
        (m) => m.rename(id: 'c', name: 'Dee')?.name,
        optimistic: () {
          final cache = client.cacheScope;
          cache.list((q) => q.me.friends()).prepend(cache.user('c')!);
        },
      );

      expect(names(client.cacheScope.query.me.friends()), ['Dee', 'Bob', 'Cy']);
      expect(sent, hasLength(1), reason: 'the mutation only, no refetch');
    });
  });

  group('evict', () {
    test(
      'removes the entity from every list and notifies each reader once',
      () {
        var meChanges = 0;
        var usersChanges = 0;
        var otherChanges = 0;
        client
            .createScope(onChanged: () => meChanges++)
            .run((q) => names(q.me.friends()));
        client
            .createScope(onChanged: () => usersChanges++)
            .run((q) => names(q.users(limit: 2)));
        client
            .createScope(onChanged: () => otherChanges++)
            .run((q) => q.me.name);

        final cache = client.cacheScope;
        expect(cache.evict(cache.user('a')!), isTrue);

        expect(client.cache.hasEntity('User:a'), isFalse);
        expect(names(cache.query.me.friends()), ['Cy']);
        expect(names(cache.query.users(limit: 2)), ['Cy']);
        expect(names(cache.query.users(limit: 3)), isEmpty);
        expect(meChanges, 1);
        expect(usersChanges, 1);
        expect(otherChanges, 0, reason: 'me.name did not change');
        expect(sent, isEmpty);
      },
    );

    test('an entity that is not cached is not evicted', () {
      final cache = client.cacheScope;
      final bob = cache.user('a')!;
      expect(cache.evict(bob), isTrue);
      expect(cache.evict(bob), isFalse);
    });
  });
}
