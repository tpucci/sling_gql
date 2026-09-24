import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

// --- Hand-written "generated" code for a tiny schema -------------------------
//
// type Query { me: User!  user(id: ID!): User }
// type User  { id: ID!  name: String!  age: Int  friends(limit: Int): [User!]! }

class Query extends Accessor {
  Query(super.recorder, super.selection, super.path);
  Query.root(Recorder r) : super(r, r.root, const []);

  User get me => object('me', User.new, keyed: true)!;
  User? user({required String id}) =>
      object('user', User.new, args: {'id': Arg('ID!', id)}, lookup: 'User');
}

class User extends Accessor {
  User(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get age => scalar<int>('age');
  List<User> friends({int? limit}) =>
      list('friends', User.new, args: {'limit': Arg('Int', limit)}, keyed: true)!;
}

// --- Test harness -------------------------------------------------------------

class Harness {
  Harness(Map<String, Object?> Function(String query, Map vars) handler) {
    client = SlingClient<Query>(
      endpoint: Uri.parse('http://test/graphql'),
      rootFactory: Query.root,
      onOperation: sent.add,
      httpClient: MockClient((req) async {
        final body = jsonDecode(req.body) as Map;
        final data = handler(body['query'] as String, body['variables'] as Map);
        return http.Response(jsonEncode({'data': data}), 200);
      }),
    );
  }

