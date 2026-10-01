# AGENTS.md — sling_gql

GQty-style GraphQL client for Flutter, **proof of concept** (queries,
normalized cache, mutations, subscriptions over SSE, SQLite persistence).
Read `README.md` first for the user-facing picture; this file is for working
on the code.

## Toolchain

- Flutter and Node are pinned via asdf in `.tool-versions`. Run `flutter` /
  `dart` / `node` / `npm` from inside the repo so the pins apply.
- `mock-api/` — graphql-yoga server (`npm start`, port 4000, `LATENCY_MS`).
  `mock-api/schema.graphql` is the **contract**; change it there, then
  `npm run introspect` and regenerate the Dart classes (below). The example
  widget tests (`example/test/app_test.dart`) need the server running.
  The mock API keeps its state in memory and the e2e tests mutate it
  (scheduled launches, favourites), so a long-running server drifts
  (e.g. `totalCount` 187 instead of 181) and `app_test.dart` fails on
  counts. `scripts/with-mock-api.mjs` *reuses* a server already on :4000.
  When the example tests fail on data/counts and a server was already
  running, restart it (kill the `npm start` / `node server.mjs` on :4000,
  rerun the tests so the script starts a fresh one, then restart
  `npm start` in `mock-api/` in the background if one was running before)
  — don't treat it as a code regression.
  The yoga instance lives in `app.mjs` (`createMockYoga`, no Node APIs);
  `server.mjs` serves it over `node:http`, `browser.mjs` exposes it as
  `globalThis.slingMockApi` and `npm run build:browser` bundles that to
  `example/web/mock-api.js` (gitignored) for the example's web build. Keep
  `resolvers.mjs` / `data.mjs` free of `Buffer`/`process`/`fs`.
- `website/` — Astro + Starlight docs site, deployed to GitHub Pages by
  `.github/workflows/website.yml`. Landing page is `src/content/docs/index.mdx`;
  internal links must include the `/sling_gql/` base path. `npm run build` must
  pass before committing content.
