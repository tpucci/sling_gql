import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gql/ast.dart';
import 'package:gql/language.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_http_link/gql_http_link.dart';
import 'package:gql_link/gql_link.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_link/sling_gql_link.dart';
import 'package:sling_gql_test/sling_gql_test.dart' as mock;

import 'support/links.dart';
import 'support/test_schema.dart';

/// A client whose queries and mutations — and subscriptions — go through
/// [link].
SlingClient<Query> _client(
  Link link, {
  Map<String, String> headers = const {},
}) {
  final client = SlingClient<Query>(
    endpoint: testEndpoint,
    schema: slingSchema,
    headers: headers,
    transport: linkTransport(link),
    subscriptionTransport: linkSubscriptionTransport(link),
    warnOnWaterfall: false,
  );
  addTearDown(client.dispose);
  return client;
}

mock.MockGraphQLServer _server() => mock.MockGraphQLServer(
  query: {
    'me': ada(),
    'user': (args) => {
      ...ada(),
      'id': args['id'],
      'name': 'User ${args['id']}',
    },
  },
  mutation: {
    'rename': (args) => {...ada(), 'id': args['id'], 'name': args['name']},
  },
);

/// An `HttpLink` on a `MockClient` answering from [server]; [send] can fail
/// a request instead.
HttpLink _httpLink(
  mock.MockGraphQLServer server, {
  List<http.Request>? seen,
  FutureOr<http.Response?> Function(http.Request request)? send,
}) => HttpLink(
  testEndpoint.toString(),
  httpClient: MockClient((request) async {
    seen?.add(request);
    return await send?.call(request) ?? await server.handle(request);
  }),
);

/// A 503 with a GraphQL body: `HttpLink` throws a [ServerException] for it.
http.Response _unavailable() => http.Response(
  jsonEncode({
    'errors': [
      {'message': 'down for maintenance'},
    ],
  }),
  503,
);

/// Calls [transport] directly with a POST carrying [body].
Future<Map<String, Object?>> _call(
  Transport transport,
  Map<String, Object?> body,
) async {
  final response = await transport(
    http.Request('POST', testEndpoint)
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(body),
  );
  expect(response.statusCode, 200);
  expect(response.headers['content-type'], 'application/json; charset=utf-8');
  return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
}

/// The error a query scope settled with.
Future<Object?> _scopeError(SlingClient<Query> client) async {
  late QueryScope<Query> scope;
  scope = client.createScope(onChanged: () => scope.run((q) => q.me.name));
  addTearDown(scope.dispose);
  scope.run((q) => q.me.name);
  await scope.whenSettled;
  return scope.error;
}

