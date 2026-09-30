import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import 'app.dart';
import 'demos/demos.dart';
import 'generated/schema.dart';
import 'in_browser_api.dart';
import 'list_rules.dart';
import 'mock_latency.dart';
import 'network_log.dart';

/// The mock API in `../mock-api` (`npm start`). The iOS simulator shares the
/// host network, so `localhost` works as-is. On the web the same URL is
/// answered by the mock API bundled into the page (`in_browser_api.dart`).
const endpoint = 'http://localhost:4000/graphql';

void main() {
  // `?demo=<name>`: one concept demo instead of the app (the website embeds
  // them after each guide). Only the web build ever has a query string.
  final demo = demoFor(Uri.base.queryParameters['demo'] ?? '');
  if (demo != null) return runApp(DemoApp(demo: demo));

  final log = NetworkLog();
  final latency = MockLatencyController();
  final httpClient = mockApiHttpClient();
  final client = SlingClient<Query>(
    endpoint: Uri.parse(endpoint),
    schema: slingSchema, // roots + key field, from the generator
    // What the client builds by default from `slingSchema` (generated with
    // `--key-field id`), spelled out: an object with `__typename` and `id`
    // is stored once as `Launch:<id>` and referenced from every list and
    // field it appears in; objects without an id (`PageInfo`, `Stats`) stay
    // inline in their parent.
    cache: Cache(normalization: const Normalization(keyField: 'id')),
    // Requests (not subscriptions) carry the latency picked in the network
    // log screen; subscriptions share the same `http.Client`.
    httpClient: httpClient,
    // Timing, status and response of each request, for the network log.
    transport: log.transport(latency.transport(httpClient)),
    onOperation: log.add,
    listRules: listRules,
    // A dropped subscription (server restarted) reopens itself.
    subscriptionRetryAfter: const Duration(seconds: 3),
  );

  runApp(
    SlingScope<Query>(
      client: client,
      child: MockLatencyScope(
        latency: latency,
        child: NetworkLogScope(log: log, child: const SlingApp()),
      ),
    ),
  );
}
