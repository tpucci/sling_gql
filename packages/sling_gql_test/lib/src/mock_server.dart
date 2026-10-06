import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'document.dart';

/// A field resolver: receives the field's arguments (variables already
/// substituted) and returns the value — a scalar, a `Map` with `__typename`,
/// a `List`, another [Resolver] for nested arguments, or a `Future` of one.
typedef Resolver = FutureOr<Object?> Function(Map<String, Object?> args);

/// Thrown from a [Resolver] to produce a GraphQL `errors[]` entry at that
/// field (the field resolves to `null`, siblings still resolve). Any other
/// exception propagates and fails the test.
///
/// [code] becomes `extensions.code` (`GraphQLError('who?', code:
/// 'UNAUTHENTICATED')`), merged over [extensions].
class GraphQLError implements Exception {
  GraphQLError(this.message, {String? code, Map<String, Object?>? extensions})
    : extensions = code == null ? extensions : {...?extensions, 'code': code};

  final String message;
  final Map<String, Object?>? extensions;

  /// `extensions.code`, when set.
  String? get code => extensions?['code'] as String?;

  @override
  String toString() => 'GraphQLError: $message';
}

/// How [MockGraphQLServer.failNext] fails a request instead of answering
/// it.
sealed class MockFailure {
  const MockFailure();

  /// An HTTP [statusCode] with [body] (the client sees a
  /// `SlingHttpException`; 5xx are retried by its default `RetryPolicy`).
  const factory MockFailure.status(int statusCode, {String body}) =
      _StatusFailure;

  /// A `200` with `data: null` and one GraphQL error carrying [code] as
  /// `extensions.code` (the client sees a `SlingGraphQLException`, or with
  /// `UNAUTHENTICATED` and a `SlingAuth`, a refresh).
  const factory MockFailure.graphQL(String message, {String? code}) =
      _GraphQLFailure;

  /// No response: the request throws an `http.ClientException` (the client
  /// sees a `SlingNetworkException`, `isNetworkUnreachable`).
  const factory MockFailure.network([String message]) = _NetworkFailure;
}

final class _StatusFailure extends MockFailure {
  const _StatusFailure(this.statusCode, {this.body = ''});
  final int statusCode;
  final String body;
}

final class _GraphQLFailure extends MockFailure {
  const _GraphQLFailure(this.message, {this.code});
  final String message;
  final String? code;
}

final class _NetworkFailure extends MockFailure {
  const _NetworkFailure([this.message = 'MockGraphQLServer: network down']);
  final String message;
}

/// One request the server answered.
class MockRequest {
  MockRequest(
    this.document,
    this.variables,
    this.operation, {
    this.headers = const {},
  });

  final String document;
  final Map<String, Object?> variables;
  final ParsedOperation operation;

  /// The HTTP headers it came with (`authorization`, …); empty for
  /// [MockGraphQLServer.execute] / `subscribe` called directly.
  final Map<String, String> headers;

  /// True when it was failed by [MockGraphQLServer.failNext] rather than
  /// answered.
  bool get failed => _failed;
  bool _failed = false;

  /// `query`, `mutation` or `subscription`.
  String get type => operation.type;

  /// Root field names selected (`me`, `launches`, …), aliases ignored.
  Set<String> get rootFields => {for (final f in operation.fields) f.name};

  /// True when [path] (`launches.nodes.name`, field names without aliases or
  /// arguments) is selected somewhere in the document. An inline fragment
  /// is one segment spelled `on Type`: `search.on Launch.name`.
  bool selects(String path) {
    var level = operation.fields;
    ParsedField? node;
    for (final part in path.split('.')) {
      final type = part.startsWith('on ') ? part.substring(3) : null;
      node = level.cast<ParsedField?>().firstWhere(
        (f) => type != null ? f!.typeCondition == type : f!.name == part,
        orElse: () => null,
      );
      if (node == null) return false;
      level = node.selection;
    }
    return true;
  }

  @override
  String toString() => 'MockRequest($type ${rootFields.join(', ')})';
}

