import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// Fails the first [failures] requests with [failure], then answers.
class _Flaky {
  _Flaky(this.failures, {http.Response? failure, this.network = false})
    : failure = failure ?? http.Response('busy', 503);

  int failures;
  final http.Response failure;
  final bool network;
  int calls = 0;

  late final http.Client httpClient = MockClient((request) async {
    calls++;
    if (failures > 0) {
      failures--;
      if (network) throw http.ClientException('connection reset');
      return failure;
    }
    final query = (jsonDecode(request.body) as Map)['query'] as String;
    if (query.startsWith('mutation')) {
      final alias = RegExp(r'(rename_\w+): rename').firstMatch(query)![1]!;
      return http.Response(
        jsonEncode({
          'data': {
            alias: {'__typename': 'User', 'id': '1', 'name': 'Zed'},
          },
        }),
        200,
      );
    }
    return http.Response(jsonEncode({'data': meWithFriends()}), 200);
  });
}

const _fast = RetryPolicy(initialDelay: Duration(milliseconds: 1), jitter: 0);

SlingClient<Query> _client(_Flaky server, {RetryPolicy retry = _fast}) =>
    SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      httpClient: server.httpClient,
      retry: retry,
    );

void main() {
  group('RetryPolicy.delayFor', () {
    test('exponential, capped at maxDelay', () {
      const policy = RetryPolicy(
        initialDelay: Duration(milliseconds: 100),
        maxDelay: Duration(milliseconds: 350),
        jitter: 0,
      );
      expect(policy.delayFor(1), const Duration(milliseconds: 100));
      expect(policy.delayFor(2), const Duration(milliseconds: 200));
      expect(policy.delayFor(3), const Duration(milliseconds: 350));
    });

    test('jitter takes up to that fraction off', () {
      const policy = RetryPolicy(initialDelay: Duration(milliseconds: 100));
      final random = Random(1);
      for (var i = 0; i < 50; i++) {
        final d = policy.delayFor(2, random).inMicroseconds;
        expect(d, inInclusiveRange(100000, 200000));
      }
    });

    test('isTransient: network, timeout, 5xx', () {
      expect(
        RetryPolicy.isTransient(SlingNetworkException(StateError('x'))),
        isTrue,
      );
      expect(RetryPolicy.isTransient(SlingTimeoutException()), isTrue);
      expect(RetryPolicy.isTransient(SlingHttpException(502)), isTrue);
      expect(RetryPolicy.isTransient(SlingHttpException(404)), isFalse);
      expect(RetryPolicy.isTransient(SlingGraphQLException(const [])), isFalse);
    });
  });

  test('the default policy: 3 attempts, network/timeout/5xx', () {
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
    );
    addTearDown(client.dispose);
    expect(client.retry.maxAttempts, 3);
    expect(identical(client.retry.retryIf, RetryPolicy.isTransient), isTrue);
  });

  test(
    'a query retried through 5xx lands; the scope only saw loading',
    () async {
      final server = _Flaky(2);
      final client = _client(server);
      final records = <SlingRequest>[];
      client.requests.listen(records.add);
      final scope = client.createScope(onChanged: () {});
      scope.run((q) => q.me.name);
      await Future<void>.delayed(Duration.zero);
      expect(scope.isLoading, isTrue);
      await scope.whenSettled;
      expect(server.calls, 3);
      expect(scope.error, isNull);
      expect(client.cache.read('query', ['me', 'name']), 'Ada');
      expect(records.last.attempts, 3);
      expect(records.last.logLine, contains('3 attempts'));
    },
  );

  test('network errors are retried too', () async {
    final server = _Flaky(1, network: true);
    final client = _client(server);
    expect(await client.resolve((q) => q.me.name), 'Ada');
    expect(server.calls, 2);
  });

  test('gives up after maxAttempts with the last error, then sticky', () async {
    final server = _Flaky(10);
    final client = _client(server);
    late QueryScope<Query> scope;
    scope = client.createScope(onChanged: () => scope.run((q) => q.me.name));
    scope.run((q) => q.me.name);
    await scope.whenSettled;
    expect(server.calls, 3);
    expect(
      scope.error,
      isA<SlingHttpException>().having((e) => e.statusCode, 'status', 503),
    );
    // The sticky error (and retryFailedAfter's cooldown) start from here:
    // rebuilds do not retry.
    scope.run((q) => q.me.name);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(server.calls, 3);
  });

  test('4xx and GraphQL errors are not retried', () async {
    final notFound = _Flaky(5, failure: http.Response('no', 404));
    await expectLater(
      _client(notFound).resolve((q) => q.me.name),
      throwsA(isA<SlingHttpException>()),
    );
    expect(notFound.calls, 1);

    final graphql = _Flaky(
      5,
      failure: http.Response(
        jsonEncode({
          'errors': [
            {'message': 'bad'},
          ],
        }),
        200,
      ),
    );
    await expectLater(
      _client(graphql).resolve((q) => q.me.name),
      throwsA(isA<SlingGraphQLException>()),
    );
    expect(graphql.calls, 1);
  });

  test('RetryPolicy.none reports the first failure', () async {
    final server = _Flaky(1);
    await expectLater(
      _client(server, retry: RetryPolicy.none).resolve((q) => q.me.name),
      throwsA(isA<SlingHttpException>()),
    );
    expect(server.calls, 1);
  });

  test('a custom retryIf', () async {
    final server = _Flaky(2, failure: http.Response('locked', 423));
    final client = _client(
      server,
      retry: RetryPolicy(
        initialDelay: const Duration(milliseconds: 1),
        retryIf: (e) => e.statusCode == 423,
      ),
    );
    expect(await client.resolve((q) => q.me.name), 'Ada');
    expect(server.calls, 3);
  });

  group('mutations', () {
    test('are not retried by default', () async {
      final server = _Flaky(1);
      await expectLater(
        _client(server).mutateWith(
          Mutation.root,
          (m) => m.rename(id: '1', name: 'Zed')?.name,
        ),
        throwsA(isA<SlingHttpException>()),
      );
      expect(server.calls, 1);
    });

    test('mutateWith(retry:) opts in', () async {
      final server = _Flaky(1);
      final name = await _client(server).mutateWith(
        Mutation.root,
        (m) => m.rename(id: '1', name: 'Zed')?.name,
        retry: _fast,
      );
      expect(name, 'Zed');
      expect(server.calls, 2);
    });
  });

  test('disposing the scope during the backoff stops retrying', () async {
    final server = _Flaky(10);
    final client = _client(
      server,
      retry: const RetryPolicy(
        initialDelay: Duration(milliseconds: 30),
        jitter: 0,
      ),
    );
    final scope = client.createScope(onChanged: () {});
    scope.run((q) => q.me.name);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(server.calls, 1);
    scope.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.calls, 1);
    expect(client.isIdle, isTrue);
  });
}
