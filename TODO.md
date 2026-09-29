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
#27, #29, #38, #39, #40 done; P3 and P4 are empty. Suggested next picks:
#22 (`gc()` trigger), #46 (in-app request overlay).

Legend: **DX** developer experience · **Perf** runtime performance ·
**Runtime** features/config · **Gen** generator · **Example** · **Test** ·
**Docs/Repo**.

## P2 — performance follow-ups (measured: ~330 ns/read, ~25× raw maps)

21. **Perf — `snapshot` is a full deep copy** and `onChange` fires per write;
    persistence adapters will need debouncing and incremental snapshots.
22. **Perf — `gc()` is manual.** Entities dropped from a replaced list stay
    until `gc()`; decide on a trigger (after N writes, on app pause).

## P5 — docs & repo hygiene

45. **Repo — Package split when needed**: `sling_gql_core` (pure Dart) vs
    Flutter widgets vs persistence adapters (see architecture doc). Not before
    a second consumer exists.

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

## Explicitly not planned

- SSR hydration (not applicable).
- Lazy / transaction / paginated query *variants* as separate APIs:
  `resolve()` plus widget state (and #5's helper) cover the same ground.
