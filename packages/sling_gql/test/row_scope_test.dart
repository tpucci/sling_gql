import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/internal.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// #19 — `SlingRow` / `RowScope`: a write to one entity rebuilds the row
/// that read it, not the enclosing `QueryBuilder`.
/// #20 — identical inline containers in a response touch nothing.
void main() {
  group('inline containers (#20)', () {
    Map<String, Object?> response({int total = 3, bool hasNext = true}) => {
      'stats': {
        'total': total,
        'pageInfo': {'hasNextPage': hasNext, 'endCursor': 'c1'},
        'tags': ['a', 'b'],
      },
    };

    test('an identical inline object touches nothing', () {
      final cache = NormalizedCache();
      expect(cache.writeResponse('query', response()), {'ROOT_QUERY.stats'});
      expect(cache.writeResponse('query', response()), isEmpty);
    });

    test('a changed leaf deep inside touches the field holding it', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', response());
      expect(cache.writeResponse('query', response(hasNext: false)), {
        'ROOT_QUERY.stats',
      });
      expect(
        cache.read('query', ['stats', 'pageInfo', 'hasNextPage']),
        isFalse,
      );
    });

    test('a new key or a list of another length touches the field', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', response());
      expect(
        cache.writeResponse('query', {
          'stats': {'extra': 1},
        }),
        {'ROOT_QUERY.stats'},
      );
      expect(
        cache.writeResponse('query', {
          'stats': {
            'tags': ['a'],
          },
        }),
        {'ROOT_QUERY.stats'},
      );
      expect(
        cache.writeResponse('query', {
          'stats': {
            'tags': ['a'],
          },
        }),
        isEmpty,
      );
    });

    test('an entity changing inside a list touches the entity only', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', meWithFriends());
      final next = meWithFriends();
      ((next['me'] as Map)['friends'] as List)[0] = {
        '__typename': 'User',
        'id': 'a',
        'name': 'Robert',
      };
      expect(cache.writeResponse('query', next), {'User:a.name'});
    });

    test('without normalization, identical responses touch nothing', () {
      final cache = NormalizedCache(normalization: Normalization.none);
      cache.writeResponse('query', meWithFriends());
      expect(cache.writeResponse('query', meWithFriends()), isEmpty);
    });
  });

  group('SlingRow (#19)', () {
    late List<PrintedOperation> operations;
    late Map<String, int> builds;

    SlingClient<Query> client() {
      operations = [];
      builds = {};
      return SlingClient<Query>(
        endpoint: testEndpoint,
        rootFactory: Query.root,
        httpClient: mockGraphQL((_, _) => meWithFriends()),
        onOperation: operations.add,
      );
    }

    void count(String what) =>
        builds.update(what, (n) => n + 1, ifAbsent: () => 1);

    Widget app(SlingClient<Query> c, {bool rows = true}) => SlingScope<Query>(
      client: c,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: QueryBuilder<Query>(
          builder: (context, q, state) {
            count('list');
            final friends = q.me.friends();
            return Column(
              children: [
                for (final f in friends)
                  rows
                      ? SlingRow(
                          f,
                          ctor: User.new,
                          builder: (context, f) {
                            count('row ${f.id}');
                            return Text(f.name ?? '…');
                          },
                        )
                      : Builder(
                          builder: (context) {
                            count('row ${f.id}');
                            return Text(f.name ?? '…');
                          },
                        ),
              ],
            );
          },
        ),
      ),
    );

    Future<void> settle(WidgetTester tester, SlingClient<Query> c) async {
      for (var i = 0; i < 5 && !c.isIdle; i++) {
        await tester.pump(Duration.zero);
        await tester.runAsync(() => c.whenIdle);
      }
      await tester.pump();
    }

    testWidgets('rows fetch in the parent request', (tester) async {
      final c = client();
      await tester.pumpWidget(app(c));
      await settle(tester, c);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Cy'), findsOneWidget);
      expect(operations, hasLength(1), reason: 'row reads join the batch');
      expect(operations.single.document, contains('name'));
    });

    testWidgets('a write to one entity rebuilds only that row', (tester) async {
      final c = client();
      await tester.pumpWidget(app(c));
      await settle(tester, c);
      builds.clear();

      c.cacheScope.user('a')!.name = 'Robert';
      await tester.pump();
      expect(find.text('Robert'), findsOneWidget);
      expect(builds, {'row a': 1}, reason: 'not the list, not row b');
      expect(operations, hasLength(1));
    });

    testWidgets('without SlingRow the whole list rebuilds (baseline)', (
      tester,
    ) async {
      final c = client();
      await tester.pumpWidget(app(c, rows: false));
      await settle(tester, c);
      builds.clear();

      c.cacheScope.user('a')!.name = 'Robert';
      await tester.pump();
      expect(find.text('Robert'), findsOneWidget);
      expect(builds, {'list': 1, 'row a': 1, 'row b': 1});
    });

    testWidgets('list changes still rebuild the parent', (tester) async {
      final c = client();
      await tester.pumpWidget(app(c));
      await settle(tester, c);
      builds.clear();

      c.cacheScope.list((q) => q.me.friends()).remove(c.cacheScope.user('b')!);
      await tester.pump();
      expect(find.text('Cy'), findsNothing);
      expect(builds['list'], 1);
    });

    testWidgets('rows are released with the parent', (tester) async {
      final c = client();
      await tester.pumpWidget(app(c));
      await settle(tester, c);
      await tester.pumpWidget(const SizedBox());
      builds.clear();
      c.cacheScope.user('a')!.name = 'Robert';
      await tester.pump();
      expect(builds, isEmpty);
    });
  });

  test('RowScope forwards misses and writes to its parent', () async {
    final c = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: mockGraphQL((_, _) => meWithFriends()),
    );
    await c.resolve((q) => q.me.friends().map((f) => f.name).toList());
    var parentChanges = 0;
    var rowChanges = 0;
    final parent = c.createScope(onChanged: () => parentChanges++);
    final friends = parent.run((q) => q.me.friends());
    final row = parent.row(onChanged: () => rowChanges++);
    final name = row.run(friends.first, User.new, (u) => u.name);
    expect(name, 'Bob');
    expect(row.deps, contains('User:a.name'));
    expect(parent.deps, isNot(contains('User:a.name')));

    // A miss in the row is the parent's (it fetches).
    row.run(friends.first, User.new, (u) => u.age);
    expect(parent.hasMissingData, isTrue);
    expect(parent.isLoading, isTrue);
    await parent.whenSettled;

    // A write through a row accessor notifies the row (and journals via the
    // client like any write).
    rowChanges = 0;
    parentChanges = 0;
    final bob = row.run(friends.first, User.new, (u) => u..name);
    bob.name = 'Robert';
    expect(rowChanges, 1);
    expect(parentChanges, 0);

    // Disposing the parent releases its rows.
    parent.dispose();
    rowChanges = 0;
    c.cacheScope.user('a')!.name = 'Bobby';
    expect(rowChanges, 0);
  });

  test('freshness (maxAge, revalidate) includes the rows\' deps', () async {
    var now = DateTime(2026);
    final c = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: mockGraphQL((_, _) => meWithFriends()),
      maxAge: const Duration(minutes: 1),
      now: () => now,
    );
    await c.resolve((q) => q.me.friends().map((f) => f.name).toList());
    // A value no response stamped: stale for `maxAge`.
    c.cache.write('query', [const Ref('User:a'), 'age'], 5);

    final parent = c.createScope(onChanged: () {});
    final friends = parent.run((q) => q.me.friends());
    expect(parent.isStale, isFalse, reason: 'the list itself is fresh');
    await parent.revalidate();
    expect(parent.isLoading, isFalse, reason: 'nothing stale: no-op');

    final row = parent.row(onChanged: () {});
    row.run(friends.first, User.new, (u) => u.age);
    final settled = parent.revalidate();
    expect(parent.isLoading, isTrue, reason: "the row's User:a.age is stale");
    await settled;
  });
}
