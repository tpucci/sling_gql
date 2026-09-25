import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

http.Response _ok(Map<String, Object?> data) =>
    http.Response(jsonEncode({'data': data}), 200);

/// A `MockClient` that records every request it received.
MockClient _recording(List<http.Request> seen, {int failFirst = 0}) {
  var failures = failFirst;
  return MockClient((req) async {
    seen.add(req);
    if (failures-- > 0) return http.Response('boom', 503);
    return _ok(meWithFriends());
  });
}

/// Copies a finalized request so it can be sent again (the retry recipe).
http.Request _copy(http.Request r) => http.Request(r.method, r.url)
  ..headers.addAll(r.headers)
  ..bodyBytes = r.bodyBytes;

void main() {
  test('default transport POSTs JSON with content-type and static headers',
      () async {
    final seen = <http.Request>[];
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      headers: const {'x-app': 'example'},
      httpClient: _recording(seen),
    );

    expect(await client.resolve((q) => q.me.name), 'Ada');
    final req = seen.single;
    expect(req.method, 'POST');
    expect(req.url, testEndpoint);
    expect(req.headers['content-type'], startsWith('application/json'));
    expect(req.headers['x-app'], 'example');
    expect(jsonDecode(req.body), containsPair('query', contains('me')));
  });

  test('a transport can add headers per request (auth / token refresh)',
      () async {
    final seen = <http.Request>[];
    final http.Client inner = _recording(seen);
    var token = 't1';
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      headers: const {'x-app': 'example'},
      transport: (request) async {
        request.headers['authorization'] = 'Bearer $token';
        return http.Response.fromStream(await inner.send(request));
      },
    );

    await client.resolve((q) => q.me.name);
    token = 't2';
    await client.resolve((q) => q.user(id: 'z')?.name); // not cached

    expect(seen.map((r) => r.headers['authorization']),
        ['Bearer t1', 'Bearer t2']);
    expect(seen.first.headers['x-app'], 'example',
        reason: 'static headers are applied before the transport runs');
  });

  test('a transport can retry (copying the request) and the scope never sees '
      'the failure', () async {
    final seen = <http.Request>[];
    final http.Client inner = _recording(seen, failFirst: 1);
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      transport: (request) async {
        for (var attempt = 0;; attempt++) {
          final res = await http.Response.fromStream(await inner.send(_copy(request)));
          if (res.statusCode < 500 || attempt == 2) return res;
        }
      },
    );

    expect(await client.resolve((q) => q.me.name), 'Ada');
    expect(seen, hasLength(2));
  });

  test('mutations go through the same transport', () async {
    final seen = <http.Request>[];
    final http.Client inner = _recording(seen);
    var calls = 0;
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      transport: (request) async {
        calls++;
        return http.Response.fromStream(await inner.send(request));
      },
    );

    await client.mutateWith(
      Mutation.root,
      (m) => m.rename(id: '1', name: 'Grace')?.name,
    );
    expect(calls, 1);
    expect(jsonDecode(seen.single.body), containsPair('query', startsWith('mutation')));
  });

  test('transport errors surface as the scope error', () async {
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      transport: (_) => throw StateError('offline'),
    );
    late QueryScope<Query> scope;
    scope = client.createScope(onChanged: () => scope.run((q) => q.me.name));
    scope.run((q) => q.me.name);
    await scope.whenSettled;

    expect(scope.error, isA<StateError>());
  });
}
