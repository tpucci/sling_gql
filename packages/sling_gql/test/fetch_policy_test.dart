import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// A client whose `me.name` answer can be changed between requests and
/// whose clock is controlled by the test.
class Harness {
  Harness({FetchPolicy? fetchPolicy, Duration? maxAge, this.fail = false}) {
    client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      fetchPolicy: fetchPolicy ?? FetchPolicy.cacheFirst,
      maxAge: maxAge,
      now: () => now,
      httpClient: MockClient((req) async {
        calls++;
        if (fail) {
          return http.Response(
            jsonEncode({
              'errors': [
                {'message': 'boom'},
              ],
            }),
            200,
          );
        }
        // Answer only the selected fields, like a real server.
        final doc = (jsonDecode(req.body) as Map)['query'] as String;
        return http.Response(
          jsonEncode({
            'data': {
              'me': {
                '__typename': 'User',
                'id': '1',
                if (RegExp(r'\bname\b').hasMatch(doc)) 'name': name,
                if (doc.contains('age')) 'age': 36,
              },
            },
          }),
          200,
        );
      }),
    );
    addTearDown(client.dispose);
  }

  late final SlingClient<Query> client;
  var now = DateTime(2026, 1, 1, 12);
  var name = 'Ada';
  var calls = 0;
  bool fail;

  /// Lets the flush microtask run and the response land.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await client.whenIdle;
    await Future<void>.delayed(Duration.zero);
  }

  /// A scope that re-runs [body] on change, like a widget would.
  QueryScope<Query> scope(
    void Function(Query q) body, {
    FetchPolicy? fetchPolicy,
    Duration? maxAge,
  }) {
    late QueryScope<Query> s;
    s = client.createScope(
      onChanged: () => s.run(body),
      fetchPolicy: fetchPolicy,
      maxAge: maxAge,
    );
    s.run(body);
    return s;
  }
}

