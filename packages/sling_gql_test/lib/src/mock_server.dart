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
class GraphQLError implements Exception {
  GraphQLError(this.message, {this.extensions});

  final String message;
  final Map<String, Object?>? extensions;

  @override
  String toString() => 'GraphQLError: $message';
}

/// One request the server answered.
class MockRequest {
  MockRequest(this.document, this.variables, this.operation);

  final String document;
  final Map<String, Object?> variables;
  final ParsedOperation operation;

  /// `query`, `mutation` or `subscription`.
  String get type => operation.type;

  /// Root field names selected (`me`, `launches`, …), aliases ignored.
  Set<String> get rootFields => {for (final f in operation.fields) f.name};

  /// True when [path] (`launches.nodes.name`, field names without aliases or
  /// arguments) is selected somewhere in the document.
  bool selects(String path) {
    var level = operation.fields;
    ParsedField? node;
    for (final part in path.split('.')) {
      node = level.cast<ParsedField?>().firstWhere(
        (f) => f!.name == part,
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
/// lands it). Every request is appended to [requests].
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
    final result = await execute(
      json['query'] as String,
      (json['variables'] as Map?)?.cast<String, Object?>() ?? const {},
    );
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
  ]) async {
    final op = parseOperation(document, variables);
    requests.add(MockRequest(document, variables, op));
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
  ]) {
    final op = parseOperation(document, variables);
    requests.add(MockRequest(document, variables, op));
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
    final object = value.cast<String, Object?>();
    final out = <String, Object?>{};
    for (final sub in field.selection) {
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
    return out;
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