- **Pub workspace + melos 7.** The root `pubspec.yaml` lists the six
  packages (`workspace:`), each has `resolution: workspace`; only the root
  `pubspec.lock` exists (per-package lockfiles are gitignored). Run
  `melos bootstrap` once (`dart pub global activate melos` if missing). Melos
  config and scripts live in the root `pubspec.yaml` under `melos:`.
  Gates: `melos run test` (all four: runtime + test helpers + hooks + link
  and sqflite adapters, generator, example with the mock server auto-started by
  `scripts/with-mock-api.mjs`, website build), or `test:runtime` / `test:gen` / `test:example` /
  `test:website` individually; `melos run analyze`, `melos run format`,
  `melos run generate`. Add `--no-select` when running non-interactively.
  - `packages/sling_gql` — the runtime (Flutter package). Tests: `flutter test`.
  - `packages/sling_gql_gen` — pure Dart CLI generator. Tests: `dart test`.
  - `packages/sling_gql_test` — test helpers (Flutter package, depends on
    `flutter_test`): `MockGraphQLServer` (parses the printed document,
    resolves it against maps/resolvers, answers under the right aliases),
    `pumpUntilSettled` (on `SlingClient.isIdle`/`whenIdle`),
    `useRealNetwork`, `disposeAfterTest`. Tests: `flutter test`. Prefer it
    over hand-rolled `MockClient` + alias regexes in new tests.
  - `packages/sling_gql_hooks` — `flutter_hooks` adapter (Flutter package):
    `useSlingQuery` / `useSlingMutation` / `useSlingSubscription` are
    `QueryBuilder` / `MutationBuilder` / `SubscriptionBuilder` as custom
    `Hook`s on the same `createScope` / `mutateWith` / `subscribeWith`, and
    hand out the runtime's `QueryState` / `MutationState` /
    `SubscriptionState` (public constructors for this). Keep their semantics
    in lockstep with the builders in `widgets.dart`. Tests: `flutter test`
    (in `test:runtime`).
  - `packages/sling_gql_link` — `gql_link` adapter (Flutter package via
    `sling_gql`): `linkTransport(link)` / `linkSubscriptionTransport(link)`
    turn a `Link` chain into the client's `Transport` /
    `SubscriptionTransport` (printed document parsed with `gql`, headers as
    `HttpLinkHeaders`, `LinkException` → `SlingLinkException`). The only
    place `gql`/`gql_link` are allowed. Tests: `flutter test` (fake links +
    `MockGraphQLServer`, `HttpLink` on a `MockClient`).
  - `packages/sling_gql_sqflite` — SQLite persistence (Flutter package;
    `sqflite` + `sqflite_common`, the only place they are allowed).
    `SqflitePersistence.open(path, schema:)` reads the rows, prunes them
    (`load.dart`, pure so `hydrateInIsolate` can `compute` it: root fields
    past `maxAge`, the oldest over `maxEntities`, unreachable entities —
    the `gc` set, computed on the JSON), builds the `Cache` before the
    client exists and listens to `onChange`; saves are
    `changesSince(savedVersion)` deltas (debounce / `maxWait` /
    lifecycle / `flush()`), one transaction each, chained, then
    `cache.compact(upTo:)` (`compact: false` when another reader needs old
    versions — the example's `CacheStats`); deletes go out as chunked
    `IN (…)` statements. Rows: one per
    entity, one per `ROOT_QUERY` field (`delta.changedFields` says which;
    for a whole-root copy in a full delta, the touched `ROOT_QUERY.<alias>`
    keys; `ROOT_MUTATION`/`ROOT_SUBSCRIPTION` never stored). A
    `sling_meta` mismatch (format version, key field, `slingSchema.hash`)
    wipes the store. Bump `sqfliteFormatVersion` when the tables change.
    Tests: `flutter test` on the host through `sqflite_common_ffi` (temp
    files; `tester.runAsync` in `testWidgets`); `benchmark/` is run by
    hand (`flutter test benchmark/persistence_bench_test.dart`).
  - `example` — Flutter app, **iOS and web** (no other platforms). On the web
    `lib/in_browser_api.dart` (conditional import) swaps the `http.Client`
    for one answering from the in-page mock API, so the site's "Try it
    live" page needs no server; `lib/persisted_cache.dart` (the other
    platform switch) opens the cache from SQLite (`sling_gql_sqflite`) on
    iOS and keeps it in memory on the web. The widget tests build their own
    client and never call `openCache()`, so no state survives a run. `melos run build:web`
    (`scripts/build-web-demo.mjs`) bundles the mock API, runs `flutter build
    web --base-href /sling_gql/demo/` and copies it to `website/public/demo/`
    (gitignored; `website.yml` does it before `astro build`). Keep
    `dart:io` out of the runtime and the example.
    `lib/demos/` holds the small demos the guides embed (`?demo=<name>`,
    `demos.dart`); the guides show their `// #region` blocks through
    `website/src/components/DemoSource.astro`, so renaming or removing a
    region breaks the site build. What each guide tells the reader to try
    is asserted in `test/demos_test.dart`. On the site, demos are views of
    one Flutter engine (multi-view): `web/flutter_bootstrap.js` (a template)
    hands over to `window.slingDemoHost` when `LiveApp.astro` installed it,
    and `main.dart` then runs `DemoViews` (no implicit view); otherwise the
    same build starts normally (`/demo/`, `?demo=`, the Try-it iframe).
- **Commit messages are Conventional Commits** -- `melos version` derives
  bumps and changelogs from them. Scope by package or area:
  `feat(sling_gql): ...`, `fix(sling_gql_gen): ...`, `feat(sling_gql_test): ...`, `feat(sling_gql_link): ...`, `feat(sling_gql_sqflite): ...`, `docs(website): ...`,
  `chore(repo): ...`, `test(example): ...`. Only commits touching a package's
  files bump that package; `feat` -> minor, `fix`/`perf`/`refactor` -> patch,
  `BREAKING CHANGE:` footer or `!` -> major — but below 1.0 melos shifts
  down one step (`feat` -> patch, 0.2.0 -> 0.2.1; observed on the 2026-10
  release), and a package bumped only because a dependency moved gets a
  `+1` build bump (`sling_gql_test` 0.1.1 -> 0.1.1+1).
  Never hand-edit versions or `CHANGELOG.md` files.
