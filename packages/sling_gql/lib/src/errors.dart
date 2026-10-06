import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One entry of a GraphQL response's `errors`, as the server sent it.
class SlingGraphQLError {
  const SlingGraphQLError({
    required this.message,
    this.path,
    this.locations = const [],
    this.extensions,
  });

  /// Reads one `errors[]` entry; tolerates missing or mistyped members.
  factory SlingGraphQLError.fromJson(Map<String, Object?> json) =>
      SlingGraphQLError(
        message: '${json['message'] ?? 'Unknown GraphQL error'}',
        path: switch (json['path']) {
          final List<Object?> path => [for (final p in path) ?p],
          _ => null,
        },
        locations: switch (json['locations']) {
          final List<Object?> locations => [
            for (final l in locations)
              if (l case {'line': final int line, 'column': final int column})
                (line: line, column: column),
          ],
          _ => const [],
        },
        extensions: (json['extensions'] as Map?)?.cast<String, Object?>(),
      );

  /// Reads a response's `errors` member (`null` or not a list: none).
  static List<SlingGraphQLError> listFromJson(Object? errors) => [
    if (errors is List)
      for (final e in errors)
        if (e is Map) SlingGraphQLError.fromJson(e.cast<String, Object?>()),
  ];

  final String message;

  /// Where in the response the error happened: response keys (sling_gql's
  /// field aliases, `launch_3f2a…`, not field names) and list indices.
  /// `null` for request-level errors (validation, auth).
  final List<Object>? path;

  /// Positions in the printed document.
  final List<({int line, int column})> locations;

  /// The server's `extensions` (`{code: 'UNAUTHENTICATED', …}`).
  final Map<String, Object?>? extensions;

  /// `extensions.code` when it is a string — the conventional machine
  /// readable error code (`UNAUTHENTICATED`, `FORBIDDEN`,
  /// `BAD_USER_INPUT`, …).
  String? get code => switch (extensions?['code']) {
    final String code => code,
    _ => null,
  };

  Map<String, Object?> toJson() => {
    'message': message,
    if (locations.isNotEmpty)
      'locations': [
        for (final l in locations) {'line': l.line, 'column': l.column},
      ],
    'path': ?path,
    'extensions': ?extensions,
  };

  @override
  String toString() => code == null ? message : '$message [$code]';
}

/// Why a request failed. Sealed: a `switch` over it is exhaustive.
///
/// ```dart
/// final message = switch (state.error) {
///   null => null,
///   SlingNetworkException() => 'You are offline',
///   SlingTimeoutException() => 'The server is slow, try again',
///   SlingHttpException(:final statusCode) => 'Server error ($statusCode)',
///   SlingGraphQLException(:final errors) => errors.first.message,
///   SlingAuthException() => 'Please sign in again',
///   SlingCancelledException() || SlingTransportException() => 'Error',
/// };
/// ```
///
/// Whether the server saw the request: never for [SlingNetworkException]
/// and [SlingCancelledException] before sending; maybe for
/// [SlingTimeoutException]; yes for [SlingHttpException],
/// [SlingGraphQLException] and [SlingAuthException].
sealed class SlingException implements Exception {
  const SlingException(this.message);

  /// Classifies what a transport (or `http.Client`) threw:
  /// `http.ClientException` (connection refused, DNS, offline — what
  /// `IOClient` and `BrowserClient` throw) → [SlingNetworkException],
  /// `http.RequestAbortedException` → [SlingCancelledException],
  /// `TimeoutException` → [SlingTimeoutException], a [SlingException]
  /// unchanged, anything else → [SlingTransportException].
  factory SlingException.from(Object error, [StackTrace? stackTrace]) =>
      switch (error) {
        SlingException() => error,
        http.RequestAbortedException() => const SlingCancelledException(),
        http.ClientException() => SlingNetworkException(error, stackTrace),
        TimeoutException(:final duration) => SlingTimeoutException(duration),
        _ => SlingTransportException(error, stackTrace),
      };

  /// Human-readable summary: `HTTP 503`, the GraphQL messages joined, …
  final String message;

  /// The HTTP status of a [SlingHttpException]; `null` otherwise.
  int? get statusCode => null;

  /// The GraphQL errors carried: a [SlingGraphQLException]'s, or those in
  /// the body of a [SlingHttpException]; empty otherwise.
  List<SlingGraphQLError> get errors => const [];

  /// True when no response came back because the server could not be
  /// reached ([SlingNetworkException]) — the device is offline, DNS failed,
  /// the connection was refused or dropped. What an offline queue waits
  /// out; every other error means the server answered (or may have).
  bool get isNetworkUnreachable => false;

  String get _name;

  @override
  String toString() => '$_name: $message';
}

/// No response: the server could not be reached (offline, DNS, connection
/// refused or reset). [cause] is what the HTTP client threw, usually an
/// `http.ClientException`.
final class SlingNetworkException extends SlingException {
  SlingNetworkException(this.cause, [this.stackTrace])
    : super(switch (cause) {
        http.ClientException(:final message) => message,
        _ => '$cause',
      });

