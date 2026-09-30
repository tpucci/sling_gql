import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/internal.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// Automatic cache garbage collection (TODO #22): `SlingClient.gc()` keeps
/// what live scopes read, and runs by itself every `gcAfterWrites`
/// responses once the client is idle.
void main() {
  // First response: friends a + b; every later one: only b.
  Map<String, Object?> shrinking(int call) => {
    'me': {
      '__typename': 'User',
      'id': '1',
      'name': 'Ada',
      'friends': [
        if (call == 1) {'__typename': 'User', 'id': 'a', 'name': 'Bob'},
        {'__typename': 'User', 'id': 'b', 'name': 'Cy'},
      ],
    },
  };

  SlingClient<Query> clientWith({int? gcAfterWrites}) {
    var call = 0;
    return SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      gcAfterWrites: gcAfterWrites,
      httpClient: mockGraphQL((q, v) => shrinking(++call)),
    );
  }

  test('cache.gc(retain:) keeps retained entities and what they reach', () {
    final cache = NormalizedCache();
    cache.writeResponse('query', {
      'me': {
        '__typename': 'User',
        'id': '1',
        'friends': [
          {'__typename': 'User', 'id': 'a'},
        ],
      },
    });
    cache.writeResponse('query', {
      'me': {'__typename': 'User', 'id': '1', 'friends': <Object?>[]},
    });
    cache.writeResponse('query', {
      'x': {
        '__typename': 'User',
        'id': 'x',
        'friends': [
          {'__typename': 'User', 'id': 'y'},
        ],
      },
    });
    cache.remove('query', ['x']);

    expect(cache.gc(retain: ['User:x', 'User:nope']), {'User:a'});
    expect(cache.hasEntity('User:x'), isTrue);
    expect(cache.hasEntity('User:y'), isTrue, reason: 'reached from User:x');
    expect(cache.gc(), {'User:x', 'User:y'});
  });

  test('gc drops the fetch stamps of collected entities', () {
    final cache = NormalizedCache();
    final at = DateTime(2026);
    cache.writeResponse('query', {
      'x': {'__typename': 'User', 'id': 'x', 'name': 'X'},
    }, at: at);
    expect(cache.fetchedAt('User:x.name'), at);
    cache.remove('query', ['x']);

    expect(cache.gc(), {'User:x'});
    expect(cache.fetchedAt('User:x.name'), isNull);
  });

  test(
    'client.gc() keeps an orphaned entity a live scope reads by lookup',
    () async {
      final client = clientWith();
      await client.resolve((q) => q.me.friends().map((f) => f.name).toList());
      // `user(id: a)` is not cached as a root field: served from User:a.
      final scope = client.createScope(onChanged: () {});
      expect(scope.run((q) => q.user(id: 'a')?.name), 'Bob');

      await client.resolve(
        (q) => q.me.friends().map((f) => f.name).toList(),
        fetchPolicy: FetchPolicy.networkOnly,
      );
      expect(client.cache.entity('User:1')!['friends'], [const Ref('User:b')]);

      expect(client.gc(), isEmpty, reason: 'the scope still reads User:a');
      scope.dispose();
      expect(client.gc(), {'User:a'});
    },
  );

  test('rows count as readers too', () async {
    final client = clientWith();
    await client.resolve((q) => q.me.friends().map((f) => f.name).toList());
    final scope = client.createScope(onChanged: () {});
    final row = scope.row(onChanged: () {});
    // A row bound to User:a directly (as SlingRow rebinds an accessor).
    User(row, row.root, const [Ref('User:a')]).name;
    await client.resolve(
      (q) => q.me.friends().map((f) => f.name).toList(),
      fetchPolicy: FetchPolicy.networkOnly,
    );

    expect(client.gc(), isEmpty);
    row.dispose();
    expect(client.gc(), {'User:a'});
    scope.dispose();
  });

  test('runs by itself after gcAfterWrites responses, once idle', () async {
    final client = clientWith(gcAfterWrites: 2);
    await client.resolve((q) => q.me.friends().map((f) => f.name).toList());
    expect(client.cache.hasEntity('User:a'), isTrue);

    await client.resolve(
      (q) => q.me.friends().map((f) => f.name).toList(),
      fetchPolicy: FetchPolicy.networkOnly,
    );
    expect(client.cache.hasEntity('User:a'), isFalse, reason: '2nd write');
  });

  test('gcAfterWrites: null never collects on its own', () async {
    final client = clientWith();
    for (var i = 0; i < 3; i++) {
      await client.resolve(
        (q) => q.me.friends().map((f) => f.name).toList(),
        fetchPolicy: FetchPolicy.networkOnly,
      );
    }
    expect(client.cache.hasEntity('User:a'), isTrue);
  });

  test('defaults to a sweep every 100 responses', () {
    expect(clientWith(gcAfterWrites: 100).gcAfterWrites, 100);
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      httpClient: mockGraphQL((q, v) => {}),
    );
    expect(client.gcAfterWrites, 100);
  });

  test('skipped while a mutation is in flight', () async {
    final release = Completer<void>();
    var queries = 0;
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      gcAfterWrites: null,
      httpClient: MockClient((req) async {
        final query =
            (jsonDecode(req.body) as Map<String, Object?>)['query'] as String;
        if (query.startsWith('mutation')) {
          await release.future;
          final alias = RegExp(r'(rename_\w+):').firstMatch(query)!.group(1)!;
          return http.Response(
            jsonEncode({
              'data': {
                alias: {'__typename': 'User', 'id': 'b', 'name': 'Cyd'},
              },
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'data': shrinking(++queries)}), 200);
      }),
    );
    await client.resolve((q) => q.me.friends().map((f) => f.name).toList());
    await client.resolve(
      (q) => q.me.friends().map((f) => f.name).toList(),
      fetchPolicy: FetchPolicy.networkOnly,
    );

    final done = client.mutateWith(
      Mutation.root,
      (m) => m.rename(id: 'b', name: 'Cyd')?.name,
    );
    await pumpEventQueue();
    expect(client.gc(), isEmpty);
    expect(client.cache.hasEntity('User:a'), isTrue);
    release.complete();
    expect(await done, 'Cyd');
    expect(client.gc(), {'User:a'});
  });
}
