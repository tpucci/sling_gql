# AGENTS.md — sling_gql

GQty-style GraphQL client for Flutter, **proof of concept, queries only**.
Read `README.md` first for the user-facing picture; this file is for working
on the code.

## Toolchain

- Flutter and Node are pinned via asdf in `.tool-versions`. Run `flutter` /
  `dart` / `node` / `npm` from inside the repo so the pins apply.
- `mock-api/` — graphql-yoga server (`npm start`, port 4000, `LATENCY_MS`).
  `mock-api/schema.graphql` is the **contract**; change it there, then
  `npm run introspect` and regenerate the Dart classes (below). The example
  widget tests (`example/test/app_test.dart`) need the server running.
- `website/` — Astro + Starlight docs site, deployed to GitHub Pages by
  `.github/workflows/website.yml`. Landing page is `src/content/docs/index.mdx`;
  internal links must include the `/sling_gql/` base path. `npm run build` must
  pass before committing content.
- Three Dart packages, no melos/workspace yet:
  - `packages/sling_gql` — the runtime (Flutter package). Tests: `flutter test`.
  - `packages/sling_gql_gen` — pure Dart CLI generator. Tests: `dart test`.
  - `example` — Flutter app, **iOS only** (`flutter create --platforms=ios`).
    Do not add other platforms.
- The example talks to `http://localhost:4000/graphql` (iOS simulator shares
  the host network). Its introspection is snapshotted in
  `example/graphql/schema.json`.

## Architecture (runtime, `packages/sling_gql/lib/src`)

| File | Role |
| --- | --- |
| `selection.dart` | `Selection` tree (field + args → alias), `Arg`, `PrintedOperation` (tree → document + variables). Alias = `field_<fnv1a(json(args))>`; the alias is **also the cache key**. |
| `cache.dart` | Path-addressed, non-normalized cache. `read` returns the `missing` sentinel on cache miss (distinct from a server `null`). `writeResponse` deep-merges. |
| `accessor.dart` | `Accessor` base class for generated types + `Recorder` interface. Helpers `scalar/scalarList/object/list/write`. Skeleton semantics live here. |
| `client.dart` | `SlingClient` (batching, HTTP, partial-error pruning, notify), `QueryScope` (one per widget: runs a build, tracks misses/loading/error, `refetch`, owns its `FlushScheduler`). |
| `widgets.dart` | `SlingScope` (InheritedWidget providing the client), `QueryBuilder` (the `useQuery` equivalent), `QueryState`, `frameEndScheduler`. |

Design decisions worth knowing before changing things:

- **Codegen replaces `Proxy`.** Dart has no property interception; every
  getter is generated and static. Do not reach for `noSuchMethod`.
- **All generated getters are nullable** even for `!` schema types — a value
  can always be absent from cache. `null` from the server and "not fetched
  yet" are told apart by `Accessor.isSkeleton` / `QueryState.hasMissingData`.
- **Skeleton lists have exactly one element** so `.map((e) => e.name)` still
  records the element selection during the first build.
- **Flush timing is per scope.** `QueryBuilder` scopes flush in a post-frame
  callback (`frameEndScheduler`): Flutter's initial build runs in
  `attachRootWidget` *outside* a frame, and slivers build rows during layout,
  so a microtask would split one screen into two requests. `resolve()` and
  plain tests use `microtaskScheduler`. The first scheduler of a batch wins.
- **Misses recorded after `run()` returned still count** (child widgets, lazy
  rows, even `onPressed` callbacks): accessors keep a reference to their scope
  and `onMiss` schedules the flush itself.
- **Partial GraphQL errors** are pruned from `data` before caching (a `null`
  at an errored path is not a real null) and surfaced as the scope's error.
- **Errors are sticky per scope** until `refetch()`; otherwise a failing query
  would loop build → miss → fetch → fail → rebuild.
- **Notification is coarse**: a scope rebuilds if any of its *root-level*
  aliases were written. Fine-grained invalidation is a known follow-up.

## Generator (`packages/sling_gql_gen`)

Input: introspection JSON. Output: one Dart file. Rules are documented in the
package README; the contract it must satisfy is the hand-written example at the
top of `packages/sling_gql/test/core_test.dart`. If you change `Accessor`'s
helper signatures, update the generator **and** that test in the same change.

Regenerate:

```sh
cd example
dart run ../packages/sling_gql_gen/bin/sling_gql_gen.dart \
  --schema graphql/schema.json --out lib/generated/schema.dart
```

## Conventions

- Keep the runtime dependency-light (`http` only). No `gql`/`ferry` in the
  runtime for now — the point of the PoC is to see how small the core can be.
- Every runtime behaviour change gets a test in `packages/sling_gql/test`.
  Prefer `MockClient` from `package:http/testing.dart` over hitting the network.
- Generated file `example/lib/generated/schema.dart` is committed; never edit
  it by hand.
- In example widgets, **read every field you will need at the top of `build`**
  (into locals) — never only inside an `if` on fetched data or in a callback.
  Each such conditional read is an extra round trip; `app_test.dart` asserts
  request counts precisely to catch them.
- Don't commit `.dart_tool/`, `build/`, `ios/Pods`, `node_modules/`, `.pixel/`.

## Known gaps / next steps

1. Normalized cache keyed on `__typename:id` (needed for mutations to update
   lists).
2. `maxAge` / stale-while-revalidate, cache persistence.
3. Mutations (`useMutation` equivalent) and subscriptions (the mock API
   already exposes `toggleFavorite`, `scheduleLaunch`, `updateLaunchStatus`
   and two SSE subscriptions).
4. Unions/interfaces via `$on` (add one to `mock-api/schema.graphql` first;
   the generator currently skips none because there are none).
5. Finer-grained rebuild (per leaf path instead of per root alias).
6. Dev overlay: which widget caused which request.
