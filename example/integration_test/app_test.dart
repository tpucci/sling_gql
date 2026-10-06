import 'package:integration_test/integration_test.dart';
import 'package:sling_gql_example/main.dart' show endpoint;
import 'package:sling_gql_test/sling_gql_test.dart';

import '../test/app_test.dart';

/// `test/app_test.dart`'s flows on a device or emulator, against the mock
/// API on the host (`10.0.2.2` from the Android emulator, `localhost` from
/// the iOS simulator — the app's own [endpoint]):
///
/// ```sh
/// SEQUENCE_MS=2000 node ../scripts/with-mock-api.mjs flutter test integration_test -d emulator-5554
/// ```
///
/// (A launch sequence step of 2 s: with the default 700 ms of the tests, the
/// emulator's round trips outlast `IN_FLIGHT` and the mission-control flow
/// never sees it.) `--dart-define=SLING_API=<url>` points them at another server, e.g. a
/// private one on port 4002 (`with-mock-api.mjs --port 4002`,
/// `SLING_API=http://10.0.2.2:4002/graphql`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  useRealNetwork();
  const api = String.fromEnvironment('SLING_API');
  appFlows(Uri.parse(api.isEmpty ? endpoint : api));
}
