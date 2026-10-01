import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_sqflite/sling_gql_sqflite.dart';
import 'package:sling_gql_test/sling_gql_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_schema.dart';

/// Everything the tests read: two root fields with arguments, a list of
/// refs and an inline list.
Future<void> fetchAll(SlingClient<Query> client) => client.resolve(
  (q) => [
    q.me?.name,
    q.me?.age,
    for (final u in q.users(first: 3) ?? const <User>[]) u.name,
    q.greeting(name: 'Ada'),
    for (final t in q.tags ?? const <Tag>[]) t.label,
  ],
);

Future<Map<String, int>> entityUpdatedAt(SqflitePersistence p) async => {
  for (final row in await p.database.query('sling_entities'))
    row['key']! as String: row['updated_at']! as int,
};

/// Waits (real time) until [condition] holds, for at most five seconds:
/// background saves land a few milliseconds after their timer.
Future<void> until(bool Function() condition) async {
  final watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > const Duration(seconds: 5)) {
      fail('timed out waiting for a save');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  // The lifecycle flush listens through the widgets binding.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late MockGraphQLServer server;
  setUp(() => server = testServer());

  Future<SqflitePersistence> open(
    String path, {
    Duration? maxAge = const Duration(days: 7),
    int? maxEntities = 10000,
    Duration debounce = const Duration(hours: 1),
    Duration maxWait = const Duration(hours: 1),
    bool hydrateInIsolate = false,
    bool flushOnLifecycle = false,
    bool compact = true,
    SlingSchema<Accessor, Accessor> schema = slingSchema,
    void Function(Object error, StackTrace stack)? onError,
    DateTime Function()? now,
  }) async {
    final p = await openStore(
      path,
      schema: schema,
      maxAge: maxAge,
      maxEntities: maxEntities,
      debounce: debounce,
      maxWait: maxWait,
      hydrateInIsolate: hydrateInIsolate,
      flushOnLifecycle: flushOnLifecycle,
      compact: compact,
      onError: onError,
      now: now,
    );
    addTearDown(p.close);
    return p;
  }

  group('round trip', () {
    test('save, reopen: the same cache, no ROOT_MUTATION', () async {
      final path = tempDatabasePath();
      final first = await open(path);
      expect(first.loaded.wiped, isTrue, reason: 'a new database');
      final client = server.client(Query.root, cache: first.cache);
      await fetchAll(client);
      await client.mutateWith(
        Mutation.root,
        (m) => m.rename(id: '2', name: 'Grace')?.name,
      );
      await first.flush();
      expect(first.savedVersion, first.cache.version);

      final snapshot = first.cache.snapshot;
      // The client removed the mutation's root fields; the (empty) root
      // itself is not stored.
      expect(snapshot.remove('ROOT_MUTATION'), isEmpty);
      expect(await storedSnapshot(first), snapshot);
      await first.close();

      final again = await open(path);
      expect(again.loaded.wiped, isFalse);
      expect(again.cache.snapshot, snapshot);
      expect(again.cache.version, 0, reason: 'the store is the baseline');
      expect(again.savedVersion, 0);
      expect(again.loaded.entities, 3);
      expect(again.loaded.rootFields, 4);
      expect(
        again.cache.entity('User:2')?['name'],
        'Grace',
        reason: 'the mutation response merged into the entity',
      );
    });

    test(
      'hydrateInIsolate builds the same cache in a background isolate',
      () async {
        final path = tempDatabasePath();
        final first = await open(path);
        await fetchAll(server.client(Query.root, cache: first.cache));
        await first.flush();
        final snapshot = first.cache.snapshot;
        await first.close();

        final again = await open(path, hydrateInIsolate: true);
        expect(again.cache.snapshot, snapshot);
        // The cache works as any other: it normalizes, notifies and persists.
        final changes = <Set<String>>[];
        again.cache.onChange.listen(changes.add);
        await server
            .client(Query.root, cache: again.cache)
            .resolve((q) => q.user(id: '4')?.name);
        expect(changes, isNotEmpty);
        await again.flush();
        expect(await storedSnapshot(again), again.cache.snapshot);
      },
    );

    test('ROOT_MUTATION and ROOT_SUBSCRIPTION are never stored', () async {
      final p = await open(tempDatabasePath());
      // What the client writes (and removes) around a mutation / an event.
      // ignore: invalid_use_of_internal_member
      p.cache.writeResponse('mutation', {'rename': user('7')});
      // ignore: invalid_use_of_internal_member
      p.cache.writeResponse('subscription', {'renamed': user('8')});
      await p.flush();
      expect(
        p.cache.entityKeys,
        containsAll(['ROOT_MUTATION', 'ROOT_SUBSCRIPTION']),
      );
      expect(await rootRows(p), isEmpty);
      // Their entities are entities like any other, until the next open
      // finds them unreachable.
      expect((await entityRows(p)).keys, {'User:7', 'User:8'});
    });
  });

  group('deltas', () {
    test(
      'a save rewrites only the root fields and entities that changed',
      () async {
        var clock = DateTime.utc(2026, 1, 1);
        final t0 = clock.millisecondsSinceEpoch;
        final p = await open(tempDatabasePath(), now: () => clock);
        final client = server.client(Query.root, cache: p.cache);
        await fetchAll(client);
        await p.flush();
        final roots = await rootRows(p);
        expect(roots, hasLength(4));
        expect({for (final r in roots.values) r.$2}, {t0});

        clock = clock.add(const Duration(hours: 1));
        final t1 = clock.millisecondsSinceEpoch;
        // A new root field and entity...
        await client.resolve((q) => q.user(id: '4')?.name);
        // ...and a change inside an entity a root field references: the
        // `me` row (a ref) does not change.
        server.query['me'] = user('1', name: 'Ada L.');
        await client.resolve(
          (q) => q.me?.name,
          fetchPolicy: FetchPolicy.networkOnly,
        );
        await p.flush();

        final after = await rootRows(p);
        final userField = after.keys.singleWhere((f) => f.startsWith('user_'));
        expect(
          {for (final e in after.entries) e.key: e.value.$2},
          {for (final f in roots.keys) f: t0, userField: t1},
        );
        expect(await entityUpdatedAt(p), {
          'User:1': t1,
          'User:2': t0,
          'User:3': t0,
          'User:4': t1,
        });
        expect(await storedSnapshot(p), p.cache.snapshot);
      },
    );

    test('a root field holding an inline list is rewritten when an element '
        'changes', () async {
      var clock = DateTime.utc(2026, 1, 1);
      final p = await open(tempDatabasePath(), now: () => clock);
      final client = server.client(Query.root, cache: p.cache);
      await fetchAll(client);
      await p.flush();

      final changes = <Set<String>>[];
      p.cache.onChange.listen(changes.add);
      clock = clock.add(const Duration(hours: 1));
      server.query['tags'] = [
        {'__typename': 'Tag', 'label': 'a'},
        {'__typename': 'Tag', 'label': 'B'},
      ];
      await client.resolve(
        (q) => [for (final t in q.tags ?? const <Tag>[]) t.label],
        fetchPolicy: FetchPolicy.networkOnly,
      );
      expect(changes.single, contains('ROOT_QUERY.tags[1]'));
      await p.flush();
      final roots = await rootRows(p);
      expect(roots['tags']!.$1, [
        {'__typename': 'Tag', 'label': 'a'},
        {'__typename': 'Tag', 'label': 'B'},
      ]);
      expect(roots['tags']!.$2, clock.millisecondsSinceEpoch);
      expect(
        roots['me']!.$2,
        isNot(clock.millisecondsSinceEpoch),
        reason: 'untouched root fields keep their row',
      );
    });

    test('evict deletes the entity and the root fields it scrubbed', () async {
      final p = await open(tempDatabasePath());
      final client = server.client(Query.root, cache: p.cache);
      await fetchAll(client);
      await client.resolve((q) => q.user(id: '4')?.name);
      await p.flush();
      expect(
        (await rootRows(p)).keys.where((f) => f.startsWith('user_')),
        hasLength(1),
      );

      p.cache.evict('User:4');
      await p.flush();
      expect((await entityRows(p)).keys, isNot(contains('User:4')));
      expect(
        (await rootRows(p)).keys.where((f) => f.startsWith('user_')),
        isEmpty,
      );
      expect(await storedSnapshot(p), p.cache.snapshot);
    });

    test('gc deletes the entities it collected', () async {
      final p = await open(tempDatabasePath());
      final client = server.client(Query.root, cache: p.cache);
      await client.resolve((q) => q.me?.name);
      server.query['me'] = user('9');
      await client.resolve(
        (q) => q.me?.name,
        fetchPolicy: FetchPolicy.networkOnly,
      );
      await p.flush();
      expect((await entityRows(p)).keys, {'User:1', 'User:9'});

      expect(p.cache.gc(), {'User:1'});
      await p.flush();
      expect((await entityRows(p)).keys, {'User:9'});
    });

    test('clear (logout) empties the cache and the database', () async {
      final path = tempDatabasePath();
      final p = await open(path);
      await fetchAll(server.client(Query.root, cache: p.cache));
      await p.flush();
      expect(await entityRows(p), isNotEmpty);

      await p.clear();
      expect(p.cache.entityKeys, isEmpty);
      expect(await entityRows(p), isEmpty);
      expect(await rootRows(p), isEmpty);
      await p.close();
      final again = await open(path);
      expect(again.cache.entityKeys, isEmpty);
    });

    // #69: compacting after each save keeps the tombstones of a big gc.
    test('a gc of more than a thousand entities deletes their rows and '
        'rewrites nothing else', () async {
      var clock = DateTime.utc(2026, 1, 1);
      final t0 = clock.millisecondsSinceEpoch;
      final p = await open(tempDatabasePath(), now: () => clock);
      final users = [for (var i = 0; i < 1002; i++) user('u$i')];
      server.query['users'] = (Map<String, Object?> args) => users;
      final client = server.client(Query.root, cache: p.cache);
      await client.resolve(
        (q) => [q.me?.name, q.users(first: 1)?.map((u) => u.name).toList()],
      );
      await p.flush();
      clock = clock.add(const Duration(days: 1));

      users.removeRange(1, users.length);
      await client.resolve(
        (q) => q.users(first: 1)?.map((u) => u.name).toList(),
        fetchPolicy: FetchPolicy.networkOnly,
      );
      p.cache.gc();
      final delta = p.cache.changesSince(p.savedVersion);
      expect(delta.full, isFalse);
      expect(delta.removed, hasLength(1001));
      await p.flush();
      expect(await entityUpdatedAt(p), {'User:1': t0, 'User:u0': t0});
      expect(await storedSnapshot(p), p.cache.snapshot);
    });

    test('without compact, a full delta (forgotten tombstones) rewrites the '
        'entities; untouched root fields keep their age', () async {
      var clock = DateTime.utc(2026, 1, 1);
      final t0 = clock.millisecondsSinceEpoch;
      final p = await open(
        tempDatabasePath(),
        now: () => clock,
        compact: false,
      );
      final users = [for (var i = 0; i < 1002; i++) user('u$i')];
      server.query['users'] = (Map<String, Object?> args) => users;
      final client = server.client(Query.root, cache: p.cache);
      await client.resolve(
        (q) => [q.me?.name, q.users(first: 1)?.map((u) => u.name).toList()],
      );
      await p.flush();
      expect(await entityRows(p), hasLength(1003));
      clock = clock.add(const Duration(days: 1));

      // More removals than the cache remembers, and than live entities:
      // `changesSince` answers with every entity, `full`.
      users.removeRange(1, users.length);
      await client.resolve(
        (q) => q.users(first: 1)?.map((u) => u.name).toList(),
        fetchPolicy: FetchPolicy.networkOnly,
      );
      p.cache.gc();
      expect(p.cache.changesSince(p.savedVersion).full, isTrue);
      await p.flush();
      expect((await entityRows(p)).keys, {'User:1', 'User:u0'});
      expect(await storedSnapshot(p), p.cache.snapshot);
      // `me` was not touched: its row (and its maxAge clock) stays.
      final ages = {
        for (final e in (await rootRows(p)).entries) e.key: e.value.$2,
      };
      expect(ages.remove('me'), t0);
      expect(ages.values.single, clock.millisecondsSinceEpoch);
    });
  });

  group('saving', () {
    test('debounced after the last change', () async {
      final p = await open(
        tempDatabasePath(),
        debounce: const Duration(milliseconds: 200),
        maxWait: const Duration(seconds: 30),
      );
      final client = server.client(Query.root, cache: p.cache);
      await client.resolve((q) => q.me?.name);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(p.savedVersion, 0, reason: 'still within the debounce');
      await until(() => p.savedVersion == p.cache.version);
      expect(await storedSnapshot(p), p.cache.snapshot);
    });

    test('changes that keep coming are saved after maxWait', () async {
      final p = await open(
        tempDatabasePath(),
        debounce: const Duration(milliseconds: 300),
        maxWait: const Duration(milliseconds: 600),
      );
      final client = server.client(Query.root, cache: p.cache);
      await client.resolve((q) => q.me?.name);
      final me = client.cacheScope.entity('User', '1', User.new)!;
      final writes = Timer.periodic(const Duration(milliseconds: 100), (t) {
        me.name = 'Ada ${t.tick}';
      });
      addTearDown(writes.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      // The debounce never elapsed (a write every 100 ms); maxWait did.
      expect(p.savedVersion, greaterThan(0));
      writes.cancel();
      await p.flush();
      expect((await entityRows(p))['User:1'], p.cache.snapshot['User:1']);
    });

    test('the app going to the background flushes', () async {
      final p = await open(tempDatabasePath(), flushOnLifecycle: true);
      await server
          .client(Query.root, cache: p.cache)
          .resolve((q) => q.me?.name);
      expect(p.savedVersion, 0);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(p.savedVersion, 0, reason: 'inactive is not a reason to save');
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await until(() => p.savedVersion == p.cache.version);

      final me = p.cache.entity('User:1')!;
      expect(me['name'], 'User 1');
      final scope = server.client(Query.root, cache: p.cache).cacheScope;
      scope.entity('User', '1', User.new)!.name = 'Paused';
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await until(() => p.savedVersion == p.cache.version);
      scope.entity('User', '1', User.new)!.name = 'Detached';
      binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await until(() => p.savedVersion == p.cache.version);
      expect(((await entityRows(p))['User:1']! as Map)['name'], 'Detached');
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    test('a save asked for while another runs waits for it, then writes only '
        'what changed since', () async {
      final p = await open(tempDatabasePath());
      final client = server.client(Query.root, cache: p.cache);
      await client.resolve(
        (q) => q.users(first: 2)?.map((u) => u.name).toList(),
      );
      await p.flush();
      final stored = p.savedVersion;
      final db = p.database;
      await db.execute('CREATE TABLE save_log (key TEXT)');
      await db.execute(
        'CREATE TRIGGER log_saves AFTER INSERT ON sling_entities '
        'BEGIN INSERT INTO save_log VALUES (NEW.key); END',
      );
      final scope = client.cacheScope;
      final versions = <int>[];

      // Keeps the database busy, so the first save takes its delta and then
      // waits for its transaction while the second change happens.
      final busy = db.rawQuery(
        'WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c '
        'WHERE x < 2000000) SELECT count(*) FROM c',
      );
      scope.entity('User', '1', User.new)!.name = 'Ada';
      final first = p.flush().then((_) => versions.add(p.savedVersion));
      await Future<void>.delayed(Duration.zero);
      expect(versions, isEmpty, reason: 'the first save is in flight');
      scope.entity('User', '2', User.new)!.name = 'Bea';
      final second = p.flush().then((_) => versions.add(p.savedVersion));
      await Future.wait([busy, first, second]);

      expect(versions, [stored + 1, stored + 2]);
      // Had the second save started at once, from the stored version, it
      // would have written User:1 again.
      expect(
        [for (final r in await db.query('save_log')) r['key']],
        ['User:1', 'User:2'],
      );
      expect(await storedSnapshot(p), p.cache.snapshot);
    });

    test('concurrent saves run one after another; the last one wins', () async {
      final p = await open(tempDatabasePath());
      final client = server.client(Query.root, cache: p.cache);
      await client.resolve((q) => q.me?.name);
      final me = client.cacheScope.entity('User', '1', User.new)!;
      final saves = <Future<void>>[];
      for (var i = 0; i < 20; i++) {
        me.name = 'Ada $i';
        saves.add(p.flush());
      }
      await Future.wait(saves);
      expect(p.savedVersion, p.cache.version);
      expect(((await entityRows(p))['User:1']! as Map)['name'], 'Ada 19');
    });

    test(
      'a failed save is retried by the next one, from the same version',
      () async {
        final errors = <Object>[];
        final p = await open(
          tempDatabasePath(),
          debounce: const Duration(milliseconds: 50),
          onError: (e, _) => errors.add(e),
        );
        final client = server.client(Query.root, cache: p.cache);
        await fetchAll(client);
        await p.flush();
        final stored = p.savedVersion;

        await p.database.execute(
          'CREATE TRIGGER disk_full BEFORE INSERT ON sling_entities '
          "BEGIN SELECT RAISE(ABORT, 'disk full'); END",
        );
        await client.resolve((q) => q.user(id: '4')?.name);
        await expectLater(p.flush(), throwsA(isA<DatabaseException>()));
        expect(p.savedVersion, stored);
        // A background save fails the same way, reported to onError.
        client.cacheScope.entity('User', '4', User.new)!.name = 'Dora';
        await until(() => errors.isNotEmpty);
        expect(errors, [isA<DatabaseException>()]);
        expect(p.savedVersion, stored);
        // The transaction rolled back: nothing of the failed delta landed.
        expect((await entityRows(p)).keys, isNot(contains('User:4')));
        expect(
          (await rootRows(p)).keys.where((f) => f.startsWith('user_')),
          isEmpty,
        );

        await p.database.execute('DROP TRIGGER disk_full');
        client.cacheScope.entity('User', '2', User.new)!.name = 'Bea';
        await until(() => p.savedVersion == p.cache.version);
        // Everything since the last stored save, root fields included.
        expect(await storedSnapshot(p), p.cache.snapshot);
      },
    );

    test('close saves what is pending', () async {
      final path = tempDatabasePath();
      final p = await open(path);
      await fetchAll(server.client(Query.root, cache: p.cache));
      final snapshot = p.cache.snapshot;
      await p.close();
      final again = await open(path);
      expect(again.cache.snapshot, snapshot);
    });
  });

  group('bounds at open', () {
    test('root fields older than maxAge go, with the entities only they '
        'reached', () async {
      final path = tempDatabasePath();
      var clock = DateTime.utc(2026, 1, 1);
      final p = await open(path, now: () => clock);
      final client = server.client(Query.root, cache: p.cache);
      await client.resolve(
        (q) => q.users(first: 3)?.map((u) => u.name).toList(),
      );
      await p.flush();
      clock = clock.add(const Duration(days: 6));
      await client.resolve((q) => q.me?.name);
      await client.resolve((q) => q.user(id: '5')?.name);
      await p.flush();
      await p.close();

      clock = clock.add(const Duration(days: 2)); // users(): 8 days old
      final again = await open(path, now: () => clock);
      expect(again.loaded.expiredRootFields, 1);
      expect(again.loaded.unreachableEntities, 2, reason: 'User:2, User:3');
      expect(again.cache.entityKeys.toSet(), {
        'ROOT_QUERY',
        'User:1',
        'User:5',
      });
      // Deleted from the database too.
      expect((await entityRows(again)).keys, {'User:1', 'User:5'});
      expect(await rootRows(again), hasLength(2));

      await again.close();
      final unbounded = await open(path, maxAge: null, now: () => clock);
      expect(unbounded.loaded.expiredRootFields, 0);
    });

    test('maxAge: null keeps everything', () async {
      final path = tempDatabasePath();
      var clock = DateTime.utc(2026, 1, 1);
      final p = await open(path, now: () => clock);
      await fetchAll(server.client(Query.root, cache: p.cache));
      final snapshot = p.cache.snapshot;
      await p.close();
      clock = clock.add(const Duration(days: 365));
      final again = await open(path, maxAge: null, now: () => clock);
      expect(again.cache.snapshot, snapshot);
    });

    test(
      'over maxEntities, the oldest root fields go until the rest fits',
      () async {
        final path = tempDatabasePath();
        var clock = DateTime.utc(2026, 1, 1);
        final p = await open(path, now: () => clock);
        final client = server.client(Query.root, cache: p.cache);
        await client.resolve(
          (q) => q.users(first: 5)?.map((u) => u.name).toList(),
        );
        await p.flush();
        clock = clock.add(const Duration(minutes: 1));
        await client.resolve((q) => q.me?.name);
        await client.resolve((q) => q.greeting(name: 'Ada'));
        await p.flush();
        await p.close();

        // users(first: 5) alone reaches 5 entities: dropped first.
        final capped = await open(path, maxEntities: 2, now: () => clock);
        expect(capped.loaded.cappedRootFields, 1);
        expect(capped.loaded.entities, 1);
        expect(capped.cache.entityKeys.toSet(), {'ROOT_QUERY', 'User:1'});
        expect((await entityRows(capped)).keys, {'User:1'});
        await capped.close();

        final unbounded = await open(path, maxEntities: null, now: () => clock);
        expect(unbounded.loaded.cappedRootFields, 0);
      },
    );

    test('a cap of 0 keeps the newest root fields without entities', () async {
      final path = tempDatabasePath();
      var clock = DateTime.utc(2026, 1, 1);
      final p = await open(path, now: () => clock);
      final client = server.client(Query.root, cache: p.cache);
      await client.resolve((q) => [q.me?.name, q.users(first: 2)?.length]);
      await p.flush();
      clock = clock.add(const Duration(minutes: 1));
      await client.resolve(
        (q) => [q.greeting(name: 'Ada'), q.tags?.map((t) => t.label).toList()],
      );
      await p.close();

      final again = await open(path, maxEntities: 0, now: () => clock);
      expect(again.cache.entityKeys.toSet(), {'ROOT_QUERY'});
      expect(
        again.cache.entity('ROOT_QUERY')!.keys,
        unorderedEquals([startsWith('greeting_'), 'tags']),
      );
      expect(again.loaded.cappedRootFields, 2);
    });
  });

  group('invalidation', () {
    Future<String> stored() async {
      final path = tempDatabasePath();
      final p = await open(path);
      await fetchAll(server.client(Query.root, cache: p.cache));
      await p.close();
      return path;
    }

    test('another schema hash wipes the database', () async {
      final path = await stored();
      final again = await open(
        path,
        schema: const SlingSchema<Query, Mutation>(
          query: Query.root,
          hash: 'test-schema-2',
        ),
      );
      expect(again.loaded.wiped, isTrue);
      expect(again.cache.entityKeys, isEmpty);
      expect(await entityRows(again), isEmpty);
      await again.close();
      expect((await open(path)).loaded.wiped, isTrue, reason: 'and back');
    });

    test('another key field wipes the database', () async {
      final path = await stored();
      final again = await open(
        path,
        schema: const SlingSchema<Query, Mutation>(
          query: Query.root,
          keyField: 'uuid',
          hash: 'test-schema-1',
        ),
      );
      expect(again.loaded.wiped, isTrue);
      expect(again.cache.entityKeys, isEmpty);
      expect(again.cache.normalization.keyField, 'uuid');
    });

    test('another format version wipes the database', () async {
      final path = await stored();
      final db = await databaseFactoryFfi.openDatabase(path);
      await db.update('sling_meta', {
        'value': '0',
      }, where: "key = 'format_version'");
      await db.close();
      final again = await open(path);
      expect(again.loaded.wiped, isTrue);
      expect(again.cache.entityKeys, isEmpty);
      expect(
        await again.database.query('sling_meta'),
        contains(
          equals({'key': 'format_version', 'value': '$sqfliteFormatVersion'}),
        ),
      );
    });

    test('undecodable rows wipe the database, reported to onError', () async {
      final path = await stored();
      final db = await databaseFactoryFfi.openDatabase(path);
      await db.update('sling_root_fields', {
        'json': '{not json',
      }, where: "field = 'me'");
      await db.close();
      final errors = <Object>[];
      final again = await open(path, onError: (e, _) => errors.add(e));
      expect(errors, [isA<FormatException>()]);
      expect(again.loaded.wiped, isTrue);
      expect(again.cache.entityKeys, isEmpty);
      expect(await entityRows(again), isEmpty);
      expect(await rootRows(again), isEmpty);
      // And it persists again.
      await server
          .client(Query.root, cache: again.cache)
          .resolve((q) => q.me?.name);
      await again.flush();
      expect(await storedSnapshot(again), again.cache.snapshot);
    });

    test('the same schema keeps it', () async {
      final path = await stored();
      final again = await open(path);
      expect(again.loaded.wiped, isFalse);
      expect(again.cache.entityKeys, isNotEmpty);
    });
  });
}
