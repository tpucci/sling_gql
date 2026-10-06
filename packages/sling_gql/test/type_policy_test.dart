import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sling_gql/internal.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/printed_document.dart';

// --- Hand-written "generated" code -------------------------------------------
//
// type Query {
//   users(first: Int, after: String, last: Int, before: String,
//         role: String): UserConnection!
//   user(id: ID!): User
//   node(id: ID!): Node
//   tags(page: Int): [String!]!
// }
// type UserConnection { edges: [UserEdge!]!  nodes: [User!]!
//                       pageInfo: PageInfo!  totalCount: Int! }
// type UserEdge { cursor: String!  node: User! }
// type PageInfo { hasNextPage: Boolean!  hasPreviousPage: Boolean!
//                 startCursor: String  endCursor: String }
// type User { id: ID!  name: String!  age: Int }
// interface Node { id: ID!  members(first: Int, after: String): UserConnection! }
// type Team implements Node { id: ID!  name: String!
//                             members(first: Int, after: String): UserConnection! }
// type Mutation { touch: Boolean }

class Query extends Accessor {
  Query(super.recorder, super.selection, super.path);
  Query.root(Recorder r) : super(r, r.root, const []);

  UserConnection? users({
    int? first,
    String? after,
    int? last,
    String? before,
    String? role,
  }) => object(
    'users',
    UserConnection.new,
    args: {
      'first': Arg('Int', first),
      'after': Arg('String', after),
      'last': Arg('Int', last),
      'before': Arg('String', before),
      'role': Arg('String', role),
    },
  );

  User? user({required String id}) =>
      object('user', User.new, args: {'id': Arg('ID!', id)}, lookup: 'User');

  Node? node({required String id}) =>
      object('node', Node.new, args: {'id': Arg('ID!', id)}, keyed: true);

  List<String?>? tags({int? page}) =>
      scalarList<String>('tags', args: {'page': Arg('Int', page)});
}

class UserConnection extends Accessor {
  UserConnection(super.recorder, super.selection, super.path);

  List<UserEdge>? get edges => list('edges', UserEdge.new);
  List<User>? get nodes => list('nodes', User.new, keyed: true);
  PageInfo? get pageInfo => object('pageInfo', PageInfo.new);
  int? get totalCount => scalar<int>('totalCount');
}

class UserEdge extends Accessor {
  UserEdge(super.recorder, super.selection, super.path);

  String? get cursor => scalar<String>('cursor');
  User? get node => object('node', User.new, keyed: true);
}

class PageInfo extends Accessor {
  PageInfo(super.recorder, super.selection, super.path);

  bool? get hasNextPage => scalar<bool>('hasNextPage');
  bool? get hasPreviousPage => scalar<bool>('hasPreviousPage');
  String? get startCursor => scalar<String>('startCursor');
  String? get endCursor => scalar<String>('endCursor');
}

class User extends Accessor {
  User(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  int? get age => scalar<int>('age');
  set age(int? v) => write('age', v);
}

class Node extends Accessor {
  Node(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  UserConnection? members({int? first, String? after}) => object(
    'members',
    UserConnection.new,
    args: {'first': Arg('Int', first), 'after': Arg('String', after)},
  );
  Team? get asTeam => on('Team', Team.new, keyed: true);
}

class Team extends Accessor {
  Team(super.recorder, super.selection, super.path);

  String? get name => scalar<String>('name');
  UserConnection? members({int? first, String? after}) => object(
    'members',
    UserConnection.new,
    args: {'first': Arg('Int', first), 'after': Arg('String', after)},
  );
}

class Mutation extends Accessor {
  Mutation(super.recorder, super.selection, super.path);
  Mutation.root(Recorder r) : super(r, r.root, const []);

