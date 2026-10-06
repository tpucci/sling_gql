# sling_gql example

A Cupertino app (Launches, Search and Me tabs) for iOS, Android and web, against the
mock API in `../mock-api`. The full tour is on the website:
[Example app](https://tpucci.github.io/sling_gql/tooling/example-app/); the
web build runs there: [Try it live](https://tpucci.github.io/sling_gql/guides/try-it/).

```sh
# iOS: against `npm start` on localhost:4000
cd ../mock-api && npm install && npm start   # http://localhost:4000/graphql
cd ../example && flutter run -d <ios-simulator>

# Android emulator: the same server, reached at 10.0.2.2:4000
cd ../example && flutter run -d emulator-5554

# Web: the mock API is bundled into the page (web/mock-api.js, not committed)
cd ../mock-api && npm install && npm run build:browser
cd ../example && flutter run -d chrome
```

`lib/in_browser_api.dart` is the only platform switch for requests: a plain
`http.Client` on iOS and Android (to `localhost` from the iOS simulator,
`10.0.2.2` — the host — from the Android emulator; the Android manifest allows
cleartext HTTP to those two hosts only), one that answers from the in-page mock
API on the web. `lib/persisted_cache.dart` keeps the cache in SQLite
(`sling_gql_sqflite`) on iOS and Android, in memory on the web.

Worth a look:

- **Network log** (**N requests**, top right): one line per request (fields,
  time, duration, size; tap for the document and the response), the open
  subscriptions, and the dev tools:
  - a **mock latency** picker (Default / Off / 500 ms / 2 s), sent per request
    as an `x-mock-latency-ms` header through `SlingClient(transport:)` — pick
    2 s to watch the skeletons (`lib/mock_latency.dart`);
  - a live **cache** summary: objects per type and `cache.snapshot` size,
    rebuilt on `cache.onChange` (`lib/widgets/cache_stats.dart`).
- **Prefetch**: tapping a row calls `LaunchScreen.open`, which starts the
  detail query with `client.resolve` before pushing the route; the screen joins
  that in-flight request (`lib/screens/launch_screen.dart`).
- **Normalization**: `lib/main.dart` passes
  `Cache(normalization: const Normalization(keyField: 'id'))` — the default
  for code generated with `--key-field id`, spelled out.

`lib/demos/` holds the small demos embedded in the website's guides (open one
with `?demo=<name>` on the web build; the names are in `lib/demos/demos.dart`).

Tests (`test/app_test.dart`) run against the real mock API and assert request
counts: `melos run test:example --no-select` from the repo root starts the
server for the run. `melos run test:example:graphql-http --no-select` runs
them (and `test/graphql_server_test.dart`) against the same schema and
resolvers behind graphql-http + graphql-sse instead of yoga.

The same flows run on a device or emulator as an integration test (the app's
own endpoint: `10.0.2.2` on the Android emulator). A slower launch sequence
gives the emulator time to show each status of the mission-control flow:

```sh
SEQUENCE_MS=2000 node ../scripts/with-mock-api.mjs flutter test integration_test -d emulator-5554
```
