import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sling_gql/internal.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// A transport that never answers on its own: [answer] lands the pending
/// requests; [aborted] counts the ones whose abort trigger fired.
class _Hanging {
  final List<(http.Request, Completer<http.Response>)> pending = [];
  int aborted = 0;

  Future<http.Response> send(http.Request request) {
    final response = Completer<http.Response>();
    pending.add((request, response));
    if (request case http.Abortable(:final abortTrigger?)) {
      abortTrigger.then((_) => aborted++);
    }
    return response.future;
  }

  void answer() {
    for (final (_, response) in pending) {
      response.complete(
        http.Response(jsonEncode({'data': meWithFriends()}), 200),
      );
    }
    pending.clear();
  }

  SlingClient<Query> client({Duration? timeout}) => SlingClient<Query>(
    endpoint: testEndpoint,
    schema: slingSchema,
    transport: send,
    timeout: timeout,
    retry: RetryPolicy.none,
  );
}

Future<void> _ticks() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('timeout', () {
    test('the client default aborts a hanging query with a '
        'SlingTimeoutException', () async {
      final transport = _Hanging();
      final client = transport.client(
        timeout: const Duration(milliseconds: 20),
      );
      final scope = client.createScope(onChanged: () {});
      scope.run((q) => q.me.name);
      await scope.whenSettled;
      expect(
        scope.error,
        isA<SlingTimeoutException>().having(
          (e) => e.timeout,
          'timeout',
          const Duration(milliseconds: 20),
        ),
      );
      await _ticks();
      expect(transport.aborted, 1, reason: 'the request was aborted');
      transport.answer(); // too late: dropped
      await _ticks();
      expect(client.cache.read('query', ['me', 'name']), missing);
    });

    test('a scope timeout overrides the client default', () async {
      final transport = _Hanging();
      final client = transport.client();
      final scope = client.createScope(
        onChanged: () {},
        timeout: const Duration(milliseconds: 10),
      );
      expect(scope.timeout, const Duration(milliseconds: 10));
      scope.run((q) => q.me.name);
      await scope.whenSettled;
      expect(scope.error, isA<SlingTimeoutException>());
    });

    test('a batch waits for the longest timeout of its scopes', () async {
      final transport = _Hanging();
      final client = transport.client();
      final short = client.createScope(
        onChanged: () {},
        timeout: const Duration(milliseconds: 5),
      );
      final patient = client.createScope(onChanged: () {});
      short.run((q) => q.me.name);
      patient.run((q) => q.me.age);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(short.isLoading, isTrue, reason: 'patient has no timeout');
      transport.answer();
      await short.whenSettled;
      expect(short.error, isNull);
      expect(patient.error, isNull);
    });

    test('resolve(timeout:) and mutateWith(timeout:)', () async {
      final client = _Hanging().client();
      const limit = Duration(milliseconds: 10);
      await expectLater(
        client.resolve((q) => q.me.name, timeout: limit),
        throwsA(isA<SlingTimeoutException>()),
      );
      await expectLater(
        client.mutateWith(
          Mutation.root,
          (m) => m.rename(id: '1', name: 'x')?.name,
          timeout: limit,
        ),
        throwsA(isA<SlingTimeoutException>()),
      );
      expect(client.isIdle, isTrue);
    });
  });

  group('cancellation', () {
    test('disposing the only waiting scope aborts the request and drops its '
        'response', () async {
      final transport = _Hanging();
      final client = transport.client();
      final records = <SlingRequest>[];
      client.requests.listen(records.add);
      var changes = 0;
      final scope = client.createScope(onChanged: () => changes++);
      scope.run((q) => q.me.name);
      await _ticks();
      expect(transport.pending, hasLength(1));
      expect(client.isIdle, isFalse);

      scope.dispose();
      await _ticks();
      expect(transport.aborted, 1);
      expect(client.isIdle, isTrue);
      expect(records.last.error, isA<SlingCancelledException>());

      transport.answer();
      await _ticks();
      expect(client.cache.read('query', ['me', 'name']), missing);
      expect(changes, 0, reason: 'a disposed scope is never notified');
    });

    test('a batch another live scope waits for is not cancelled', () async {
      final transport = _Hanging();
      final client = transport.client();
      final gone = client.createScope(onChanged: () {});
      final stays = client.createScope(onChanged: () {});
      gone.run((q) => q.me.name);
      stays.run((q) => q.me.name);
      await _ticks();
      gone.dispose();
      await _ticks();
      expect(transport.aborted, 0);
      transport.answer();
      await stays.whenSettled;
      expect(client.cache.read('query', ['me', 'name']), 'Ada');
    });

    test('nothing is sent when every scope of a batch is disposed before the '
        'flush', () async {
      final transport = _Hanging();
      final client = transport.client();
      final scope = client.createScope(onChanged: () {});
      scope.run((q) => q.me.name);
      scope.dispose();
      await _ticks();
      expect(transport.pending, isEmpty);
      expect(client.isIdle, isTrue);
    });

    test('client.dispose aborts the batch in flight', () async {
      final transport = _Hanging();
      final client = transport.client();
      client.createScope(onChanged: () {}).run((q) => q.me.name);
      await _ticks();
      client.dispose();
      await _ticks();
      expect(transport.aborted, 1);
    });
  });
}
