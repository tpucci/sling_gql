// #54 — list-index granularity: a read through element `i` of an inline
// list held by an entity field records `entity.field[i]`, `Accessor.list`
// of inline objects records `entity.field[length]`, and a write touches only
// the elements that changed (plus the length when it changes).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/internal.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart' show mockGraphQL, testEndpoint;

// type Query { me: User! }
// type User  { id: ID!  name: String  tags: [String!]!  links: [Link!]!
//              friends: [User!]! }
// type Link  { url: String  parts: [Part!]! }   (no id: inline)
// type Part  { text: String }                   (no id: inline)

class Query extends Accessor {
  Query(super.recorder, super.selection, super.path);
  Query.root(Recorder r) : super(r, r.root, const []);

  User get me => object('me', User.new, keyed: true)!;
}

class User extends Accessor {
  User(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  List<String?> get tags => scalarList<String>('tags')!;
  List<Link> get links => list('links', Link.new)!;
  List<User> get friends => list('friends', User.new, keyed: true)!;
}

class Link extends Accessor {
  Link(super.recorder, super.selection, super.path);

  String? get url => scalar<String>('url');
  set url(String? v) => write('url', v);
  List<Part> get parts => list('parts', Part.new)!;
}

class Part extends Accessor {
  Part(super.recorder, super.selection, super.path);

  String? get text => scalar<String>('text');
}

extension on CacheScope<Query> {
  User? user(String id) => entity('User', id, User.new);
}

const me = 'User:1';
final links = depKey(me, 'links');
final linksLength = lengthDepKey(me, 'links');
String link(int i) => elementDepKey(me, 'links', i);

/// What the server answers; tests edit it between fetches.
class Server {
  List<String> urls = ['a', 'b', 'c'];
  List<String> texts = ['x', 'y', 'z'];
  List<String> tags = ['t1', 't2'];
  List<String> friends = ['a', 'b'];

