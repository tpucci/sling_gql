# TODO — sling_gql

Single backlog for the PoC, ordered roughly by value. Items are numbered so
they can be picked one at a time ("do #23"). Numbers stay stable; done items
move to the **Done** section at the bottom (one line each). Sources: the
DX/performance review of the example app (2026-09), smaller issues noticed
while building the normalized cache and mutations, and the roadmap (website
`internals/roadmap.mdx`, folded in as items 46+).

Roadmap status: ~~normalized cache~~ · ~~mutations~~ · ~~pagination helper~~ ·
~~transport hook~~ · fine-grained rebuilds done but #54 ·
~~expiry/SWR~~ · ~~subscriptions~~ · ~~unions~~ (#57 left) · dev experience #46, #47 ·
`gql_link` #48.

Status (2026-09-27): P0 and P1 done (#1–#16); fetch policies + SWR (#23,
#52); example/docs sweep done (#34–#37, #41, #42); pub workspace + melos and
pub.dev-ready packages (#43), CI + tag-triggered pub.dev publishing (#44); API surface split (#32).
Per-row rebuilds (#19, #20) done. Unions & interfaces (#31) done.
Suggested next picks: #17/#18
(read-path allocations), #57 (conflicting fields across fragments).

Legend: **DX** developer experience · **Perf** runtime performance ·
**Runtime** features/config · **Gen** generator · **Example** · **Test** ·
**Docs/Repo**.

## P2 — performance follow-ups (measured: 506 ns/read, 38× raw maps)

17. **Perf — Allocation per read.** Each getter allocates `[...path, alias]`,
    a `'$entity.$field'` dep string, and an empty args map in `_aliasFor`.
    Intern dep keys per `(entity, field)`, give accessors a parent pointer
    instead of a copied path, skip the map when `args` is empty.
18. **Perf — Alias hashing on every build.** Arg-bearing fields re-run
    `jsonEncode` + FNV on every `child()` call. Cache the alias on the
    `Selection` node / memoize per args map identity.
21. **Perf — `snapshot` is a full deep copy** and `onChange` fires per write;
    persistence adapters will need debouncing and incremental snapshots.
22. **Perf — `gc()` is manual.** Entities dropped from a replaced list stay
    until `gc()`; decide on a trigger (after N writes, on app pause).

## P3 — runtime configurability & correctness

26. **Runtime — `depKey` uses `'.'` as separator**; an id containing
    `.fieldname` could collide (only causes an extra rebuild, never a missed
    one). Use a non-printable separator or a record key.
27. **Runtime — `Cache.writeResponse` takes an unused `selection`
    parameter.** Either use it (typed merge policies) or drop it.
29. **Runtime — Partial mutation errors** write the resolved fields then
    reject; document the semantics or make it a policy.
33. **Runtime — 32-bit FNV alias.** Collision is theoretical but would merge
    two arg sets silently; consider 64-bit or include a length/checksum.

57. **Runtime/Gen — Same response name, conflicting types across
    fragments.** `... on Launch { status }` (`LaunchStatus!`) next to
    `... on Launchpad { status }` (`String!`) fails GraphQL validation
    (FieldsInSetCanMerge): aliases are derived from arguments only. Needs a
    type-aware alias (the generator knows the field types) that still maps
    back to the entity field name when writing to the cache.

## P4 — example app & tooling

38. **Example — Show more of the API**: `client.resolve()` (imperative
    prefetch) is never used or documented in the example; `Normalization`
    config, `cache.snapshot`, `onChange` likewise.
39. **Example — `.vscode/` is ignored by a global gitignore** on this machine,
    so the launch configs are not shared. Force-add them (`git add -f`) or
    document the setup in README.
40. **Example — `LATENCY_MS` toggle in-app** to make skeletons visible on
    demand. (The per-row half is done: `LaunchRow` is a `SlingRow`, #19.)

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
28. Runtime — `MutationState.data` (last successful result, kept while loading, cleared on failure); only the latest overlapping `mutate` call updates the state; `mutate` never throws (documented).

## Explicitly not planned

- SSR hydration (not applicable).
- Lazy / transaction / paginated query *variants* as separate APIs:
  `resolve()` plus widget state (and #5's helper) cover the same ground.
