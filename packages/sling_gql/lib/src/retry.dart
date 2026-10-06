import 'dart:math';

import 'errors.dart';

/// When and how often a failed request is sent again — with exponential
/// backoff and jitter — before its error is reported.
///
/// Queries use `SlingClient.retry` (by default `RetryPolicy()`: 3 attempts
/// in all, network errors, timeouts and 5xx). Mutations are not retried
/// unless the call asks for it (`mutateWith(retry:)`): a mutation that timed
/// out may have been applied. Subscriptions reconnect on their own
/// (`SlingClient.subscriptionRetryAfter`) and ignore this.
///
/// Retries happen inside one fetch: the scopes stay loading meanwhile and
/// only the final failure becomes their (sticky) error — from which
/// `SlingClient.retryFailedAfter`'s cooldown starts.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 300),
    this.maxDelay = const Duration(seconds: 10),
    this.multiplier = 2,
    this.jitter = 0.5,
    this.retryIf = RetryPolicy.isTransient,
  }) : assert(maxAttempts >= 1, 'maxAttempts counts the first attempt'),
       assert(jitter >= 0 && jitter <= 1, 'jitter is a fraction in [0, 1]');

  /// One attempt, no retry.
  static const none = RetryPolicy(maxAttempts: 1);

  /// Attempts in all, the first one included: `3` is one try and two
  /// retries.
  final int maxAttempts;

  /// Delay before the first retry.
  final Duration initialDelay;

  /// Upper bound of any delay, before jitter.
  final Duration maxDelay;

  /// Each retry waits [multiplier] times longer than the previous one.
  final double multiplier;

  /// Random fraction taken off each delay, so clients that failed together
  /// do not retry together: with `0.5`, a 600 ms delay is 300–600 ms. `0`
  /// makes delays exact.
  final double jitter;

  /// Whether [error] is worth another attempt. Sees the failures without
  /// `data` (a partial response is never retried). Default:
  /// [isTransient].
  final bool Function(SlingException error) retryIf;

  /// Network errors, timeouts and HTTP 5xx: the server was unreachable,
  /// slow or broken, and may not be on the next attempt.
  static bool isTransient(SlingException error) => switch (error) {
    SlingNetworkException() || SlingTimeoutException() => true,
    SlingHttpException(:final statusCode) => statusCode >= 500,
    _ => false,
  };

  /// The wait before retry number [retry] (`1` = the first retry):
  /// `initialDelay * multiplier^(retry - 1)`, capped at [maxDelay], minus up
  /// to [jitter] of it.
  Duration delayFor(int retry, [Random? random]) {
    final base =
        initialDelay.inMicroseconds * pow(multiplier, retry - 1).toDouble();
    final capped = min(base, maxDelay.inMicroseconds.toDouble());
    final factor = jitter == 0
        ? 1.0
        : 1 - jitter * (random ?? _random).nextDouble();
    return Duration(microseconds: (capped * factor).round());
  }

  static final Random _random = Random();
}
