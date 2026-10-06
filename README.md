# sling_gql

A GraphQL client for Flutter where the widget is the query.
Inspired by [GQty](https://gqty.dev). Docs: https://tpucci.github.io/sling_gql/ ·
[Versioning policy](https://tpucci.github.io/sling_gql/internals/versioning/) ·
[Upgrading to 1.0](https://tpucci.github.io/sling_gql/guides/upgrading-to-1-0/) ·
[Security](SECURITY.md)

> Read a field, get the query. No operation documents, no fragments, no
> `builder`-per-query boilerplate: widgets read typed accessors during
> `build()`, sling_gql records what was read, batches everything read in the
> frame into one GraphQL document, fetches it, fills a cache, and rebuilds only
> the widgets that read the affected data.

```dart
QueryBuilder<Query>(
  builder: (context, query, state) {
    final launch = query.latestLaunch;
    return ListTile(
      title: Text(launch?.name ?? '…'),
      subtitle: Text(launch?.rocket?.name ?? '…'),
    );
  },
)
```

…generates, fetches and caches:

```graphql
query {
  latestLaunch {
    __typename
    name
    rocket {
      __typename
      name
    }
  }
}
```

## Status

| Feature | State |
| --- | --- |
| Typed accessors generated from introspection | ✅ `packages/sling_gql_gen` |
| Selection recording during `build()` | ✅ incl. accessors handed to child widgets and lazily built sliver rows |
| Per-frame batching across widgets | ✅ one HTTP request per frame (flush at end of frame) |
| Arguments → variables, aliased per argument set | ✅ |
| Skeleton state (`null` scalars, 1-element lists) before data arrives | ✅ |
| Normalized cache (`__typename:id` entities, `launch(id:)` served from the list's entity) | ✅ per-field rebuild notifications, `evict`, `gc`, JSON snapshot + `onChange` |
| Partial responses merging into one cache tree | ✅ per entity |
| Optimistic writes (`launch.favorite = true`) | ✅ setters on scalar fields; journaled + rolled back when a mutation fails |
| Mutations (`client.mutate((m) => m.toggleFavorite(launchId: id)?.favorite)`, `MutationBuilder`) | ✅ response normalized into the same entities → every widget showing the launch rebuilds |
| Offline mutations (`client.mutate(..., offline: true)`) | ✅ queued while the server is unreachable (optimistic writes kept, `state.isQueued`), replayed in order; persisted with `persistence.mutationQueue`, rolled back from the stored log after a restart |
| `prepare` to avoid waterfalls on conditional reads | ✅ |
| `refetch`, sticky errors (no retry loops), partial `errors[]` handling | ✅ typed, sealed `SlingException`s; `errorPolicy` none / all / ignore |
| Auth, retry, timeouts (`SlingClient(auth:, retry:, timeout:)`) | ✅ single-flight token refresh on 401 / `UNAUTHENTICATED` (SSE too), backoff + jitter for queries, aborted requests when the widget is gone |
| Cursor pagination (`RelayStylePagination`: pages merged into one cached list) and type policies (`keyArgs`, custom `merge`) | ✅ `PaginatedQueryBuilder`, example |
| Test helpers (`MockGraphQLServer`, `pumpUntilSettled`) | ✅ `packages/sling_gql_test` |
| Subscriptions (`client.subscribe((s) => s.launchStatusChanged?..status)`, `SubscriptionBuilder`) | ✅ GraphQL over SSE by default, `subscriptionTransport:` to swap; events normalized into the same entities |
| List rules (`ListRule`: "`launches(filter:)` holds a launch iff its status matches") | ✅ cached lists gain/lose entities on mutations, subscription events and setters; query responses only remove |
| Fetch policies (`cacheAndNetwork`, `networkOnly`), `maxAge` stale-while-revalidate | ✅ per widget or client-wide, `state.isStale`, soft `revalidate()` |
| Persistence (`SqflitePersistence.open(path, schema: slingSchema)`) | ✅ `packages/sling_gql_sqflite`: SQLite write-behind copy saved as `changesSince` deltas, bounded by age and entity count, migrated along `slingSchema.fields` on a new `slingSchema.hash`, corruption-safe, optional row codec (encryption) |
| Unions / interfaces (`hit.asLaunch`, `hit.when(launch: …, rocket: …)`) | ✅ inline fragments, every branch recorded on the skeleton; example Search tab |
| `flutter_hooks` (`useSlingQuery`, `useSlingMutation`, `useSlingSubscription`) | ✅ `packages/sling_gql_hooks`, same scopes as the builders |

## Layout

```
packages/sling_gql/      runtime: Accessor, Selection, Cache, SlingClient, QueryBuilder
packages/sling_gql_gen/  CLI: introspection JSON → Dart accessor classes
packages/sling_gql_test/ test helpers: in-memory GraphQL server, pumpUntilSettled
packages/sling_gql_hooks/ flutter_hooks adapter: useSlingQuery, useSlingMutation, useSlingSubscription
packages/sling_gql_link/ gql_link adapter: a Link chain as the client's transport
packages/sling_gql_sqflite/ sqflite adapter: the cache persisted in SQLite
mock-api/                graphql-yoga server, space theme, ~180 launches, cursor + offset pagination
example/                 Flutter app (iOS + Android + web) talking to the mock API
```

## Setup

```sh
asdf install                                   # flutter + nodejs from .tool-versions
dart pub global activate melos
melos bootstrap                                # pub workspace: one `pub get` for all packages

melos run test                                 # runtime + generator + example (yoga, then graphql-http; servers auto-started) + website
melos run test:runtime                         # or one gate at a time

cd mock-api && npm install && npm start        # http://localhost:4000/graphql (GraphiQL), for `flutter run`
cd example && flutter run -d <ios-simulator>    # or an Android emulator (10.0.2.2:4000)

# Web: the mock API runs in the page, no server needed
cd mock-api && npm run build:browser && cd ../example && flutter run -d chrome
melos run build:web                            # release build for the website (Try it page)
```

Or just [try it live](https://tpucci.github.io/sling_gql/guides/try-it/) on the website.

The packages are on pub.dev:
[`sling_gql`](https://pub.dev/packages/sling_gql) (runtime),
[`sling_gql_gen`](https://pub.dev/packages/sling_gql_gen) (generator),
[`sling_gql_test`](https://pub.dev/packages/sling_gql_test) (test helpers),
[`sling_gql_hooks`](https://pub.dev/packages/sling_gql_hooks) (flutter_hooks adapter),
[`sling_gql_link`](https://pub.dev/packages/sling_gql_link) (gql_link adapter) and
[`sling_gql_sqflite`](https://pub.dev/packages/sling_gql_sqflite) (SQLite persistence).

The example is a two-tab Cupertino app (dark space theme): a **Launches** tab
with cursor pagination and a launch-status segment filter, and a **Me** tab
showing the viewer profile and their favourite launches. It prints every
GraphQL document it sends to the console and shows them in-app (**N requests**,
top right). Server latency is `LATENCY_MS` (default 400 ms) so skeletons are
visible; the log screen also has a latency picker (an `x-mock-latency-ms`
header per request) and a live view of the cache.

Regenerate the example's schema classes after editing `mock-api/schema.graphql`:

```sh
cd mock-api && npm run introspect              # → example/graphql/schema.json
cd .. && melos run generate                    # → example/lib/generated/schema.dart
```

## How it works

1. **Generated accessors instead of JS `Proxy`.** Each GraphQL type becomes a
   Dart class extending `Accessor`, a cheap `(selection node, cache path)`
   view. Every getter calls `scalar<T>('field')` / `object('field', Type.new)`
   / `list(...)`, which (a) records the field on the current selection tree,
   then (b) reads `cache[path + field]`.
2. **`QueryBuilder` = `useQuery()`.** It owns a `QueryScope`, runs the builder
   inside it, and if any read was a cache miss, asks the client to flush.
3. **Batching.** The client merges all pending selections into a single tree
   and flushes once — at the end of the frame for widgets (so lazily built
   sliver rows are included), on a microtask for imperative `resolve()` — as
   one `query { … }` document. Fields with arguments get a deterministic alias
   (`launches_<hash>`) that doubles as their cache key.
4. **Rebuild.** The response is normalized into entities (`Launch:launch-181`)
   and merged; scopes that read any of the touched `entity.field` keys are told
   to `setState`.

## Lessons learned

- **Waterfalls are the main footgun**, exactly as in GQty. A field read only
  inside an `if` on fetched data, or only inside an `onPressed`, costs a second
  round trip. The example's widget test caught two of these. Remedies: read
  fields into locals unconditionally at the top of `build`, and use `prepare`.
- **Frame timing matters.** Flutter's first build runs outside a frame and
  slivers build children during layout; a microtask flush split the first
  screen into two requests. Flushing in a post-frame callback fixed it.
- **Normalization needs the generator's help.** Dart cannot intercept reads,
  so knowing which types carry an `id` (and which root fields are by-id
  lookups) is a codegen fact; the runtime just consumes `keyed`/`lookup`
  flags. With them, opening a detail screen after the list fetches only the
  fields the list did not have.
- **Codegen is a fine `Proxy` replacement**: 414 lines of generated Dart for
  40 types, fully static and tree-shakeable; sound null safety makes the
  "maybe not fetched yet" state explicit instead of lying like TS types do.

See `AGENTS.md` for the design decisions and `TODO.md` for the numbered
backlog (roadmap, DX findings, performance follow-ups).
