# TODO — sling_gql

Single backlog for the PoC, ordered roughly by value. Items are numbered so
they can be picked one at a time ("do #23"). Numbers stay stable; done items
move to the **Done** section at the bottom (one line each). Sources: the
DX/performance review of the example app (2026-09), smaller issues noticed
while building the normalized cache and mutations, and the roadmap (website
`internals/roadmap.mdx`, folded in as items 46+).

Roadmap status: ~~normalized cache~~ · ~~mutations~~ · ~~pagination helper~~ ·
~~transport hook~~ · fine-grained rebuilds done but #54 ·
~~expiry/SWR~~ · ~~subscriptions~~ · ~~unions~~ · dev experience #46, #47 ·
`gql_link` #48.

Status (2026-09-27): P0 and P1 done (#1–#16); fetch policies + SWR (#23,
#52); example/docs sweep done (#34–#37, #41, #42); pub workspace + melos and
pub.dev-ready packages (#43), CI + tag-triggered pub.dev publishing (#44); API surface split (#32).
Per-row rebuilds (#19, #20) done. Unions & interfaces (#31) done.
Read-path allocations (#17, #18) done. Conflicting fragment fields (#57)
and key/alias collisions (#26, #33) done. Small-items sweep (2026-09-29):
#27, #29, #38, #39, #40 done; P3 is empty. The example runs on the web and
live on the website (#58), with a live demo in the batching, fetch-policies
and mutations guides (#59, 2026-09-29). Suggested next picks: #60 (demos for
the other guides), #22 (`gc()` trigger), #46 (request overlay). Tour of the
guides and the example (2026-09-29): #61–#66.

Legend: **DX** developer experience · **Perf** runtime performance ·
**Runtime** features/config · **Gen** generator · **Example** · **Test** ·
**Docs/Repo**.

## P2 — performance follow-ups (measured: ~330 ns/read, ~25× raw maps)

21. **Perf — `snapshot` is a full deep copy** and `onChange` fires per write;
    persistence adapters will need debouncing and incremental snapshots.
22. **Perf — `gc()` is manual.** Entities dropped from a replaced list stay
    until `gc()`; decide on a trigger (after N writes, on app pause).

## P4 — example app & tooling

60. **Docs — Live demos for the other guides** (after #59: add a widget
    to `example/lib/demos/` with `// #region` markers, register it in
    `demos.dart`, embed `<DemoSource>` + `<LiveApp demo>`, assert what the
    guide says to try in `example/test/demos_test.dart`). Candidates:
    loading states & sticky errors, pagination (`PaginatedQueryBuilder`),
    caching (normalization, `SlingRow`), subscriptions. Later: Flutter
    multi-view embedding (one engine for every demo of a page) instead of
    one iframe each.

61. **Example — Plain-language copy in the app** (tour, 2026-09-29). The app
    explains itself in library jargon:
    - detail screen: drop the payloads toggle ("Show payloads (2) — no
      request, thanks to prepare") entirely — a library demo has nothing to
      do in the app's UI. Payloads become a plain section, like Crew.
      Knock-on: the expand step of `app_test.dart` test 1 ("0 requests to
      expand payloads"), the example-app page (`_showPayloads`, the same
      claim), the batching guide's `prepare` excerpt ("rendered only when
      `_showPayloads` is true"). `LaunchScreen.prepare` stays (the
      `resolve` prefetch uses it); the `prepare` story moves to #65;
    - schedule screen blurb ("subscribes to launchScheduled and
      launchStatusChanged … written into the same Launch:<id> entity the row
      reads") → what the user will *see* ("the row appears, lifts off and
      lands on its own; nothing refreshes");
    - `ErrorView` says "Is the mock API running? `cd mock-api && npm start`"
      on the web too, where there is no server to start;
    - latency picker "Server" → "Default (400 ms)".
62. **Example — Network log polish.** Today: one long scroll of fully
    expanded documents, open subscriptions pinned on top, dev tools mixed in.
    - Title "2 request(s) · 2 subscription(s)" → real plurals.
    - One collapsed line per request: #, operation type, root fields,
      variables, time; tap to expand the document. Newest first, the first
      request of a screen easy to spot.
    - Separate the parts: Requests · Subscriptions · Dev tools (latency,
      cache), e.g. segments, instead of one list.
    - Dim or hide what the printer adds (`__typename`, `id`, aliases) behind
      a toggle, so what the widgets *read* stands out.
    - Duration, status and size per request (the latency transport already
      sees them); errors inline in red; optionally the response JSON.
    - Monospace font: 'Menlo' does not exist on the web build (falls back to
      a proportional font); bundle one or add `fontFamilyFallback`.
    - Cache stats: "31 entities · snapshot 6.7 KB · no change since opened"
      reads as jargon — label it ("Cache: 20 launches, 4 rockets…").
    - "Clear" and "copy document" actions.
    - The antenna + number in the nav bar does not say "network log": a
      label or first-run hint.
    - Which widget/screen caused each request: see #46.
63. **Example — Small UI fixes from the tour.**
    - Status icons have no legend; the grey "pause" (scrubbed) covers most
      of the first screen, and there is no Scrubbed segment.
    - Rocket mass "5000000 kg" unformatted; payload mass "? kg" when unknown.
    - Crew rows are labelled by agency abbreviation (CSA, JAXA) with no
      header: read as field names.
    - Rocket description cut at two lines with no way to expand.
    - The debug banner: `SlingApp`'s `CupertinoApp` has no
      `debugShowCheckedModeBanner: false` (shows in every iOS debug run and
      screenshot; the demos already turn it off).
66. **Example — Nicer skeletons.** Today `SkeletonBox` is a flat
    `kColorSurface` rectangle (radius 4) and `SkeletonText` a box of a
    fixed width, so every placeholder row is identical and nothing says
    "loading". Proposal:
    - one shared shimmer (a gradient sweeping across every placeholder in
      sync, driven by a single ancestor animation, not one controller per
      box), off when the platform asks for reduced motion;
    - pill-shaped text bars sized from the text style (line height, not font
      size) and varied widths per row (seeded by index) so a list looks like
      a list;
    - placeholders that match the real layout: a circle where the status
      icon goes, the detail screen's sections (title, meta line, rocket
      table) instead of a few bars;
    - a short fade from skeleton to content.
    Keep it one file (`widgets/skeleton.dart`) with the same
    `SkeletonText(text, …)` call shape — the guides show it as "all the
    loading UI you need" — and update the loading-and-errors excerpt if the
    API changes. Check that `app_test.dart` still settles (a repeating
    animation must not keep `pumpUntilSettled` busy; it only waits on the
    client).

## P5 — docs & repo hygiene

45. **Repo — Package split when needed**: `sling_gql_core` (pure Dart) vs
    Flutter widgets vs persistence adapters (see architecture doc). Not before
    a second consumer exists.
64. **Docs — Stale statements sweep** (tour, 2026-09-29; fix in one pass):
    - `index.mdx`: "~600 lines of runtime, one dependency (`http`)" (≈4,500
      lines; `http` + `meta`); "deep-merged into a path-addressed cache"
      (normalized now); the generated snippet shows `String? get status` (an
      enum now) and `object('rocket', Rocket.new)` without `keyed:`; no
      "Try it live" action in the hero.
    - `getting-started`: "released in lockstep" (versions are independent:
      0.2.0 / 0.1.2 / 0.1.1); "a constant holder per enum" (real enums since
      #2); `launch.isFetched('details')` on a nullable `launch`.
    - `querying`: the "Enums are strings" aside and `LaunchStatus.SUCCESS`,
      `LaunchOrder.DATE_DESC` in the arguments example (now
      `LaunchStatus.success`).
    - `loading-and-errors`: the launch row uses `date.substring(0, 10)`
      (`DateTime` now) and an undefined `_icon`.
    - `caching`: "`Company` stays inline" (it is keyed); "Optimistic writes
      — when mutations land, the pattern will be…" (they have); "replaced
      the coarse root-alias intersection of the first PoC iteration" and
      "the old path-addressed behaviour" (history, not guidance).
    - `mutations`: "Updating lists after a mutation" shows the hand-written
      `me.favorites` edit and "What is in the example" says the callback
      prepends/removes — the example uses the `favorites` `ListRule` now;
      the `refetchQueries` examples call `scheduleLaunch(name:)` (it takes
      `input:`).
    - `tooling/example-app`: "Known limitation: `me.favorites` membership
      does not update" (fixed by #55); test sections ordered 1, 3, 4, 5, 2, 6.
    - `internals/feasibility`: "What we would need to believe to go to
      production" lists normalization, mutations, subscriptions — all done.
      Keep it as the day-one record, add a short "since then".
    - Consistency: transport, subscriptions, testing and fetch-policies build
      clients with `rootFactory: Query.root`, the rest with
      `schema: slingSchema` — use the latter everywhere; `testing` types `me`
      as `User`, the schema's is `Viewer`.
65. **Docs — Missing examples.**
    - `prepare`: the batching guide's excerpt hides the point
      (`LaunchScreen.prepare(launch); // reads payloads, crew, rocket…`).
      Show the collapsed section, the request it costs without `prepare`
      (a second one, on tap), and the one request with it. A demo fits (#60).
    - Prefetch on tap with `client.resolve` (the example's
      `LaunchScreen.open`) is only on the example-app page; add it to
      querying ("Reading outside of build()").
    - `ErrorView` is used in getting-started and loading-and-errors but never
      shown: one complete error + retry + pull-to-refresh widget.
    - The "never branch on list length while loading" rule is stated three
      times and never shown as a complete widget with a real empty state.
    - Getting started targets an imaginary `api.example.com` only: add the
      five-minute path against the mock API (or point at Try it live first).

## Roadmap items not covered above

46. **DX — In-app request overlay.** Attribute each request to the widgets
    that recorded it (builds on #1's per-scope attribution); a `pixel`-style
    one-line log per operation (duration, bytes, fields, scopes).
47. **DX — `flutter_hooks` adapter** (`useSlingQuery`, `useSlingMutation`) on
    top of `QueryScope`/`mutateWith`, as a separate small package.
48. **Runtime — `gql_link` adapter** for auth, retries and persisted queries,
    implemented as one `transport` (#6) so the runtime stays `http`-only.
49. **Runtime — Persistence adapters** (`sling_gql_hive`, `sling_gql_sqlite`,
    file) on `Cache.snapshot` / `Cache(initial:)` / `Cache.onChange`, with
    the debouncing from #21. Separate packages, never in core.
50. **Runtime — Type policies**: custom merge per field and connection
    merging (Apollo `relayStylePagination`-style) so pages can live in one
    growing cache list instead of one entry per cursor (pairs with #5).
    Membership half done: `ListRule` (#55). Left: merge policies / position.
51. **Runtime — Weakly held stale entries** (`WeakReference`/`Finalizer`) as
    an eviction mechanism for data past `maxAge` (#23 only revalidates, never
    drops).
54. **Perf — List-index granularity for inline lists** (today: the whole
    entity field). Remaining half of "fine-grained rebuilds".

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

## Explicitly not planned

- SSR hydration (not applicable).
- Lazy / transaction / paginated query *variants* as separate APIs:
  `resolve()` plus widget state (and #5's helper) cover the same ground.