- **Publishing** (`sling_gql`, `sling_gql_gen`, `sling_gql_test`, `sling_gql_hooks`, `sling_gql_link`, `sling_gql_sqflite`; MIT; each with its own
  `README.md`, `CHANGELOG.md`, `LICENSE`, `example/`). Versions are
  independent. Release from a clean, up-to-date `main`:

  ```sh
  melos run publish:dry-run          # pub.dev validation of both packages
  melos version                      # bump + CHANGELOG + commit + tags <pkg>-vX.Y.Z
  git push --follow-tags
  ```

  `.github/workflows/publish.yml` runs once per `<pkg>-vX.Y.Z` tag, checks the
  tag matches that package's `pubspec.yaml`, and publishes via pub.dev
  automated publishing (OIDC; pub.dev tag patterns `sling_gql-v{{version}}` /
  `sling_gql_gen-v{{version}}` / `sling_gql_test-v{{version}}` /
  `sling_gql_hooks-v{{version}}` / `sling_gql_link-v{{version}}` /
  `sling_gql_sqflite-v{{version}}`, no secrets;
  the pattern must be enabled on pub.dev for each package). Manual escape hatch:
  `melos version <package> x.y.z` (give the exact version: below 1.0 melos maps
  `patch` to a `+build` bump). The `<pkg>-v0.1.1` tags are the baseline melos
  reads commits from; before them the history is not conventional. A **new**
  package cannot go through the tag workflow the first time — pub.dev only enables automated
  publishing on an existing package: publish its first version by hand
  (`dart pub publish` in the package), enable its tag pattern on the package's
  pub.dev admin page, then tag that commit `<pkg>-vX.Y.Z` as its melos
  baseline (`sling_gql_hooks`, `sling_gql_link` and `sling_gql_sqflite` went
  this way at 0.1.0). A new package that needs an unreleased runtime API must
  wait for that `sling_gql` release and name it in its constraint (`melos
  version` raises it; the in-workspace dry run resolves the local path and
  will not catch a stale one). Code must be
  `dart format`ed (pub.dev scores it; `melos run format` checks).
- **CI.** `.github/workflows/ci.yml` runs on push/PR: analyze, format,
  runtime + generator tests, a check that `melos run generate` leaves
  `example/lib/generated/schema.dart` unchanged, example tests against the
  mock API, the example's web build, website build. `website.yml` builds the
  web demo and deploys the docs on push to `main`.
- The example talks to `http://localhost:4000/graphql` (iOS simulator shares
  the host network). Its introspection is snapshotted in
  `example/graphql/schema.json`.

## Architecture (runtime, `packages/sling_gql/lib/src`)

| File | Role |
| --- | --- |
| `selection.dart` | `Selection` tree (field + args → alias), `Arg`, `PrintedOperation` (tree → document + variables). Alias = `field_<fnv1a64(json(args))>` (64-bit, web-safe); the alias is **also the cache key**. |
| `cache/cache.dart` | `Cache` interface + `NormalizedCache`: flat entity map (`ROOT_QUERY`, `Launch:launch-181`), `Ref` values, `read` follows refs and fills the caller's `deps` with `entity.field` keys, returns the `missing` sentinel on miss (distinct from a server `null`); `readField(path, field)` is the allocation-free variant getters use, dep keys are interned. `writeResponse` normalizes + merges and returns touched keys. `evict`, `gc`, `snapshot`/`initial`, `onChange` (once per change: a write outside `batch`, or a whole `batch` — the client batches every response/mutation/subscription event/optimistic callback), `version`/`changesSince` → `CacheDelta` (entities stamped per change, tombstones for removals; operation roots stamped per field and reported as `changedFields`/`removedFields`, copied whole only before a root removal / stamp purge; `compact(upTo:)` drops the records a store holds, after which older versions get `full`); `NormalizedCache.adopt` hydrates decoded JSON without copying. Imports only its siblings in `cache/` (`normalization.dart` imports `selection.dart`) — keep it that way. |
| `cache/normalization.dart` | `Normalization`: `keyField` (`id`), `identify(obj)` → entity key or null (inline), `lookup(type, args)` for by-id root fields. `Normalization.none` = old path-addressed behaviour. |
| `cache/ref.dart` | `Ref`, `missing`. |
| `accessor.dart` | `Accessor` base class for generated types + `Recorder` interface. Helpers `scalar/scalarList/object/list/write`. Skeleton semantics live here. |
| `client.dart` | `SlingClient` (batching, HTTP, partial-error pruning, notify, `mutateWith` + optimistic journal/rollback, `subscribeWith`, list rules), `QueryScope` (one per widget: runs a build, tracks misses/loading/error, `refetch`, owns its `FlushScheduler`), `MutationScope` (recorder for one mutate call; misses never fetch), `RowScope` (`QueryScope.row`: own deps, everything else forwarded to the parent). |
| `widgets.dart` | `SlingScope` (provides the client; `of<Q>` typed, `clientOf` untyped), `QueryBuilder` (the `useQuery` equivalent), `QueryState`, `MutationBuilder` (`useMutation`: `mutate` + `MutationState`), `SubscriptionBuilder` (`select` records once, opens on the first post-frame callback, closes in `dispose`), `SlingRow` (rebinds an accessor to a `RowScope`), `frameEndScheduler`. |
| `request_overlay.dart` | `SlingRequestOverlay`: debug-only chip + panel over the app listing `client.requests` (`SlingRequest`, defined in `client.dart`: kind, root fields, duration, bytes, error, `scopes` = the `debugLabel`s of the scopes in the batch). Widgets default their label to the enclosing widget (`debugOwnerLabel`, debug builds only). |

