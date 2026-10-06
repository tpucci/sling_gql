import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// #72 — `mutateWith(offline: true)`: a call the server cannot be reached
/// for is queued (optimistic writes kept, future pending, `onQueued`),
/// persisted in `SlingClient.mutationQueue` with its document, variables and
/// rollback log, and replayed in order — on `replayQueue`, after the next
/// successful request, on backoff timers, and by the next client created on
/// the same store (an app restart).
void main() {
  late _Server server;
  late InMemoryMutationQueueStore store;

  setUp(() {
    server = _Server();
    store = InMemoryMutationQueueStore();
  });

  SlingClient<Query> newClient({
    Cache? cache,
    RetryPolicy backoff = const RetryPolicy(
      initialDelay: Duration(seconds: 1),
      jitter: 0,
    ),
  }) {
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      cache: cache,
      httpClient: server.httpClient,
      retry: RetryPolicy.none,
      mutationQueue: store,
      mutationQueueBackoff: backoff,
    );
    addTearDown(client.dispose);
    return client;
  }

  Future<void> loadMe(SlingClient<Query> client) =>
      client.resolve((q) => q.me.name);

  String? cachedName(SlingClient<Query> client) =>
      client.cacheScope.user('1')?.name;

  Future<String?> renameOffline(
    SlingClient<Query> client,
    String name, {
    void Function()? onQueued,
  }) => client.mutateWith(
    Mutation.root,
    (m) => m.rename(id: '1', name: name)?.name,
    optimistic: () => client.cacheScope.user('1')!.name = name,
    offline: true,
    onQueued: onQueued,
  );

  test('a network failure queues the call: optimistic write kept, future '
      'pending, entry persisted; replayQueue sends it', () async {
    final client = newClient();
    await loadMe(client);
    server.online = false;
    var queued = 0;
    String? result;
    final call = renameOffline(
      client,
      'Grace',
      onQueued: () => queued++,
    ).then((v) => result = v);
    await client.whenIdle;
    await pumpEventQueue();

    expect(queued, 1);
    expect(result, isNull, reason: 'still pending');
    expect(cachedName(client), 'Grace', reason: 'optimistic write stays');
    expect(client.isIdle, isTrue, reason: 'a queued call is not in flight');
    expect(client.queuedMutations, hasLength(1));
    final entry = store.entries.single;
    expect(entry.document, startsWith('mutation'));
    expect(entry.variables, {'id': '1', 'name': 'Grace'});
    expect(entry.rollback, [
      {
        'operation': 'query',
        'path': [
          {'__ref': 'User:1'},
          'name',
        ],
        'previous': 'Ada',
      },
    ]);

    server.online = true;
    await client.replayQueue();
    await call;
    expect(result, 'Grace', reason: "body's value from the response");
    expect(server.names['1'], 'Grace');
    expect(store.entries, isEmpty);
    expect(client.queuedMutations, isEmpty);
    expect(cachedName(client), 'Grace');
  });

  test('an offline call that reaches the server behaves like any mutation '
      '(and leaves the store empty)', () async {
    final client = newClient();
    await loadMe(client);
    var queued = 0;
    final result = await renameOffline(
      client,
      'Grace',
      onQueued: () => queued++,
    );
    expect(result, 'Grace');
    expect(queued, 0);
    expect(store.entries, isEmpty);
  });

  test('an offline call rejected at once fails like any mutation: rolled '
      'back, thrown, not reported as a queued failure', () async {
    final client = newClient();
    await loadMe(client);
    final failures = <QueuedMutationFailure>[];
    client.onQueuedMutationFailed.listen(failures.add);
    server.rejectNext = true;
    await expectLater(
      renameOffline(client, 'Grace'),
      throwsA(isA<SlingGraphQLException>()),
    );
    expect(cachedName(client), 'Ada');
    expect(failures, isEmpty);
    expect(store.entries, isEmpty);
  });

  test('queued calls are replayed in order, one at a time; a later offline '
      'call waits behind them', () async {
    final client = newClient();
    await loadMe(client);
    server.online = false;
    final results = <String?>[];
    final first = renameOffline(client, 'B').then(results.add);
    await client.whenIdle;
    await pumpEventQueue();
    var secondQueued = false;
    final second = renameOffline(
      client,
      'C',
      onQueued: () => secondQueued = true,
    ).then(results.add);
    expect(secondQueued, isTrue, reason: 'queued behind a waiting call');
    expect(server.mutations, 1, reason: 'not sent while the queue waits');
    expect(store.entries.map((e) => e.variables['name']), ['B', 'C']);

    server
      ..online = true
      ..latency = const Duration(milliseconds: 5);
    await client.replayQueue();
    await Future.wait([first, second]);
    expect(results, ['B', 'C']);
    expect(server.renames, ['B', 'C']);
    expect(server.maxConcurrent, 1);
    expect(cachedName(client), 'C');
  });

  test('the next successful request of any kind replays the queue', () async {
    final client = newClient();
    await loadMe(client);
    server.online = false;
    final call = renameOffline(client, 'Grace');
    await client.whenIdle;
    await pumpEventQueue();
    expect(client.queuedMutations, hasLength(1));

    server.online = true;
    await client.resolve(
      (q) => q.user(id: '2')?.name,
      fetchPolicy: FetchPolicy.networkOnly,
    );
    expect(await call, 'Grace');
    expect(server.renames, ['Grace']);
    expect(store.entries, isEmpty);
  });

  test('a subscription event replays the queue too', () async {
    final events = StreamController<Map<String, Object?>>();
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      httpClient: server.httpClient,
      subscriptionTransport: (_) => events.stream,
      mutationQueue: store,
    );
    addTearDown(client.dispose);
    await loadMe(client);
    server.online = false;
    final call = renameOffline(client, 'Grace');
    await client.whenIdle;
    await pumpEventQueue();
    final sub = client
        .subscribeWith(Subscription.root, (s) => s.userChanged?.name)
        .stream
        .listen((_) {});
    addTearDown(sub.cancel);

    server.online = true;
    events.add({
      'data': {
        'userChanged': {'__typename': 'User', 'id': 'a', 'name': 'Bob'},
      },
    });
    expect(await call, 'Grace');
  });

  testWidgets('backoff timers replay the queue until the server answers', (
    tester,
  ) async {
    final client = newClient();
    await tester.runAsync(() => loadMe(client));
    server.online = false;
    String? result;
    renameOffline(client, 'Grace').then((v) => result = v);
    await tester.pump(); // first attempt fails: retry in 1 s
    expect(server.mutations, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(server.mutations, 2, reason: 'replayed by the timer, offline');
    await tester.pump(const Duration(seconds: 1));
    expect(server.mutations, 2, reason: 'backing off: next one after 2 s');

    server.online = true;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(server.mutations, 3);
    expect(result, 'Grace');
    expect(store.entries, isEmpty);
  });

  test('a replay the server rejects drops the entry, rolls back and is '
      'reported; the call fails with the error', () async {
    final client = newClient();
    await loadMe(client);
    final failures = <QueuedMutationFailure>[];
    client.onQueuedMutationFailed.listen(failures.add);
    server.online = false;
    final call = renameOffline(client, 'Grace');
    final failed = expectLater(call, throwsA(isA<SlingGraphQLException>()));
    await client.whenIdle;
    await pumpEventQueue();
    expect(cachedName(client), 'Grace');

    server
      ..online = true
      ..rejectNext = true;
    await client.replayQueue();
    await failed;
    expect(cachedName(client), 'Ada', reason: 'optimistic write undone');
    expect(failures.single.error, isA<SlingGraphQLException>());
    expect(failures.single.mutation.variables['name'], 'Grace');
    expect(store.entries, isEmpty);
  });

  group('replay failures', () {
    /// `rename(Grace)` queued while offline, then the network is back.
    Future<(SlingClient<Query>, Future<String?>, List<QueuedMutationFailure>)>
    queuedCall({RetryPolicy? backoff}) async {
      final client = backoff == null
          ? newClient()
          : newClient(backoff: backoff);
      await loadMe(client);
      final failures = <QueuedMutationFailure>[];
      client.onQueuedMutationFailed.listen(failures.add);
      server.online = false;
      final call = renameOffline(client, 'Grace');
      await client.whenIdle;
      await pumpEventQueue();
      server.online = true;
      return (client, call, failures);
    }

    test('a retryable failure (5xx) keeps the call queued, optimistic write '
        'and store entry included; the next replay lands it', () async {
      final (client, call, failures) = await queuedCall();
      String? result;
      unawaited(call.then((v) => result = v));
      server.statusNext.add(503);
      await client.replayQueue();
      await pumpEventQueue();
      expect(result, isNull, reason: 'still pending');
      expect(failures, isEmpty);
      expect(cachedName(client), 'Grace', reason: 'not rolled back');
      expect(store.entries, hasLength(1));
      expect(client.queuedMutations, hasLength(1));

      await client.replayQueue();
      expect(await call, 'Grace');
      expect(store.entries, isEmpty);
    });

    test('a non-retryable failure (4xx) drops the call, rolls back and is '
        'reported', () async {
      final (client, call, failures) = await queuedCall();
      final failed = expectLater(
        call,
        throwsA(
          isA<SlingHttpException>().having((e) => e.statusCode, 'status', 400),
        ),
      );
      server.statusNext.add(400);
      await client.replayQueue();
      await failed;
      expect(failures.single.error.statusCode, 400);
      expect(cachedName(client), 'Ada');
      expect(store.entries, isEmpty);
    });

    test("mutationQueueBackoff's retryIf decides what is retryable", () async {
      final (client, call, failures) = await queuedCall(
        backoff: RetryPolicy(retryIf: (e) => e.isNetworkUnreachable),
      );
      final failed = expectLater(call, throwsA(isA<SlingHttpException>()));
      server.statusNext.add(503);
      await client.replayQueue();
      await failed;
      expect(failures, hasLength(1));
      expect(cachedName(client), 'Ada');
    });

    test('before it was ever queued, a 5xx fails the call as usual', () async {
      final client = newClient();
      await loadMe(client);
      server.statusNext.add(503);
      await expectLater(
        renameOffline(client, 'Grace'),
        throwsA(isA<SlingHttpException>()),
      );
      expect(cachedName(client), 'Ada');
      expect(store.entries, isEmpty);
    });
  });

  group('clearMutationQueue', () {
    test('rolls every queued call back, fails its future with '
        'SlingCancelledException, empties the store and sends nothing '
        'more', () async {
      final client = newClient();
      await loadMe(client);
      final failures = <QueuedMutationFailure>[];
      client.onQueuedMutationFailed.listen(failures.add);
      server.online = false;
      final first = renameOffline(client, 'B');
      final firstFailed = expectLater(
        first,
        throwsA(isA<SlingCancelledException>()),
      );
      await client.whenIdle;
      await pumpEventQueue();
      final second = renameOffline(client, 'C');
      final secondFailed = expectLater(
        second,
        throwsA(isA<SlingCancelledException>()),
      );
      expect(cachedName(client), 'C');

      await client.clearMutationQueue();
      await Future.wait([firstFailed, secondFailed]);
      expect(cachedName(client), 'Ada', reason: 'newest undone first');
      expect(client.queuedMutations, isEmpty);
      expect(store.entries, isEmpty);
      expect(failures, isEmpty, reason: 'a clear is not a failure');

      server.online = true;
      final sent = server.mutations;
      await loadMe(client);
      await client.replayQueue();
      expect(server.mutations, sent);
      expect(server.renames, isEmpty);
    });

    test('aborts the replay in flight and ignores its response', () async {
      final client = newClient();
      await loadMe(client);
      server.online = false;
      final call = renameOffline(client, 'Grace');
      final failed = expectLater(call, throwsA(isA<SlingCancelledException>()));
      await client.whenIdle;
      await pumpEventQueue();
      server
        ..online = true
        ..latency = const Duration(milliseconds: 20);
      final replay = client.replayQueue();
      await pumpEventQueue();
      expect(client.isIdle, isFalse, reason: 'replay in flight');
      await client.clearMutationQueue();
      await failed;
      await replay;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(cachedName(client), 'Ada', reason: 'response not written');
      expect(client.isIdle, isTrue);
      expect(store.entries, isEmpty);
    });

    test('rolls calls restored from an earlier run back from their stored '
        'log', () async {
      final previous = newClient();
      await loadMe(previous);
      server.online = false;
      unawaited(renameOffline(previous, 'Grace'));
      await previous.whenIdle;
      await pumpEventQueue();
      final persisted = previous.cache.snapshot;
      previous.dispose();

      final client = newClient(
        cache: Cache(
          normalization: slingSchema.normalization,
          initial: persisted,
        ),
      );
      expect(cachedName(client), 'Grace');
      await client.clearMutationQueue();
      expect(cachedName(client), 'Ada');
      expect(store.entries, isEmpty);
      server.online = true;
      await pumpEventQueue();
      await client.whenIdle;
      expect(server.renames, isEmpty);
    });

    test('while the store is still loading, its entries are rolled back '
        'and dropped when they arrive', () async {
      final previous = newClient();
      await loadMe(previous);
      server.online = false;
      unawaited(renameOffline(previous, 'Grace'));
      await previous.whenIdle;
      await pumpEventQueue();
      final persisted = previous.cache.snapshot;
      previous.dispose();
      server.online = true;

      final slow = _SlowStore(store);
      final client = SlingClient<Query>(
        endpoint: testEndpoint,
        schema: slingSchema,
        cache: Cache(
          normalization: slingSchema.normalization,
          initial: persisted,
        ),
        httpClient: server.httpClient,
        mutationQueue: slow,
      );
      addTearDown(client.dispose);
      final cleared = client.clearMutationQueue();
      slow.release();
      await cleared;
      await pumpEventQueue();
      await client.whenIdle;
      expect(cachedName(client), 'Ada');
      expect(client.queuedMutations, isEmpty);
      expect(server.renames, isEmpty);
    });
  });

  group('after an app restart (a new client on the same store)', () {
    /// A run that queued `rename(Grace)` offline, then was killed: the
    /// cache it persisted holds the optimistic value.
    Future<Map<String, Object?>> killedRun() async {
      final client = newClient();
      await loadMe(client);
      server.online = false;
      unawaited(renameOffline(client, 'Grace'));
      await client.whenIdle;
      await pumpEventQueue();
      final persisted = client.cache.snapshot;
      client.dispose();
      expect(store.entries, hasLength(1), reason: 'survives the client');
      return persisted;
    }

    test('the queue is replayed and its response cached', () async {
      final persisted = await killedRun();
      server.online = true;
      final client = newClient(
        cache: Cache(
          normalization: slingSchema.normalization,
          initial: persisted,
        ),
      );
      expect(client.queuedMutations, hasLength(1));
      server.names['1'] = 'Ada'; // the server never saw the call
      await pumpEventQueue();
      await client.whenIdle;
      expect(server.renames, ['Grace']);
      expect(store.entries, isEmpty);
      expect(cachedName(client), 'Grace');
      expect(
        client.cache.entity('ROOT_MUTATION') ?? const {},
        isEmpty,
        reason: 'root fields removed as for any mutation',
      );
    });

    test('a rejected replay rolls the persisted optimistic write back from '
        'the stored log and is reported', () async {
      final persisted = await killedRun();
      server
        ..online = true
        ..rejectNext = true;
      final cache = Cache(
        normalization: slingSchema.normalization,
        initial: persisted,
      );
      final client = newClient(cache: cache);
      final failures = <QueuedMutationFailure>[];
      client.onQueuedMutationFailed.listen(failures.add);
      expect(cachedName(client), 'Grace', reason: 'persisted optimistic');
      await pumpEventQueue();
      await client.whenIdle;
      expect(failures, hasLength(1));
      expect(cachedName(client), 'Ada', reason: 'rolled back');
      expect(store.entries, isEmpty);
    });

    test('still offline: the restored call waits, offline calls queue '
        'behind it', () async {
      final persisted = await killedRun();
      final client = newClient(
        cache: Cache(
          normalization: slingSchema.normalization,
          initial: persisted,
        ),
      );
      await pumpEventQueue();
      await client.whenIdle;
      final later = renameOffline(client, 'Hopper');
      expect(client.queuedMutations.map((m) => m.variables['name']), [
        'Grace',
        'Hopper',
      ]);
      server.online = true;
      await client.replayQueue();
      expect(await later, 'Hopper');
      expect(server.renames, ['Grace', 'Hopper']);
    });

    test('a store that loads asynchronously is replayed before new '
        'calls', () async {
      await killedRun();
      server.online = true;
      final slow = _SlowStore(store);
      final client = SlingClient<Query>(
        endpoint: testEndpoint,
        schema: slingSchema,
        httpClient: server.httpClient,
        mutationQueue: slow,
      );
      addTearDown(client.dispose);
      final later = client.mutateWith(
        Mutation.root,
        (m) => m.rename(id: '1', name: 'Hopper')?.name,
        offline: true,
      );
      expect(server.mutations, 1, reason: 'waits for the restored entries');
      slow.release();
      expect(await later, 'Hopper');
      expect(server.renames, ['Grace', 'Hopper']);
    });
  });

  test('gc keeps the entities a queued rollback would restore', () async {
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      httpClient: server.httpClient,
      mutationQueue: store,
      gcAfterWrites: null,
    );
    addTearDown(client.dispose);
    await client.resolve((q) => [for (final f in q.me.friends()) f.name]);
    server.online = false;
    unawaited(
      client.mutateWith(
        Mutation.root,
        (m) => m.rename(id: '1', name: 'Grace')?.name,
        optimistic: () => client.cacheScope
            .list((q) => q.me.friends())
            .remove(client.cacheScope.user('b')!),
        offline: true,
      ),
    );
    await client.whenIdle;
    await pumpEventQueue();
    expect(client.gc(), isEmpty, reason: 'User:b is in the rollback log');
    expect(client.cache.hasEntity('User:b'), isTrue);
  });

  testWidgets('MutationBuilder: isQueued while the call waits, then the '
      'result', (tester) async {
    final client = newClient();
    await tester.runAsync(() => loadMe(client));
    server.online = false;
    late Mutate<Mutation> mutate;
    late MutationState state;
    await tester.pumpWidget(
      SlingScope<Query>(
        client: client,
        child: MutationBuilder<Mutation>(
          root: Mutation.root,
          builder: (context, m, s) {
            mutate = m;
            state = s;
            return const SizedBox();
          },
        ),
      ),
    );
    final call = mutate(
      (m) => m.rename(id: '1', name: 'Grace')?.name,
      offline: true,
    );
    await tester.pump();
    expect(state.isQueued, isTrue);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);

    server.online = true;
    await tester.pump(const Duration(seconds: 1)); // the backoff timer
    await tester.pump();
    expect(await call, 'Grace');
    expect(state.isQueued, isFalse);
    expect(state.data, 'Grace');
  });
}

