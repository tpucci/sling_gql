import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

Future<void> settle(QueryScope<Query> scope) async {
  await scope.whenSettled;
  await Future<void>.delayed(Duration.zero); // let the rebuild's flush run
}

void main() {
  test('sticky forever by default: a repeated miss never re-sends the failed document',
      () async {
    var calls = 0;
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: MockClient((req) async {
        calls++;
        return http.Response(jsonEncode({'errors': [{'message': 'boom'}]}), 200);
      }),
    );

    late QueryScope<Query> scope;
    scope = client.createScope(onChanged: () => scope.run((q) => q.me.name));
    scope.run((q) => q.me.name);
    await settle(scope);
    expect(calls, 1);
    expect(scope.error, isA<SlingException>());

    // Rebuilding (a real widget would re-run on every parent build) must not
    // re-send the document, no matter how much time passes.
    scope.run((q) => q.me.name);
    await settle(scope);
    expect(calls, 1);
  });

  test('retryFailedAfter: a miss retries the document once the cooldown has elapsed',
      () async {
    var now = DateTime(2024, 1, 1);
    var calls = 0;
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      retryFailedAfter: const Duration(seconds: 5),
      now: () => now,
      httpClient: MockClient((req) async {
        calls++;
        if (calls == 1) {
          return http.Response(jsonEncode({'errors': [{'message': 'boom'}]}), 200);
        }
        return http.Response(
          jsonEncode({
            'data': {
              'me': {'__typename': 'User', 'id': '1', 'name': 'Ada'},
            },
          }),
          200,
        );
      }),
    );

    late QueryScope<Query> scope;
    scope = client.createScope(onChanged: () => scope.run((q) => q.me.name));
    scope.run((q) => q.me.name);
    await settle(scope);
    expect(calls, 1);
    expect(scope.error, isA<SlingException>());

    // Before the cooldown: still sticky.
    now = now.add(const Duration(seconds: 3));
    scope.run((q) => q.me.name);
    await settle(scope);
    expect(calls, 1, reason: 'cooldown has not elapsed yet');
    expect(scope.error, isA<SlingException>());

    // After the cooldown: retried automatically, and this time it succeeds.
    now = now.add(const Duration(seconds: 3)); // total 6s since the failure
    scope.run((q) => q.me.name);
    await settle(scope);
    expect(calls, 2, reason: 'cooldown elapsed: the document is retried');
    expect(scope.error, isNull);
    expect(scope.run((q) => q.me.name), 'Ada');
  });
}
