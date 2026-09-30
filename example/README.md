# sling_gql example

A Cupertino app (Launches, Search and Me tabs) for iOS and web, against the
mock API in `../mock-api`. The full tour is on the website:
[Example app](https://tpucci.github.io/sling_gql/tooling/example-app/); the
web build runs there: [Try it live](https://tpucci.github.io/sling_gql/guides/try-it/).

```sh
# iOS: against `npm start` on localhost:4000
cd ../mock-api && npm install && npm start   # http://localhost:4000/graphql
cd ../example && flutter run -d <ios-simulator>

# Web: the mock API is bundled into the page (web/mock-api.js, not committed)
cd ../mock-api && npm install && npm run build:browser
cd ../example && flutter run -d chrome
```

`lib/in_browser_api.dart` is the only platform switch: a plain `http.Client`
on iOS, one that answers from the in-page mock API on the web.

Worth a look:

- **Network log** (antenna icon, top right): every document the client sent,
  with the request count. Its screen also has the dev tools:
  - a **mock latency** picker (Default / Off / 500 ms / 2 s), sent per request
    as an `x-mock-latency-ms` header through `SlingClient(transport:)` — pick
    2 s to watch the skeletons (`lib/mock_latency.dart`);
  - a live **cache** summary: entities per type and `cache.snapshot` size,
    rebuilt on `cache.onChange` (`lib/widgets/cache_stats.dart`).
- **Prefetch**: tapping a row calls `LaunchScreen.open`, which starts the
  detail query with `client.resolve` before pushing the route; the screen joins
  that in-flight request (`lib/screens/launch_screen.dart`).
- **Normalization**: `lib/main.dart` passes
  `Cache(normalization: const Normalization(keyField: 'id'))` — the default
  for code generated with `--key-field id`, spelled out.

`lib/demos/` holds the small demos embedded in the website's guides (open one
with `?demo=batching`, `fetch-policies` or `optimistic` on the web build).

Tests (`test/app_test.dart`) run against the real mock API and assert request
counts: `melos run test:example --no-select` from the repo root starts the
server for the run.