/// An in-memory GraphQL server that answers the documents `SlingClient`
/// prints from plain Dart data — no aliases to compute, no regexes over the
/// document.
///
/// ```dart
/// final server = MockGraphQLServer(
///   query: {
///     'me': {'__typename': 'User', 'id': '1', 'name': 'Ada'},
///     'user': (args) => users[args['id']],           // resolver
///     'launches': (args) => page(first: args['first']),
///   },
///   mutation: {
///     'toggleFavorite': (args) { ...mutate state...; return launch; },
///   },
///   subscription: {
///     'launchStatusChanged': statusChanges.stream,   // a Stream of values
///     'userRenamed': (args) => renames(args['id']),   // or a resolver to one
///   },
/// );
/// final client = server.client(Query.root);
/// ```
///
/// Resolution walks the selection: for every selected field the value is
/// looked up on the parent `Map` (a [Resolver] value is called with the
/// field's arguments), lists are mapped, objects are projected to the
/// selected fields, and the result is written under the document's alias.
/// Objects must carry `__typename` when the client asks for it (it always
/// does) — that is what makes the normalized cache work.
///
/// [latency] delays every response (a `Future.delayed`; in `testWidgets` it
/// runs on the fake clock, so `pump(latency)` — or `pumpUntilSettled` —
/// lands it). Every request is appended to [requests]. [failNext] makes the
/// next requests fail with an HTTP status, a GraphQL error code or a
/// network error, for error-handling, retry and auth tests.
class MockGraphQLServer {
  MockGraphQLServer({
    Map<String, Object?> query = const {},
    Map<String, Object?> mutation = const {},
    Map<String, Object?> subscription = const {},
    this.latency = Duration.zero,
  }) : query = Map.of(query),
       mutation = Map.of(mutation),
       subscription = Map.of(subscription);

  /// Root query fields: values or [Resolver]s. Mutable, so a test can change
  /// what the server answers mid-way.
  final Map<String, Object?> query;

  /// Root mutation fields, same shape as [query].
  final Map<String, Object?> mutation;

  /// Root subscription fields: a `Stream` of values (each projected to the
  /// selection like a query result, so objects need `__typename`), or a
  /// [Resolver] returning one. A stream error ends the subscription with a
  /// transport error; the stream closing completes it.
  final Map<String, Object?> subscription;

  /// Subscriptions currently open (listened to and not yet cancelled or
  /// completed) — assert `0` after a `SubscriptionBuilder` unmounts.
  int get openSubscriptions => _openSubscriptions;
  int _openSubscriptions = 0;

  /// Delay applied to every response.
  Duration latency;

  /// Every request handled so far, oldest first.
  final List<MockRequest> requests = [];

  /// The last request handled.
  MockRequest get lastRequest => requests.last;

  final List<MockFailure> _failures = [];

  /// Fails the next [times] requests (queries, mutations and subscription
  /// connections, in arrival order) with [failure] — after [latency], and
  /// still recorded in [requests] (`MockRequest.failed`) — then answers
  /// normally again:
  ///
  /// ```dart
  /// server.failNext(const MockFailure.status(503), times: 2); // then OK
  /// server.failNext(const MockFailure.graphQL('expired', code: 'UNAUTHENTICATED'));
  /// server.failNext(const MockFailure.network());
  /// ```
  void failNext(MockFailure failure, {int times = 1}) {
    for (var i = 0; i < times; i++) {
      _failures.add(failure);
    }
  }

  /// Failures queued by [failNext] and not used yet.
  int get pendingFailures => _failures.length;

  MockFailure? _takeFailure() =>
      _failures.isEmpty ? null : _failures.removeAt(0);

  /// An `http.Client` that routes every POST to this server; pass it as
  /// `SlingClient(httpClient:)`.
  http.Client get httpClient => MockClient(handle);

  /// A [Transport] that routes every request to this server.
  Transport get transport => handle;

  /// A [SubscriptionTransport] that opens subscriptions on this server;
  /// pass it as `SlingClient(subscriptionTransport:)`.
  SubscriptionTransport get subscriptionTransport => (request) {
    final json = jsonDecode(request.body) as Map<String, Object?>;
    return subscribe(
      json['query'] as String,
      (json['variables'] as Map?)?.cast<String, Object?>() ?? const {},
      request.headers,
    );
  };

