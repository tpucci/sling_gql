import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/internal.dart';
import 'package:sling_gql/sling_gql.dart';

// --- Hand-written "generated" code for unions and interfaces (#31) ----------
//
// interface Node   { id: ID! }
// type User implements Node { id: ID!  name: String! }
// type Bot  implements Node { id: ID!  model: String! }
// type Note        { text: String! }                 -- not keyed
// union SearchResult = User | Bot | Note
// type Query { search(text: String!): [SearchResult!]!
//              pinned: SearchResult
//              node(id: ID!): Node }
//
// The generator must emit exactly this shape (see emitter_test.dart).

class Query extends Accessor {
  Query(super.recorder, super.selection, super.path);
  Query.root(Recorder r) : super(r, r.root, const []);

  List<SearchResult>? search({required String text}) =>
      list('search', SearchResult.new, args: {'text': Arg('String!', text)});
  SearchResult? get pinned => object('pinned', SearchResult.new);
  Node? node({required String id}) =>
      object('node', Node.new, args: {'id': Arg('ID!', id)}, keyed: true);
}

class SearchResult extends Accessor {
  SearchResult(super.recorder, super.selection, super.path);

  User? get asUser => on('User', User.new, keyed: true);
  Bot? get asBot => on('Bot', Bot.new, keyed: true);
  Note? get asNote => on('Note', Note.new);

  T? when<T>({
    T Function(User user)? user,
    T Function(Bot bot)? bot,
    T Function(Note note)? note,
    T Function()? orElse,
  }) => whenType({
    if (user != null) 'User': () => user(asUser!),
    if (bot != null) 'Bot': () => bot(asBot!),
    if (note != null) 'Note': () => note(asNote!),
  }, orElse: orElse);
}

class Node extends Accessor {
  Node(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');

  User? get asUser => on('User', User.new, keyed: true);
  Bot? get asBot => on('Bot', Bot.new, keyed: true);

  T? when<T>({
    T Function(User user)? user,
    T Function(Bot bot)? bot,
    T Function()? orElse,
  }) => whenType({
    if (user != null) 'User': () => user(asUser!),
    if (bot != null) 'Bot': () => bot(asBot!),
  }, orElse: orElse);
}

class User extends Accessor {
  User(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  // `status: UserStatus!` — an enum — while `Bot.status` is a `String` (#57).
  String? get status => scalar<String>('status');
}

class Bot extends Accessor {
  Bot(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get model => scalar<String>('model');
  String? get status => scalar<String>('status');
}

class Note extends Accessor {
  Note(super.recorder, super.selection, super.path);

  String? get text => scalar<String>('text');
}

// --- Harness -------------------------------------------------------------------

class Harness {
  Harness(this.data) {
    client = SlingClient<Query>(
      endpoint: Uri.parse('http://test/graphql'),
      rootFactory: Query.root,
      onOperation: sent.add,
      httpClient: MockClient((req) async {
        final body = jsonDecode(req.body) as Map;
        return http.Response(jsonEncode({'data': data(body['query'])}), 200);
      }),
    );
  }

