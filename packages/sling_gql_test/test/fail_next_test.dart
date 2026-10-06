import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

import 'support/test_schema.dart';

void main() {
  group('MockGraphQLServer.failNext', () {
    test(
      'an HTTP status, then answers again; failed requests are logged',
      () async {
        final server = MockGraphQLServer(query: {'me': user('1', 'Ada')})
          ..failNext(const MockFailure.status(503, body: 'busy'));
        final client = server.client(Query.root, retry: RetryPolicy.none);
        final scope = client.createScope(onChanged: () {});
        scope.run((q) => q.me.name);
        await scope.whenSettled;
        expect(
          scope.error,
          isA<SlingHttpException>()
              .having((e) => e.statusCode, 'status', 503)
              .having((e) => e.body, 'body', 'busy'),
        );
        expect(server.lastRequest.failed, isTrue);
        expect(server.pendingFailures, 0);
        await scope.refetch();
        expect(scope.error, isNull);
        expect(server.lastRequest.failed, isFalse);
      },
    );

    test('the client default retry goes through transient failures', () async {
      final server = MockGraphQLServer(query: {'me': user('1', 'Ada')})
        ..failNext(const MockFailure.status(502), times: 2);
      final client = server.client(
        Query.root,
        retry: const RetryPolicy(initialDelay: Duration(milliseconds: 1)),
      );
      expect(await client.resolve((q) => q.me.name), 'Ada');
      expect(server.requests.map((r) => r.failed), [true, true, false]);
    });

    test('a GraphQL error code', () async {
      final server = MockGraphQLServer(query: {'me': user('1', 'Ada')})
        ..failNext(const MockFailure.graphQL('nope', code: 'FORBIDDEN'));
      final client = server.client(Query.root);
      await expectLater(
        client.resolve((q) => q.me.name),
        throwsA(
          isA<SlingGraphQLException>().having(
            (e) => e.errors.single.code,
            'code',
            'FORBIDDEN',
          ),
        ),
      );
    });

    test('a network error: unreachable', () async {
      final server = MockGraphQLServer(query: {'me': user('1', 'Ada')})
        ..failNext(const MockFailure.network());
      final client = server.client(Query.root, retry: RetryPolicy.none);
      await expectLater(
        client.resolve((q) => q.me.name),
        throwsA(
          isA<SlingNetworkException>().having(
            (e) => e.isNetworkUnreachable,
            'unreachable',
            isTrue,
          ),
        ),
      );
    });

    test('a subscription connection fails too', () async {
      final server = MockGraphQLServer(
        subscription: {'userChanged': const Stream<Object?>.empty()},
      )..failNext(const MockFailure.status(401));
      final client = server.client(Query.root);
      final errors = <Object>[];
      client
          .subscribeWith(Subscription.root, (s) => s.userChanged?.name)
          .stream
          .listen((_) {}, onError: errors.add);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        errors.single,
        isA<SlingHttpException>().having((e) => e.statusCode, 'status', 401),
      );
    });
  });

  test('MockGraphQLError(code:) becomes extensions.code', () async {
    final server = MockGraphQLServer(
      query: {
        'user': (Map<String, Object?> _) =>
            throw MockGraphQLError('who?', code: 'UNAUTHENTICATED'),
      },
    );
    final result = await server.execute('query { user(id: "x") { id } }');
    expect(result['errors'], [
      {
        'message': 'who?',
        'path': ['user'],
        'extensions': {'code': 'UNAUTHENTICATED'},
      },
    ]);
  });

  test('requests record their headers; client(auth:) refreshes on an '
      'UNAUTHENTICATED code', () async {
    var token = 'old';
    final server = MockGraphQLServer(query: {'me': user('1', 'Ada')})
      ..failNext(const MockFailure.graphQL('expired', code: 'UNAUTHENTICATED'));
    final client = server.client(
      Query.root,
      auth: SlingAuth(
        headers: () => {'authorization': 'Bearer $token'},
        refresh: () async => token = 'new',
      ),
    );
    expect(await client.resolve((q) => q.me.name), 'Ada');
    expect(server.requests.map((r) => r.headers['authorization']), [
      'Bearer old',
      'Bearer new',
    ]);
  });

  testWidgets('client(timeout:, errorPolicy:) reach the client', (
    tester,
  ) async {
    final server = MockGraphQLServer(
      query: {'me': user('1', 'Ada')},
      latency: const Duration(seconds: 2),
    );
    final client = server.client(
      Query.root,
      timeout: const Duration(milliseconds: 100),
      retry: RetryPolicy.none,
      errorPolicy: ErrorPolicy.all,
    );
    expect(client.errorPolicy, ErrorPolicy.all);
    final scope = client.createScope(onChanged: () {});
    scope.run((q) => q.me.name);
    await tester.pumpUntilSettled(client);
    expect(scope.error, isA<SlingTimeoutException>());
    await tester.pump(const Duration(seconds: 2)); // the latency timer
  });
}
