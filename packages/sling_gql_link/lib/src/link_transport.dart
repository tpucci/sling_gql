import 'dart:async';
import 'dart:convert';

import 'package:gql/ast.dart';
import 'package:gql/language.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:http/http.dart' as http;
import 'package:sling_gql/sling_gql.dart';

/// A [Transport] that runs every query and mutation through [link].
///
/// ```dart
/// SlingClient<Query>(
///   endpoint: uri,
///   schema: slingSchema,
///   transport: linkTransport(Link.from([authLink, retryLink, httpLink])),
/// );
/// ```
///
/// The printed document is parsed into the `Request`'s `DocumentNode`; its
/// `variables` and `operationName` (the body's, else the name of the
/// document's single operation — sling_gql's own are anonymous) are passed
/// through. The request's headers — [SlingClient.headers] — are put in the
/// context as [HttpLinkHeaders]; `content-type` and `accept` are left to the
/// terminating link.
///
/// The first `Response` of the link's stream is the result: `data`, `errors`
/// (message, locations, path, extensions) and `extensions` are encoded back
/// into a `200` JSON body, which the client handles like any other (partial
/// errors pruned, `data: null` a [SlingException]). A [LinkException] becomes
/// a [SlingLinkException] (`HTTP <code>` and its [SlingException.statusCode]
/// for a [ServerException] with an error status); anything else a link
/// throws surfaces unchanged.
Transport linkTransport(Link link) => (request) async {
  Response? first;
  try {
    await for (final response in link.request(_linkRequest(request))) {
      first = response;
      break;
    }
  } on LinkException catch (e, st) {
    Error.throwWithStackTrace(SlingLinkException(e), st);
  }
  if (first == null) {
    throw SlingException('The link completed without a response');
  }
  return http.Response.bytes(
    utf8.encode(jsonEncode(_executionResult(first))),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
    request: request,
  );
};

/// A [SubscriptionTransport] that opens every subscription through [link]:
/// each `Response` the link's stream emits is one event (encoded like
/// [linkTransport]'s results), the stream completing completes the
/// subscription, and a stream error is a transport failure (a [LinkException]
/// as a [SlingLinkException]) — which reconnects when the subscription has a
/// `retryAfter`. Cancelling the subscription cancels the link's stream.
///
/// The link has to be able to run subscriptions (a websocket link, usually
/// routed with `Link.split`); an `HttpLink` cannot.
SubscriptionTransport linkSubscriptionTransport(Link link) => (request) {
  Stream<Response> responses;
  try {
    responses = link.request(_linkRequest(request));
  } catch (e, st) {
    responses = Stream.error(e, st);
  }
  return responses.transform(
    StreamTransformer.fromHandlers(
      handleData: (response, sink) => sink.add(_executionResult(response)),
      handleError: (error, stackTrace, sink) => sink.addError(
        error is LinkException ? SlingLinkException(error) : error,
        stackTrace,
      ),
    ),
  );
};

/// A [LinkException] a link threw, as the [SlingException] the client and
/// the widgets report: `HTTP <code>` with [statusCode] for a
/// [ServerException] with an error status, else the GraphQL errors of its
/// parsed response, else the original exception's message.
class SlingLinkException extends SlingException {
  SlingLinkException(this.linkException)
    : super(
        _message(linkException),
        statusCode: switch (linkException) {
          ServerException(:final statusCode) => statusCode,
          _ => null,
        },
        graphqlErrors: switch (linkException) {
          ServerException(:final parsedResponse?) => [
            for (final e in parsedResponse.errors ?? const <GraphQLError>[])
              _errorJson(e),
          ],
          _ => const [],
        },
      );

  /// What the link threw; [LinkException.originalException] is the cause
  /// (the `http.ClientException` of a failed connection, a parse error, …).
  final LinkException linkException;

  static String _message(LinkException e) {
    if (e is ServerException) {
      final status = e.statusCode;
      if (status != null && status >= 300) return 'HTTP $status';
      final errors = e.parsedResponse?.errors ?? const [];
      if (errors.isNotEmpty) return errors.map((e) => e.message).join('\n');
      if (e.originalException == null) return 'Empty response';
    }
    return '${e.originalException ?? e}';
  }
}

/// Headers the terminating link sets itself: the client's
/// `application/json` / `text/event-stream` describe its own HTTP request,
/// not the link's.
const _linkOwnedHeaders = {'content-type', 'accept'};

Request _linkRequest(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, Object?>;
  final document = parseString(body['query'] as String);
  final headers = {
    for (final MapEntry(:key, :value) in request.headers.entries)
      if (!_linkOwnedHeaders.contains(key.toLowerCase())) key: value,
  };
  return Request(
    operation: Operation(
      document: document,
      operationName:
          body['operationName'] as String? ?? _operationName(document),
    ),
    variables: (body['variables'] as Map?)?.cast<String, dynamic>() ?? const {},
    context: headers.isEmpty
        ? const Context()
        : const Context().withEntry(HttpLinkHeaders(headers: headers)),
  );
}

String? _operationName(DocumentNode document) {
  final operations = document.definitions.whereType<OperationDefinitionNode>();
  return operations.length == 1 ? operations.single.name?.value : null;
}

Map<String, Object?> _executionResult(Response response) {
  final errors = response.errors ?? const [];
  final extensions =
      response.context.entry<ResponseExtensions>()?.extensions ??
      response.response['extensions'];
  return {
    'data': response.data,
    if (errors.isNotEmpty) 'errors': [for (final e in errors) _errorJson(e)],
    'extensions': ?extensions,
  };
}

Map<String, Object?> _errorJson(GraphQLError error) => {
  'message': error.message,
  if (error.locations case final locations?)
    'locations': [
      for (final l in locations) {'line': l.line, 'column': l.column},
    ],
  'path': ?error.path,
  'extensions': ?error.extensions,
};
