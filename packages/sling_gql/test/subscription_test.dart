import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// A client whose subscriptions are fed by hand through [events]; queries
/// answer [meWithFriends].
class _Harness {
  _Harness() {
    client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: mockGraphQL((_, _) => meWithFriends()),
      onOperation: operations.add,
      subscriptionTransport: (request) {
        requests.add(request);
        events = StreamController<Map<String, Object?>>(
          onCancel: () => cancelled++,
        );
        return events.stream;
      },
    );
    addTearDown(client.dispose);
  }

  late final SlingClient<Query> client;
  final operations = <PrintedOperation>[];
  final requests = <http.Request>[];
  late StreamController<Map<String, Object?>> events;
  int cancelled = 0;

  /// Alias the client printed for the subscription's single root field.
  String get alias =>
      RegExp(r'\{\s*(\w+)').firstMatch(operations.last.document)!.group(1)!;

  /// One `userChanged` event for [id] with [fields].
  void emit(Map<String, Object?> fields) => events.add({
    'data': {
      alias: {'__typename': 'User', ...fields},
    },
  });
}

void main() {
  test('subscribeWith records the selection and opens on listen', () async {
    final h = _Harness();
    final sub = h.client.subscribeWith(
      Subscription.root,
      (s) => s.userChanged?.name,
    );
    expect(sub.operation.document, startsWith('subscription'));
    expect(sub.operation.document, contains('userChanged'));
    expect(sub.operation.document, contains('name'));
    expect(h.requests, isEmpty, reason: 'nothing sent before listen');
    expect(h.operations, isEmpty, reason: 'onOperation fires when sent');
    expect(sub.isActive, isFalse);

    final received = <String?>[];
    sub.stream.listen(received.add);
    await Future<void>.delayed(Duration.zero);
    expect(h.requests, hasLength(1));
    expect(h.operations, hasLength(1));
    expect(h.requests.single.headers['accept'], 'text/event-stream');
    expect(h.requests.single.headers['content-type'], 'application/json');
    final body = jsonDecode(h.requests.single.body) as Map;
    expect(body['query'], h.operations.single.document);
    expect(sub.isActive, isTrue);
    expect(h.client.activeSubscriptions, 1);

    h.emit({'id': 'a', 'name': 'Bobby'});
    await Future<void>.delayed(Duration.zero);
    expect(received, ['Bobby']);
    expect(sub.eventCount, 1);
  });

  test('events are normalized into the cache and notify scopes', () async {
    final h = _Harness();
    final scope = h.client.createScope(onChanged: () {});
    var rebuilds = 0;
    final scope2 = h.client.createScope(onChanged: () => rebuilds++);
    scope.run((q) => q.me.friends().map((f) => f.name).toList());
    await scope.whenSettled;
    scope2.run((q) => q.me.friends().map((f) => f.name).toList());
    expect(scope2.run((q) => q.me.friends().map((f) => f.name).toList()), [
      'Bob',
      'Cy',
    ]);

    final sub = h.client.subscribeWith(
      Subscription.root,
      (s) => s.userChanged?.name,
    );
    sub.stream.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    h.emit({'id': 'a', 'name': 'Bobby'});
    await Future<void>.delayed(Duration.zero);
    expect(rebuilds, 1, reason: 'User:a.name is a dep of scope2');
    expect(scope2.run((q) => q.me.friends().map((f) => f.name).toList()), [
      'Bobby',
      'Cy',
    ]);
    expect(h.client.cache.entity('User:a')!['name'], 'Bobby');
    expect(
      h.client.cache.entity('ROOT_SUBSCRIPTION'),
      isNotNull,
      reason: 'the last event stays addressable while the subscription lives',
    );
  });

  test('the value is computed from the cache after each event', () async {
    final h = _Harness();
    final sub = h.client.subscribeWith(Subscription.root, (s) => s.userChanged);
    final names = <String?>[];
    User? last;
    // Accessors are live views of the cache: read them when they arrive.
    sub.stream.listen((u) {
      names.add(u?.name);
      last = u;
    });
    await Future<void>.delayed(Duration.zero);

    h.emit({'id': 'a', 'name': 'Bobby'});
    h.emit({'id': 'b', 'name': 'Cyrus'});
    await Future<void>.delayed(Duration.zero);
    expect(names, ['Bobby', 'Cyrus']);
    final received = [last];
    expect(received.last!.id, 'b');
    // Fields not selected read as null without fetching (the scope never
    // fetches).
    expect(received.last!.age, isNull);
    expect(h.client.isIdle, isTrue);
  });

  test('cancel closes the transport, the stream and drops the root', () async {
    final h = _Harness();
    final sub = h.client.subscribeWith(
      Subscription.root,
      (s) => s.userChanged?.name,
    );
    var done = false;
    sub.stream.listen((_) {}, onDone: () => done = true);
    await Future<void>.delayed(Duration.zero);
    h.emit({'id': 'a', 'name': 'Bobby'});
    await Future<void>.delayed(Duration.zero);
    expect(h.client.cache.entity('ROOT_SUBSCRIPTION'), isNotEmpty);

    await sub.cancel();
    expect(h.cancelled, 1);
    expect(sub.isActive, isFalse);
    expect(done, isTrue);
    expect(h.client.activeSubscriptions, 0);
    expect(
      h.client.cache.entity('ROOT_SUBSCRIPTION') ?? const {},
      isEmpty,
      reason: 'root fields would only pin the entities',
    );
    expect(
      h.client.cache.entity('User:a')!['name'],
      'Bobby',
      reason: 'the entity itself stays',
    );
    // Cancelling twice is harmless.
    await sub.cancel();
    expect(h.cancelled, 1);
  });

  test('cancelling the stream subscription closes too', () async {
    final h = _Harness();
    final sub = h.client.subscribeWith(
      Subscription.root,
      (s) => s.userChanged?.name,
    );
    final listener = sub.stream.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(h.client.activeSubscriptions, 1);
    await listener.cancel();
    expect(h.cancelled, 1);
    expect(h.client.activeSubscriptions, 0);
  });

  test('server completion ends the stream', () async {
    final h = _Harness();
    final sub = h.client.subscribeWith(
      Subscription.root,
      (s) => s.userChanged?.name,
    );
    var done = false;
    sub.stream.listen((_) {}, onDone: () => done = true);
    await Future<void>.delayed(Duration.zero);
    await h.events.close();
    await Future<void>.delayed(Duration.zero);
    expect(done, isTrue);
    expect(sub.isActive, isFalse);
    expect(h.client.activeSubscriptions, 0);
  });

  test('a transport error surfaces on the stream and ends it', () async {
    final h = _Harness();
    final sub = h.client.subscribeWith(
      Subscription.root,
      (s) => s.userChanged?.name,
    );
    Object? error;
    var done = false;
    sub.stream.listen(
      (_) {},
      onError: (Object e) => error = e,
      onDone: () => done = true,
    );
    await Future<void>.delayed(Duration.zero);
    h.events.addError(StateError('connection lost'));
    await Future<void>.delayed(Duration.zero);
    expect(error, isA<StateError>());
    expect(done, isTrue);
    expect(h.client.activeSubscriptions, 0);
  });

  test('partial errors: resolved fields are written, error is a stream error '
      'and the stream stays open', () async {
    final h = _Harness();
    final sub = h.client.subscribeWith(
      Subscription.root,
      (s) => (s.userChanged?.name, s.userChanged?.age),
    );
    final values = <(String?, int?)>[];
    final errors = <Object>[];
    sub.stream.listen(values.add, onError: errors.add);
    await Future<void>.delayed(Duration.zero);

    h.events.add({
      'data': {
        h.alias: {
          '__typename': 'User',
          'id': 'a',
          'name': 'Bobby',
          'age': null,
        },
      },
      'errors': [
        {
          'message': 'age unavailable',
          'path': [h.alias, 'age'],
        },
      ],
    });
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));
    expect((errors.single as SlingException).message, 'age unavailable');
    expect(values, [('Bobby', null)]);
    expect(
      h.client.cache.entity('User:a')!.containsKey('age'),
      isFalse,
      reason: 'the null at the errored path is pruned, not cached',
    );
    expect(sub.isActive, isTrue);

    h.emit({'id': 'a', 'name': 'Bobby', 'age': 40});
    await Future<void>.delayed(Duration.zero);
    expect(values.last, ('Bobby', 40));
  });

  test('an event without data is an error and the stream stays open', () async {
    final h = _Harness();
    final sub = h.client.subscribeWith(
      Subscription.root,
      (s) => s.userChanged?.name,
    );
    final errors = <Object>[];
    sub.stream.listen((_) {}, onError: errors.add);
    await Future<void>.delayed(Duration.zero);
    h.events.add({
      'errors': [
        {'message': 'boom'},
      ],
    });
    await Future<void>.delayed(Duration.zero);
    expect(errors.single, isA<SlingException>());
    expect(sub.isActive, isTrue);
  });

  test('arguments are sent as variables', () async {
    final h = _Harness();
    final sub = h.client.subscribeWith(
      Subscription.root,
      (s) => s.userRenamed(id: 'a')?.name,
    );
    sub.stream.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    final body = jsonDecode(h.requests.single.body) as Map;
    expect(body['variables'], {'id': 'a'});
    expect(body['query'], contains('userRenamed(id: \$id)'));
  });

  group('retryAfter', () {
    test('a dropped connection is reopened after the delay, stream stays '
        'open, isReconnecting meanwhile', () {
      fakeAsync((async) {
        final h = _Harness();
        final sub = h.client.subscribeWith(
          Subscription.root,
          (s) => s.userChanged?.name,
          retryAfter: const Duration(seconds: 2),
        );
        final errors = <Object>[];
        final names = <String?>[];
        var done = false;
        sub.stream.listen(
          names.add,
          onError: errors.add,
          onDone: () => done = true,
        );
        async.flushMicrotasks();
        expect(h.requests, hasLength(1));
        expect(sub.isConnected, isTrue);

        h.events.addError(StateError('server went away'));
        async.flushMicrotasks();
        expect(errors, hasLength(1), reason: 'the failure is reported');
        expect(done, isFalse, reason: 'but the stream stays open');
        expect(sub.isActive, isTrue);
        expect(sub.isConnected, isFalse);
        expect(sub.isReconnecting, isTrue);
        expect(h.client.activeSubscriptions, 1);

        async.elapse(const Duration(seconds: 2));
        expect(h.requests, hasLength(2), reason: 'reopened');
        expect(sub.isConnected, isTrue);
        expect(sub.isReconnecting, isFalse);
        h.emit({'id': 'a', 'name': 'Bobby'});
        async.flushMicrotasks();
        expect(names, ['Bobby']);

        // Fails again, twice: keeps retrying.
        h.events.addError(StateError('again'));
        async.elapse(const Duration(seconds: 2));
        h.events.addError(StateError('and again'));
        async.elapse(const Duration(seconds: 2));
        expect(h.requests, hasLength(4));
        expect(done, isFalse);

        sub.cancel();
        expect(sub.isActive, isFalse);
      });
    });

    test('reconnect() retries at once; cancel drops a pending retry', () {
      fakeAsync((async) {
        final h = _Harness();
        final sub = h.client.subscribeWith(
          Subscription.root,
          (s) => s.userChanged?.name,
          retryAfter: const Duration(minutes: 1),
        );
        sub.stream.listen((_) {}, onError: (_) {});
        async.flushMicrotasks();
        sub.reconnect(); // connected: no-op
        expect(h.requests, hasLength(1));

        h.events.addError(StateError('drop'));
        async.flushMicrotasks();
        expect(sub.isReconnecting, isTrue);
        sub.reconnect();
        expect(h.requests, hasLength(2));
        expect(sub.isReconnecting, isFalse);

        h.events.addError(StateError('drop'));
        async.flushMicrotasks();
        sub.cancel();
        async.elapse(const Duration(minutes: 2));
        expect(h.requests, hasLength(2), reason: 'no retry after cancel');
        expect(h.cancelled, 2);
      });
    });

    test('the client default applies; server complete never retries', () {
      fakeAsync((async) {
        final c = SlingClient<Query>(
          endpoint: testEndpoint,
          rootFactory: Query.root,
          subscriptionRetryAfter: const Duration(seconds: 1),
          subscriptionTransport: (_) => Stream.value({
            'data': {'userChanged': null},
          }),
        );
        addTearDown(c.dispose);
        final sub = c.subscribeWith(Subscription.root, (s) => s.userChanged);
        expect(sub.retryAfter, const Duration(seconds: 1));
        var done = false;
        sub.stream.listen((_) {}, onDone: () => done = true);
        async.flushMicrotasks();
        expect(done, isTrue, reason: 'completed by the server: final');
        async.elapse(const Duration(seconds: 5));
        expect(sub.isActive, isFalse);
      });
    });
  });

  test('client.dispose closes open subscriptions', () async {
    final h = _Harness();
    final sub = h.client.subscribeWith(
      Subscription.root,
      (s) => s.userChanged?.name,
    );
    sub.stream.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    h.client.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(h.cancelled, 1);
    expect(h.client.activeSubscriptions, 0);
  });

  group('sseSubscriptionTransport', () {
    /// A client answering every request with [body] as a streamed
    /// `text/event-stream`, one chunk per element (chunks may split lines).
    http.Client sse(List<String> chunks, {int status = 200}) =>
        MockClient.streaming((request, bodyStream) async {
          await bodyStream.drain<void>();
          return http.StreamedResponse(
            Stream.fromIterable(chunks.map(utf8.encode)),
            status,
            headers: const {'content-type': 'text/event-stream'},
          );
        });

    test(
      'decodes next events, ignores comments/pings, ends on complete',
      () async {
        final events = <Map<String, Object?>>[];
        var done = false;
        final request = http.Request('POST', testEndpoint);
        sseSubscriptionTransport(
          request,
          client: sse([
            ':keep-alive\n\n',
            'event: next\ndata: {"data":{"a":1}}\n\n',
            'event: ping\n\n',
            'event: next\ndata: {"data":',
            '{"a":2}}\n\nevent: complete\n\n',
            'event: next\ndata: {"data":{"a":3}}\n\n',
          ]),
        ).listen(events.add, onDone: () => done = true);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(events, [
          {
            'data': {'a': 1},
          },
          {
            'data': {'a': 2},
          },
        ]);
        expect(done, isTrue, reason: 'nothing after complete');
      },
    );

    test('unnamed data events and multi-line data', () async {
      final events = <Map<String, Object?>>[];
      sseSubscriptionTransport(
        http.Request('POST', testEndpoint),
        client: sse(['data: {"data":\ndata: {"a":1}}\n\n']),
      ).listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events, [
        {
          'data': {'a': 1},
        },
      ]);
    });

    test('an HTTP error status is a SlingException', () async {
      Object? error;
      var done = false;
      sseSubscriptionTransport(
        http.Request('POST', testEndpoint),
        client: sse(['nope'], status: 503),
      ).listen(
        (_) {},
        onError: (Object e) => error = e,
        onDone: () => done = true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(error, isA<SlingException>());
      expect((error as SlingException).statusCode, 503);
      expect(done, isTrue);
    });

    test('end to end through SlingClient', () async {
      final alias = <String>[];
      final client = SlingClient<Query>(
        endpoint: testEndpoint,
        rootFactory: Query.root,
        onOperation: (op) =>
            alias.add(RegExp(r'\{\s*(\w+)').firstMatch(op.document)!.group(1)!),
        httpClient: MockClient.streaming((request, bodyStream) async {
          await bodyStream.drain<void>();
          expect(request.headers['accept'], 'text/event-stream');
          final payload = jsonEncode({
            'data': {
              alias.single: {'__typename': 'User', 'id': 'a', 'name': 'Bobby'},
            },
          });
          return http.StreamedResponse(
            Stream.fromIterable([
              utf8.encode('event: next\ndata: $payload\n\n'),
              utf8.encode('event: complete\n\n'),
            ]),
            200,
          );
        }),
      );
      addTearDown(client.dispose);
      final names = await client
          .subscribeWith(Subscription.root, (s) => s.userChanged?.name)
          .stream
          .toList();
      expect(names, ['Bobby']);
      expect(client.cache.entity('User:a')!['name'], 'Bobby');
    });
  });
}