void main() {
  group('cacheFirst (default)', () {
    test('cached data never expires without a maxAge', () async {
      final h = Harness();
      await h.client.resolve((q) => q.me.name);
      expect(h.calls, 1);
      h.now = h.now.add(const Duration(days: 365));
      final s = h.scope((q) => q.me.name);
      await h.settle();
      expect(h.calls, 1);
      expect(s.isStale, isFalse);
      expect(s.isLoading, isFalse);
    });
  });

  group('cacheAndNetwork', () {
    test('serves the cache and refetches once, on the first run', () async {
      final h = Harness();
      await h.client.resolve((q) => q.me.name);
      h.name = 'Grace';

      String? seen;
      final s = h.scope(
        (q) => seen = q.me.name,
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      );
      expect(seen, 'Ada', reason: 'cached value shown at once');
      expect(s.isLoading, isTrue, reason: 'background refetch scheduled');
      expect(s.hasMissingData, isFalse);
      await h.settle();
      expect(h.calls, 2);
      expect(seen, 'Grace', reason: 'rebuilt with the fresh value');
      expect(s.isLoading, isFalse);

      // Later runs (parent rebuilds) do not refetch again.
      s.run((q) => seen = q.me.name);
      await h.settle();
      expect(h.calls, 2);
    });

    test('with nothing cached it is one request, like cacheFirst', () async {
      final h = Harness();
      final s = h.scope(
        (q) => q.me.name,
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      );
      expect(s.hasMissingData, isTrue);
      await h.settle();
      expect(h.calls, 1);
      expect(s.run((q) => q.me.name), 'Ada');
      await h.settle();
      expect(h.calls, 1);
    });

    test('resolve() waits for the network round trip', () async {
      final h = Harness();
      await h.client.resolve((q) => q.me.name);
      h.name = 'Grace';
      final name = await h.client.resolve(
        (q) => q.me.name,
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      );
      expect(name, 'Grace');
      expect(h.calls, 2);
    });
  });

  group('networkOnly', () {
    test('ignores the cache until its own response has landed', () async {
      final h = Harness();
      await h.client.resolve((q) => q.me.name);
      h.name = 'Grace';

      String? seen;
      final s = h.scope(
        (q) => seen = q.me.name,
        fetchPolicy: FetchPolicy.networkOnly,
      );
      expect(seen, isNull, reason: 'skeleton, even though Ada is cached');
      expect(s.hasMissingData, isTrue);
      expect(s.isLoading, isTrue);
      expect(
        h.client.cacheScope.query.me.name,
        'Ada',
        reason: 'the shared cache is untouched',
      );

      await h.settle();
      expect(h.calls, 2);
      expect(seen, 'Grace');
      expect(s.hasMissingData, isFalse);

      // From now on the scope reads the cache like any other.
      s.run((q) => seen = q.me.name);
      await h.settle();
      expect(h.calls, 2);
      expect(seen, 'Grace');
    });

    test(
      'a failed request keeps the scope on skeletons with the error',
      () async {
        final h = Harness(fail: true);
        h.client.cache.writeResponse('query', {
          'me': {'__typename': 'User', 'id': '1', 'name': 'Ada'},
        });
        String? seen;
        final s = h.scope(
          (q) => seen = q.me.name,
          fetchPolicy: FetchPolicy.networkOnly,
        );
        await h.settle();
        expect(h.calls, 1);
        expect(s.error, isA<SlingException>());
        expect(seen, isNull, reason: 'not falling back to the cached value');
        // Sticky: rebuilds do not re-send.
        s.run((q) => seen = q.me.name);
        await h.settle();
        expect(h.calls, 1);
      },
    );

    test('resolve(networkOnly) always hits the server', () async {
      final h = Harness();
      await h.client.resolve((q) => q.me.name);
      h.name = 'Grace';
      expect(await h.client.resolve((q) => q.me.name), 'Ada');
      expect(
        await h.client.resolve(
          (q) => q.me.name,
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        'Grace',
      );
      expect(h.calls, 2);
    });
  });

  group('background errors', () {
    test(
      'a failed refetch() stays visible while cached data renders',
      () async {
        final h = Harness();
        await h.client.resolve((q) => q.me.name);
        final s = h.scope((q) => q.me.name);
        await h.settle();

        h.fail = true;
        await s.refetch();
        expect(s.error, isA<SlingException>());
        expect(s.run((q) => q.me.name), 'Ada', reason: 'cached data stays');
        expect(s.error, isNotNull, reason: 'rebuilds do not swallow it');
        await h.settle();
        expect(h.calls, 2);

        h.fail = false;
        await s.refetch();
        expect(s.error, isNull);
        expect(h.calls, 3);
      },
    );

    test('a failed cacheAndNetwork refresh is sticky too', () async {
      final h = Harness();
      await h.client.resolve((q) => q.me.name);
      h.fail = true;
      final s = h.scope(
        (q) => q.me.name,
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      );
      await h.settle();
      expect(s.error, isA<SlingException>());
      s.run((q) => q.me.name);
      expect(s.error, isNotNull);
      await h.settle();
      expect(h.calls, 2, reason: 'no retry loop');
    });
  });

  group('maxAge (stale-while-revalidate)', () {
    test('fresh data: no request; stale data: shown and refetched', () async {
      final h = Harness(maxAge: const Duration(minutes: 5));
      await h.client.resolve((q) => q.me.name);
      expect(h.calls, 1);

      h.now = h.now.add(const Duration(minutes: 4));
      String? seen;
      var s = h.scope((q) => seen = q.me.name);
      await h.settle();
      expect(h.calls, 1, reason: 'within maxAge');
      expect(s.isStale, isFalse);
      s.dispose();

      h.now = h.now.add(const Duration(minutes: 2));
      h.name = 'Grace';
      s = h.scope((q) => seen = q.me.name);
      expect(seen, 'Ada', reason: 'stale value rendered immediately');
      expect(s.isStale, isTrue);
      expect(s.isLoading, isTrue);
      expect(s.hasMissingData, isFalse);
      await h.settle();
      expect(h.calls, 2);
      expect(seen, 'Grace');
      expect(s.isStale, isFalse, reason: 'rebuilt after the response');
      expect(s.isLoading, isFalse);
    });

    test(
      'freshness is per field: any stale dep revalidates the whole selection',
      () async {
        final h = Harness(maxAge: const Duration(minutes: 5));
        await h.client.resolve((q) => q.me.name);
        h.now = h.now.add(const Duration(minutes: 10));
        await h.client.resolve((q) => q.me.age); // stamps me + age, not name
        expect(h.calls, 2);

        final s = h.scope((q) => (q.me.name, q.me.age));
        expect(s.isStale, isTrue, reason: 'name is 10 minutes old');
        await h.settle();
        expect(h.calls, 3);
        expect(s.isStale, isFalse);
      },
    );

    test(
      'data with no stamp (hydrated snapshot, manual write) is stale',
      () async {
        final h = Harness(maxAge: const Duration(hours: 1));
        h.client.cache.writeResponse('query', {
          'me': {'__typename': 'User', 'id': '1', 'name': 'Old'},
        });
        String? seen;
        final s = h.scope((q) => seen = q.me.name);
        expect(seen, 'Old');
        expect(s.isStale, isTrue);
        await h.settle();
        expect(h.calls, 1);
        expect(seen, 'Ada');
        expect(s.isStale, isFalse);
      },
    );

    test('a failing revalidation is sticky: no refetch loop', () async {
      final h = Harness(maxAge: const Duration(minutes: 5), fail: true);
      h.client.cache.writeResponse('query', {
        'me': {'__typename': 'User', 'id': '1', 'name': 'Ada'},
      }, at: h.now);
      h.now = h.now.add(const Duration(minutes: 10));
      String? seen;
      final s = h.scope((q) => seen = q.me.name);
      await h.settle();
      expect(h.calls, 1);
      expect(s.error, isA<SlingException>());
      expect(seen, 'Ada', reason: 'stale data stays on screen');
      expect(s.isStale, isTrue);

      for (var i = 0; i < 3; i++) {
        s.run((q) => seen = q.me.name);
        await h.settle();
      }
      expect(h.calls, 1, reason: 'sticky until refetch()');

      await s.refetch();
      expect(h.calls, 2);
    });

    test('revalidate() is a no-op when fresh, a refetch when stale', () async {
      final h = Harness(maxAge: const Duration(minutes: 5));
      await h.client.resolve((q) => q.me.name);
      final s = h.scope((q) => q.me.name);
      await h.settle();

      await s.revalidate();
      expect(h.calls, 1, reason: 'fresh');

      h.now = h.now.add(const Duration(minutes: 6));
      await s.revalidate();
      expect(h.calls, 2, reason: 'stale');

      await s.refetch();
      expect(h.calls, 3, reason: 'refetch is unconditional');
    });

    test('without maxAge, revalidate() is refetch()', () async {
      final h = Harness();
      await h.client.resolve((q) => q.me.name);
      final s = h.scope((q) => q.me.name);
      await s.revalidate();
      expect(h.calls, 2);
    });

    testWidgets('QueryBuilder: isStale and revalidate through QueryState', (
      tester,
    ) async {
      final h = Harness(maxAge: const Duration(minutes: 5));
      await h.client.resolve((q) => q.me.name);
      h.now = h.now.add(const Duration(minutes: 6));
      h.name = 'Grace';

      late QueryState state;
      await tester.pumpWidget(
        SlingScope<Query>(
          client: h.client,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: QueryBuilder<Query>(
              builder: (context, q, s) {
                state = s;
                return Text(q.me.name ?? '…');
              },
            ),
          ),
        ),
      );
      expect(find.text('Ada'), findsOneWidget);
      expect(state.isStale, isTrue);
      await tester.pump(); // response landed → rebuild
      expect(find.text('Grace'), findsOneWidget);
      expect(state.isStale, isFalse);
      expect(state.isLoading, isFalse);
      expect(h.calls, 2);
      await state.revalidate();
      expect(h.calls, 2, reason: 'fresh again');
    });
  });
}
