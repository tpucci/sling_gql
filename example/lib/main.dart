import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import 'app.dart';
import 'demos/demos.dart';
import 'demos/views.dart';
import 'generated/schema.dart';
import 'in_browser_api.dart';
import 'list_rules.dart';
import 'mock_latency.dart';
import 'network_log.dart';
import 'persisted_cache.dart';

/// The mock API in `../mock-api` (`npm start`). The iOS simulator shares the
/// host network, so `localhost` works as-is. On the web the same URL is
/// answered by the mock API bundled into the page (`in_browser_api.dart`).
const endpoint = 'http://localhost:4000/graphql';

Future<void> main() async {
  // Embedded in a docs page (multi-view): one view per demo, one engine
  // for all of them.
  if (isEmbedded) return runWidget(const DemoViews());
  // `?demo=<name>`: one concept demo instead of the app, in a page of its
  // own. Only the web build ever has a query string.
  final demo = demoFor(Uri.base.queryParameters['demo'] ?? '');
  if (demo != null) return runApp(DemoApp(demo: demo));

  // iOS: the previous run's cache, from SQLite (`sling_gql_sqflite`), loaded
  // before the client exists so the first frame paints it. The web keeps it
  // in memory. See `persisted_cache.dart`.
  WidgetsFlutterBinding.ensureInitialized();
  final cache = await openCache();

  final log = NetworkLog();
  final latency = MockLatencyController();
  final httpClient = mockApiHttpClient();
  final client = SlingClient<Query>(
    endpoint: Uri.parse(endpoint),
    schema: slingSchema, // roots + key field, from the generator
    // Normalized on `slingSchema.keyField` (`id`): an object with
    // `__typename` and `id` is stored once as `Launch:<id>` and referenced
    // from every list and field it appears in; objects without an id
    // (`PageInfo`, `Stats`) stay inline in their parent.
    cache: cache,
    // Restored data has no fetch time: shown at once, then revalidated in
    // the background (iOS; `null` on the web, where nothing is restored).
    maxAge: restoredCacheMaxAge,
    // Requests (not subscriptions) carry the latency picked in the network
    // log screen; subscriptions share the same `http.Client`.
    httpClient: httpClient,
    // The response body of each request, for the network log.
    transport: log.transport(latency.transport(httpClient)),
    // One line per operation in the console: timing, size, fields, and the
    // widgets that asked for it (`client.requests` feeds the network log
    // and the request overlay).
    logRequests: true,
    listRules: listRules,
    // A dropped subscription (server restarted) reopens itself.
    subscriptionRetryAfter: const Duration(seconds: 3),
  );
  log.attach(client);

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