  bool? get touch => scalar<bool>('touch');
}

extension on CacheScope<Query> {
  User? user(String id) => entity('User', id, User.new);
}

// --- Mock data: six users, cursors `c<i>` ------------------------------------

final ages = <int, int?>{};

Map<String, Object?> userJson(int i) => {
  '__typename': 'User',
  'id': 'u$i',
  'name': 'U$i',
  'age': ages[i] ?? 20 + i,
};

Map<String, Object?> connection(Map<String, Object?> args, List<int> all) {
  final after = args['after'] as String?;
  final before = args['before'] as String?;
  // Cursors are positions in id order, so they survive a deletion.
  var start = 0, end = all.length;
  if (after != null) {
    final id = int.parse(after.substring(1));
    start = all.indexWhere((i) => i > id);
    if (start < 0) start = all.length;
  }
  if (before != null) {
    final id = int.parse(before.substring(1));
    end = all.indexWhere((i) => i >= id);
    if (end < 0) end = all.length;
  }
  var slice = all.sublist(start, end);
  final first = args['first'] as int?, last = args['last'] as int?;
  if (first != null && slice.length > first) slice = slice.sublist(0, first);
  if (last != null && slice.length > last) {
    slice = slice.sublist(slice.length - last);
  }
  return {
    '__typename': 'UserConnection',
    'edges': [
      for (final i in slice)
        {'__typename': 'UserEdge', 'cursor': 'c$i', 'node': userJson(i)},
    ],
    'nodes': [for (final i in slice) userJson(i)],
    'pageInfo': {
      '__typename': 'PageInfo',
      'hasNextPage': slice.isNotEmpty && slice.last != all.last,
      'hasPreviousPage': slice.isNotEmpty && slice.first != all.first,
      'startCursor': slice.isEmpty ? null : 'c${slice.first}',
      'endCursor': slice.isEmpty ? null : 'c${slice.last}',
    },
    'totalCount': all.length,
  };
}

/// The users the server lists, in order (a test may change it).
var everyone = [1, 2, 3, 4, 5, 6];

Map<String, Object?> rootJson() => {
  '__typename': 'Query',
  'users': (Map<String, Object?> args) =>
      connection(args, args['role'] == 'admin' ? const [1, 3, 5] : everyone),
  'user': (Map<String, Object?> args) =>
      userJson(int.parse((args['id'] as String).substring(1))),
  'node': (Map<String, Object?> args) => {
    '__typename': 'Team',
    'id': args['id'],
    'name': 'Team',
    'members': (Map<String, Object?> a) => connection(a, everyone),
  },
  'tags': (Map<String, Object?> args) => switch (args['page']) {
    2 => ['c'],
    _ => ['a', 'b'],
  },
};

const relay = {
  Query: TypePolicy(fields: {'users': RelayStylePagination()}),
};

void main() {
  late List<PrintedOperation> sent;
  setUp(() {
    sent = [];
    ages.clear();
    everyone = [1, 2, 3, 4, 5, 6];
  });

  SlingClient<Query> client({
    Map<Type, TypePolicy> typePolicies = relay,
    Iterable<ListRule<Accessor>> listRules = const [],
    Cache? cache,
    FetchPolicy fetchPolicy = FetchPolicy.cacheFirst,
  }) {
    final c = SlingClient<Query>(
      endpoint: Uri.parse('http://test/graphql'),
      rootFactory: Query.root,
      cache: cache,
      onOperation: sent.add,
      typePolicies: typePolicies,
      listRules: listRules,
      fetchPolicy: fetchPolicy,
      gcAfterWrites: null,
      httpClient: printedDocumentServer(
        rootJson,
        onRequest: (document, _) =>
            document.startsWith('mutation') ? http.Response('down', 500) : null,
      ),
    );
    addTearDown(c.dispose);
    return c;
  }

  /// The names of [c]'s nodes, after reading the rest of what a list
  /// screen reads (page info, count).
  List<String?> namesOf(UserConnection? c) {
    c?.pageInfo
      ?..hasNextPage
      ..hasPreviousPage
      ..startCursor
      ..endCursor;
    c?.totalCount;
    return [for (final u in c?.nodes ?? const <User>[]) u.name];
  }

  /// The merged list, read from the cache only.
  List<String?> cached(SlingClient<Query> c) =>
      namesOf(c.cacheScope.query.users());

  Map<String, Object?> rootFields(SlingClient<Query> c) =>
      Map.of(c.cache.entity('ROOT_QUERY')!);

  Future<List<String?>> page(SlingClient<Query> c, {String? after}) =>
      c.resolve((q) => namesOf(q.users(first: 2, after: after)));

  group('cache key', () {
    test('pagination args are not part of a relay entry; key args are', () {
      final root = Selection.root('query');
      Selection field(Map<String, Arg> args) =>
          root.objectChild('users', args)
            ..bindPolicy(const RelayStylePagination());
      final first = field({'first': const Arg('Int', 2)});
      final next = field({
        'first': const Arg('Int', 2),
        'after': const Arg('String', 'c2'),
      });
      final admins = field({
        'first': const Arg('Int', 2),
        'role': const Arg('String', 'admin'),
      });
      expect(first.alias, isNot(next.alias), reason: 'one response key each');
      expect(first.cacheKey, 'users');
      expect(next.cacheKey, 'users');
      expect(admins.cacheKey, startsWith('users_'));
      expect(next.sameEntry, [first, next]);

      final explicit = Selection.root('query').objectChild('users', {
        'first': const Arg('Int', 2),
        'role': const Arg('String', 'admin'),
      })..bindPolicy(const FieldPolicy(keyArgs: []));
      expect(explicit.cacheKey, 'users', reason: 'keyArgs: [] → one entry');
    });

    test(
      'a keyArgs-only policy shares one entry between argument sets',
      () async {
        final c = client(
          typePolicies: const {
            Query: TypePolicy(
              fields: {
                'users': FieldPolicy(keyArgs: ['role']),
              },
            ),
          },
        );
        expect(await page(c), ['U1', 'U2']);
        // `first: 3` is not a key argument: the entry is served from cache.
        final three = await c.resolve((q) => namesOf(q.users(first: 3)));
        expect(three, ['U1', 'U2']);
        expect(sent, hasLength(1));
        expect(rootFields(c).keys, ['users']);
      },
    );
  });

  group('RelayStylePagination', () {
    test(
      'pages merge into one entry: one root field, pages recorded',
      () async {
        final c = client();
        expect(await page(c), ['U1', 'U2']);
        expect(await page(c, after: 'c2'), ['U1', 'U2', 'U3', 'U4']);

        expect(sent, hasLength(2));
        expect(sent.last.document, contains(r'after: $after'));
        expect(sent.last.variables, {'first': 2, 'after': 'c2'});
        expect(rootFields(c).keys, ['users'], reason: 'no entry per cursor');
        final entry = rootFields(c)['users']! as Map;
        expect(entry[RelayStylePagination.pagesKey], [
          <Object?>[],
          ['after', 'c2'],
        ]);
        final merged = c.cacheScope.query.users()!;
        expect(cached(c), ['U1', 'U2', 'U3', 'U4']);
        expect(merged.pageInfo?.endCursor, 'c4');
        expect(merged.pageInfo?.startCursor, 'c1');
        expect(merged.pageInfo?.hasNextPage, isTrue);
        expect(merged.totalCount, 6);
        expect(
          sent.map((op) => op.document).join(),
          isNot(contains('__pages')),
          reason: 'the bookkeeping is never selected',
        );
      },
    );

    test(
      'a page not merged yet reads as a skeleton miss; a merged one hits',
      () async {
        final c = client();
        await page(c);
        final scope = c.createScope(onChanged: () {});
        addTearDown(scope.dispose);
        List<User>? nodes;
        scope.run((q) => nodes = q.users(first: 2, after: 'c2')?.nodes);
        expect(nodes, hasLength(1));
        expect(nodes!.single.isSkeleton, isTrue);
        expect(scope.hasMissingData, isTrue);
        await scope.whenSettled;
        expect(sent, hasLength(2));

        scope.run((q) => nodes = q.users(first: 2, after: 'c2')?.nodes);
        expect(scope.hasMissingData, isFalse);
        expect(nodes, hasLength(4), reason: 'the merged list');
        await Future<void>.delayed(Duration.zero);
        expect(sent, hasLength(2));
      },
    );

    test('each key-arg set is its own merged list', () async {
      final c = client();
      await page(c);
      final admins = await c.resolve(
        (q) => namesOf(q.users(first: 2, role: 'admin')),
      );
      expect(admins, ['U1', 'U3']);
      expect(
        await c.resolve(
          (q) => namesOf(q.users(first: 2, after: 'c3', role: 'admin')),
        ),
        ['U1', 'U3', 'U5'],
      );
      expect(cached(c), ['U1', 'U2'], reason: 'the unfiltered list is apart');
      expect(rootFields(c).keys, hasLength(2));
    });

    test(
      'two pages in one request: own response keys, merged in order',
      () async {
        final c = client();
        final names = await c.resolve(
          (q) => [
            ...namesOf(q.users(first: 2)),
            ...namesOf(q.users(first: 2, after: 'c2')),
          ],
        );
        expect(sent, hasLength(1));
        final doc = sent.single.document;
        expect(RegExp(r'users_\w+: users\(').allMatches(doc), hasLength(2));
        expect(cached(c), ['U1', 'U2', 'U3', 'U4']);
        // Both reads return the merged list once it landed.
        expect(names, ['U1', 'U2', 'U3', 'U4', 'U1', 'U2', 'U3', 'U4']);
      },
    );

    test('toCacheKeys maps every page to the entry as a PolicyWrite', () {
      final root = Selection.root('query');
      for (final after in [null, 'c2']) {
        root.objectChild('users', {
            'first': const Arg('Int', 2),
            'after': Arg('String', after),
          })
          ..bindPolicy(const RelayStylePagination())
          ..child('totalCount').bindPolicy(null);
      }
      final op = PrintedOperation.from(root);
      final aliases = [for (final c in root.children) c.alias];
      final data = op.toCacheKeys({
        aliases[0]: {'totalCount': 6},
        aliases[1]: {'totalCount': 6},
      });
      expect(data.keys, ['users']);
      final write = data['users']! as PolicyWrite;
      expect(write.pages.map((p) => p.args), [
        {'first': 2},
        {'first': 2, 'after': 'c2'},
      ]);
      expect(write.pages.every((p) => !p.fill), isTrue);
    });

    test('backward pages prepend; pageInfo ends follow', () async {
      final c = client();
      final last = await c.resolve(
        (q) => namesOf(q.users(last: 2, before: 'c5')),
      );
      expect(last, ['U3', 'U4']);
      await c.resolve((q) => namesOf(q.users(last: 2, before: 'c3')));
      final merged = c.cacheScope.query.users()!;
      expect(cached(c), ['U1', 'U2', 'U3', 'U4']);
      expect(merged.pageInfo?.startCursor, 'c1');
      expect(merged.pageInfo?.endCursor, 'c4');
      expect(merged.pageInfo?.hasPreviousPage, isFalse);
    });

    test('merge: an edges cursor cuts the list; null pages keep the entry', () {
      const policy = RelayStylePagination();
      Map<String, Object?> edge(int i) => {'cursor': 'c$i', 'node': Ref('u$i')};
      final existing = {
        'edges': [edge(1), edge(2), edge(3)],
        'nodes': [const Ref('u1'), const Ref('u2'), const Ref('u3')],
        'pageInfo': {'endCursor': 'c3', 'hasNextPage': true},
        'totalCount': 3,
        RelayStylePagination.pagesKey: [
          <Object?>[],
          ['after', 'c1'],
          ['after', 'c3'],
        ],
      };
      final merged = policy.merge(existing, {
        'edges': [edge(9)],
        'nodes': [const Ref('u9')],
        'pageInfo': {'endCursor': 'c9', 'hasNextPage': false},
        'totalCount': 9,
      }, const FieldMergeContext(field: 'users', args: {'after': 'c1'})) as Map;
      expect(merged['edges'], [edge(1), edge(9)]);
      expect(merged['nodes'], [const Ref('u1'), const Ref('u9')]);
      expect(merged['pageInfo'], {'endCursor': 'c9', 'hasNextPage': false});
      expect(merged['totalCount'], 9);
      expect(merged[RelayStylePagination.pagesKey], [
        <Object?>[],
        ['after', 'c1'],
      ], reason: 'the page after c3 was cut off with it');
      expect(existing['nodes'], hasLength(3), reason: 'not mutated');

      // A server `null` for a later page keeps the entry; for the first
      // page it is the value.
      const later = FieldMergeContext(field: 'users', args: {'after': 'c3'});
      expect(policy.merge(existing, null, later), same(existing));
      const first = FieldMergeContext(field: 'users', args: {'first': 2});
      expect(policy.merge(existing, null, first), isNull);

      // An empty last page keeps the end cursor.
      final empty = policy.merge(existing, {
        'nodes': <Object?>[],
        'pageInfo': {'endCursor': null, 'hasNextPage': false},
      }, later) as Map;
      expect(empty['pageInfo'], {'endCursor': 'c3', 'hasNextPage': false});
    });
  });

  group('refresh resets', () {
    test(
      'refetch sends the first page only and starts the list over',
      () async {
        final c = client();
        final scope = c.createScope(onChanged: () {});
        addTearDown(scope.dispose);
        List<String?> read() => scope.run(
          (q) => [
            ...namesOf(q.users(first: 2)),
            if (q.users(first: 2, after: 'c2') case final next?) ...[
              next.pageInfo?.endCursor,
            ],
          ],
        );
        read();
        await scope.whenSettled;
        expect(cached(c), ['U1', 'U2', 'U3', 'U4']);

        read();
        await scope.refetch();
        final doc = sent.last.document;
        expect(RegExp(r'users\(').allMatches(doc), hasLength(1));
        expect(doc, isNot(contains('after')));
        expect(cached(c), ['U1', 'U2']);
        final entry = rootFields(c)['users']! as Map;
        expect(entry[RelayStylePagination.pagesKey], [<Object?>[]]);
      },
    );

    test('cacheAndNetwork revalidates from the first page too', () async {
      final c = client();
      await page(c);
      await page(c, after: 'c2');
      final scope = c.createScope(
        onChanged: () {},
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      );
      addTearDown(scope.dispose);
      scope.run(
        (q) => [
          namesOf(q.users(first: 2)),
          namesOf(q.users(first: 2, after: 'c2')),
        ],
      );
      await scope.whenSettled;
      expect(sent, hasLength(3));
      expect(sent.last.document, isNot(contains('after')));
      expect(cached(c), ['U1', 'U2']);
    });

    test('a refetch returning the same first page changes nothing', () async {
      final c = client();
      final scope = c.createScope(onChanged: () {});
      addTearDown(scope.dispose);
      scope.run((q) => namesOf(q.users(first: 2)));
      await scope.whenSettled;
      final changes = <Set<String>>[];
      c.cache.onChange.listen(changes.add);
      final version = c.cache.version;
      scope.run((q) => namesOf(q.users(first: 2)));
      await scope.refetch();
      expect(sent, hasLength(2));
      expect(changes, isEmpty);
      expect(c.cache.version, version);
    });
  });

  group('fill', () {
    test('a field read inside the merged list is fetched for every page held, '
        'and never resets it', () async {
      final c = client();
      await page(c);
      await page(c, after: 'c2');
      ages[3] = 99;
      final changes = <Set<String>>[];
      c.cache.onChange.listen(changes.add);

      final read = await c.resolve(
        (q) => [for (final u in q.users(first: 2)!.nodes!) u.age],
      );
      expect(read, [21, 22, 99, 24]);
      expect(changes.expand((k) => k), isNot(contains('ROOT_QUERY.users')));
      expect(sent, hasLength(3));
      final doc = sent.last.document;
      expect(RegExp(r'users_\w+: users\(').allMatches(doc), hasLength(2));
      expect(sent.last.variables, containsPair('after', 'c2'));
      expect(cached(c), ['U1', 'U2', 'U3', 'U4'], reason: 'no page lost');
      final entry = rootFields(c)['users']! as Map;
      expect(entry[RelayStylePagination.pagesKey], [
        <Object?>[],
        ['after', 'c2'],
      ]);
    });

    test('fill adds what an entry lacks, matching edges by cursor', () {
      final filled = FieldPolicy.addAbsent(
        {
          'edges': [
            {'cursor': 'c1'},
            {'cursor': 'c2'},
          ],
          'pageInfo': {'endCursor': 'c2'},
        },
        {
          'edges': [
            {'cursor': 'c2', 'extra': 'x'},
          ],
          'pageInfo': {'endCursor': 'c9', 'startCursor': 'c1'},
          'totalCount': 2,
        },
      ) as Map;
      expect(filled, {
        'edges': [
          {'cursor': 'c1'},
          {'cursor': 'c2', 'extra': 'x'},
        ],
        'pageInfo': {'endCursor': 'c2', 'startCursor': 'c1'},
        'totalCount': 2,
      });
    });

    test('a relay fill of every held page drops what no page returned', () {
      const policy = RelayStylePagination();
      final existing = {
        'nodes': [const Ref('u1'), const Ref('u2'), const Ref('u9')],
        RelayStylePagination.pagesKey: [
          <Object?>[],
          ['after', 'c2'],
        ],
      };
      ({Map<String, Object?> args, Object? value}) fetched(
        Map<String, Object?> args,
        List<Ref> nodes,
      ) => (args: args, value: {'nodes': nodes});
      final all = policy.fill(existing, [
        fetched({'first': 2}, [const Ref('u1')]),
        fetched({'first': 2, 'after': 'c2'}, [const Ref('u2')]),
      ]) as Map;
      expect(all['nodes'], [const Ref('u1'), const Ref('u2')]);
      // Only some pages refetched: nothing can be told about the others.
      final some = policy.fill(existing, [
        fetched({'first': 2}, [const Ref('u1')]),
      ]) as Map;
      expect(some['nodes'], hasLength(3));
    });
  });

  group('fill drift', () {
    test('a fill does not merge pages again: no duplicate, no reset; what '
        'no page returns any more leaves the list', () async {
      final c = client();
      await page(c);
      await page(c, after: 'c2');
      // Deleted on the server: merging the pages again would give U1 U3
      // U3 U4, a reset U1 U3. The fill drops U2, whose age could never
      // come back (a widget would refetch it forever).
      everyone = [1, 3, 4, 5, 6];
      final read = await c.resolve(
        (q) => [for (final u in q.users(first: 2)!.nodes!) u.age],
      );
      expect(read, [21, 23, 24]);
      expect(cached(c), ['U1', 'U3', 'U4']);
      final entry = rootFields(c)['users']! as Map;
      expect(entry[RelayStylePagination.pagesKey], hasLength(2));
    });
  });

  group('cache machinery', () {
    test('deltas, compact, fetchedAt, snapshot round trip', () async {
      final c = client();
      await page(c);
      final v1 = c.cache.version;
      await page(c, after: 'c2');
      final delta = c.cache.changesSince(v1);
      expect(delta.changedFields.keys, ['ROOT_QUERY']);
      final users = delta.changedFields['ROOT_QUERY']!['users']! as Map;
      expect(users['nodes'], hasLength(4));
      expect(users[RelayStylePagination.pagesKey], hasLength(2));
      expect(delta.changed.keys, containsAll(['User:u3', 'User:u4']));
      expect(c.cache.fetchedAt('ROOT_QUERY.users'), isNotNull);
      c.cache.compact(upTo: c.cache.version);
      expect(c.cache.changesSince(c.cache.version).isEmpty, isTrue);

      // A persisted copy: the next page continues from where it was.
      final restored = client(
        cache: Cache(initial: jsonDecode(jsonEncode(c.cache.snapshot))),
      );
      expect(cached(restored), ['U1', 'U2', 'U3', 'U4']);
      expect(await page(restored, after: 'c2'), hasLength(4));
      expect(sent, hasLength(2), reason: 'page two is covered after restore');
      expect(await page(restored, after: 'c4'), hasLength(6));
      expect(sent, hasLength(3));
    });

    test('a new page touches the field only', () async {
      final c = client();
      await page(c);
      final changes = <Set<String>>[];
      c.cache.onChange.listen(changes.add);
      await page(c, after: 'c2');
      expect(changes, hasLength(1));
      expect(changes.single.where((k) => k.startsWith('ROOT_QUERY')), [
        'ROOT_QUERY.users',
      ]);
    });

    test('gc drops the entities a reset removed from the list', () async {
      final c = client();
      await page(c);
      await page(c, after: 'c2');
      expect(c.gc(), isEmpty);
      await c.resolve(
        (q) => namesOf(q.users(first: 2)),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      );
      expect(cached(c), ['U1', 'U2']);
      expect(c.gc(), {'User:u3', 'User:u4'});
    });

    test('ListRule removes from and inserts into the merged list', () async {
      final c = client(
        listRules: [
          ListRule<User>(
            field: 'users',
            items: 'nodes',
            typename: 'User',
            ctor: User.new,
            belongs: (args, u) => (u.age ?? 0) < 90,
            position: ListPosition.prepend,
          ),
        ],
      );
      List<Object?> rows(UserConnection? c) => [
        for (final u in c?.nodes ?? const <User>[]) [u.name, u.age],
      ];
      await c.resolve((q) => rows(q.users(first: 2)));
      await c.resolve((q) => rows(q.users(first: 2, after: 'c2')));
      await c.resolve((q) => [q.user(id: 'u5')?.name, q.user(id: 'u5')?.age]);

      c.cacheScope.user('u2')!.age = 95;
      expect(cached(c), ['U1', 'U3', 'U4']);
      ages[5] = 99;
      c.cacheScope.user('u5')!.age = 1;
      expect(cached(c), ['U5', 'U1', 'U3', 'U4']);
    });

    test(
      'an optimistic CacheList edit of the merged list rolls back',
      () async {
        final c = client();
        await page(c);
        await page(c, after: 'c2');
        await c.resolve((q) => q.user(id: 'u5')?.name);
        final failed = c.mutateWith(
          Mutation.root,
          (m) => m.touch,
          optimistic: () {
            final scope = c.cacheScope;
            scope.list((q) => q.users()?.nodes).prepend(scope.user('u5')!);
          },
        );
        expect(cached(c), ['U5', 'U1', 'U2', 'U3', 'U4']);
        await expectLater(failed, throwsA(isA<SlingException>()));
        expect(cached(c), ['U1', 'U2', 'U3', 'U4']);
      },
    );
  });

  group('policy lookup', () {
    test(
      'keys on the accessor class: through on(...) and the interface',
      () async {
        final c = client(
          typePolicies: const {
            Team: TypePolicy(fields: {'members': RelayStylePagination()}),
          },
        );
        Future<int> members({String? after, bool viaInterface = false}) =>
            c.resolve((q) {
              final node = q.node(id: 't1');
              final connection = viaInterface
                  ? node?.members(first: 2, after: after)
                  : node?.asTeam?.members(first: 2, after: after);
              return connection?.nodes?.length ?? 0;
            });

        expect(await members(), 2);
        expect(await members(after: 'c2'), 4);
        final team = c.cache.entity('Team:t1')!;
        expect(team.keys, contains('members'));
        expect((team['members']! as Map)['nodes'], hasLength(4));

        // Read through the `Node` interface accessor: no policy for `Node`,
        // so every argument set is its own entry.
        expect(await members(viaInterface: true), 2);
        expect(
          c.cache
              .entity('Team:t1')!
              .keys
              .where((k) => k.startsWith('members_')),
          hasLength(1),
        );
      },
    );

    test('a custom merge sees the cached value and the arguments', () async {
      final seen = <FieldMergeContext>[];
      final c = client(
        typePolicies: {
          Query: TypePolicy(
            fields: {
              'tags': FieldPolicy(
                keyArgs: const [],
                merge: (existing, incoming, context) {
                  seen.add(context);
                  return [...?existing as List?, ...incoming! as List];
                },
              ),
            },
          ),
        },
      );
      expect(await c.resolve((q) => q.tags()), ['a', 'b']);
      expect(
        await c.resolve(
          (q) => q.tags(page: 2),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        ['a', 'b', 'c'],
      );
      expect(rootFields(c).keys, ['tags']);
      expect(seen.map((s) => s.args), [
        <String, Object?>{},
        {'page': 2},
      ]);
      expect(seen.map((s) => s.field).toSet(), {'tags'});
    });
  });
}
