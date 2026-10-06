# TODO — sling_gql

Single backlog for the PoC, ordered roughly by value. Items are numbered so
they can be picked one at a time ("do #23"). Numbers stay stable; done items
move to the **Done** section at the bottom (one line each). Sources: the
DX/performance review of the example app (2026-09), smaller issues noticed
while building the normalized cache and mutations, and the roadmap (website
`internals/roadmap.mdx`, folded in as items 46+).

Roadmap status: ~~normalized cache~~ · ~~mutations~~ · ~~pagination helper~~ ·
~~transport hook~~ · ~~fine-grained rebuilds~~ (#54) ·
~~expiry/SWR~~ · ~~subscriptions~~ · ~~unions~~ · ~~dev experience~~ (#46, #47) ·
~~`gql_link`~~ (#48) · ~~persistence~~ (#49, SQLite).

Status (2026-09-27): P0 and P1 done (#1–#16); fetch policies + SWR (#23,
#52); example/docs sweep done (#34–#37, #41, #42); pub workspace + melos and
pub.dev-ready packages (#43), CI + tag-triggered pub.dev publishing (#44); API surface split (#32).
Per-row rebuilds (#19, #20) done. Unions & interfaces (#31) done.
Read-path allocations (#17, #18) done. Conflicting fragment fields (#57)
and key/alias collisions (#26, #33) done. Small-items sweep (2026-09-29):
#27, #29, #38, #39, #40 done; P3 is empty. The example runs on the web and
live on the website (#58), with a live demo in the batching, fetch-policies
and mutations guides (#59, 2026-09-29). Demos in four more
guides (#60). Demos share one Flutter engine (#67).
Automatic `gc()` (#22) done. Request overlay + log line (#46) done. Tour of the
guides and the example (2026-09-29): #61–#66 done. 2026-09-30: #21 (coalesced
`onChange`, `changesSince` deltas), #47 (`sling_gql_hooks`), #48
(`sling_gql_link`), #54 (per-element inline list deps) done. 2026-10-01: #49
(`sling_gql_sqflite`) done; open follow-ups #68, #69. 2026-10-02: #68, #69 done.
Production-readiness review (2026-10): next are #50, #70, #71, #72, #73 in
that order; `graphql-ws` dropped from the core. #50 (type policies,
connection merging) done.

Legend: **DX** developer experience · **Perf** runtime performance ·
**Runtime** features/config · **Gen** generator · **Example** · **Test** ·
**Docs/Repo**.

## P2 — performance follow-ups (measured: ~350 ns/read, ~25× raw maps)

(empty)

## P4 — example app & tooling

(empty)

## P5 — docs & repo hygiene

45. **Repo — Package split when needed**: `sling_gql_core` (pure Dart) vs
    Flutter widgets vs persistence adapters (see architecture doc). Not before
    a second consumer exists.

## P1 — production readiness (2026-10 review, in this order)

50 done (see Done), then:

70. **Runtime — Error model + auth/retry**: typed errors (network /
    HTTP status / GraphQL / partial) with `extensions` and error codes
    surfaced; `errorPolicy` (none / all / ignore) per query and client-wide;
    request timeout and cancellation; retry with backoff for queries (never
    mutations by default); token refresh on 401 as a first-class, tested hook
    (today only `Transport` recipes + sticky errors / `retryFailedAfter`).
    Settle the API shape before #73.
71. **Test — Android + real-backend coverage**: add Android to the example
    (sqflite persistence included) and run the e2e suite on it; a soak test
    (memory, batching, GC) on a large generated schema; run the runtime
    against a second real GraphQL server besides yoga.
72. **Runtime — Persistence migration + offline mutation queue**: ~~migrate
    the `sling_gql_sqflite` store across schema-hash changes instead of
    always wiping (keep entities whose type/fields still exist), corruption
    recovery, multi-isolate access, encryption option~~ (done 2026-10:
    `slingSchema.fields` + `_Migration`, recover by recreating the file,
    one writer per file, `SqfliteCodec`); still open: a persisted mutation
    queue replayed on reconnect, and defined behaviour for optimistic writes
    when the app is killed mid-flight (after #70).
73. **Repo — API audit + 1.0**: decide the public surface (what leaves
    `internal.dart`, what gets hidden), semver + deprecation policy,
    migration guide, security policy, benchmarks tracked in CI; then release
    1.0 of every package.

## Roadmap items not covered above

51. **Runtime — Weakly held stale entries** (`WeakReference`/`Finalizer`) as
    an eviction mechanism for data past `maxAge` (#23 only revalidates, never
    drops).

## Done

Kept for number stability; see git history for details.

1. DX — Dev-mode waterfall warning: `SlingClient(warnOnWaterfall:, onWaterfall:)`, `WaterfallWarning`, `QueryBuilder.debugLabel`.
2. Gen — Real Dart enums (lowerCamel + `unknown`, `.graphqlName`, `fromGraphQL`/`toGraphQL`; `Accessor.enumValue`/`enumList`).
3. Gen — No setter on the key field, `PageInfo` fields, or `pageInfo`/`totalCount` of connections.
4. Perf — `_notify` probes the small `touched` set.
5. DX — Pagination helper: `PaginationController`, `ConnectionPage`, `PaginatedQueryBuilder`/`PaginatedState`.
6. Runtime — `Transport` hook (`SlingClient(transport:)`), recipes in `guides/transport`.
7. DX — Three meanings of `null`: `state.hasMissingData` pattern + `Accessor.isFetched`; story on getting-started.
8. DX — `QueryState.isSkeleton` + "never branch on list length while `hasMissingData`" rule.
9. DX — `SlingScope(schema: slingSchema)` / `mutationRoot:`; `MutationBuilder` needs no `root:`.
10. DX — Sticky-error docs + `SlingClient(retryFailedAfter:)`.
11. DX — Generated-file header explains the `$` rename scheme.
12. DX — Typed cache access: `client.cacheScope` (`.query`, generated `.launch(id)` per keyed type); reads never fetch.
13. Gen — `--scalar Name=DartType[:converter]` (`DateTime` built in); example uses it.
14. Runtime — List membership: `cacheScope.list((q) => q.me?.favorites).append/prepend/remove(e)`, `cacheScope.evict(e)`; journaled inside `optimistic:`. Example favourites update without refetch.
15. Runtime — `mutateWith(..., refetchQueries: [...])`, forwarded by generated `client.mutate`.
16. Test — `packages/sling_gql_test`: `MockGraphQLServer` (parses the printed document, resolves against maps/resolvers, answers under the document's aliases, `GraphQLError`, request log, `latency`), `pumpUntilSettled` on the new `SlingClient.isIdle`/`whenIdle`, `useRealNetwork()` (lifts the socket block and turns keep-alive off), `disposeAfterTest()`. Guide: `guides/testing`.
23. Runtime — `FetchPolicy` (`cacheFirst`/`cacheAndNetwork`/`networkOnly`) on `QueryBuilder`, `createScope`, `resolve` and as `SlingClient` default; `maxAge` stale-while-revalidate on per-dep-key fetch stamps (`Cache.fetchedAt`, `writeResponse(at:)`), `QueryState.isStale`; background-fetch errors sticky like miss errors. Guide: `guides/fetch-policies`.
32. Runtime — `package:sling_gql/internal.dart` (`NormalizedCache`, `Ref`, `missing`, `depKey`, `CacheWrite`, `MutationScope`, `ListLocator`); `Cache.read/write/remove/writeResponse` `@internal`; `FlushScheduler`/`microtaskScheduler`/`frameEndScheduler` exported for `createScope`.
34. Example — Printed-document variables named after the argument (`$first`, `$after`, `$first2` on clash).
35. Example — Shared `ErrorView` widget.
36. Example — `NetworkLog.add` guarded with `kDebugMode`.
37. Example — `settle()` is `tester.pumpUntilSettled(client)` + one pump for page transitions; no `runAsync` polling, no `client.dispose()` in test bodies.
41. Docs — "queries only" phrasing swept.
42. Docs — "Rules of the road" block on getting-started.
43. Repo — Pub workspace (root `pubspec.yaml`, `resolution: workspace`) + melos 7 scripts (`melos run test` = four gates, `analyze`, `format`, `generate`, `publish:dry-run`); `sling_gql` / `sling_gql_gen` 0.1.0 pub.dev-ready (LICENSE MIT, CHANGELOG, README, repository metadata, `dart pub publish --dry-run` clean).
44. Repo — CI (`.github/workflows/ci.yml`): analyze, format, runtime, generator, generated-file-is-fresh, example against the mock API, website build, on push/PR. `publish.yml`: `melos version` (Conventional Commits) tags `<pkg>-vX.Y.Z`; pushing a tag publishes that package to pub.dev via OIDC (automated publishing enabled on pub.dev).
52. Runtime — Soft refetch: `QueryScope.revalidate()` / `state.revalidate()`, a no-op within `maxAge`.
30. Runtime/Gen — Subscriptions: `SlingClient.subscribeWith` / generated `client.subscribe`, `SlingSubscription` (stream, cancel), `SubscriptionScope`, `SubscriptionTransport` with `sseSubscriptionTransport` default (GraphQL over SSE, distinct connections); generator emits the `Subscription` root, `SlingSubscriptions`, `slingSchema.subscription`; `MockGraphQLServer(subscription:)`; example "Live" banner + e2e test against yoga.
56. Runtime — Subscription reconnection: `SlingClient(subscriptionRetryAfter:)` / `subscribe(retryAfter:)`, `SlingSubscription.isConnected`/`isReconnecting`/`reconnect()`, `SubscriptionState.retry()`; example banner shows "reconnecting… (tap to retry now)".
55. Runtime — `ListRule` / `SlingClient(listRules:)`: cached lists follow their entities (`belongs(args, entity)` per remembered alias; responses only remove; journaled in `optimistic`). Example `list_rules.dart` + mission-control flow (`scheduleLaunch` form, mock launch sequence `SEQUENCE_MS`, `IN_FLIGHT` status).
19. Perf — Per-row rebuilds: `SlingRow(value, ctor: Launch.new, builder:)` over `RowScope` (`QueryScope.row`, own deps; misses/writes/selections go to the parent; freshness checks include rows' deps). Example `LaunchRow` is one.
20. Perf — Inline containers compared structurally while merging (`_normalize` flags real changes): identical `stats`/`pageInfo`/lists touch nothing.
53. Runtime — `SubscriptionBuilder<Subscription>` (`select` records once, opens post-frame, `SubscriptionState`), root from `SlingScope(schema:)` via `subscriptionRootOf`.
31. Runtime/Gen — Unions & interfaces: `Selection.fragment` (inline fragments, transparent to cache paths), `Accessor.on`/`whenType`; generated `asType` getters + `when(...)` per `UNION`/`INTERFACE` (all branches recorded on the skeleton; keyed members and key-declaring interfaces normalize); `MockGraphQLServer` resolves `... on Type`; mock `Node` interface + `search: [SearchResult!]!` union, `node(id:)`; example Search tab + e2e test.
24. Runtime — `QueryBuilder(scheduler:)` (default `frameEndScheduler`); when `microtaskScheduler` fits documented in `guides/batching-and-waterfalls`.
25. Runtime/Gen — `slingSchema` carries `keyField` (always emitted, `SlingSchema<Query, Accessor>` without a Mutation type); `SlingClient(schema:)` supplies `rootFactory` + default cache normalization, asserts on a mismatching `cache:`; `SlingScope` falls back to `client.schema`.
17. Perf — Read path: `Cache.readField` (no `[...path, alias]` per getter), dep keys interned per `(entity, field)`, constant `rootKey`, single map lookup per step, `scalarAs` memoizes parsed values per `(parse, wire value)` (`DateTime.parse` was ~⅓ of a warm list build). Bench warm build 720 → 330 ns/read; bench now reports best of 5 rounds. A per-accessor location memo (`Expando`) was measured slower and dropped; object accessors still copy their path.
46. DX — Request log: `SlingRequest` on `client.requests` (kind, root fields, field count, duration, bytes, status, error, events; `scopes` = labels of the scopes in the batch, `scopeSummary` folds repeats), `SlingClient(logRequests:)` one-line log, `SlingRequestOverlay` (debug-only chip + panel); `QueryBuilder`/`MutationBuilder`/`SubscriptionBuilder` default their label to the enclosing widget in debug builds, `debugLabel:` on `mutateWith`/`subscribeWith`. Example network log reads `client.requests`.
18. Perf — `Selection.child`: no-args fast path, arg-bearing children memoized by structural args key (`_ArgsKey`, deep equality, order-free, nulls ignored, `10` ≠ `10.0`), `jsonEncode` + FNV only on a node's first creation.
28. Runtime — `MutationState.data` (last successful result, kept while loading, cleared on failure); only the latest overlapping `mutate` call updates the state; `mutate` never throws (documented).
57. Runtime — Same response name across fragments: printed `<alias>__<Type>: field` per fragment when repeated (type-free, conservative), `PrintedOperation.toCacheKeys` maps responses back (merging direct + fragment selections) after error pruning, for queries, mutations and subscriptions.
26. Runtime — `depKey` separator: not a bug — cache field aliases never contain `.`, so `entity.field` splits unambiguously at the last dot; documented on `depKey`, test with dotted ids.
27. Runtime — `Cache.writeResponse(operation, data, {at})`: unused `selection` parameter dropped.
29. Runtime — Partial mutation errors: optimistic writes are rolled back *before* the resolved fields are written (server values win), `ROOT_MUTATION` fields removed on failure too; still a failure (throws / `state.error`, no body re-run, no `refetchQueries`). Documented on `mutateWith` + guides/mutations.
38. Example — `LaunchScreen.open` prefetches the detail query with `client.resolve()`; explicit `Normalization(keyField: 'id')`; live `CacheStats` (`snapshot`/`onChange`) on the network log screen.
39. Example — `.vscode/` launch/tasks/settings are tracked (nothing to do).
40. Example — Latency picker (Server/Off/500 ms/2 s) on the network log screen; `x-mock-latency-ms` header honoured per request by the mock API, injected by the example's transport.
33. Runtime — 64-bit FNV-1a aliases (`Selection.fnv1a64`, on 32-bit halves so web = native); all hashed aliases changed once (persisted caches, if any, start cold).

58. Example — Web platform + in-browser mock API: `mock-api/app.mjs` (`createMockYoga`, Node-free) served by `server.mjs` and bundled from `browser.mjs` (`npm run build:browser` → `example/web/mock-api.js`); `example/lib/in_browser_api.dart` swaps the `http.Client` on web (queries, mutations, SSE streamed from the Fetch `Response`); `melos run build:web` → `website/public/demo/`; site page `guides/try-it` with `LiveApp.astro` (click-to-load iframe, restart); CI builds the web target, `website.yml` ships it.
59. Docs — Live demo per concept: `example/lib/demos/` (`DemoHarness`: own client per run, request panel; `?demo=batching|fetch-policies|optimistic`), `DemoSource.astro` pulls `// #region` blocks into the guides (shown code = running code), `LiveApp demo=`; embedded in batching, fetch-policies and mutations guides; `example/test/demos_test.dart`. Found and fixed on the way: a builder saw the previous run's `isStale` / background `isLoading` (the scope now re-runs once when they change).

Tour follow-ups done (2026-09-29): the detail screen's "Show payloads — no request, thanks to prepare" toggle is gone (payloads are a plain section, like Crew; unknown mass omitted), with the matching test step and docs; no debug banner in `SlingApp`.

61. Example — Plain-language copy: the schedule screen says what you will see (the launch appears, lifts off and lands on its own), `ErrorView` only suggests `npm start` on iOS, the latency picker's no-header option is "Default".
63. Example — Tour UI fixes: rows name their status next to the date (the icons' legend) and a Scrubbed segment; masses as `5,000,000 kg` (`number_format.dart`); crew as name + agency; launch details in full, rocket description three lines + More/Less.
64. Docs — Stale statements sweep: landing (runtime size/deps, normalized cache, generated snippet with enums and `keyed:`, "Try it live" action), getting-started (independent versions, Dart enums, `launch?.isFetched`), querying (Dart enums aside and arguments), loading-and-errors (row excerpt), caching (`Company` is keyed, optimistic writes, history lines), mutations (list rule in the example, `scheduleLaunch(input:)`), example-app (favourites limitation gone, tests in order), feasibility ("since then"), every client built with `schema: slingSchema`.
66. Example — Nicer skeletons: `SkeletonShimmer` (one animation for every placeholder, runs only while one is on screen, off with reduced motion), pill bars as tall as a line of the style with a fade to the text, `SkeletonBox.circle` for icons, eight varied-width placeholder rows while the Launches list loads.
62. Example — Network log: "N requests" button; Requests · Subscriptions · Dev tools; one line per request (number, type, root fields by name, time, duration, size, variables; red with the error on failure), tap for the document, the response and "Copy document"; documents without `__typename`/aliases unless switched on; bundled JetBrains Mono (the web has no system monospace); plain cache labels ("20 launches · 4 rockets"); Clear. `NetworkLog.transport` records status/size/time. Which widget caused a request: #46 (`← _Header, LaunchesScreen`).
65. Docs — Missing examples: a `prepare` demo in the batching guide (Without/With prepare, 2 requests vs 1 on "Show payloads"), prefetch on tap with `client.resolve` in querying (`LaunchScreen.open`), a complete screen in loading-and-errors (the Me tab: error + retry, pull-to-refresh, empty state guarded on `isSkeleton`, and `ErrorView`), "Five minutes with the mock API" in getting-started. `DemoSource` reads any `example/lib/<dir>/`.
60. Docs — Live demos in four more guides: loading & errors (`errors`: placeholders, a sticky error, Retry), pagination (`pagination`: load more fetches one page, refresh both), caching (`caching`: a detail served from the list's entity, a cache write, SlingRow vs plain rows with build counters), subscriptions (`subscriptions`: an event updates banner and row, no request). Harness: `failRequests`, subscriptions counted apart. Multi-view embedding moved to #67.
67. Docs — One Flutter engine for every demo: `LiveApp` demos are views of a shared engine started with `multiViewEnabled` (`web/flutter_bootstrap.js` template hands over to `window.slingDemoHost`; `DemoViews` runs one `View` per host, demo from the initial data). Loaded once per visit, survives `<ClientRouter />` navigations (views removed before a swap, a demo re-mounts in ~30 ms), iframe fallback on failure; the whole app on Try it stays an iframe. The in-page mock API is shared by the demos of a visit.

22. Perf — Automatic GC: `SlingClient(gcAfterWrites: 100)` sweeps once idle after N responses (`null` = manual); `client.gc()` retains entities live scopes/rows read (`Cache.gc(retain:)`), skips while a mutation is in flight; collected entities lose their `fetchedAt` stamps. App pause: `AppLifecycleListener(onPause: client.gc)` recipe in guides/caching.

21. Perf — Coalesced `Cache.onChange` (once per change: `Cache.batch`; the client batches every response, mutation, optimistic callback and subscription event; `gc` reports removals), `Cache.version` + `changesSince(v)` → `CacheDelta` (changed entities only, removed keys, `full` after `clear`/dropped removal record, `applyTo`); `snapshot` ~40% faster (still a deep copy: entities are merged in place). Example CacheStats shows the incremental save.
47. DX — `packages/sling_gql_hooks`: `useSlingQuery` / `useSlingMutation` / `useSlingSubscription` on `createScope` / `mutateWith` / `subscribeWith`, returning the runtime's `QueryState` / `MutationState` / `SubscriptionState` (now publicly constructible); guides/hooks. Not on pub.dev yet (needs `sling_gql` 0.3.0 first).
48. Runtime — `packages/sling_gql_link`: `linkTransport` / `linkSubscriptionTransport` turn a `gql_link` chain into the client's transports, `SlingLinkException` (HTTP status kept for unparsable error pages); gql_link section in guides/transport; runtime stays `http`-only. Not on pub.dev yet.
54. Perf — Inline lists notify per element: reads through an inline element of an entity-field list record `entity.field[i]`, `Accessor.list` of inline objects `entity.field[length]` (`Cache.readListField`); writes touch changed elements + length on resize; keyed/scalar lists unchanged (`elementDepKey`/`lengthDepKey` in `internal.dart`; ~4–6% on the warm read bench).

49. Runtime — `packages/sling_gql_sqflite`: `SqflitePersistence.open(path, schema:)` restores the cache before the client starts (optionally in an isolate), saves `changesSince` deltas in one transaction (debounced 1 s / max 5 s, flushed on app pause, serialized, retried after failure), one row per entity and per `ROOT_QUERY` field with `updated_at`; bounds `maxAge` 7 d + `maxEntities` 10k pruned on the stored JSON at open; wipes on format / key field / `slingSchema.hash` mismatch (new generated FNV fingerprint of the generated code). Example persists on iOS, web stays in memory. Guide: guides/persistence. Hive/file adapters dropped until needed.
68. Perf — Roots in `CacheDelta` field by field (`changedFields` / `removedFields`, per-field stamps on the operation roots, a root copied whole only for versions before its removal or a stamp purge; `applyTo` merges): `changesSince` at 10k entities 0.8 → 0.1 ms, a delta save 4 → 2–3 ms; `sling_gql_sqflite` writes exactly those root rows. `NormalizedCache.adopt` hydrates decoded JSON in place (no second copy): open at 10k 57 → 46–57 ms — `jsonDecode` is ~30 ms of it, the copy was less than estimated.
69. Perf — `Cache.compact(upTo:)`: a store acknowledges what it saved, the change records up to it go (older versions get `full`); a compacted cache only forgets its removals past 100 000. `SqflitePersistence(compact: true)` compacts after each save (the example turns it off: `CacheStats` reads its own deltas) and deletes rows in chunked `IN (…)` statements. Save after a `gc` of 60% at 10k: ~90 → 37–44 ms (70–92 ms without compact); `changesSince` 0.03 ms.
50. Runtime — Type policies: `SlingClient(typePolicies: {Query: TypePolicy(fields: {...})})` keyed by the generated accessor class (exact `runtimeType`, bound once per selection node); `FieldPolicy(keyArgs:, merge:)` (+ overridable `covers` / `pageArgs` / `pages` / `fill`), `RelayStylePagination` (pages merged into one list: `nodes`/`edges` spliced, `pageInfo` ends, `__pages` record; unmerged page = skeleton miss; first page resets). `Selection.cacheKey` (key args only) vs `alias` (response name), `PrintedOperation.toCacheKeys` → `PolicyWrite`, merged in `NormalizedCache` before the structural merge. Whole-selection fetches send first pages only (refresh resets); a field read inside a merged entry fetches every held page as a fill (no re-merge; entities no page returns leave). `PaginationController` holds the pending cursor, `PaginatedQueryBuilder` reads the merged list; example `type_policies.dart`. Guides: pagination, caching (type policies).

## Explicitly not planned

- SSR hydration (not applicable).
- `graphql-ws` (WebSocket) subscriptions in the core: SSE stays the only
  built-in transport; a separate adapter package maybe later
  (`SlingClient(subscriptionTransport:)` already allows it).
- Lazy / transaction / paginated query *variants* as separate APIs:
  `resolve()` plus widget state (and #5's helper) cover the same ground.