  /// A `SlingClient` wired to this server, disposed at the end of the
  /// current test (`addTearDown`). [endpoint] is nominal: nothing is sent
  /// over the network.
  SlingClient<Q> client<Q extends Accessor>(
    RootFactory<Q> rootFactory, {
    Uri? endpoint,
    Cache? cache,
    Map<String, String> headers = const {},
    void Function(PrintedOperation op)? onOperation,
    bool? warnOnWaterfall,
    void Function(WaterfallWarning warning)? onWaterfall,
    Duration? retryFailedAfter,
    ErrorPolicy errorPolicy = ErrorPolicy.none,
    Duration? timeout,
    RetryPolicy retry = const RetryPolicy(),
    SlingAuth? auth,
  }) {
    final c = SlingClient<Q>(
      endpoint: endpoint ?? Uri.parse('http://mock/graphql'),
      rootFactory: rootFactory,
      httpClient: httpClient,
      subscriptionTransport: subscriptionTransport,
      cache: cache,
      headers: headers,
      onOperation: onOperation,
      warnOnWaterfall: warnOnWaterfall,
      onWaterfall: onWaterfall,
      retryFailedAfter: retryFailedAfter,
      errorPolicy: errorPolicy,
      timeout: timeout,
      retry: retry,
      auth: auth,
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Handles one HTTP request (a JSON `{query, variables}` POST).
  Future<http.Response> handle(http.BaseRequest request) async {
    final body = switch (request) {
      http.Request r => r.body,
      _ => throw UnsupportedError('MockGraphQLServer: ${request.runtimeType}'),
    };
    final json = jsonDecode(body) as Map<String, Object?>;
    final document = json['query'] as String;
    final variables =
        (json['variables'] as Map?)?.cast<String, Object?>() ?? const {};
    final failure = _takeFailure();
    if (failure != null) {
      _record(document, variables, request.headers)._failed = true;
      if (latency > Duration.zero) await Future<void>.delayed(latency);
      return switch (failure) {
        _StatusFailure(:final statusCode, :final body) => http.Response(
          body,
          statusCode,
        ),
        _GraphQLFailure() => http.Response(
          jsonEncode(_failureResult(failure)),
          200,
          headers: const {'content-type': 'application/json'},
        ),
        _NetworkFailure(:final message) => throw http.ClientException(
          message,
          request.url,
        ),
      };
    }
    final result = await execute(document, variables, request.headers);
    return http.Response(
      jsonEncode(result),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }

  /// Executes [document] and returns the GraphQL response body
  /// (`{data, errors?}`).
  Future<Map<String, Object?>> execute(
    String document, [
    Map<String, Object?> variables = const {},
    Map<String, String> headers = const {},
  ]) async {
    final op = _record(document, variables, headers).operation;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final roots = switch (op.type) {
      'query' => query,
      'mutation' => mutation,
      'subscription' => throw UnsupportedError(
        'MockGraphQLServer.execute: subscriptions go through subscribe()',
      ),
      final t => throw UnsupportedError('MockGraphQLServer: $t operations'),
    };
    final errors = <Map<String, Object?>>[];
    final data = <String, Object?>{};
    for (final field in op.fields) {
      if (!roots.containsKey(field.name)) {
        throw StateError(
          'MockGraphQLServer: no ${op.type} field "${field.name}" — add it to '
          'MockGraphQLServer(${op.type}: {...})',
        );
      }
      data[field.alias] = await _resolve(roots[field.name], field, [
        field.alias,
      ], errors);
    }
    return {'data': data, if (errors.isNotEmpty) 'errors': errors};
  }

  /// Opens the subscription [document] and returns its execution results
  /// (`{data, errors?}`), one per value of the field's stream. Records the
  /// request like [execute].
  Stream<Map<String, Object?>> subscribe(
    String document, [
    Map<String, Object?> variables = const {},
    Map<String, String> headers = const {},
  ]) {
    final failure = _takeFailure();
    final request = _record(document, variables, headers);
    final op = request.operation;
    if (failure != null) {
      request._failed = true;
      return Stream.fromFuture(
        Future<void>.delayed(latency).then(
          (_) => switch (failure) {
            _StatusFailure(:final statusCode, :final body) =>
              throw SlingHttpException.fromBody(statusCode, body),
            _GraphQLFailure() => _failureResult(failure),
            _NetworkFailure(:final message) => throw SlingNetworkException(
              http.ClientException(message),
            ),
          },
        ),
      );
    }
    if (op.type != 'subscription') {
      throw UnsupportedError(
        'MockGraphQLServer.subscribe: a ${op.type} document; use execute()',
      );
    }
    if (op.fields.length != 1) {
      throw StateError(
        'MockGraphQLServer: a subscription selects exactly one root field, '
        'got ${op.fields.map((f) => f.name).join(', ')}',
      );
    }
    final field = op.fields.single;
    if (!subscription.containsKey(field.name)) {
      throw StateError(
        'MockGraphQLServer: no subscription field "${field.name}" — add it '
        'to MockGraphQLServer(subscription: {...})',
      );
    }
    late StreamController<Map<String, Object?>> out;
    StreamSubscription<Object?>? upstream;
    out = StreamController(
      onListen: () async {
        _openSubscriptions++;
        if (latency > Duration.zero) await Future<void>.delayed(latency);
        final Stream<Object?> source;
        try {
          final value = await _invoke(subscription[field.name], field.args);
          if (value is! Stream) {
            throw StateError(
              'MockGraphQLServer: subscription field "${field.name}" must '
              'be a Stream or a resolver returning one, got '
              '${value.runtimeType}',
            );
          }
          source = value;
        } catch (e, st) {
          out.addError(e, st);
          await out.close();
          return;
        }
        Future<Map<String, Object?>> project(Object? value) async {
          final errors = <Map<String, Object?>>[];
          Object? data;
          try {
            data = await _project(value, field, [field.alias], errors);
          } on GraphQLError catch (e) {
            errors.add({
              'message': e.message,
              'path': [field.alias],
              if (e.extensions != null) 'extensions': e.extensions,
            });
          }
          return {
            'data': {field.alias: data},
            if (errors.isNotEmpty) 'errors': errors,
          };
        }

        // asyncMap keeps results in order and holds `done` until the last
        // value was projected.
        upstream = source
            .asyncMap(project)
            .listen(
              (result) {
                if (!out.isClosed) out.add(result);
              },
              onError: (Object e, StackTrace st) {
                if (!out.isClosed) out.addError(e, st);
              },
              onDone: () {
                if (!out.isClosed) out.close();
              },
            );
      },
      onCancel: () {
        _openSubscriptions--;
        return upstream?.cancel();
      },
    );
    return out.stream;
  }

  MockRequest _record(
    String document,
    Map<String, Object?> variables,
    Map<String, String> headers,
  ) {
    final request = MockRequest(
      document,
      variables,
      parseOperation(document, variables),
      headers: Map.unmodifiable(headers),
    );
    requests.add(request);
    return request;
  }

  static Map<String, Object?> _failureResult(_GraphQLFailure failure) => {
    'data': null,
    'errors': [
      {
        'message': failure.message,
        if (failure.code != null) 'extensions': {'code': failure.code},
      },
    ],
  };

  Future<Object?> _resolve(
    Object? source,
    ParsedField field,
    List<Object> path,
    List<Map<String, Object?>> errors,
  ) async {
    Object? value;
    try {
      value = await _invoke(source, field.args);
    } on GraphQLError catch (e) {
      errors.add({
        'message': e.message,
        'path': path,
        if (e.extensions != null) 'extensions': e.extensions,
      });
      return null;
    }
    return _project(value, field, path, errors);
  }

  Future<Object?> _project(
    Object? value,
    ParsedField field,
    List<Object> path,
    List<Map<String, Object?>> errors,
  ) async {
    if (value == null) return null;
    if (value is List) {
      return [
        for (var i = 0; i < value.length; i++)
          await _project(value[i], field, [...path, i], errors),
      ];
    }
    // Scalars pass through (a `Map` here is a JSON-like custom scalar).
    if (field.selection.isEmpty) return _scalar(value);
    if (value is! Map) {
      throw StateError(
        'MockGraphQLServer: ${_pathString(path)} selects sub-fields '
        '(${field.selection.join(', ')}) but the data is ${value.runtimeType}',
      );
    }
    final out = <String, Object?>{};
    await _projectInto(
      value.cast<String, Object?>(),
      field.selection,
      path,
      errors,
      out,
    );
    return out;
  }

  /// Resolves [selection] on [object] into [out]. An inline fragment applies
  /// when the object's `__typename` equals its type condition (the mock has
  /// no schema, so `... on SomeInterface` never matches: sling_gql only
  /// prints fragments on concrete types).
  Future<void> _projectInto(
    Map<String, Object?> object,
    List<ParsedField> selection,
    List<Object> path,
    List<Map<String, Object?>> errors,
    Map<String, Object?> out,
  ) async {
    for (final sub in selection) {
      if (sub.isFragment) {
        if (object['__typename'] == sub.typeCondition) {
          await _projectInto(object, sub.selection, path, errors, out);
        }
        continue;
      }
      if (sub.name == '__typename') {
        final typename = object['__typename'];
        if (typename == null) {
          throw StateError(
            'MockGraphQLServer: the object at ${_pathString(path)} has no '
            "'__typename' — every object returned to sling_gql needs one",
          );
        }
        out[sub.alias] = typename;
        continue;
      }
      if (!object.containsKey(sub.name)) {
        throw StateError(
          'MockGraphQLServer: the object at ${_pathString(path)} '
          '(${object['__typename']}) has no field "${sub.name}"',
        );
      }
      out[sub.alias] = await _resolve(object[sub.name], sub, [
        ...path,
        sub.alias,
      ], errors);
    }
  }

  static FutureOr<Object?> _invoke(Object? source, Map<String, Object?> args) {
    if (source is Resolver) return source(args);
    if (source is FutureOr<Object?> Function()) return source();
    if (source is Function) {
      throw ArgumentError(
        'MockGraphQLServer: resolvers take one Map<String, Object?> argument '
        '(the field arguments) or none; got $source',
      );
    }
    return source;
  }

  static Object? _scalar(Object value) =>
      value is DateTime ? value.toUtc().toIso8601String() : value;

  static String _pathString(List<Object> path) => path.join('.');
}
