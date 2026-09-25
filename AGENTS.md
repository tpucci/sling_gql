# AGENTS.md — sling_gql

GQty-style GraphQL client for Flutter, **proof of concept** (queries,
normalized cache, mutations; no subscriptions yet).
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
| `cache/cache.dart` | `Cache` interface + `NormalizedCache`: flat entity map (`ROOT_QUERY`, `Launch:launch-181`), `Ref` values, `read` follows refs and fills the caller's `deps` with `entity.field` keys, returns the `missing` sentinel on miss (distinct from a server `null`). `writeResponse` normalizes + merges and returns touched keys. `evict`, `gc`, `snapshot`/`initial`, `onChange`. Imports only `selection.dart` — keep it that way. |
| `cache/normalization.dart` | `Normalization`: `keyField` (`id`), `identify(obj)` → entity key or null (inline), `lookup(type, args)` for by-id root fields. `Normalization.none` = old path-addressed behaviour. |
| `cache/ref.dart` | `Ref`, `missing`. |
| `accessor.dart` | `Accessor` base class for generated types + `Recorder` interface. Helpers `scalar/scalarList/object/list/write`. Skeleton semantics live here. |
| `client.dart` | `SlingClient` (batching, HTTP, partial-error pruning, notify, `mutateWith` + optimistic journal/rollback), `QueryScope` (one per widget: runs a build, tracks misses/loading/error, `refetch`, owns its `FlushScheduler`), `MutationScope` (recorder for one mutate call; misses never fetch). |
| `widgets.dart` | `SlingScope` (provides the client; `of<Q>` typed, `clientOf` untyped), `QueryBuilder` (the `useQuery` equivalent), `QueryState`, `MutationBuilder` (`useMutation`: `mutate` + `MutationState`), `frameEndScheduler`. |

Design decisions worth knowing before changing things:

- **Codegen replaces `Proxy`.** Dart has no property interception; every
  getter is generated and static. Do not reach for `noSuchMethod`.
- **All generated getters are nullable** even for `!` schema types — a value
  can always be absent from cache. `null` from the server and "not fetched
  yet" are told apart by `Accessor.isSkeleton` / `QueryState.hasMissingData`.
- **Skeleton lists have exactly one element** so `.map((e) => e.name)` still
  records the element selection during the first build.
- **Normalization is driven by codegen flags.** `object(..., keyed: true)` /
  `list(..., keyed: true)` make the printer add `id` next to `__typename`;
  `object(..., lookup: 'Launch')` lets `launch(id:)` resolve to `Launch:<id>`
  when the root field is not cached but the entity is (accessor path becomes
  `[Ref(key)]`). Objects without an id stay inline. Lists of refs are replaced
  by the incoming list; entities merge per field.
- **Mutations run the body twice**: once on a `MutationScope` to record the
  selection (every read counts, nothing is fetched), once after the response
  landed to compute the return value from the cache. The response goes through
  the same `writeResponse` → normalized entities → per-field notify, which is
  how the list row updates when the detail screen toggles a favourite. Root
  fields under `ROOT_MUTATION` are removed afterwards (they would pin entities).
  Mutations are sent immediately and alone, never batched with queries.
- **Optimistic writes are journaled.** `Accessor.write` reports a `CacheWrite`
  (path, previous value, touched keys) via `Recorder.onWrite`; while a
  mutation's `optimistic` callback runs, the client collects them and undoes
  them in reverse on failure (`previous == missing` → `cache.remove`).
- **Dependency keys, not root aliases.** Every `cache.read` adds
  `entity.field` keys to `Recorder.deps`; every write returns the keys it
  touched; `_notify` rebuilds scopes whose deps intersect. `depKey()` builds
  them.
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
- **Notification is per entity field** (`Launch:launch-181.name`). Inline
  objects and lists notify at the granularity of the entity field that
  contains them.

## Generator (`packages/sling_gql_gen`)

Input: introspection JSON. Output: one Dart file. Rules are documented in the
package README; the contract it must satisfy is the hand-written example at the
top of `packages/sling_gql/test/core_test.dart`. If you change `Accessor`'s
helper signatures, update the generator **and** that test in the same change.

The generator emits the `Mutation` root (with `.root`) and an
`extension SlingMutations on SlingClient<Query>` providing `client.mutate(...)`,
so no wiring is needed in app code. Subscription roots are still skipped.

The generator decides which types are *keyed* (have a scalar `--key-field`,
default `id`) and which fields are *lookups* (single `id` argument returning a
keyed type); it emits `keyed: true` / `lookup: 'Type'` on `object()`/`list()`
calls. Cache behaviour stays in the runtime — the generator emits facts only.

Regenerate:

```sh
cd example
dart run ../packages/sling_gql_gen/bin/sling_gql_gen.dart \
  --schema graphql/schema.json --out lib/generated/schema.dart \
  --scalar DateTime=DateTime
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

The backlog lives in **`TODO.md`** (numbered, prioritised, single source of
truth — the website roadmap is folded into it). Pick items by number; strike
them there when done and keep `website/src/content/docs/internals/roadmap.mdx`
in sync for the user-facing summary.
