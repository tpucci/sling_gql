import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:sling_gql/sling_gql.dart';

/// Latency the mock API adds to each request, picked in the app so skeletons
/// can be made visible on demand (the network log screen has the picker).
enum MockLatency {
  /// No header: the server's `LATENCY_MS` (400 ms unless overridden) applies.
  serverDefault(null, 'Server'),
  off(0, 'Off'),
  halfSecond(500, '500 ms'),
  twoSeconds(2000, '2 s');

  const MockLatency(this.milliseconds, this.label);

  /// Value of the `x-mock-latency-ms` header, `null` to send none.
  final int? milliseconds;
  final String label;
}

/// The selected [MockLatency], applied to every request through [transport].
///
/// A per-request header rather than a setting on the server, so two clients
/// (two simulators, parallel tests) never see each other's latency.
class MockLatencyController extends ValueNotifier<MockLatency> {
  MockLatencyController() : super(MockLatency.serverDefault);

  static const header = 'x-mock-latency-ms';

  /// A [Transport] sending over [httpClient] with the latency header of the
  /// current [value]. Subscriptions do not go through it (they are one
  /// long-lived connection, not a round trip).
  Transport transport(http.Client httpClient) => (request) async {
    final ms = value.milliseconds;
    if (ms != null) request.headers[header] = '$ms';
    return http.Response.fromStream(await httpClient.send(request));
  };
}

class MockLatencyScope extends InheritedNotifier<MockLatencyController> {
  const MockLatencyScope({
    super.key,
    required MockLatencyController latency,
    required super.child,
  }) : super(notifier: latency);

  /// `null` when the app was built without one (e.g. in tests that do not
  /// need the picker).
  static MockLatencyController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MockLatencyScope>()?.notifier;
}

/// Segmented control over [MockLatency]; the next request uses the new value.
class MockLatencyPicker extends StatelessWidget {
  const MockLatencyPicker({super.key, required this.latency});
  final MockLatencyController latency;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<MockLatency>(
      key: const ValueKey('mock-latency'),
      groupValue: latency.value,
      onValueChanged: (v) {
        if (v != null) latency.value = v;
      },
      children: {
        for (final l in MockLatency.values)
          l: Text(l.label, style: const TextStyle(fontSize: 13)),
      },
    );
  }
}