  Map<String, Object?> data() => {
    'me': {
      '__typename': 'User',
      'id': '1',
      'name': 'Ada',
      'tags': [...tags],
      'links': [
        for (var i = 0; i < urls.length; i++)
          {
            'url': urls[i],
            'parts': [
              {'text': texts[i]},
            ],
          },
      ],
      'friends': [
        for (final id in friends)
          {'__typename': 'User', 'id': id, 'name': 'Friend $id'},
      ],
    },
  };
}

void main() {
  group('NormalizedCache list keys', () {
    late Server server;
    late NormalizedCache cache;
    setUp(() {
      server = Server();
      cache = NormalizedCache();
      cache.writeResponse('query', server.data());
    });

    test('a read through an inline element records its element key', () {
      final deps = <String>{};
      cache.read('query', [const Ref(me), 'links', 1, 'url'], deps: deps);
      expect(deps, {link(1)});
      deps.clear();
      cache.readField('query', [const Ref(me), 'links', 1], 'url', deps: deps);
      expect(deps, {link(1)}, reason: 'readField records the same');
    });

    test('the list itself: whole key, or length key for readListField', () {
      final deps = <String>{};
      cache.readField('query', const [Ref(me)], 'links', deps: deps);
      expect(deps, {links});
      deps.clear();
      cache.readListField('query', const [Ref(me)], 'links', deps: deps);
      expect(deps, {linksLength});
      deps.clear();
      // Out of range (a skeleton row) or not a list: the whole field.
      cache.read('query', [const Ref(me), 'links', 7, 'url'], deps: deps);
      cache.readListField('query', const [Ref(me)], 'nope', deps: deps);
      expect(deps, {links, depKey(me, 'nope')});
    });

    test('element and length keys are interned', () {
      final d1 = <String>{};
      final d2 = <String>{};
      for (final d in [d1, d2]) {
        cache.read('query', [const Ref(me), 'links', 2, 'url'], deps: d);
        cache.readListField('query', const [Ref(me)], 'links', deps: d);
      }
      for (final k in d1) {
        expect(identical(k, d2.lookup(k)), isTrue, reason: k);
      }
    });

    test('a changed element touches that element only', () {
      server.urls[1] = 'B';
      expect(cache.writeResponse('query', server.data()), {links, link(1)});
      expect(cache.writeResponse('query', server.data()), isEmpty);
    });

    test('a length change touches the length and the removed elements', () {
      server.urls.add('d');
      server.texts.add('w');
      expect(cache.writeResponse('query', server.data()), {links, linksLength});
      server.urls = ['a', 'b'];
      expect(cache.writeResponse('query', server.data()), {
        links,
        linksLength,
        link(2),
        link(3),
      });
    });

    test('nested inline lists belong to the outer element', () {
      server.texts[2] = 'Z';
      expect(cache.writeResponse('query', server.data()), {links, link(2)});
      final deps = <String>{};
      cache.readListField(
        'query',
        [const Ref(me), 'links', 2],
        'parts',
        deps: deps,
      );
      cache.read('query', [
        const Ref(me),
        'links',
        0,
        'parts',
        0,
        'text',
      ], deps: deps);
      expect(deps, {link(2), link(0)});
    });

    test('keyed lists keep the whole field', () {
      final deps = <String>{};
      cache.readField(
        'query',
        [const Ref(me), 'friends', 0],
        'name',
        deps: deps,
      );
      expect(deps, {depKey(me, 'friends'), 'User:a.name'});
      server.friends = ['b', 'a'];
      expect(cache.writeResponse('query', server.data()), {
        depKey(me, 'friends'),
      }, reason: 'reordered refs: no element keys');
    });

    test('scalar lists are read whole', () {
      final deps = <String>{};
      cache.readField('query', const [Ref(me)], 'tags', deps: deps);
      expect(deps, {depKey(me, 'tags')});
      server.tags[1] = 'T2';
      expect(
        cache.writeResponse('query', server.data()),
        containsAll([depKey(me, 'tags'), elementDepKey(me, 'tags', 1)]),
      );
    });

    test('write and remove touch the elements they change', () {
      expect(cache.write('query', [const Ref(me), 'links', 1, 'url'], 'B'), {
        links,
        link(1),
      });
      expect(cache.write('query', [const Ref(me), 'links', 3], {'url': 'd'}), {
        links,
        linksLength,
      });
      expect(cache.remove('query', [const Ref(me), 'links', 2]), {
        links,
        linksLength,
        link(2),
        link(3),
      });
      expect(cache.remove('query', [const Ref(me), 'links', 0, 'url']), {
        links,
        link(0),
      });
      // The whole list, element-wise like a response.
      final next = cache.read('query', const [Ref(me), 'links']) as List;
      expect(
        cache.write(
          'query',
          const [Ref(me), 'links'],
          [
            {'url': 'A'},
            next[1],
            next[2],
          ],
        ),
        {links, link(0)},
      );
      // Replaced by something else, or removed: every element.
      expect(cache.write('query', const [Ref(me), 'links'], null), {
        links,
        linksLength,
        link(0),
        link(1),
        link(2),
      });
    });

    test('a list becoming null touches its elements (response)', () {
      final user = Map<String, Object?>.of(
        server.data()['me'] as Map<String, Object?>,
      );
      user['links'] = null;
      expect(cache.writeResponse('query', {'me': user}), {
        links,
        linksLength,
        link(0),
        link(1),
        link(2),
      });
    });

    test('evict and clear touch the list keys', () {
      expect(
        cache.evict(me),
        containsAll([links, linksLength, link(0), link(1), link(2)]),
      );
      cache.writeResponse('query', server.data());
      final touched = <String>{};
      cache.onChange.listen(touched.addAll);
      cache.clear();
      expect(touched, containsAll([links, linksLength, link(2)]));
    });

    test('an evicted ref inside an inline list touches every element', () {
      cache.writeResponse('query', {
        'feed': [
          {'text': 'hi'},
          {
            'author': {'__typename': 'User', 'id': 'a'},
          },
          {'text': 'bye'},
        ],
      });
      expect(
        cache.evict('User:a'),
        containsAll([
          'ROOT_QUERY.feed',
          'ROOT_QUERY.feed[length]',
          'ROOT_QUERY.feed[0]',
          'ROOT_QUERY.feed[2]',
        ]),
      );
    });

    test('element and length keys answer fetchedAt for their field', () {
      final at = DateTime(2026);
      cache.writeResponse('query', server.data(), at: at);
      expect(cache.fetchedAt(link(1)), at);
      expect(cache.fetchedAt(linksLength), at);
      expect(cache.fetchedAt(elementDepKey(me, 'nope', 0)), isNull);
    });
  });

  group('scopes', () {
    late Server server;
    late SlingClient<Query> client;
    late Map<String, int> rebuilds;

    setUp(() async {
      server = Server();
      client = SlingClient<Query>(
        endpoint: testEndpoint,
        rootFactory: Query.root,
        httpClient: mockGraphQL((_, _) => server.data()),
      );
      rebuilds = {};
      await client.resolve(
        (q) => [
          q.me.name,
          q.me.tags,
          for (final l in q.me.links) (l.url, l.parts.map((p) => p.text)),
          for (final f in q.me.friends) f.name,
        ],
      );
    });

    QueryScope<Query> scope(String label, void Function(Query q) body) =>
        client.createScope(
          onChanged: () =>
              rebuilds.update(label, (n) => n + 1, ifAbsent: () => 1),
        )..run(body);

    Future<void> refetch() => client.resolve(
      (q) => [
        for (final l in q.me.links) (l.url, l.parts.map((p) => p.text)),
        for (final f in q.me.friends) f.name,
        q.me.tags,
      ],
      fetchPolicy: FetchPolicy.networkOnly,
    );

    void readers() {
      scope('link 0', (q) => q.me.links[0].url);
      scope('link 1', (q) => q.me.links[1].url);
      scope('link 2 part', (q) => q.me.links[2].parts[0].text);
      scope('length', (q) => q.me.links.length);
      scope('all', (q) => q.me.links.map((l) => l.url).toList());
      scope('friends', (q) => q.me.friends.map((f) => f.id).toList());
      scope('tags', (q) => q.me.tags);
    }

    test('an element change rebuilds the readers of that element', () async {
      readers();
      final s = scope('probe', (q) => q.me.links[0].url);
      expect(s.deps, containsAll([linksLength, link(0)]));
      expect(s.deps, isNot(contains(links)));
      rebuilds.clear();

      server.urls[1] = 'B';
      await refetch();
      expect(rebuilds, {'link 1': 1, 'all': 1});
    });

    test('a nested change rebuilds the readers of the outer element', () async {
      readers();
      server.texts[2] = 'Z';
      await refetch();
      // `all` read element 2's url: same element.
      expect(rebuilds, {'link 2 part': 1, 'all': 1});
    });

    test('a length change rebuilds whoever called the list getter', () async {
      readers();
      server.urls.add('d');
      server.texts.add('w');
      await refetch();
      // `links[0]` goes through the `links` list (its length): every reader
      // of the list, none of `friends` / `tags`.
      expect(rebuilds, {
        'link 0': 1,
        'link 1': 1,
        'link 2 part': 1,
        'length': 1,
        'all': 1,
      });
    });

    test('rows depend on their element only, not the length', () async {
      var parentChanges = 0;
      final rowChanges = <int, int>{};
      final parent = client.createScope(onChanged: () => parentChanges++);
      final items = parent.run((q) => q.me.links);
      for (var i = 0; i < items.length; i++) {
        final row = parent.row(
          onChanged: () =>
              rowChanges.update(i, (n) => n + 1, ifAbsent: () => 1),
        );
        row.run(items[i], Link.new, (l) => l.url);
        expect(row.deps, {'ROOT_QUERY.me', link(i)});
      }
      expect(parent.deps, {'ROOT_QUERY.me', linksLength});

      server.urls[1] = 'B';
      await refetch();
      expect(parentChanges, 0);
      expect(rowChanges, {1: 1});

      server.urls.add('d');
      server.texts.add('w');
      await refetch();
      expect(parentChanges, 1, reason: 'grew');
      expect(rowChanges, {1: 1});

      server.urls = ['a', 'B'];
      await refetch();
      expect(parentChanges, 2, reason: 'shrank');
      expect(rowChanges, {1: 1, 2: 1});
    });

    test('keyed lists: reordering rebuilds every reader of the list', () async {
      readers();
      server.friends = ['b', 'a'];
      await refetch();
      expect(rebuilds, {'friends': 1});
    });

    test('scalar lists: any element rebuilds the reader', () async {
      readers();
      server.tags[0] = 'T1';
      await refetch();
      expect(rebuilds, {'tags': 1});
    });

    test('a setter on an element rebuilds that element\'s readers', () {
      readers();
      client.cacheScope.user('1')!.links[0].url = 'A';
      expect(rebuilds, {'link 0': 1, 'all': 1});
    });
  });

  group('SlingRow over inline elements', () {
    testWidgets('a change to one element rebuilds only its row', (
      tester,
    ) async {
      final server = Server();
      final client = SlingClient<Query>(
        endpoint: testEndpoint,
        rootFactory: Query.root,
        httpClient: mockGraphQL((_, _) => server.data()),
      );
      final builds = <String, int>{};
      void count(String what) =>
          builds.update(what, (n) => n + 1, ifAbsent: () => 1);

      await tester.pumpWidget(
        SlingScope<Query>(
          client: client,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: QueryBuilder<Query>(
              builder: (context, q, state) {
                count('list');
                final items = q.me.links;
                return Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      SlingRow(
                        items[i],
                        ctor: Link.new,
                        builder: (context, l) {
                          count('row $i');
                          return Text(l.url ?? '…');
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      for (var i = 0; i < 5 && !client.isIdle; i++) {
        await tester.pump(Duration.zero);
        await tester.runAsync(() => client.whenIdle);
      }
      await tester.pump();
      expect(find.text('b'), findsOneWidget);
      builds.clear();

      client.cacheScope.user('1')!.links[1].url = 'B';
      await tester.pump();
      expect(find.text('B'), findsOneWidget);
      expect(builds, {'row 1': 1}, reason: 'not the list, not rows 0 and 2');

      builds.clear();
      server.urls.add('d');
      server.texts.add('w');
      await tester.runAsync(
        () => client.resolve(
          (q) => q.me.links.map((l) => (l.url, l.parts.length)).toList(),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      await tester.pump();
      expect(find.text('d'), findsOneWidget);
      expect(builds['list'], 1, reason: 'the length changed');
    });
  });
}
