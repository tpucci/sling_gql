import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// Tokens `t0`, `t1`, … — [refresh] moves to the next one; the server
/// accepts [valid] only.
class _Tokens {
  int current = 0;
  int refreshes = 0;
  Object? refreshError;
  Completer<void>? refreshGate;

  String get token => 't$current';

  late final auth = SlingAuth(
    headers: () async => {'authorization': 'Bearer $token'},
    refresh: () async {
      refreshes++;
      await refreshGate?.future;
      if (refreshError != null) throw refreshError!;
      current++;
    },
  );
}

/// Accepts `Bearer <valid>`; answers anything else with [rejection].
class _Server {
  _Server({this.valid = 't1', this.graphqlRejection = false});

  String valid;
  final bool graphqlRejection;
  final List<String?> seen = [];

  /// Holds the responses to rejected requests until completed.
  Completer<void>? rejectGate;

  /// With [holdEach], each rejected request waits for its own completer.
  bool holdEach = false;
  final List<Completer<void>> held = [];

  late final http.Client httpClient = MockClient((request) async {
    final authorization = request.headers['authorization'];
    seen.add(authorization);
    final query = (jsonDecode(request.body) as Map)['query'] as String;
    if (authorization != 'Bearer $valid') {
      await rejectGate?.future;
      if (holdEach) {
        final hold = Completer<void>();
        held.add(hold);
        await hold.future;
      }
      if (!graphqlRejection) return http.Response('unauthorized', 401);
      return http.Response(
        jsonEncode({
          'data': null,
          'errors': [
            {
              'message': 'not signed in',
              'extensions': {'code': 'UNAUTHENTICATED'},
            },
          ],
        }),
        200,
      );
    }
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

  SlingClient<Query> client(_Tokens tokens) => SlingClient<Query>(
    endpoint: testEndpoint,
    schema: slingSchema,
    httpClient: httpClient,
    headers: const {'x-app': 'test'},
    auth: tokens.auth,
    retry: RetryPolicy.none,
  );
}

void main() {
  test('headers are added to every request', () async {
    final tokens = _Tokens()..current = 1;
    final server = _Server();
    final client = server.client(tokens);
    expect(await client.resolve((q) => q.me.name), 'Ada');
    expect(server.seen, ['Bearer t1']);
    expect(tokens.refreshes, 0);
  });

  test('a 401 refreshes once and replays with the new token', () async {
    final tokens = _Tokens();
    final server = _Server();
    final client = server.client(tokens);
    final records = <SlingRequest>[];
    client.requests.listen(records.add);
    expect(await client.resolve((q) => q.me.name), 'Ada');
    expect(server.seen, ['Bearer t0', 'Bearer t1']);
    expect(tokens.refreshes, 1);
    expect(records.last.attempts, 2);
  });

  test('a GraphQL UNAUTHENTICATED code refreshes too', () async {
    final tokens = _Tokens();
    final server = _Server(graphqlRejection: true);
    final client = server.client(tokens);
    expect(await client.resolve((q) => q.me.name), 'Ada');
    expect(tokens.refreshes, 1);
  });

  test('concurrent rejections share one refresh', () async {
    final tokens = _Tokens();
    final server = _Server()..rejectGate = Completer<void>();
    final client = server.client(tokens);
    final query = client.resolve((q) => q.me.name);
    final mutation = client.mutateWith(
      Mutation.root,
      (m) => m.rename(id: '1', name: 'Zed')?.name,
    );
    await Future<void>.delayed(Duration.zero);
    server.rejectGate!.complete();
    expect(await query, 'Ada');
    expect(await mutation, 'Zed');
    expect(tokens.refreshes, 1);
    expect(server.seen.where((h) => h == 'Bearer t1'), hasLength(2));
  });

  test('a request rejected after a refresh finished replays without '
      'refreshing again', () async {
    final tokens = _Tokens();
    final server = _Server()..holdEach = true;
    final client = server.client(tokens);
    // Both go out with t0.
    final first = client.resolve((q) => q.me.name);
    final second = client.mutateWith(
      Mutation.root,
      (m) => m.rename(id: '1', name: 'Zed')?.name,
    );
    await Future<void>.delayed(Duration.zero);
    expect(server.held, hasLength(2));
    server.holdEach = false;
    // One rejection lands: refresh, replay with t1.
    server.held[0].complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(tokens.refreshes, 1);
    expect(server.seen.last, 'Bearer t1');
    // The other one lands only now, rejected for its old t0.
    server.held[1].complete();
    expect(await first, 'Ada');
    expect(await second, 'Zed');
    expect(tokens.refreshes, 1);
    expect(server.seen, ['Bearer t0', 'Bearer t0', 'Bearer t1', 'Bearer t1']);
  });

  test('a failing refresh is a SlingAuthException', () async {
    final tokens = _Tokens()..refreshError = StateError('session over');
    final server = _Server();
    final client = server.client(tokens);
    final scope = client.createScope(onChanged: () {});
    scope.run((q) => q.me.name);
    await scope.whenSettled;
    expect(
      scope.error,
      isA<SlingAuthException>().having(
        (e) => e.cause,
        'cause',
        isA<StateError>(),
      ),
    );
    expect(server.seen, hasLength(1));
  });

  test('still rejected after the refresh: SlingAuthException with the last '
      'response as cause', () async {
    final tokens = _Tokens();
    final server = _Server(valid: 'never');
    final client = server.client(tokens);
    await expectLater(
      client.mutateWith(
        Mutation.root,
        (m) => m.rename(id: '1', name: 'Zed')?.name,
      ),
      throwsA(
        isA<SlingAuthException>().having(
          (e) => e.cause,
          'cause',
          isA<SlingHttpException>().having((e) => e.statusCode, 'status', 401),
        ),
      ),
    );
    expect(tokens.refreshes, 1);
    expect(server.seen, ['Bearer t0', 'Bearer t1']);
  });

  test('a throwing headers callback is a SlingAuthException', () async {
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      httpClient: _Server().httpClient,
      auth: SlingAuth(
        headers: () => throw StateError('no keychain'),
        refresh: () async {},
      ),
    );
    await expectLater(
      client.resolve((q) => q.me.name),
      throwsA(isA<SlingAuthException>()),
    );
  });

  test('isUnauthenticated is configurable', () async {
    var refreshed = 0;
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      retry: RetryPolicy.none,
      httpClient: MockClient((request) async {
        if (refreshed == 0) return http.Response('expired', 419);
        return http.Response(jsonEncode({'data': meWithFriends()}), 200);
      }),
      auth: SlingAuth(
        headers: () => const {},
        refresh: () async => refreshed++,
        isUnauthenticated: (e) => e.statusCode == 419,
      ),
    );
    expect(await client.resolve((q) => q.me.name), 'Ada');
    expect(refreshed, 1);
  });

