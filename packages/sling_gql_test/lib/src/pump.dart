import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';

/// Pumps frames until [client] has nothing in flight and the last frame
/// caused no new request — i.e. every `QueryBuilder` on screen has its data
/// (or its error) and has rebuilt with it.
///
/// Each round: pump a frame, advance the fake clock by [step] (so a
/// [MockGraphQLServer.latency] timer or a page transition completes), and,
/// if the client is still busy, let real async work run for up to [step]
/// (`tester.runAsync`) so that a real HTTP request — the example app against
/// its mock API — can land. Fails the test after [timeout].
///
/// Works with [MockGraphQLServer], a hand-rolled `MockClient`, or the real
/// network (`useRealNetwork()` first).
Future<void> pumpUntilSettled(
  WidgetTester tester,
  SlingClient<Accessor> client, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 50),
}) async {
  var elapsed = Duration.zero;
  while (true) {
    await tester.pump(step);
    if (client.isIdle) {
      // Let the rebuilds the last response triggered run; they may miss.
      await tester.pump();
      if (client.isIdle) return;
    }
    if (elapsed >= timeout) {
      fail(
        'pumpUntilSettled: the client was still busy after $timeout '
        '(a request never completed, or every frame causes a new one)',
      );
    }
    await tester.runAsync(
      () => client.whenIdle.timeout(step, onTimeout: () {}),
    );
    elapsed += step;
  }
}

/// `tester.pumpUntilSettled(client)` — see [pumpUntilSettled].
extension SlingWidgetTester on WidgetTester {
  Future<void> pumpUntilSettled(
    SlingClient<Accessor> client, {
    Duration timeout = const Duration(seconds: 10),
    Duration step = const Duration(milliseconds: 50),
  }) => _pumpUntilSettled(this, client, timeout: timeout, step: step);
}

const _pumpUntilSettled = pumpUntilSettled;

/// Lets widget tests reach a real server. `flutter test` installs an
/// `HttpOverrides` that fails every socket; this replaces it, for the whole
/// file (`setUpAll`), with one that also turns keep-alive off
/// (`HttpClient.idleTimeout = Duration.zero`): an idle connection's 15 s
/// timer would otherwise be reported as "still pending" at the end of every
/// `testWidgets`, which is why tests used to end with `client.dispose()`.
/// Call it at the top of `main()`.
///
/// Prefer [MockGraphQLServer] — it needs no server and no network; this is
/// for end-to-end tests against a running mock API.
void useRealNetwork() {
  setUpAll(() => HttpOverrides.global = _RealNetwork());
}

class _RealNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..idleTimeout = Duration.zero;
}

/// Registers `client.dispose()` as a tear-down of the current test and
/// returns the client, so it can wrap a constructor:
///
/// ```dart
/// client = disposeAfterTest(SlingClient<Query>(endpoint: ..., rootFactory: Query.root));
/// ```
///
/// Clients from [MockGraphQLServer.client] are already registered. Tear-downs
/// run *after* `testWidgets` checks for pending timers, so this does not
/// replace [useRealNetwork] for tests over a real connection.
T disposeAfterTest<T extends SlingClient<Accessor>>(T client) {
  addTearDown(client.dispose);
  return client;
}
