import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_sqflite/sling_gql_sqflite.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

import 'support/test_schema.dart';

/// #72 — `SqflitePersistence.mutationQueue`: the client's offline mutations
/// in a `sling_mutation_queue` table of the cache's database, so a killed
/// app replays them (and can still roll their optimistic writes back) on
/// its next run.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGraphQLServer server;
  setUp(() => server = testServer());

  SlingClient<Query> clientOn(SqflitePersistence p) {
    final client = SlingClient<Query>(
      endpoint: Uri.parse('http://mock/graphql'),
      schema: slingSchema,
      cache: p.cache,
      httpClient: server.httpClient,
      retry: RetryPolicy.none,
      mutationQueue: p.mutationQueue,
      // Replays only when a test asks (or a request succeeds).
      mutationQueueBackoff: const RetryPolicy(initialDelay: Duration(hours: 1)),
    );
    addTearDown(client.dispose);
    return client;
  }

  Future<String?> renameOffline(SlingClient<Query> client, String name) =>
      client.mutateWith(
        Mutation.root,
        (m) => m.rename(id: '1', name: name)?.name,
        optimistic: () =>
            client.cacheScope.entity('User', '1', User.new)!.name = name,
        offline: true,
      );

  Future<List<Map<String, Object?>>> queueRows(SqflitePersistence p) async => [
    for (final row in await p.database.query(
      'sling_mutation_queue',
      orderBy: 'rowid',
    ))
      row,
  ];

  /// A run that loaded `me`, queued `rename(Grace)` while offline and was
  /// then killed — after its cache save, which holds the optimistic value.
  Future<String> killedRun({
    SqfliteCodec? codec,
    List<String> names = const ['Grace'],
  }) async {
    final path = tempDatabasePath();
    final p = await openStore(path, codec: codec);
    final client = clientOn(p);
    await client.resolve((q) => q.me?.name);
    // The first call fails offline; the others queue behind it unsent.
    server.failNext(const MockFailure.network());
    for (final name in names) {
      unawaited(renameOffline(client, name));
      await client.whenIdle;
      await pumpEventQueue();
    }
    expect(client.queuedMutations, hasLength(names.length));
    client.dispose();
    await p.close(); // the cache save: optimistic values included
    return path;
  }

  test('a queued mutation is stored with its document, variables and '
      'rollback log, in its own table', () async {
    final path = tempDatabasePath();
    final p = await openStore(path);
    addTearDown(p.close);
    final client = clientOn(p);
    await client.resolve((q) => q.me?.name);
    server.failNext(const MockFailure.network());
    unawaited(renameOffline(client, 'Grace'));
    await client.whenIdle;
    await p.flush(); // after the queue writes
    final rows = await queueRows(p);
    expect(rows, hasLength(1));
    final stored = jsonDecode(rows.single['data']! as String) as Map;
    expect(stored['variables'], {'id': '1', 'name': 'Grace'});
    expect(stored['document'], contains('rename('));
    expect(stored['rollback'], [
      {
        'operation': 'query',
        'path': [
          {'__ref': 'User:1'},
          'name',
        ],
        'previous': 'User 1',
      },
    ]);

    await client.replayQueue();
    await p.flush();
    expect(await queueRows(p), isEmpty, reason: 'removed once landed');
  });

  test('after a kill the queue is restored in order and replayed; the '
      'responses are cached and stored', () async {
    final path = await killedRun(names: ['Grace', 'Hopper']);
    final p = await openStore(path);
    addTearDown(p.close);
    expect(p.cache.entity('User:1')?['name'], 'Hopper', reason: 'optimistic');
    expect((await p.mutationQueue.load()).map((m) => m.variables['name']), [
      'Grace',
      'Hopper',
    ]);

    final client = clientOn(p);
    await pumpEventQueue();
    await client.whenIdle;
    expect(
      [
        for (final r in server.requests)
          if (r.type == 'mutation') r.variables['name'],
      ],
      ['Grace', 'Grace', 'Hopper'],
      reason: 'one failed offline, then both replayed in order',
    );
    await p.flush();
    expect(await queueRows(p), isEmpty);
    expect((await entityRows(p))['User:1'], containsPair('name', 'Hopper'));
  });

  test('after a kill, a rejected replay rolls the stored optimistic write '
      'back and is reported', () async {
    final path = await killedRun();
    final p = await openStore(path);
    addTearDown(p.close);
    server.failNext(const MockFailure.graphQL('not allowed'));
    final client = clientOn(p);
    final failures = <QueuedMutationFailure>[];
    client.onQueuedMutationFailed.listen(failures.add);
    await pumpEventQueue();
    await client.whenIdle;
    expect(failures.single.error, isA<SlingGraphQLException>());
    expect(p.cache.entity('User:1')?['name'], 'User 1', reason: 'undone');
    await p.flush();
    expect(await queueRows(p), isEmpty);
    expect((await entityRows(p))['User:1'], containsPair('name', 'User 1'));
  });

  test('rows go through the codec', () async {
    final path = await killedRun(codec: const XorCodec());
    final p = await openStore(path, codec: const XorCodec());
    addTearDown(p.close);
    expect((await queueRows(p)).single['data'], isA<List<int>>());
    expect((await p.mutationQueue.load()).single.variables['name'], 'Grace');
  });

  test('a wiped cache keeps the queue but drops its rollback logs', () async {
    final path = await killedRun();
    // Another hash and no fields to migrate along: the cache is wiped.
    final p = await openStore(
      path,
      schema: const SlingSchema<Query, Mutation>(
        query: Query.root,
        mutation: Mutation.root,
        hash: 'test-schema-2',
      ),
    );
    addTearDown(p.close);
    expect(p.loaded.wiped, isTrue);
    final entry = (await p.mutationQueue.load()).single;
    expect(entry.variables['name'], 'Grace');
    expect(entry.rollback, isEmpty);
    final stored =
        jsonDecode((await queueRows(p)).single['data']! as String) as Map;
    expect(stored.containsKey('rollback'), isFalse, reason: 'rewritten');
  });

  test(
    'another codec id drops the queue (its rows cannot be decoded)',
    () async {
      final path = await killedRun(codec: const XorCodec());
      final p = await openStore(
        path,
        codec: const XorCodec(key: 7, id: 'xor:7'),
      );
      addTearDown(p.close);
      expect((await p.mutationQueue.load()), isEmpty);
      expect(await queueRows(p), isEmpty);
    },
  );

  test('a row that does not decode is reported and deleted', () async {
    final path = await killedRun(names: ['Grace', 'Hopper']);
    final first = await openStore(path);
    await first.database.update('sling_mutation_queue', {
      'data': '{not json',
    }, where: 'rowid = (SELECT MIN(rowid) FROM sling_mutation_queue)');
    await first.close();
    final errors = <Object>[];
    final p = await openStore(path, onError: (e, _) => errors.add(e));
    addTearDown(p.close);
    expect(errors.single, isA<FormatException>());
    expect(p.loaded.recovered, isFalse, reason: 'the cache is intact');
    expect((await p.mutationQueue.load()).single.variables['name'], 'Hopper');
    expect(await queueRows(p), hasLength(1));
  });

  test('a superseded instance stores no queue entries', () async {
    final path = tempDatabasePath();
    final errors = <Object>[];
    final first = await openStore(path, onError: (e, _) => errors.add(e));
    await compute(_openAndClose, path); // another isolate takes over
    await first.mutationQueue.add(
      QueuedMutation(
        id: 'x',
        document: 'mutation { a }',
        variables: const {},
        createdAt: DateTime(2026),
      ),
    );
    expect(errors.single, isA<SqfliteSupersededException>());
    expect(first.superseded, isTrue);
    await first.close();
    final again = await openStore(path);
    addTearDown(again.close);
    expect((await again.mutationQueue.load()), isEmpty);
  });
}

Future<void> _openAndClose(String path) async {
  final other = await openStore(path);
  await other.close();
}