  late final SlingClient<Query> client;
  final sent = <PrintedOperation>[];
}

void main() {
  _childWidgetTests();
  _normalizationTests();

  test('reading fields records a selection and prints a document', () async {
    final h = Harness((q, v) => {
          'me': {'__typename': 'User', 'id': '1', 'name': 'Ada', 'age': 36},
        });

    final name = await h.client.resolve((q) => q.me.name);

    expect(name, 'Ada');
    expect(h.sent, hasLength(1));
    expect(h.sent.single.document, '''
query {
  me {
    __typename
    id
    name
  }
}''');
  });

  test('skeleton state: missing scalars are null, lists have one element', () {
    final h = Harness((q, v) => {});
    final scope = h.client.createScope(onChanged: () {});

    final out = scope.run((q) {
      final me = q.me;
      return (me.isSkeleton, me.name, me.friends(limit: 3).map((f) => f.name).toList());
    });

    expect(out.$1, isTrue);
    expect(out.$2, isNull);
    expect(out.$3, [null]);
    expect(scope.hasMissingData, isTrue);
    expect(scope.isLoading, isTrue);
  });

  test('arguments become variables and aliases; cache keys follow', () async {
    final h = Harness((q, v) => {
          'me': {
            '__typename': 'User',
            'friends_1n0h7gq': [
              {'__typename': 'User', 'id': 'a', 'name': 'Bob'},
              {'__typename': 'User', 'id': 'b', 'name': 'Cy'},
            ],
          },
        });

    final names = await h.client.resolve(
      (q) => q.me.friends(limit: 2).map((f) => f.name).toList(),
    );

    final op = h.sent.single;
    expect(op.variables, {'v0': 2});
    expect(op.document, contains('friends(limit: \$v0)'));
    // Cache key = alias = field + hash(args)
    final alias = RegExp(r'(friends_\w+): friends').firstMatch(op.document)!.group(1);
    expect(alias, 'friends_1n0h7gq');
    expect(names, ['Bob', 'Cy']);
  });

  test('null object from server is null, not a skeleton', () async {
    final h = Harness((q, v) => {'user_${_alias(v)}': null});
    final user = await h.client.resolve((q) {
      final u = q.user(id: 'nope');
      u?.name;
      return u;
    });
    expect(user, isNull);
  });

  test('optimistic write updates cache and is visible on next read', () async {
    final h = Harness((q, v) => {
          'me': {'__typename': 'User', 'id': '1', 'name': 'Ada'},
        });
    await h.client.resolve((q) => q.me.name);

    final scope = h.client.createScope(onChanged: () {});
    scope.run((q) => q.me.name = 'Grace');
    expect(scope.run((q) => q.me.name), 'Grace');
    expect(h.sent, hasLength(1), reason: 'no refetch after optimistic write');
  });

  test('partial responses merge: two selections on the same object accumulate',
      () async {
    var call = 0;
    final h = Harness((q, v) {
      call++;
      return {
        'me': call == 1
            ? {'__typename': 'User', 'name': 'Ada'}
            : {'__typename': 'User', 'age': 36},
      };
    });
    await h.client.resolve((q) => q.me.name);
    await h.client.resolve((q) => q.me.age);

    final scope = h.client.createScope(onChanged: () {});
    final both = scope.run((q) => (q.me.name, q.me.age));
    expect(both, ('Ada', 36));
    expect(scope.hasMissingData, isFalse);
  });

  test('error is sticky until refetch (no retry loop)', () async {
    var calls = 0;
    final client = SlingClient<Query>(
      endpoint: Uri.parse('http://test/graphql'),
      rootFactory: Query.root,
      httpClient: MockClient((req) async {
        calls++;
        return http.Response(jsonEncode({'errors': [{'message': 'boom'}]}), 200);
      }),
    );
    var rebuilds = 0;
    late QueryScope<Query> scope;
    scope = client.createScope(onChanged: () {
      rebuilds++;
      scope.run((q) => q.me.name); // simulate widget rebuild
    });
    scope.run((q) => q.me.name);
    await scope.whenSettled;
    await Future<void>.delayed(Duration.zero);

    expect(calls, 1);
    expect(rebuilds, 1);
    expect(scope.error, isA<SlingException>());
    expect(scope.isLoading, isFalse);
  });

  test('an object read without sub-fields still prints a valid selection', () {
    final h = Harness((q, v) => {});
    final scope = h.client.createScope(onChanged: () {});
    scope.run((q) => q.me.friends(limit: 1));
    expect(PrintedOperation.from(scope.root).document, '''
query (\$v0: Int) {
  me {
    __typename
    id
    friends_${_friendsAlias(1)}: friends(limit: \$v0) {
      __typename
      id
    }
  }
}''');
  });

  testWidgets('lazily built sliver children join the same request', (tester) async {
    final h = Harness((q, v) => {
          'me': {
            '__typename': 'User',
            'name': 'Ada',
            'friends': [
              for (var i = 0; i < 30; i++) {'__typename': 'User', 'id': '$i', 'name': 'F$i'},
            ],
          },
        });
    await tester.pumpWidget(SlingScope<Query>(
      client: h.client,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: QueryBuilder<Query>(
          builder: (_, q, s) {
            final friends = q.me.friends();
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(child: Text(q.me.name ?? '\u2026')),
              SliverList.builder(
                itemCount: friends.length,
                itemBuilder: (_, i) => _FriendTile(friends[i]),
              ),
            ]);
          },
        ),
      ),
    ));
    await tester.pump();
    expect(h.sent, hasLength(1));
    expect(h.sent.single.document, contains('friends {\n      __typename\n      id\n      name'));
    expect(find.text('F0'), findsOneWidget);
  });

  test('partial errors: resolved fields cached, errored paths stay missing',
      () async {
    final client = SlingClient<Query>(
      endpoint: Uri.parse('http://test/graphql'),
      rootFactory: Query.root,
      httpClient: MockClient((req) async => http.Response(
            jsonEncode({
              'data': {
                'me': {'__typename': 'User', 'name': 'Ada', 'age': null},
              },
              'errors': [
                {'message': 'upstream down', 'path': ['me', 'age']},
              ],
            }),
            200,
          )),
    );
    final scope = client.createScope(onChanged: () {});
    scope.run((q) => (q.me.name, q.me.age));
    await scope.whenSettled;

    expect(scope.error, isA<SlingException>());
    expect((scope.error as SlingException).graphqlErrors, hasLength(1));
    expect(client.cache.read('query', ['me', 'name']), 'Ada');
    expect(client.cache.read('query', ['me', 'age']), missing);
  });

  testWidgets('two widgets in one frame → one batched request', (tester) async {
    final h = Harness((q, v) => {
          'me': {
            '__typename': 'User',
            'name': 'Ada',
            'friends': [
              {'__typename': 'User', 'id': 'x', 'name': 'Bob'},
            ],
          },
        });

    await tester.pumpWidget(SlingScope<Query>(
      client: h.client,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [
          QueryBuilder<Query>(
            builder: (_, q, s) => Text(q.me.name ?? 'loading'),
          ),
          QueryBuilder<Query>(
            builder: (_, q, s) => Column(
              children: [for (final f in q.me.friends()) Text(f.name ?? '…')],
            ),
          ),
        ]),
      ),
    ));

    expect(find.text('loading'), findsOneWidget);
    expect(find.text('…'), findsOneWidget);

    await tester.pump(); // let the microtask flush + response land

    expect(h.sent, hasLength(1));
    expect(h.sent.single.document, '''
query {
  me {
    __typename
    id
    name
    friends {
      __typename
      id
      name
    }
  }
}''');
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });
}