  final Map<String, Object?> Function(String query) data;
  late final SlingClient<Query> client;
  final sent = <PrintedOperation>[];
}

const searchAlias = 'search_jo0dpl1kgtlq7';

Map<String, Object?> searchResponse() => {
  searchAlias: [
    {'__typename': 'User', 'id': 'u1', 'name': 'Ada'},
    {'__typename': 'Bot', 'id': 'b1', 'model': 'R2'},
    {'__typename': 'Note', 'text': 'hello'},
  ],
};

String describe(SearchResult r) =>
    r.when(
      user: (u) => 'user ${u.name}',
      bot: (b) => 'bot ${b.model}',
      note: (n) => 'note ${n.text}',
    ) ??
    '?';

void main() {
  test('alias of search(text: "a") is stable', () {
    expect(
      Selection.root('query')
          .child('search', {'text': Arg('String!', 'a')})
          .alias,
      searchAlias,
    );
  });

  test(
    'a skeleton records every branch; one request, inline fragments',
    () async {
      final h = Harness((_) => searchResponse());
      final scope = h.client.createScope(onChanged: () {});

      final first = scope.run(
        (q) => q.search(text: 'a')!.map(describe).toList(),
      );
      expect(first, ['user null'], reason: 'skeleton: first branch rendered');
      await scope.whenSettled;

      expect(h.sent, hasLength(1));
      expect(h.sent.single.document, '''
query (\$text: String!) {
  $searchAlias: search(text: \$text) {
    __typename
    ... on User {
      id
      name
    }
    ... on Bot {
      id
      model
    }
    ... on Note {
      text
    }
  }
}''');

      final out = scope.run((q) => q.search(text: 'a')!.map(describe).toList());
      expect(out, ['user Ada', 'bot R2', 'note hello']);
      expect(scope.hasMissingData, isFalse);
      expect(h.sent, hasLength(1), reason: 'no second round trip');
    },
  );

  test(
    'asX is null for another type; members are normalized entities',
    () async {
      final h = Harness((_) => searchResponse());
      final items = await h.client.resolve(
        (q) => q
            .search(text: 'a')!
            .map((r) => (r.asUser?.name, r.asBot?.model, r.asNote?.text))
            .toList(),
      );
      expect(items, [
        ('Ada', null, null),
        (null, 'R2', null),
        (null, null, 'hello'),
      ]);
      final cache = h.client.cache;
      expect(cache.hasEntity('User:u1'), isTrue);
      expect(cache.hasEntity('Bot:b1'), isTrue);
      expect(
        cache.read('query', [searchAlias, 2, 'text']),
        'hello',
        reason: 'a member without a key stays inline',
      );
    },
  );

  test(
    'a field first read in one branch later fetches only that fragment',
    () async {
      var calls = 0;
      final h = Harness((query) {
        calls++;
        if (calls == 1) {
          return {
            'pinned': {'__typename': 'User', 'id': 'u1', 'name': 'Ada'},
          };
        }
        return {
          'pinned': {'__typename': 'User', 'id': 'u1'},
        };
      });
      final scope = h.client.createScope(onChanged: () {});
      scope.run((q) => q.pinned?.asUser?.name);
      await scope.whenSettled;
      expect(scope.run((q) => q.pinned?.asUser?.name), 'Ada');

      // A new branch field (`asBot`) on a cached User: nothing to fetch.
      expect(scope.run((q) => q.pinned?.asBot?.model), isNull);
      expect(scope.hasMissingData, isFalse);
      expect(h.sent, hasLength(1));

      // A new User field: one request with just `... on User { id }`.
      expect(scope.run((q) => q.pinned?.asUser?.id), 'u1');
      expect(h.sent, hasLength(1), reason: 'id came with the first response');
    },
  );

  test('interface: common fields on the node, keyed at the field', () async {
    final h = Harness(
      (_) => {
        'node_1fqm5qj1yt11y5': {'__typename': 'Bot', 'id': 'b1', 'model': 'R2'},
      },
    );
    final aliasOfNode = Selection.root('query')
        .child('node', {'id': Arg('ID!', 'b1')})
        .alias;
    expect(aliasOfNode, 'node_1fqm5qj1yt11y5');

    final out = await h.client.resolve((q) {
      final n = q.node(id: 'b1')!;
      return (n.id, n.when(user: (u) => u.name, bot: (b) => b.model));
    });
    expect(out, ('b1', 'R2'));
    expect(h.sent.single.document, '''
query (\$id: ID!) {
  node_1fqm5qj1yt11y5: node(id: \$id) {
    __typename
    id
    ... on User {
      id
      name
    }
    ... on Bot {
      id
      model
    }
  }
}''');
    expect(h.client.cache.hasEntity('Bot:b1'), isTrue);
  });

  test(
    'when: orElse for a type without a branch, null without orElse',
    () async {
      final h = Harness(
        (_) => {
          'pinned': {'__typename': 'Robot'},
        },
      );
      await h.client.resolve((q) => q.pinned?.asUser?.name);
      final scope = h.client.createScope(onChanged: () {});
      expect(
        scope.run(
          (q) => q.pinned!.when(user: (u) => 'user', orElse: () => 'other'),
        ),
        'other',
      );
      expect(scope.run((q) => q.pinned!.when(user: (u) => 'user')), isNull);
      expect(scope.run((q) => q.pinned!.asUser), isNull);
    },
  );

  test(
    'a write through a fragment accessor notifies readers of the entity',
    () async {
      final h = Harness((_) => searchResponse());
      await h.client.resolve(
        (q) => q.search(text: 'a')!.map((r) => r.asUser?.name).toList(),
      );
      var rebuilds = 0;
      final scope = h.client.createScope(onChanged: () => rebuilds++);
      expect(scope.run((q) => q.search(text: 'a')!.first.asUser!.name), 'Ada');
      h.client
          .createScope(onChanged: () {})
          .run((q) => q.search(text: 'a')!.first.asUser!.name = 'Grace');
      await Future<void>.delayed(Duration.zero);
      expect(rebuilds, greaterThan(0));
      expect(h.client.cache.read('query', [Ref('User:u1'), 'name']), 'Grace');
    },
  );

  test('fragments survive ensurePath / mergeFrom / covers', () {
    final a = Selection.root('query');
    final leaf = a.objectChild('pinned').fragment('User', 'id').child('name');
    final b = Selection.root('query')..ensurePath(leaf);
    expect(b.covers(a), isTrue);
    expect(leaf.aliasPath, ['pinned', 'name']);
    final c = Selection.root('query')..mergeFrom(a);
    expect(
      PrintedOperation.from(c).document,
      PrintedOperation.from(a).document,
    );
    expect(PrintedOperation.from(b).document, contains('... on User {'));
  });

  group('same field in several fragments (#57)', () {
    test('printed type-qualified, cached under the field alias', () async {
      final h = Harness(
        (_) => {
          searchAlias: [
            {'__typename': 'User', 'id': 'u1', 'status__User': 'ACTIVE'},
            {'__typename': 'Bot', 'id': 'b1', 'status__Bot': 'idle'},
          ],
        },
      );
      String? status(SearchResult r) =>
          r.when<String?>(user: (u) => u.status, bot: (b) => b.status);

      final out = await h.client.resolve(
        (q) => q.search(text: 'a')!.map(status).toList(),
      );
      expect(out, ['ACTIVE', 'idle']);
      expect(h.sent.single.document, '''
query (\$text: String!) {
  $searchAlias: search(text: \$text) {
    __typename
    ... on User {
      id
      status__User: status
    }
    ... on Bot {
      id
      status__Bot: status
    }
  }
}''');
      expect(h.sent.single.renamesFields, isTrue);
      final cache = h.client.cache;
      expect(cache.read('query', [Ref('User:u1'), 'status']), 'ACTIVE');
      expect(cache.read('query', [Ref('Bot:b1'), 'status']), 'idle');
    });

    test('a field in one fragment only keeps its plain name', () {
      final root = Selection.root('query');
      final pinned = root.objectChild('pinned');
      pinned.fragment('User', 'id').child('name');
      pinned.fragment('Bot', 'id').child('model');
      final op = PrintedOperation.from(root);
      expect(op.renamesFields, isFalse);
      final data = <String, Object?>{'pinned': <String, Object?>{}};
      expect(identical(op.toCacheKeys(data), data), isTrue);
    });

    test('direct and fragment selections of one field are merged', () {
      final root = Selection.root('query');
      final node = root.objectChild('node');
      node.objectChild('owner').child('a');
      node.fragment('User').objectChild('owner').child('b');
      final op = PrintedOperation.from(root);
      expect(op.document, '''
query {
  node {
    __typename
    owner {
      __typename
      a
    }
    ... on User {
      owner__User: owner {
        __typename
        b
      }
    }
  }
}''');
      expect(
        op.toCacheKeys({
          'node': {
            '__typename': 'User',
            'owner': {'__typename': 'O', 'a': 1},
            'owner__User': {'__typename': 'O', 'b': 2},
          },
        }),
        {
          'node': {
            '__typename': 'User',
            'owner': {'__typename': 'O', 'a': 1, 'b': 2},
          },
        },
      );
    });

    test('renames below lists and nested objects are mapped back', () {
      final root = Selection.root('query');
      final item = root.objectChild('items').objectChild('inner');
      item.fragment('User').child('status');
      item.fragment('Bot').child('status');
      final op = PrintedOperation.from(root);
      expect(
        op.toCacheKeys({
          'items': [
            {
              'inner': {'__typename': 'User', 'status__User': 'A'},
            },
            {
              'inner': {'__typename': 'Bot', 'status__Bot': 'b'},
            },
            {'inner': null},
          ],
        }),
        {
          'items': [
            {
              'inner': {'__typename': 'User', 'status': 'A'},
            },
            {
              'inner': {'__typename': 'Bot', 'status': 'b'},
            },
            {'inner': null},
          ],
        },
      );
    });

    test(
      'a partial error at a renamed path is pruned before caching',
      () async {
        final client = SlingClient<Query>(
          endpoint: Uri.parse('http://test/graphql'),
          rootFactory: Query.root,
          httpClient: MockClient(
            (req) async => http.Response(
              jsonEncode({
                'data': {
                  'pinned': {
                    '__typename': 'User',
                    'id': 'u1',
                    'status__User': null,
                  },
                },
                'errors': [
                  {
                    'message': 'boom',
                    'path': ['pinned', 'status__User'],
                  },
                ],
              }),
              200,
            ),
          ),
        );
        final scope = client.createScope(onChanged: () {});
        scope.run((q) => (q.pinned?.asUser?.status, q.pinned?.asBot?.status));
        await scope.whenSettled;
        expect(scope.error, isNotNull);
        expect(
          client.cache.read('query', [Ref('User:u1'), 'status']),
          missing,
          reason: 'the errored null is not a real null',
        );
      },
    );
  });
}