  final Object cause;
  final StackTrace? stackTrace;

  @override
  bool get isNetworkUnreachable => true;

  @override
  String get _name => 'SlingNetworkException';
}

/// No response within the request's timeout (`SlingClient.timeout`, or a
/// per-call `timeout:`); the request was aborted. The server may have
/// received — and, for a mutation, applied — it.
final class SlingTimeoutException extends SlingException {
  SlingTimeoutException([this.timeout])
    : super(
        timeout == null
            ? 'Timed out'
            : 'Timed out after ${timeout.inMilliseconds} ms',
      );

  /// The limit that elapsed, when known.
  final Duration? timeout;

  @override
  String get _name => 'SlingTimeoutException';
}

/// The server answered with an HTTP error status (`>= 400`). [body] is the
/// response body; when it is a GraphQL response, its `errors` are in
/// [errors] (yoga answers a validation failure with a 400 and errors).
final class SlingHttpException extends SlingException {
  SlingHttpException(this.statusCode, {this.body = '', this.errors = const []})
    : super('HTTP $statusCode');

  /// Builds one from a response, parsing GraphQL `errors` out of [body]
  /// when it is JSON.
  factory SlingHttpException.fromBody(int statusCode, String body) {
    List<SlingGraphQLError> errors = const [];
    try {
      final json = jsonDecode(body);
      if (json is Map) errors = SlingGraphQLError.listFromJson(json['errors']);
    } on FormatException {
      // Not JSON (an HTML error page, an empty body).
    }
    return SlingHttpException(statusCode, body: body, errors: errors);
  }

  @override
  final int statusCode;

  final String body;

  @override
  final List<SlingGraphQLError> errors;

  @override
  String get _name => 'SlingHttpException';
}

/// The server answered, with GraphQL `errors`. [isPartial]: `data` came too
/// (some fields resolved) — what `ErrorPolicy` decides about; otherwise the
/// response had no `data` at all and is an error under every policy.
final class SlingGraphQLException extends SlingException {
  SlingGraphQLException(
    this.errors, {
    this.isPartial = false,
    this.data,
    String? message,
  }) : super(
         message ??
             (errors.isEmpty
                 ? 'Empty response'
                 : errors.map((e) => e.message).join('\n')),
       );

  @override
  final List<SlingGraphQLError> errors;

  final bool isPartial;

  /// With `ErrorPolicy.all`, what `resolve` / `mutateWith`'s body computed
  /// from the cache once the partial response was written — the value the
  /// call would have returned. `null` otherwise.
  final Object? data;

  /// This error with [data] attached.
  SlingGraphQLException withData(Object? data) => SlingGraphQLException(
    errors,
    isPartial: isPartial,
    data: data,
    message: message,
  );

  @override
  String get _name => 'SlingGraphQLException';
}

/// Authentication failed for good: `SlingAuth.refresh` threw (or
/// `SlingAuth.headers` did), or the request was still unauthenticated after
/// the one replay with fresh credentials. [cause] is the refresh error or
/// the last unauthenticated response's [SlingException].
final class SlingAuthException extends SlingException {
  SlingAuthException(this.cause)
    : super(switch (cause) {
        SlingException(:final message) => 'Unauthenticated: $message',
        _ => 'Authentication failed: $cause',
      });

  final Object cause;

  @override
  String get _name => 'SlingAuthException';
}

/// The request was abandoned before it completed: every scope waiting on a
/// query batch was disposed, or the client was. Rarely seen by app code —
/// nobody is left to see it — except in `SlingRequest.error`.
final class SlingCancelledException extends SlingException {
  const SlingCancelledException() : super('Cancelled');

  @override
  String get _name => 'SlingCancelledException';
}

/// Anything else: a custom transport threw something sling_gql does not
/// know, or a response could not be decoded or cached. [cause] is the
/// original error.
final class SlingTransportException extends SlingException {
  SlingTransportException(this.cause, [this.stackTrace, String? message])
    : super(message ?? '$cause');

  final Object cause;
  final StackTrace? stackTrace;

  @override
  String get _name => 'SlingTransportException';
}

/// What a scope (or a `resolve` / `mutateWith` call) does with GraphQL
/// errors that come **with** `data` — a partial response. Transport, HTTP
/// and `data: null` failures are errors under every policy.
enum ErrorPolicy {
  /// The default. The `null`s the server put at errored paths are pruned
  /// (they are not real `null`s, so the fields stay missing) and the
  /// [SlingGraphQLException] is the scope's error, sticky until `refetch`.
  /// `resolve` / `mutateWith` throw it.
  none,

  /// Keep both: the response is cached as sent, `null`s at errored paths
  /// included, and the error is the scope's error too (sticky until
  /// `refetch`, though nothing is missing). `resolve` / `mutateWith` throw
  /// the [SlingGraphQLException] with [SlingGraphQLException.data] set to
  /// what the body computed.
  all,

  /// Drop the errors: the response is cached as sent, `null`s included,
  /// and the scope reports no error. `resolve` / `mutateWith` return
  /// normally.
  ignore,
}
