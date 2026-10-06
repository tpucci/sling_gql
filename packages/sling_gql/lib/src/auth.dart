import 'dart:async';

import 'errors.dart';

/// Authentication for every request the client sends — queries, mutations
/// and subscription connections:
///
/// ```dart
/// SlingClient<Query>(
///   endpoint: uri,
///   schema: slingSchema,
///   auth: SlingAuth(
///     headers: () async => {'authorization': 'Bearer ${await tokens.access()}'},
///     refresh: tokens.refresh, // throws when the session is over
///   ),
/// );
/// ```
///
/// [headers] runs before each attempt (retries and replays included), so it
/// always sends the current token. When a response is unauthenticated
/// ([isUnauthenticated]: HTTP 401 or a GraphQL `UNAUTHENTICATED` code by
/// default), the client calls [refresh] and replays the request once with
/// fresh [headers]. Refreshing is single-flight: requests failing together
/// share one [refresh] call, and a request that was sent with a token
/// already replaced by a finished refresh replays without refreshing again.
///
/// The request fails with a [SlingAuthException] when [refresh] (or
/// [headers]) throws, or when the replay is unauthenticated again — the
/// moment to sign the user out. A subscription connection refreshes and
/// reopens the same way; when that fails, the auth error is a stream error
/// and the subscription follows its usual `retryAfter` path.
class SlingAuth {
  const SlingAuth({
    required this.headers,
    required this.refresh,
    this.isUnauthenticated = SlingAuth.isUnauthenticatedError,
  });

  /// Headers to add to one request (`authorization`, …), over
  /// `SlingClient.headers`.
  final FutureOr<Map<String, String>> Function() headers;

  /// Gets new credentials, so that the next [headers] call returns them.
  /// Throw to give up (the session expired for good).
  final Future<void> Function() refresh;

  /// Whether [error] means the credentials were rejected. For a response
  /// with `data` and errors, it sees a partial [SlingGraphQLException].
  final bool Function(SlingException error) isUnauthenticated;

  /// HTTP 401, or any GraphQL error with `extensions.code ==
  /// 'UNAUTHENTICATED'` (Apollo Server's and graphql-yoga's convention).
  static bool isUnauthenticatedError(SlingException error) =>
      error.statusCode == 401 ||
      error.errors.any((e) => e.code == 'UNAUTHENTICATED');
}