class _FriendTile extends StatelessWidget {
  const _FriendTile(this.user);
  final User user;
  @override
  Widget build(BuildContext context) => Text(user.name ?? '…');
}

void _childWidgetTests() {
  testWidgets('accessors passed to child widgets are fetched in the same batch',
      (tester) async {
    final h = Harness((q, v) => {
          'me': {
            '__typename': 'User',
            'friends': [
              {'__typename': 'User', 'name': 'Bob'},
              {'__typename': 'User', 'name': 'Cy'},
            ],
          },
        });

    await tester.pumpWidget(SlingScope<Query>(
      client: h.client,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: QueryBuilder<Query>(
          // The builder itself reads no scalar: only the child widgets do.
          builder: (_, q, s) => Column(
            children: [for (final f in q.me.friends()) _FriendTile(f)],
          ),
        ),
      ),
    ));

    expect(find.text('…'), findsOneWidget);
    await tester.pump();

    expect(h.sent, hasLength(1));
    expect(h.sent.single.document, contains('friends {\n      __typename\n      id\n      name'));
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Cy'), findsOneWidget);
  });
}

// --- Normalization --------------------------------------------------------------

void _normalizationTests() {
  Map<String, Object?> meWithFriends() => {
        'me': {
          '__typename': 'User',
          'id': '1',
          'name': 'Ada',
          'friends': [
            {'__typename': 'User', 'id': 'a', 'name': 'Bob'},
            {'__typename': 'User', 'id': 'b', 'name': 'Cy'},
          ],
        },
      };

  test('keyed objects are stored once and referenced', () async {
    final h = Harness((q, v) => meWithFriends());
    await h.client.resolve((q) => q.me.friends().map((f) => f.name).toList());

    final cache = h.client.cache;
    expect(cache.entityKeys, containsAll(['ROOT_QUERY', 'User:1', 'User:a', 'User:b']));
    expect(cache.entity('ROOT_QUERY')!['me'], const Ref('User:1'));
    expect(cache.entity('User:1')!['friends'], [const Ref('User:a'), const Ref('User:b')]);
    expect(cache.read('query', ['me', 'friends', 1, 'name']), 'Cy');
    expect(cache.read('query', [const Ref('User:b'), 'name']), 'Cy');
  });

  test('lookup field is served from the entity: no request for known fields, '
      'only the missing ones are fetched', () async {
    final h = Harness((q, v) {
      if (q.contains('user(')) {
        return {'user_${_alias(v)}': {'__typename': 'User', 'id': 'a', 'age': 41}};
      }
      return meWithFriends();
    });
    await h.client.resolve((q) => q.me.friends().map((f) => f.name).toList());

    final name = await h.client.resolve((q) => q.user(id: 'a')?.name);
    expect(name, 'Bob');
    expect(h.sent, hasLength(1), reason: 'served from User:a via lookup');

    final age = await h.client.resolve((q) => q.user(id: 'a')?.age);
    expect(age, 41);
    expect(h.sent, hasLength(2));
    expect(h.sent.last.document, contains('user(id: \$v0) {\n    __typename\n    id\n    age\n  }'));
    expect(h.sent.last.document, isNot(contains('\n    name')), reason: 'name was cached');
    // After the fetch the root field points at the same entity.
    expect(h.client.cache.entity('ROOT_QUERY')!['user_${_alias({'v0': 'a'})}'],
        const Ref('User:a'));
  });

  test('optimistic write on one path is visible through every other path', () async {
    final h = Harness((q, v) => meWithFriends());
    await h.client.resolve((q) => q.me.friends().map((f) => f.name).toList());

    final scope = h.client.createScope(onChanged: () {});
    scope.run((q) => q.user(id: 'a')!.name = 'Robert');
    expect(scope.run((q) => q.me.friends()[0].name), 'Robert');
    expect(h.sent, hasLength(1));
  });

  test('notification is per entity field: only scopes that read it rebuild',
      () async {
    final h = Harness((q, v) => meWithFriends());
    await h.client.resolve((q) => (q.me.name, q.me.friends().map((f) => f.name).toList()));

    var listRebuilds = 0, headerRebuilds = 0, ageRebuilds = 0;
    final list = h.client.createScope(onChanged: () => listRebuilds++);
    final header = h.client.createScope(onChanged: () => headerRebuilds++);
    final age = h.client.createScope(onChanged: () => ageRebuilds++);
    list.run((q) => q.me.friends().map((f) => f.name).toList());
    header.run((q) => q.me.name);
    age.run((q) => q.me.friends()[0].age); // missing → skeleton, dep on User:a.age

    final touched = h.client.cache.write('query', [const Ref('User:a'), 'name'], 'Robert');
    expect(touched, {'User:a.name'});
    // Notify manually: cache writes outside a scope do not notify by themselves.
    list.onWrite(touched);

    expect(listRebuilds, 1);
    expect(headerRebuilds, 0);
    expect(ageRebuilds, 0, reason: 'read a different field of the same entity');
  });

  test('lists of entities are replaced, entities are merged', () async {
    var call = 0;
    final h = Harness((q, v) {
      call++;
      return {
        'me': {
          '__typename': 'User',
          'id': '1',
          'friends': call == 1
              ? [
                  {'__typename': 'User', 'id': 'a', 'name': 'Bob'},
                  {'__typename': 'User', 'id': 'b', 'name': 'Cy'},
                ]
              : [
                  {'__typename': 'User', 'id': 'b', 'age': 30},
                ],
        },
      };
    });
    final scope = h.client.createScope(onChanged: () {});
    scope.run((q) => q.me.friends().map((f) => f.name).toList());
    await scope.whenSettled;
    await scope.refetch();

    final cache = h.client.cache;
    expect(cache.entity('User:1')!['friends'], [const Ref('User:b')]);
    expect(cache.entity('User:b'), {'__typename': 'User', 'id': 'b', 'name': 'Cy', 'age': 30});
    expect(cache.hasEntity('User:a'), isTrue, reason: 'unreachable until gc()');
    expect(cache.gc(), {'User:a'});
  });

  test('evict removes the entity, drops it from lists and blanks object fields',
      () async {
    final h = Harness((q, v) => meWithFriends());
    await h.client.resolve((q) => q.me.friends().map((f) => f.name).toList());
    final cache = h.client.cache;

    final touched = cache.evict('User:a');
    expect(touched, containsAll(['User:a.name', 'User:1.friends']));
    expect(cache.entity('User:1')!['friends'], [const Ref('User:b')]);

    cache.evict('User:1');
    expect(cache.read('query', ['me']), missing, reason: 'blanked field → refetch');
  });

  test('snapshot round-trips through JSON and hydrates', () async {
    final h = Harness((q, v) => meWithFriends());
    await h.client.resolve((q) => q.me.friends().map((f) => f.name).toList());

    final json = jsonDecode(jsonEncode(h.client.cache.snapshot)) as Map<String, Object?>;
    expect((json['ROOT_QUERY'] as Map)['me'], {'__ref': 'User:1'});

    final restored = Cache(initial: json);
    expect(restored.read('query', ['me', 'friends', 0, 'name']), 'Bob');
    expect(restored.entity('ROOT_QUERY')!['me'], const Ref('User:1'));
  });

  test('onChange streams the touched keys', () async {
    final h = Harness((q, v) => meWithFriends());
    final events = <Set<String>>[];
    final sub = h.client.cache.onChange.listen(events.add);
    await h.client.resolve((q) => q.me.name);
    h.client.cache.write('query', ['me', 'name'], 'Grace');
    await sub.cancel();

    expect(events, hasLength(2));
    expect(events.first, containsAll(['ROOT_QUERY.me', 'User:1.name']));
    expect(events.last, {'User:1.name'});
  });

  test('Normalization.none keeps everything inline', () async {
    final client = SlingClient<Query>(
      endpoint: Uri.parse('http://test/graphql'),
      rootFactory: Query.root,
      cache: Cache(normalization: Normalization.none),
      httpClient: MockClient((req) async =>
          http.Response(jsonEncode({'data': meWithFriends()}), 200)),
    );
    await client.resolve((q) => q.me.friends().map((f) => f.name).toList());
    expect(client.cache.entityKeys, ['ROOT_QUERY']);
    expect(client.cache.read('query', ['me', 'friends', 0, 'name']), 'Bob');
  });
}

String _friendsAlias(int limit) => Selection.root('query')
    .child('friends', {'limit': Arg('Int', limit)})
    .alias
    .substring('friends_'.length);

String _alias(Map vars) {
  // Recompute the alias the same way Selection does, for the test server.
  final root = Selection.root('query');
  final sel = root.child('user', {'id': Arg('ID!', vars['v0'])});
  return sel.alias.substring('user_'.length);
}