  group('subscriptions (SSE)', () {
    /// Answers `Bearer t1` with one event, anything else with a 401.
    http.Client sse(List<String?> seen) =>
        MockClient.streaming((request, body) async {
          await body.drain<void>();
          seen.add(request.headers['authorization']);
          if (request.headers['authorization'] != 'Bearer t1') {
            return http.StreamedResponse(
              Stream.value(utf8.encode('unauthorized')),
              401,
            );
          }
          final payload = jsonEncode({
            'data': {
              'userChanged': {'__typename': 'User', 'id': 'a', 'name': 'Bob'},
            },
          });
          return http.StreamedResponse(
            Stream.value(utf8.encode('event: next\ndata: $payload\n\n')),
            200,
            headers: const {'content-type': 'text/event-stream'},
          );
        });

    test('a 401 on connect refreshes and reopens with the new token', () async {
      final tokens = _Tokens();
      final seen = <String?>[];
      final client = SlingClient<Query>(
        endpoint: testEndpoint,
        schema: slingSchema,
        httpClient: sse(seen),
        auth: tokens.auth,
      );
      final values = <String?>[];
      final errors = <Object>[];
      final sub = client.subscribeWith(
        Subscription.root,
        (s) => s.userChanged?.name,
      );
      sub.stream.listen(values.add, onError: errors.add);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(seen, ['Bearer t0', 'Bearer t1']);
      expect(tokens.refreshes, 1);
      expect(values, ['Bob']);
      expect(errors, isEmpty);
      await sub.cancel();
    });

    test('a failing refresh is a SlingAuthException stream error', () async {
      final tokens = _Tokens()..refreshError = StateError('session over');
      final client = SlingClient<Query>(
        endpoint: testEndpoint,
        schema: slingSchema,
        httpClient: sse([]),
        auth: tokens.auth,
      );
      final errors = <Object>[];
      var done = false;
      client
          .subscribeWith(Subscription.root, (s) => s.userChanged?.name)
          .stream
          .listen((_) {}, onError: errors.add, onDone: () => done = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(errors.single, isA<SlingAuthException>());
      expect(done, isTrue, reason: 'no retryAfter: the stream ends');
    });
  });
}
