import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import 'app.dart';
import 'generated/schema.dart';
import 'list_rules.dart';
import 'network_log.dart';

/// The mock API in `../mock-api` (`npm start`). The iOS simulator shares the
/// host network, so `localhost` works as-is.
const endpoint = 'http://localhost:4000/graphql';

void main() {
  final log = NetworkLog();
  final client = SlingClient<Query>(
    endpoint: Uri.parse(endpoint),
    schema: slingSchema, // roots + key field, from the generator
    onOperation: log.add,
    listRules: listRules,
    // A dropped subscription (server restarted) reopens itself.
    subscriptionRetryAfter: const Duration(seconds: 3),
  );

  runApp(
    SlingScope<Query>(
      client: client,
      child: NetworkLogScope(log: log, child: const SlingApp()),
    ),
  );
}
