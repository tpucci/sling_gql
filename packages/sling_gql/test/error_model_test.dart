import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// A client answering every request with [respond], retries off.
SlingClient<Query> _client(
  FutureOr<http.Response> Function(http.Request request) respond,
) => SlingClient<Query>(
  endpoint: testEndpoint,
  schema: slingSchema,
  retry: RetryPolicy.none,
  httpClient: MockClient((request) async => respond(request)),
);

/// The error `me.name` fails with on [client].
Future<SlingException?> _queryError(SlingClient<Query> client) async {
  final scope = client.createScope(onChanged: () {});
  scope.run((q) => q.me.name);
  await scope.whenSettled;
  return scope.error;
}

/// Exhaustive over the sealed hierarchy: adding a subclass breaks this.
String _describe(SlingException error) => switch (error) {
  SlingNetworkException() => 'offline',
  SlingTimeoutException() => 'slow',
  SlingHttpException(:final statusCode) => 'http $statusCode',
  SlingGraphQLException(:final isPartial) => isPartial ? 'partial' : 'graphql',
  SlingAuthException() => 'auth',
  SlingCancelledException() => 'cancelled',
  SlingTransportException() => 'transport',
};

void main() {
  test('a failed connection is a SlingNetworkException: unreachable', () async {
    final client = _client((_) => throw http.ClientException('no route'));
    final error = await _queryError(client);
    expect(error, isA<SlingNetworkException>());
    error as SlingNetworkException;
    expect(error.isNetworkUnreachable, isTrue);
    expect(error.cause, isA<http.ClientException>());
    expect(error.message, 'no route');
    expect(_describe(error), 'offline');
  });

  test('an error status is a SlingHttpException with the body and its '
      'GraphQL errors', () async {
    final body = jsonEncode({
      'errors': [
        {
          'message': 'Cannot query field "nope"',
          'locations': [
            {'line': 2, 'column': 3},
          ],
          'extensions': {'code': 'GRAPHQL_VALIDATION_FAILED'},
        },
      ],
    });
    final client = _client((_) => http.Response(body, 400));
    final error = await _queryError(client);
    expect(error, isA<SlingHttpException>());
    error as SlingHttpException;
    expect(error.statusCode, 400);
    expect(error.body, body);
    expect(error.message, 'HTTP 400');
    expect(error.isNetworkUnreachable, isFalse);
    expect(error.errors.single.code, 'GRAPHQL_VALIDATION_FAILED');
    expect(error.errors.single.locations.single, (line: 2, column: 3));
  });

  test('a non-JSON error body still gives the status', () async {
    final client = _client((_) => http.Response('<html>502</html>', 502));
    final error = await _queryError(client) as SlingHttpException;
    expect(error.statusCode, 502);
    expect(error.body, '<html>502</html>');
    expect(error.errors, isEmpty);
  });

  test(
    'errors without data are a SlingGraphQLException, not partial',
    () async {
      final client = _client(
        (_) => http.Response(
          jsonEncode({
            'data': null,
            'errors': [
              {
                'message': 'Not allowed',
                'path': ['me'],
                'extensions': {'code': 'FORBIDDEN', 'reason': 'banned'},
              },
            ],
          }),
          200,
        ),
      );
      final error = await _queryError(client);
      expect(error, isA<SlingGraphQLException>());
      error as SlingGraphQLException;
      expect(error.isPartial, isFalse);
      expect(error.message, 'Not allowed');
      expect(error.statusCode, isNull);
      final e = error.errors.single;
      expect(e.message, 'Not allowed');
      expect(e.path, ['me']);
      expect(e.code, 'FORBIDDEN');
      expect(e.extensions, {'code': 'FORBIDDEN', 'reason': 'banned'});
      expect(e.toJson(), {
        'message': 'Not allowed',
        'path': ['me'],
        'extensions': {'code': 'FORBIDDEN', 'reason': 'banned'},
      });
    },
  );

  test('errors next to data are a partial SlingGraphQLException', () async {
    final client = _client(
      (_) => http.Response(
        jsonEncode({
          'data': {
            'me': {'__typename': 'User', 'id': '1', 'name': null},
          },
          'errors': [
            {
              'message': 'name unavailable',
              'path': ['me', 'name'],
            },
          ],
        }),
        200,
      ),
    );
    final error = await _queryError(client) as SlingGraphQLException;
    expect(error.isPartial, isTrue);
    expect(_describe(error), 'partial');
  });

  test('a body that is not JSON is a SlingTransportException', () async {
    final client = _client((_) => http.Response('surprise', 200));
    final error = await _queryError(client) as SlingTransportException;
    expect(error.cause, isA<FormatException>());
    expect(error.message, 'Invalid JSON response (HTTP 200)');
  });

  test('resolve and mutateWith throw the typed error', () async {
    final client = _client((_) => http.Response('down', 503));
    await expectLater(
      client.resolve((q) => q.me.name),
      throwsA(
        isA<SlingHttpException>().having((e) => e.statusCode, 'status', 503),
      ),
    );
    await expectLater(
      client.mutateWith(
        Mutation.root,
        (m) => m.rename(id: '1', name: 'x')?.name,
      ),
      throwsA(isA<SlingHttpException>()),
    );
  });

  test('SlingRequest.error is the typed error', () async {
    final client = _client((_) => throw http.ClientException('offline'));
    final records = <SlingRequest>[];
    client.requests.listen(records.add);
    await _queryError(client);
    expect(records.last.error, isA<SlingNetworkException>());
    expect(records.last.logLine, contains('✗ offline'));
  });

  test('SlingException.from classifies what transports throw', () {
    final network = http.ClientException('refused');
    expect(SlingException.from(network), isA<SlingNetworkException>());
    expect(
      SlingException.from(http.RequestAbortedException()),
      isA<SlingCancelledException>(),
    );
    expect(
      SlingException.from(TimeoutException('t', const Duration(seconds: 2))),
      isA<SlingTimeoutException>().having(
        (e) => e.timeout,
        'timeout',
        const Duration(seconds: 2),
      ),
    );
    final http503 = SlingHttpException(503);
    expect(SlingException.from(http503), same(http503));
    expect(
      SlingException.from(StateError('bug')),
      isA<SlingTransportException>().having(
        (e) => e.cause,
        'cause',
        isA<StateError>(),
      ),
    );
  });

  test('SlingGraphQLError.fromJson tolerates odd shapes', () {
    final e = SlingGraphQLError.fromJson({
      'path': ['a', 0, null],
      'locations': [
        {'line': 'x'},
      ],
      'extensions': {'code': 42},
    });
    expect(e.message, 'Unknown GraphQL error');
    expect(e.path, ['a', 0]);
    expect(e.locations, isEmpty);
    expect(e.code, isNull);
    expect(SlingGraphQLError.listFromJson('nope'), isEmpty);
  });
}
