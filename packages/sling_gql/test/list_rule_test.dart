import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// [ListRule]: cached lists follow their entities. Test schema:
/// `me.friends(limit:)` holds Users; the rule below says a user belongs in
/// `friends(limit: n)` iff `age` is null (a stand-in for a filter — Bob and
/// Cy have no age in [meWithFriends], Ada is 36).
void main() {
  late StreamController<Map<String, Object?>> events;
  late List<PrintedOperation> ops;

  SlingClient<Query> client({ListPosition position = ListPosition.append}) {
    ops = [];
    final c = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      onOperation: ops.add,
      httpClient: mockGraphQL((query, vars) {
        if (query.startsWith('mutation')) {
          final alias = RegExp(r'(rename_\w+):').firstMatch(query)!.group(1)!;
          return {
            alias: {
              '__typename': 'User',
              'id': vars['id'],
              'name': vars['name'],
              'age': 50,
            },
          };
        }
        // Answer `friends(limit:)` under whatever alias the client printed.
        final data = meWithFriends();
        final me = data['me'] as Map<String, Object?>;
        for (final m in RegExp(r'(friends_\w+):').allMatches(query)) {
          me[m.group(1)!] = me['friends'];
        }
        return data;
      }),
      subscriptionTransport: (_) {
        events = StreamController();
        return events.stream;
      },
      listRules: [
        ListRule<User>(
          field: 'friends',
          typename: 'User',
          ctor: User.new,
          belongs: (args, user) => user.age == null,
          position: position,
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  List<String?> friends(SlingClient<Query> c) =>
      c.cacheScope.query.me.friends().map((f) => f.name).toList();

  test('an entity change removes it from / adds it to cached lists', () async {
    final c = client();
    await c.resolve((q) => q.me.friends().map((f) => f.age).toList());
    expect(friends(c), ['Bob', 'Cy']);

    // Ada loses her age: she now belongs, so she joins the list.
    c.cacheScope.user('1')!.age = null;
    expect(friends(c), ['Bob', 'Cy', 'Ada']);

    // Bob gets one: he leaves.
    c.cacheScope.user('a')!.age = 5;
    expect(friends(c), ['Cy', 'Ada']);

    // A write that does not change membership leaves the list alone.
    c.cacheScope.user('b')!.name = 'Cyrus';
    expect(friends(c), ['Cyrus', 'Ada']);
  });

  test(
    'a query response only removes: pages never absorb each other',
    () async {
      var calls = 0;
      final c = SlingClient<Query>(
        endpoint: testEndpoint,
        rootFactory: Query.root,
        httpClient: mockGraphQL((query, _) {
          String alias(String field) => RegExp(
            '($field'
            r'_\w+):',
          ).firstMatch(query)!.group(1)!;
          if (++calls == 1) {
            // "page" limit: 1 → Bob (age not selected: reads null → belongs).
            return {
              'me': {
                '__typename': 'User',
                'id': '1',
                alias('friends'): [
                  {'__typename': 'User', 'id': 'a', 'name': 'Bob'},
                ],
              },
            };
          }
          // "page" limit: 2 → Cy; and, elsewhere in the same response, Bob
          // now has an age (he no longer belongs anywhere).
          return {
            'me': {
              '__typename': 'User',
              'id': '1',
              alias('friends'): [
                {'__typename': 'User', 'id': 'b', 'name': 'Cy', 'age': null},
              ],
            },
            alias('user'): {'__typename': 'User', 'id': 'a', 'age': 7},
          };
        }),
        listRules: [
          ListRule<User>(
            field: 'friends',
            typename: 'User',
            ctor: User.new,
            belongs: (args, user) => user.age == null,
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.resolve(
        (q) => q.me.friends(limit: 1).map((f) => f.name).toList(),
      );
      await c.resolve(
        (q) => (
          q.me.friends(limit: 2).map((f) => f.age).toList(),
          q.user(id: 'a')?.age,
        ),
      );
      final scope = c.cacheScope;
      expect(
        scope.query.me.friends(limit: 1).map((f) => f.name),
        isEmpty,
        reason:
            'Bob left (no longer belongs); Cy was NOT added — a response '
            'only removes',
      );
      expect(scope.query.me.friends(limit: 2).map((f) => f.name), ['Cy']);
    },
  );

  test('prepend position', () async {
    final c = client(position: ListPosition.prepend);
    await c.resolve((q) => q.me.friends().map((f) => f.age).toList());
    c.cacheScope.user('1')!.age = null;
    expect(friends(c), ['Ada', 'Bob', 'Cy']);
  });

  test('every cached argument set is maintained, on or off screen', () async {
    final c = client();
    await c.resolve((q) => q.me.friends(limit: 1).map((f) => f.name).toList());
    await c.resolve((q) => q.me.friends(limit: 2).map((f) => f.name).toList());
    c.cacheScope.user('1')!.age = null;
    final scope = c.cacheScope;
    expect(scope.query.me.friends(limit: 1).map((f) => f.name), [
      'Bob',
      'Cy',
      'Ada',
    ]);
    expect(scope.query.me.friends(limit: 2).map((f) => f.name), [
      'Bob',
      'Cy',
      'Ada',
    ]);
    // The unfiltered list came along in the (over-answering) mock response
    // but was never *sent* in a document: the client knows no arguments for
    // it, so it is left alone.
    expect(scope.query.me.friends().map((f) => f.name), ['Bob', 'Cy']);
  });

  test('belongs receives the node arguments', () async {
    final seen = <Map<String, Object?>>[];
    final c = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: mockGraphQL((query, _) {
        final data = meWithFriends();
        final me = data['me'] as Map<String, Object?>;
        for (final m in RegExp(r'(friends_\w+):').allMatches(query)) {
          me[m.group(1)!] = me['friends'];
        }
        return data;
      }),
      listRules: [
        ListRule<User>(
          field: 'friends',
          typename: 'User',
          ctor: User.new,
          belongs: (args, user) {
            seen.add(args);
            return true;
          },
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.resolve((q) => q.me.friends(limit: 2).map((f) => f.name).toList());
    seen.clear();
    c.cacheScope.user('1')!.age = 1;
    expect(seen, [
      {'limit': 2},
    ]);
  });

  test('a subscription event drives membership', () async {
    final c = client();
    await c.resolve((q) => q.me.friends().map((f) => f.name).toList());
    var rebuilds = 0;
    final scope = c.createScope(onChanged: () => rebuilds++);
    scope.run((q) => q.me.friends().map((f) => f.name).toList());

    c
        .subscribeWith(Subscription.root, (s) => s.userChanged?.age)
        .stream
        .listen((_) {});
    await Future<void>.delayed(Duration.zero);
    final alias = RegExp(r'\{\s*(\w+)')
        .firstMatch(ops.last.document)!
        .group(1)!;
    events.add({
      'data': {
        alias: {'__typename': 'User', 'id': 'z', 'age': null},
      },
    });
    await Future<void>.delayed(Duration.zero);
    expect(c.cacheScope.query.me.friends().map((f) => f.id), [
      'a',
      'b',
      'z',
    ], reason: 'a brand-new entity that belongs is added');
    expect(rebuilds, 1, reason: 'the list scope rebuilt');
  });

  test(
    'rule edits made during optimistic are rolled back on failure',
    () async {
      final c = SlingClient<Query>(
        endpoint: testEndpoint,
        rootFactory: Query.root,
        httpClient: mockGraphQL((_, _) => throw StateError('down')),
        listRules: [
          ListRule<User>(
            field: 'friends',
            typename: 'User',
            ctor: User.new,
            belongs: (args, user) => user.age != null,
          ),
        ],
      );
      addTearDown(c.dispose);
      // Seed the cache by hand.
      c.cache.writeResponse('query', Selection.root('query'), meWithFriends());
      expect(friends(c), ['Bob', 'Cy']);
      await expectLater(
        c.mutateWith(
          Mutation.root,
          (m) => m.rename(id: '1', name: 'x')?.name,
          optimistic: () => c.cacheScope.user('1')!.age = null,
        ),
        throwsA(anything),
      );
      expect(friends(c), ['Bob', 'Cy'], reason: 'the rule edit was undone');
      expect(c.cacheScope.user('1')!.age, 36);
    },
  );
}