void main() {
  group('linkTransport', () {
    test('a query reaches the link as a parsed DocumentNode with its '
        'variables', () async {
      final seen = <Request>[];
      final client = _client(serverLink(_server(), seen: seen));

      expect(await client.resolve((q) => q.user(id: '7')?.name), 'User 7');

      final request = seen.single;
      expect(request.operation.document, isA<DocumentNode>());
      expect(request.operation.getOperationType(), OperationType.query);
      expect(printNode(request.operation.document), contains('user(id: \$id)'));
      expect(request.variables, {'id': '7'});
      expect(
        request.operation.operationName,
        isNull,
        reason: 'sling_gql prints anonymous operations',
      );
    });

    test('operationName: the body\'s, else the named document\'s', () async {
      final seen = <Request>[];
      final transport = linkTransport(
        Link.function((request, [_]) {
          seen.add(request);
          return Stream.value(const Response(data: {}, response: {}));
        }),
      );

      await _call(transport, {
        'query': 'query Me { me { name } }',
        'variables': <String, Object?>{},
      });
      expect(seen.last.operation.operationName, 'Me');

      await _call(transport, {
        'query': 'query A { me { name } } query B { me { id } }',
        'operationName': 'B',
        'variables': {'x': 1},
      });
      expect(seen.last.operation.operationName, 'B');
      expect(seen.last.variables, {'x': 1});
    });

    test('SlingClient.headers reach the link as HttpLinkHeaders; content-type '
        'and accept are left to the terminating link', () async {
      final seen = <Request>[];
      final client = _client(
        serverLink(_server(), seen: seen),
        headers: const {'x-app': 'example'},
      );

      await client.resolve((q) => q.me.name);

      final headers = seen.single.context.entry<HttpLinkHeaders>()!.headers;
      expect(headers, {'x-app': 'example'});
    });

    test('an auth link adds the current token to every request', () async {
      final seen = <Request>[];
      var token = 't1';
      final client = _client(
        Link.from([authLink(() => token), serverLink(_server(), seen: seen)]),
        headers: const {'x-app': 'example'},
      );

      await client.resolve((q) => q.me.name);
      token = 't2';
      await client.resolve((q) => q.user(id: 'z')?.name); // not cached

      expect(seen.map(authorizationOf), ['Bearer t1', 'Bearer t2']);
      expect(
        seen.first.context.entry<HttpLinkHeaders>()!.headers['x-app'],
        'example',
        reason: 'the client\'s static headers are kept',
      );
    });

    test(
      'with an HttpLink the auth header lands on the HTTP request',
      () async {
        final wire = <http.Request>[];
        final client = _client(
          Link.from([authLink(() => 't1'), _httpLink(_server(), seen: wire)]),
          headers: const {'x-app': 'example'},
        );

        expect(await client.resolve((q) => q.me.name), 'Ada');

        final request = wire.single;
        expect(request.headers['authorization'], 'Bearer t1');
        expect(request.headers['x-app'], 'example');
        expect(request.headers['content-type'], startsWith('application/json'));
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['query'], contains('me'));
      },
    );

    test('a retry link hides a failed attempt from the scope', () async {
      final wire = <http.Request>[];
      var failures = 1;
      final client = _client(
        Link.from([
          retryLink(),
          _httpLink(
            _server(),
            seen: wire,
            send: (_) => failures-- > 0 ? _unavailable() : null,
          ),
        ]),
      );

      expect(await client.resolve((q) => q.me.name), 'Ada');
      expect(wire, hasLength(2));
    });

    test('a persisted-queries link sends the document once, then only its '
        'hash', () async {
      final server = _server();
      final wire = <PersistedQuery>[];
      final link = Link.from([
        persistedQueryLink(),
        persistedQueryServerLink(server, wire: wire),
      ]);

      expect(await _client(link).resolve((q) => q.me.name), 'Ada');
      expect(wire.map((p) => p.includeQuery), [false, true]);

      // A new client prints the same document: the server knows its hash.
      expect(await _client(link).resolve((q) => q.me.name), 'Ada');
      expect(wire.map((p) => p.includeQuery), [false, true, false]);
      expect(wire.map((p) => p.hash).toSet(), hasLength(1));
      expect(server.requests, hasLength(2));
    });

    test('mutations go through the same link', () async {
      final seen = <Request>[];
      final client = _client(serverLink(_server(), seen: seen));

      final name = await client.mutateWith(
        Mutation.root,
        (m) => m.rename(id: '1', name: 'Grace')?.name,
      );

      expect(name, 'Grace');
      expect(seen.single.operation.getOperationType(), OperationType.mutation);
      expect(seen.single.variables, {'id': '1', 'name': 'Grace'});
    });

    test('the result is UTF-8 JSON', () async {
      final server = _server()
        ..query['me'] = {...ada(), 'name': 'Ada 🚀 Lovelace'};
      final client = _client(serverLink(server));

      expect(await client.resolve((q) => q.me.name), 'Ada 🚀 Lovelace');
    });
  });

  group('response and error mapping', () {
    test('errors keep message, locations, path and extensions; top-level '
        'extensions are kept', () async {
      final transport = linkTransport(
        Link.function(
          (request, [_]) => Stream.value(
            const ResponseParser().parseResponse({
              'data': {'me': null},
              'errors': [
                {
                  'message': 'nope',
                  'locations': [
                    {'line': 1, 'column': 3},
                  ],
                  'path': ['me'],
                  'extensions': {'code': 'FORBIDDEN'},
                },
              ],
              'extensions': {'cost': 3},
            }),
          ),
        ),
      );

      final result = await _call(transport, {
        'query': '{ me { name } }',
        'variables': <String, Object?>{},
      });
      expect(result, {
        'data': {'me': null},
        'errors': [
          {
            'message': 'nope',
            'locations': [
              {'line': 1, 'column': 3},
            ],
            'path': ['me'],
            'extensions': {'code': 'FORBIDDEN'},
          },
        ],
        'extensions': {'cost': 3},
      });
    });

    test('partial errors are pruned and reported like over HTTP', () async {
      final server = _server()
        ..query['user'] = (args) => throw mock.GraphQLError(
          'hidden',
          extensions: {'code': 'FORBIDDEN'},
        );
      final client = _client(serverLink(server));
      late QueryScope<Query> scope;
      String? read(Query q) => '${q.me.name} ${q.user(id: '2')?.name}';
      scope = client.createScope(onChanged: () => scope.run(read));
      addTearDown(scope.dispose);
      scope.run(read);
      await scope.whenSettled;

      final error = scope.error as SlingException;
      expect(error.message, 'hidden');
      expect(error.graphqlErrors.single['extensions'], {'code': 'FORBIDDEN'});
      expect(scope.run(read), 'Ada null', reason: 'me resolved and is cached');
    });

    test('data: null with errors fails with the GraphQL message', () async {
      final client = _client(
        Link.function(
          (request, [_]) => Stream.value(
            const Response(
              errors: [GraphQLError(message: 'not authenticated')],
              response: {},
            ),
          ),
        ),
      );

      await expectLater(
        client.resolve((q) => q.me.name),
        throwsA(
          isA<SlingException>()
              .having((e) => e.message, 'message', 'not authenticated')
              .having((e) => e.graphqlErrors, 'graphqlErrors', [
                {'message': 'not authenticated'},
              ]),
        ),
      );
    });

    test('an HTTP error status is a SlingLinkException with the status code '
        'and the body\'s errors', () async {
      final client = _client(_httpLink(_server(), send: (_) => _unavailable()));

      final error = await _scopeError(client);
      expect(
        error,
        isA<SlingLinkException>()
            .having((e) => e.message, 'message', 'HTTP 503')
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.graphqlErrors, 'graphqlErrors', [
              {'message': 'down for maintenance'},
            ])
            .having(
              (e) => e.linkException,
              'linkException',
              isA<HttpLinkServerException>(),
            ),
      );
    });

    test('a failed connection is a SlingLinkException keeping its '
        'cause', () async {
      final client = _client(
        _httpLink(
          _server(),
          send: (_) => throw http.ClientException('offline'),
        ),
      );

      final error = await _scopeError(client);
      expect(
        error,
        isA<SlingLinkException>()
            .having((e) => e.message, 'message', contains('offline'))
            .having((e) => e.statusCode, 'statusCode', isNull)
            .having(
              (e) => e.linkException.originalException,
              'originalException',
              isA<http.ClientException>(),
            ),
      );
    });

    test('a response with neither data nor errors is an empty '
        'response', () async {
      final client = _client(
        _httpLink(_server(), send: (_) => http.Response('{}', 200)),
      );

      expect(
        await _scopeError(client),
        isA<SlingLinkException>().having(
          (e) => e.message,
          'message',
          'Empty response',
        ),
      );
    });

    test('other errors a link throws surface unchanged', () async {
      final client = _client(
        Link.function((request, [_]) => throw StateError('no route')),
      );

      expect(await _scopeError(client), isA<StateError>());
    });

    test('a link completing without a response is an error', () async {
      final client = _client(
        Link.function((request, [_]) => const Stream<Response>.empty()),
      );

      expect(
        await _scopeError(client),
        isA<SlingException>().having(
          (e) => e.message,
          'message',
          contains('without a response'),
        ),
      );
    });
  });

  group('linkSubscriptionTransport', () {
    test('events arrive through the link; cancelling closes its '
        'stream', () async {
      final renamed = StreamController<Map<String, Object?>>();
      final server = _server()..subscription['userRenamed'] = renamed.stream;
      final seen = <Request>[];
      final client = _client(serverLink(server, seen: seen));

      final sub = client.subscribeWith(
        Subscription.root,
        (s) => s.userRenamed(id: '1')?.name,
      );
      final received = <String?>[];
      final listening = sub.stream.listen(received.add);
      await Future<void>.delayed(Duration.zero);

      expect(server.openSubscriptions, 1);
      final request = seen.single;
      expect(request.operation.getOperationType(), OperationType.subscription);
      expect(request.variables, {'id': '1'});
      expect(
        request.context.entry<HttpLinkHeaders>(),
        isNull,
        reason: 'accept: text/event-stream is the SSE transport\'s',
      );

      renamed.add({...ada(), 'name': 'Grace'});
      await Future<void>.delayed(Duration.zero);
      expect(received, ['Grace']);
      expect(
        await client.resolve((q) => q.user(id: '1')?.name),
        'Grace',
        reason: 'the event was normalized into User:1',
      );

      await listening.cancel();
      expect(server.openSubscriptions, 0);
    });

    test('a LinkException on the stream is a SlingLinkException transport '
        'error', () async {
      final client = _client(
        Link.function(
          (request, [_]) => Stream.error(
            ServerException(originalException: StateError('dropped')),
          ),
        ),
      );

      final sub = client.subscribeWith(
        Subscription.root,
        (s) => s.userRenamed(id: '1')?.name,
      );
      final errors = <Object>[];
      final done = Completer<void>();
      sub.stream.listen(null, onError: errors.add, onDone: done.complete);
      await done.future;

      expect(errors.single, isA<SlingLinkException>());
      expect(
        (errors.single as SlingLinkException).message,
        contains('dropped'),
      );
    });
  });
}