/// `me` / `user(id:)` and `rename`, with a switch for the network and one
/// for rejecting the next mutation.
class _Server {
  final Map<String, String> names = {'1': 'Ada', 'a': 'Bob', 'b': 'Cy'};
  bool online = true;
  bool rejectNext = false;

  /// HTTP statuses the next mutations answer with, in order.
  final List<int> statusNext = [];
  Duration latency = Duration.zero;
  int mutations = 0;
  final List<String> renames = [];
  int _concurrent = 0;
  int maxConcurrent = 0;

  Map<String, Object?> _user(String id) => {
    '__typename': 'User',
    'id': id,
    'name': names[id],
  };

  late final http.Client httpClient = MockClient((req) async {
    final body = jsonDecode(req.body) as Map<String, Object?>;
    final query = body['query']! as String;
    final vars = (body['variables']! as Map).cast<String, Object?>();
    final isMutation = query.startsWith('mutation');
    if (isMutation) mutations++;
    if (!online) throw http.ClientException('offline');
    _concurrent++;
    if (_concurrent > maxConcurrent) maxConcurrent = _concurrent;
    try {
      if (latency > Duration.zero) await Future<void>.delayed(latency);
      if (!isMutation) {
        final data = <String, Object?>{};
        for (final m in RegExp(
          r'^  (?:(\w+): )?(\w+)',
          multiLine: true,
        ).allMatches(query)) {
          final key = m.group(1) ?? m.group(2)!;
          data[key] = switch (m.group(2)) {
            'me' => {
              ..._user('1'),
              'friends': [_user('a'), _user('b')],
            },
            'user' => _user(vars['id']! as String),
            _ => null,
          };
        }
        return http.Response(jsonEncode({'data': data}), 200);
      }
      if (statusNext.isNotEmpty) {
        return http.Response('', statusNext.removeAt(0));
      }
      if (rejectNext) {
        rejectNext = false;
        return http.Response(
          jsonEncode({
            'data': null,
            'errors': [
              {'message': 'not allowed'},
            ],
          }),
          200,
        );
      }
      final alias = RegExp(r'(rename_\w+):').firstMatch(query)!.group(1)!;
      final name = vars['name']! as String;
      names[vars['id']! as String] = name;
      renames.add(name);
      return http.Response(
        jsonEncode({
          'data': {alias: _user(vars['id']! as String)},
        }),
        200,
      );
    } finally {
      _concurrent--;
    }
  });
}

/// A store whose [load] completes on [release], with what [inner] held
/// when it was created (what a slow store read before anything changed).
class _SlowStore implements MutationQueueStore {
  _SlowStore(this.inner) : _held = inner.load();

  final InMemoryMutationQueueStore inner;
  final List<QueuedMutation> _held;
  final _loaded = Completer<List<QueuedMutation>>();

  void release() => _loaded.complete(_held);

  @override
  Future<List<QueuedMutation>> load() => _loaded.future;

  @override
  Future<void> add(QueuedMutation entry) => inner.add(entry);

  @override
  Future<void> remove(String id) => inner.remove(id);

  @override
  Future<void> clear() => inner.clear();
}
