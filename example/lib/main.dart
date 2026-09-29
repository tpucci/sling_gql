import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:sling_gql/sling_gql.dart';

import 'app.dart';
import 'generated/schema.dart';
import 'list_rules.dart';
import 'mock_latency.dart';
import 'network_log.dart';

/// The mock API in `../mock-api` (`npm start`). The iOS simulator shares the
/// host network, so `localhost` works as-is.
const endpoint = 'http://localhost:4000/graphql';

void main() {
  final log = NetworkLog();
  final latency = MockLatencyController();
  final httpClient = http.Client();
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
    transport: latency.transport(httpClient),
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
