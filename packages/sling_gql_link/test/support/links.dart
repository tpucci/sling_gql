import 'package:gql/ast.dart';
import 'package:gql/language.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:sling_gql_test/sling_gql_test.dart' show MockGraphQLServer;

/// A terminating link answering from [server] (no network): the document is
/// printed back from the `DocumentNode` the adapter parsed, so the server
/// sees what an `HttpLink` would send. Every request is appended to [seen].
Link serverLink(MockGraphQLServer server, {List<Request>? seen}) =>
    Link.function((request, [_]) {
      seen?.add(request);
      final document = printNode(request.operation.document);
      final variables = request.variables.cast<String, Object?>();
      if (request.operation.getOperationType() == OperationType.subscription) {
        return server
            .subscribe(document, variables)
            .map(const ResponseParser().parseResponse);
      }
      return Stream.fromFuture(
        server
            .execute(document, variables)
            .then(const ResponseParser().parseResponse),
      );
    });

/// The `authorization` header an auth link put in the request's context.
String? authorizationOf(Request request) =>
    request.context.entry<HttpLinkHeaders>()?.headers['authorization'];

/// The auth link every `gql_link` app writes: adds a bearer token to the
/// [HttpLinkHeaders] already in the context (the client's static headers).
Link authLink(String Function() token) => Link.function(
  (request, [forward]) => forward!(
    request.updateContextEntry<HttpLinkHeaders>(
      (headers) => HttpLinkHeaders(
        headers: {...?headers?.headers, 'authorization': 'Bearer ${token()}'},
      ),
    ),
  ),
);

/// Retries a request up to [attempts] times while the rest of the chain
/// fails with a [ServerException].
Link retryLink({int attempts = 3}) =>
    Link.function((request, [forward]) async* {
      for (var attempt = 1; ; attempt++) {
        try {
          // Not `yield*`: it would forward the error instead of throwing.
          await for (final response in forward!(request)) {
            yield response;
          }
          return;
        } on ServerException {
          if (attempt == attempts) rethrow;
        }
      }
    });

/// Automatic-persisted-queries-style link: sends only the document's hash
/// (in the [PersistedQuery] context entry); when the server does not know
/// it (`PersistedQueryNotFound`), sends it again with the document.
Link persistedQueryLink() => Link.function((request, [forward]) async* {
  final hash = printNode(request.operation.document).hashCode.toRadixString(16);
  final first = await forward!(
    request.withContextEntry(PersistedQuery(hash, includeQuery: false)),
  ).first;
  final notFound =
      first.errors?.any((e) => e.message == 'PersistedQueryNotFound') ?? false;
  if (!notFound) {
    yield first;
    return;
  }
  yield* forward(
    request.withContextEntry(PersistedQuery(hash, includeQuery: true)),
  );
});

/// What [persistedQueryLink] puts on the wire: the document's hash, and the
/// document itself only when [includeQuery].
class PersistedQuery extends ContextEntry {
  const PersistedQuery(this.hash, {required this.includeQuery});

  final String hash;
  final bool includeQuery;

  @override
  List<Object?> get fieldsForEquality => [hash, includeQuery];
}

/// A terminating link playing an APQ server: registers documents sent with
/// their hash, answers hash-only requests for known ones from [server], and
/// `PersistedQueryNotFound` for the others. [wire] logs what was "sent".
Link persistedQueryServerLink(
  MockGraphQLServer server, {
  required List<PersistedQuery> wire,
}) {
  final known = <String, DocumentNode>{};
  final answer = serverLink(server);
  return Link.function((request, [_]) {
    final persisted = request.context.entry<PersistedQuery>()!;
    wire.add(persisted);
    if (persisted.includeQuery) {
      known[persisted.hash] = request.operation.document;
    }
    final document = known[persisted.hash];
    if (document == null) {
      return Stream.value(
        const Response(
          errors: [GraphQLError(message: 'PersistedQueryNotFound')],
          response: {},
        ),
      );
    }
    return answer.request(
      Request(
        operation: Operation(document: document),
        variables: request.variables,
        context: request.context,
      ),
    );
  });
}
