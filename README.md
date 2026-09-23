# sling_gql

**Proof of concept** — a GraphQL client for Flutter where the widget is the query.
Inspired by [GQty](https://gqty.dev). Docs: https://tpucci.github.io/sling_gql/

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
| Partial responses merging into one cache tree | ✅ |
| Optimistic writes (`launch.mission_name = 'x'`) | ✅ setters on scalar fields |
| `prepare` to avoid waterfalls on conditional reads | ✅ |
| `refetch`, sticky errors (no retry loops), partial `errors[]` handling | ✅ |
| Cursor pagination (one cache entry per `after`) | ✅ example |
| Mutations, subscriptions | ❌ not in this PoC |
| Normalized cache (`__typename:id`), SWR / expiry, persistence | ❌ not in this PoC |
| Unions / interfaces (`$on`) | ❌ SpaceX schema has none |

## Layout

```
packages/sling_gql/      runtime: Accessor, Selection, Cache, SlingClient, QueryBuilder
packages/sling_gql_gen/  CLI: introspection JSON → Dart accessor classes
mock-api/                graphql-yoga server, space theme, ~180 launches, cursor + offset pagination
example/                 iOS-only Flutter app talking to the mock API
```

## Setup

```sh
asdf install                                   # flutter + nodejs from .tool-versions

cd mock-api && npm install && npm start        # http://localhost:4000/graphql (GraphiQL)

cd packages/sling_gql && flutter pub get && flutter test
cd ../../example && flutter pub get
flutter test                                   # widget tests against the running mock API
flutter run -d <ios-simulator>
```

The example prints every GraphQL document it sends to the console and shows
them in-app (antenna icon, top right). Server latency is `LATENCY_MS` (default
400 ms) so skeletons are visible.

Regenerate the example's schema classes after editing `mock-api/schema.graphql`:

```sh
cd mock-api && npm run introspect              # → example/graphql/schema.json
cd ../example && dart run ../packages/sling_gql_gen/bin/sling_gql_gen.dart \
  --schema graphql/schema.json --out lib/generated/schema.dart
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
4. **Rebuild.** The response is deep-merged into the cache; scopes whose root
   fields intersect the written fields are told to `setState`.

## Lessons from the PoC

- **Waterfalls are the main footgun**, exactly as in GQty. A field read only
  inside an `if` on fetched data, or only inside an `onPressed`, costs a second
  round trip. The example's widget test caught two of these. Remedies: read
  fields into locals unconditionally at the top of `build`, and use `prepare`.
- **Frame timing matters.** Flutter's first build runs outside a frame and
  slivers build children during layout; a microtask flush split the first
  screen into two requests. Flushing in a post-frame callback fixed it.
- **Without normalization, the same entity fetched through two paths is
  fetched twice** (`launches.nodes[i]` vs `launch(id:)`). Normalizing on
  `__typename` + `id` is the obvious next step and the mock API is ready for it.
- **Codegen is a fine `Proxy` replacement**: 414 lines of generated Dart for
  40 types, fully static and tree-shakeable; sound null safety makes the
  "maybe not fetched yet" state explicit instead of lying like TS types do.

See `AGENTS.md` for the design decisions and the list of known gaps.
