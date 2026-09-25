import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import 'app.dart';
import 'generated/schema.dart';
import 'network_log.dart';

/// The mock API in `../mock-api` (`npm start`). The iOS simulator shares the
/// host network, so `localhost` works as-is.
const endpoint = 'http://localhost:4000/graphql';

void main() {
  final log = NetworkLog();
  final client = SlingClient<Query>(
    endpoint: Uri.parse(endpoint),
    rootFactory: Query.root,
    onOperation: log.add,
  );

  runApp(SlingScope<Query>(
    client: client,
    schema: slingSchema,
    child: NetworkLogScope(
      log: log,
      child: const SlingApp(),
    ),
  ));
}
