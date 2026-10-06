import 'dart:async';
import 'dart:convert';

import 'package:gql/ast.dart';
import 'package:gql/language.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_http_link/gql_http_link.dart'
    show HttpLinkParserException, HttpLinkServerException;
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
/// errors pruned, `data: null` a [SlingGraphQLException]). A [LinkException]
/// becomes the [SlingException] it stands for ([slingExceptionFromLink]: a
/// failed connection a [SlingNetworkException], an error status a
/// [SlingHttpException], …); anything else a link throws is classified by
/// the client ([SlingException.from]).
Transport linkTransport(Link link) => (request) async {
  Response? first;
  try {
    await for (final response in link.request(_linkRequest(request))) {
      first = response;
      break;
    }
  } on LinkException catch (e, st) {
    Error.throwWithStackTrace(slingExceptionFromLink(e, st), st);
  }
  if (first == null) {
    throw SlingTransportException(
      StateError('The link completed without a response'),
      null,
      'The link completed without a response',
    );
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
/// as [slingExceptionFromLink] maps it) — which reconnects when the
/// subscription has a `retryAfter`. Cancelling the subscription cancels the link's stream.
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
        error is LinkException
            ? slingExceptionFromLink(error, stackTrace)
            : error,
        stackTrace,
      ),
    ),
  );
};

/// A [LinkException] a link threw, as the [SlingException] the client and
/// the widgets report:
///
/// - a [ServerException] with an error status (`>= 300`) — or an
///   [HttpLinkParserException] of one (`HttpLink` parses the body before it
///   checks the status, so a 502 HTML page or an empty 401 fails as a parse
///   error) — is a [SlingHttpException] with the body and its GraphQL
///   errors;
/// - a [ServerException] wrapping the HTTP client's failure (no response) is
///   that failure classified by [SlingException.from]: an
///   `http.ClientException` is a [SlingNetworkException];
/// - a [ServerException] with GraphQL errors and no data is a
///   [SlingGraphQLException] (`Empty response` without errors either);
/// - anything else (an unparsable 200, a context error) is a
///   [SlingTransportException] whose `cause` is the link exception.
SlingException slingExceptionFromLink(LinkException e, [StackTrace? st]) {
  final status = switch (e) {
    ServerException(:final statusCode) => statusCode,
    HttpLinkParserException(:final response) => response.statusCode,
    _ => null,
  };
  final errors = switch (e) {
    ServerException(:final parsedResponse?) => [
      for (final error in parsedResponse.errors ?? const <GraphQLError>[])
        SlingGraphQLError.fromJson(_errorJson(error)),
    ],
    _ => const <SlingGraphQLError>[],
  };
  if (status != null && status >= 300) {
    return switch (e) {
      HttpLinkServerException(:final response) => SlingHttpException(
        status,
        body: response.body,
        errors: errors,
      ),
      HttpLinkParserException(:final response) => SlingHttpException.fromBody(
        status,
        response.body,
      ),
      _ => SlingHttpException(status, errors: errors),
    };
  }
  if (e is ServerException) {
    final cause = e.originalException;
    if (e.parsedResponse == null && cause != null) {
      return SlingException.from(cause, e.originalStackTrace ?? st);
    }
    if (e.parsedResponse != null) return SlingGraphQLException(errors);
  }
  return SlingTransportException(e, st, '${e.originalException ?? e}');
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