Design decisions worth knowing before changing things:

- **Codegen replaces `Proxy`.** Dart has no property interception; every
  getter is generated and static. Do not reach for `noSuchMethod`.
- **All generated getters are nullable** even for `!` schema types — a value
  can always be absent from cache. `null` from the server and "not fetched
  yet" are told apart by `Accessor.isSkeleton` / `QueryState.hasMissingData`.
- **Skeleton lists have exactly one element** so `.map((e) => e.name)` still
  records the element selection during the first build.
- **Unions/interfaces are inline fragments.** `Accessor.on(typename, ctor,
  keyed:)` records a fragment node (`Selection.fragment`, alias
  `... on Type`, skipped by `aliasPath`) and returns an accessor at the
  *same* cache path; `null` when the cached `__typename` differs, a skeleton
  when the object is missing. `whenType` (behind the generated `when`) runs
  every branch on a skeleton so one build records all fragments. Generated
  `asType` getters + `when(...)` per `UNION`/`INTERFACE`; the hand-written
  contract is at the top of `packages/sling_gql/test/fragments_test.dart`.
  A field read in two fragments of one object (or a fragment and directly)
  is printed `<alias>__<Type>: field` per fragment (GraphQL requires one
  shape per response name); `PrintedOperation.toCacheKeys` maps the response
  back to aliases after error pruning, before `writeResponse` (#57).
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
- **Subscriptions are one POST each** (`accept: text/event-stream`), through
  `SlingClient.subscriptionTransport` (default: `sseSubscriptionTransport`,
  GraphQL-over-SSE "distinct connections" — what yoga serves on `/graphql`).
  `subscribeWith` runs the body once on a `SubscriptionScope` to record, opens
  on `listen`, and for each event prunes partial errors, `writeResponse`s
  under `ROOT_SUBSCRIPTION`, `_notify`s, then runs the body again for the
  stream value. The root fields are removed on close. Not part of `isIdle`.
  A transport error with `retryAfter` (default
  `SlingClient.subscriptionRetryAfter`) schedules `_open` again instead of
  closing (`isReconnecting`, `reconnect()`, `onStatusChanged` for the
  widget); a server `complete` always closes.
  Test helpers: `MockGraphQLServer(subscription: {field: Stream})` +
  `openSubscriptions`.
- **List rules** (`SlingClient(listRules:)`, `ListRule<E>`): `_rememberLists`
  records (alias path, args) of every node matching a rule's `field` from
  each *query* document at flush; `_notify` first runs `_applyListRules`
  over the touched entities of the rule's typename, evaluating `belongs`
  per remembered list and rewriting it (journaled while `_journal` is set).
  `insert: false` for query responses — pages must not absorb each other —
  so responses only remove. The example's `lib/list_rules.dart` replaces
  hand-written membership edits.
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
  would loop build → miss → fetch → fail → rebuild. A run served entirely from
  fresh cache clears a *miss-driven* error; an error from a background fetch
  (`refetch()`, `cacheAndNetwork`, stale revalidation) stays until the next
  `refetch()`/`retryFailedAfter` since cached data is still on screen.
- **Fetch policies live on the scope.** `FetchPolicy.networkOnly` swaps the
  scope's `cache` for a `_BypassCache` (every read `missing`) until its first
  successful response; `cacheAndNetwork` enqueues the whole `_root` on the
  first `run()`; `maxAge` compares each dep key's `Cache.fetchedAt` (stamped
  by `writeResponse(at:)` for every key a response writes, changed or not)
  and enqueues the whole selection when any is stale. All three go through
  `_errorBlocksFetch()` so a failing server never loops.
  `isStale` and a background `isLoading` are only known after the body ran
  (the builder saw the previous run's values): `run()` schedules one more
  `onChanged` (microtask) when they differ from what the body saw.
- **Notification is per entity field** (`Launch:launch-181.name`). Inline
  objects notify at the granularity of the entity field that contains them.
  A list held directly by an entity field is finer (#54): a read through an
  inline element records `elementDepKey` (`Launch:x.links[2]`), a read
  through a `Ref` element keeps the field key, `Accessor.list` of inline
  objects (`keyed: false`) records `lengthDepKey` (`Launch:x.links[length]`)
  via `Cache.readListField`. Writes (`_mergeList`, `write`, `remove`,
  `evict`, `clear`) touch the field key plus the element keys of changed
  inline elements and the length key on resize — every writer of an
  entity-level list must keep doing so. Deeper lists belong to their element
  / field; `fetchedAt` maps the finer keys to the field's stamp.
  A key is touched only when something under it changed: `_normalize` sets
  `_changed` for leaves, refs, new keys and list lengths, `_mergeEntity`
  reads it per field. Changes inside a referenced entity touch that entity.
- **GC is the client's.** `Cache.gc(retain:)` only marks from roots +
  `retain`; `SlingClient.gc()` passes the entities of every live scope's and
  row's deps (lookups read orphaned entities) and is a no-op while a mutation
  is in flight (rollbacks restore refs). It runs itself from `_checkIdle`
  after `gcAfterWrites` responses (default 100, `null` = off).
- **Rows are scopes for deps only.** `SlingRow` rebinds the accessor it is
  given (`ctor(rowScope, selection, path)`) to a `RowScope`: same cache,
  same selection tree, misses/writes forwarded to the parent `QueryScope`
  (which fetches and holds loading/error); only `deps` are the row's, and
  `_notify` probes rows after scopes. `_allDeps` (scope + rows) feeds
  `maxAge`/`revalidate`.

## Generator (`packages/sling_gql_gen`)

Input: introspection JSON. Output: one Dart file. Rules are documented in the
package README; the contract it must satisfy is the hand-written example at the
top of `packages/sling_gql/test/core_test.dart` (unions/interfaces:
`packages/sling_gql/test/fragments_test.dart`). If you change `Accessor`'s
helper signatures, update the generator **and** that test in the same change.

The generator emits the `Mutation` root (with `.root`) and an
`extension SlingMutations on SlingClient<Query>` providing `client.mutate(...)`,
and likewise the `Subscription` root with `extension SlingSubscriptions`
providing `client.subscribe(...)`; `slingSchema` carries all three roots and
the `--key-field`, so `SlingClient(schema: slingSchema)` needs no other wiring
(its default cache normalizes on that key field; `SlingScope` falls back to
`client.schema` for its roots). It also carries `hash`: `generatedCodeHash`
(64-bit FNV-1a) of the generated file with the `hash:` argument left out
(a placeholder), so it moves with the introspection, `--key-field`,
`--scalar` and the generator's output; the runtime never reads it,
`sling_gql_sqflite` wipes its store when it changes.

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

- **Two entry points.** `package:sling_gql/sling_gql.dart` is the app-facing
  surface (client, widgets, `Accessor`/`Recorder`/`Arg` for generated code,
  `Cache` interface, `CacheScope`); `package:sling_gql/internal.dart` exports
  the building blocks (`NormalizedCache`, `Ref`, `missing`, `depKey`,
  `CacheWrite`, `MutationScope`, `ListLocator`) with no stability promise.
  Path-level `Cache.read/write/remove/writeResponse` are `@internal`
  (`package:meta`). New public symbols go in the main library only if an app
  would call them; everything else in `internal.dart`.
- Keep the runtime dependency-light (`http` and `meta` only). No `gql`/`ferry` in the
  runtime for now — the point of the PoC is to see how small the core can be;
  `gql_link` users go through `packages/sling_gql_link`.
- Every runtime behaviour change gets a test in `packages/sling_gql/test`.
  Never hit the network: the runtime tests use `MockClient` from
  `package:http/testing.dart` (see `test/support/test_schema.dart`); app-level
  tests use `sling_gql_test`'s `MockGraphQLServer`. The example's
  `app_test.dart` is the one end-to-end test against the real mock API
  (`useRealNetwork()` + `tester.pumpUntilSettled(client)`).
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
