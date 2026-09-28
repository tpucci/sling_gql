import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// A client whose responses are held back until [release] is called.
class _Gated {
  _Gated({Map<String, Object?> Function()? data}) {
    client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      transport: (request) async {
        await gate.future;
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final document = body['query'] as String;
        final vars = (body['variables'] as Map).cast<String, Object?>();
        final alias =
            RegExp(r'(rename_\w+):').firstMatch(document)?.group(1) ?? '';
        final payload = document.startsWith('mutation')
            ? {
                alias: {
                  '__typename': 'User',
                  'id': vars['id'],
                  'name': vars['name'],
                },
              }
            : (data ?? meWithFriends)();
        return http.Response(jsonEncode({'data': payload}), 200);
      },
    );
    addTearDown(client.dispose);
  }

  final gate = Completer<void>();
  late final SlingClient<Query> client;

  void release() => gate.complete();
}

void main() {
  test('idle client: isIdle is true and whenIdle completes at once', () async {
    final g = _Gated();
    expect(g.client.isIdle, isTrue);
    await g.client.whenIdle;
  });

  test(
    'a query keeps the client busy from the first miss to the response',
    () async {
      final g = _Gated();
      final scope = g.client.createScope(onChanged: () {});
      scope.run((q) => q.me.name);
      expect(g.client.isIdle, isFalse, reason: 'flush scheduled');
      var idle = false;
      final whenIdle = g.client.whenIdle.then((_) => idle = true);

      await Future<void>.delayed(Duration.zero); // flush → request in flight
      expect(g.client.isIdle, isFalse, reason: 'request in flight');
      expect(idle, isFalse);

      g.release();
      await whenIdle;
      expect(g.client.isIdle, isTrue);
      expect(scope.run((q) => q.me.name), 'Ada');
      scope.dispose();
    },
  );

  test('a mutation keeps the client busy until its response lands', () async {
    final g = _Gated();
    final done = g.client.mutateWith(
      Mutation.root,
      (m) => m.rename(id: '1', name: 'Grace')?.name,
    );
    expect(g.client.isIdle, isFalse);
    var idle = false;
    final whenIdle = g.client.whenIdle.then((_) => idle = true);
    await Future<void>.delayed(Duration.zero);
    expect(idle, isFalse);

    g.release();
    expect(await done, 'Grace');
    await whenIdle;
    expect(g.client.isIdle, isTrue);
  });

  test('a failed request also settles the client', () async {
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      transport: (request) async => http.Response('boom', 500),
    );
    addTearDown(client.dispose);
    final scope = client.createScope(onChanged: () {});
    scope.run((q) => q.me.name);
    expect(client.isIdle, isFalse);
    await client.whenIdle;
    expect(client.isIdle, isTrue);
    expect(scope.error, isA<SlingException>());
    scope.dispose();
  });
}
