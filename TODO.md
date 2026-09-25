# TODO — sling_gql

Single backlog for the PoC, ordered roughly by value. Items are numbered so
they can be picked one at a time ("do #3"). Sources: the DX/performance review
of the example app (2026-09), smaller issues noticed while building the
normalized cache and mutations, and the roadmap (website
`internals/roadmap.mdx`, folded in below as items 46+ where not already
covered). Numbers stay stable; strike items when done.

Roadmap status: ~~normalized cache~~ done · ~~mutations~~ done ·
fine-grained rebuilds mostly done (#19, #20) · subscriptions #30 · unions
#31 · expiry/SWR #23 · dev experience #1, #46, #47 · transport #6, #48.

P0 status (2026-09-25): #1–#5 done; **#6 (transport hook) is the only P0
left** — next pick.

Legend: **DX** developer experience · **Perf** runtime performance ·
**Runtime** features/config · **Gen** generator · **Example** · **Test** ·
**Docs/Repo**.

## P0 — biggest multipliers

1. ~~**DX — Dev-mode waterfall warning.**~~ done: `SlingClient(warnOnWaterfall:,
   onWaterfall:)` (on when asserts are enabled, prints by default),
   `WaterfallWarning(scope, fields)`, `QueryBuilder.debugLabel` (falls back
   to the key, then `QueryScope#n`). Only rebuilds the *client* triggered
   count; `refetch()` and `setState` rebuilds never warn. Follow-up: mention
   it in the batching-and-waterfalls guide; in-app overlay is #46.
2. ~~**Gen — Real Dart `enum`s**~~ done: lowerCamel constants + `unknown`,
   `.graphqlName`, `fromGraphQL`/`toGraphQL` (throws on `unknown` as an
   argument); `Accessor.enumValue`/`enumList`.
3. ~~**Gen — No setter on the key field**~~ done: no setter on the key field,
   on `PageInfo` fields, or on `pageInfo`/`totalCount` of connection types.
   Explicit `write(...)` call deliberately not adopted (setters stay).
4. ~~**Perf — `_notify` iterates the large set.**~~ done:
   `touched.any(scope.deps.contains)`.
5. ~~**DX — Pagination helper.**~~ done: `PaginationController`,
   `ConnectionPage<Node>`, `PaginatedQueryBuilder<Q, Node>` /
   `PaginatedState` in `pagination.dart`; example launches screen uses it.
   Follow-up: `guides/batching-and-waterfalls.mdx` still shows the manual
   `_cursors.add` snippet.
6. **Runtime — Single `transport` hook** on `SlingClient`
   (`Future<Response> Function(Request)`): covers auth headers/token refresh,
   retry, timeout, logging, without adding a link system. Today `headers` is a
   static map and there is no timeout.

## P1 — DX rough edges seen in the example

7. **DX — Three meanings of `null`.** Not fetched / server null / errored path
   all read as `null`; `isSkeleton` lives on the accessor, `hasMissingData` and
   `isLoading` on `QueryState`, nothing on a scalar. Decide on one story
   (e.g. `state.hasMissingData ? Skeleton : …` as the blessed pattern, and a
   `Accessor.isFetched(field)`/`Fetched<T>` helper) and document it on the
   first page of the guides.
8. **DX — Skeleton lists have one element.** `list.length == 1`, `isEmpty ==
   false`, `itemCount` renders a ghost row while loading; the example patches
   this with `&& !state.isLoading`. Provide a loading-aware helper or make the
   rule ("never branch on length while `hasMissingData`") prominent in docs.
9. **DX — Asymmetric mutation API.** `client.mutate(...)` is generated and
   wired; `MutationBuilder<Mutation>(root: Mutation.root, …)` needs the root by
   hand. Generate a typed builder/typedef too, or resolve the root from
   `SlingScope`.
10. **DX — Sticky errors are undocumented at the call site.** A failed scope
    stays failed until `refetch()`. Add doc comments on `QueryState.error` /
    `isLoading` explaining it, recommend pull-to-refresh, consider a
    `retryAfter`/auto-clear option.
11. **DX — `$` renames without explanation.** `type$`, `$typename`, `$eq`.
    Emit a header comment in the generated file describing the scheme.
12. **DX — Cache is opaque to users.** `cache.read('query', ['launches_1qouruf',
    …])` uses hashed aliases nobody can type. Add typed entity access
    (`client.cache.entity<Launch>('1')`-style, generated) and a way to edit
    list membership (see #14).
13. **Gen — Custom scalar mapping.** `DateTime` arrives as `String`
    (`date.substring(0, 10)` in the example). Allow `--scalar DateTime=DateTime`
    with a converter, default to `String`/`Object?` as today.
14. **Runtime — List membership after a mutation (write policies).**
    `me.favorites` / `launches(filter: …)` do not gain or lose a row after
    `toggleFavorite`; only refetch fixes it. Add/remove a `Ref` in a cached list
    (typed API from #12), plus create/delete helpers (`evict` from an accessor).
15. **Runtime — `refetchQueries` sugar** on `mutate` (refetch named scopes /
    root fields after success) as the simple alternative to #14.
16. **Test — `sling_gql_test` helpers.** `pumpUntilSettled(tester, client)`,
    a schema-aware in-memory server/`MockClient` builder, and the folklore
    (`HttpOverrides.global = null`, `pump(Duration)` for transitions,
    `client.dispose()` for keep-alive timers) wrapped so app tests don't
    rediscover it.

## P2 — performance follow-ups (measured: 506 ns/read, 38× raw maps)

17. **Perf — Allocation per read.** Each getter allocates `[...path, alias]`,
    a `'$entity.$field'` dep string, and an empty args map in `_aliasFor`.
    Intern dep keys per `(entity, field)`, give accessors a parent pointer
    instead of a copied path, skip the map when `args` is empty.
18. **Perf — Alias hashing on every build.** Arg-bearing fields re-run
    `jsonEncode` + FNV on every `child()` call. Cache the alias on the
    `Selection` node / memoize per args map identity.
19. **Perf — Per-row rebuild.** A write to one entity rebuilds the whole
    `QueryBuilder` (all built rows). Offer a row-scoped builder (`SlingRow`) or
    per-row scopes for large lists.
20. **Perf — Over-notification for inline containers.** `_mergeEntity` always
    marks a field touched when the value is a `Map`/`List` (no deep compare),
    so `company`/`stats`/`pageInfo` rebuild their readers on every identical
    response. Cheap structural compare for small inline objects.
21. **Perf — `snapshot` is a full deep copy** and `onChange` fires per write;
    persistence adapters will need debouncing and incremental snapshots.
22. **Perf — `gc()` is manual.** Entities dropped from a replaced list stay
    until `gc()`; decide on a trigger (after N writes, on app pause).

## P3 — runtime configurability & correctness

23. **Runtime — Fetch policies.** `cache-first` only today; add per-scope
    `network-only` / `cache-and-network` (fresh detail screen) and
    `maxAge`/stale-while-revalidate (roadmap #2).
24. **Runtime — `QueryBuilder` hardcodes `frameEndScheduler`**; expose the
    scheduler (and document when `microtaskScheduler` is right).
25. **Runtime — `Normalization.keyField` and generator `--key-field` must be
    kept in sync by hand.** Emit the key field from the generator (constant in
    the generated file) and have the client read it.
26. **Runtime — `depKey` uses `'.'` as separator**; an id containing
    `.fieldname` could collide (only causes an extra rebuild, never a missed
    one). Use a non-printable separator or a record key.
27. **Runtime — `Cache.writeResponse` takes an unused `selection`
    parameter.** Either use it (typed merge policies) or drop it.
28. **Runtime — `MutationState` has no `data`**; `mutate` returns `null` on
    error and swallows the exception into `state.error`. Document, and expose
    the last result.
29. **Runtime — Partial mutation errors** write the resolved fields then
    reject; document the semantics or make it a policy.
30. **Runtime — Subscriptions** (SSE; mock exposes `launchStatusChanged`,
    `launchScheduled`). Generator currently skips the Subscription root.
31. **Runtime/Gen — Unions & interfaces (`$on`).** Add one to the mock schema
    first.
32. **Runtime — Public API surface.** `sling_gql.dart` exports `depKey`,
    `NormalizedCache`, `MutationScope`, `Recorder`; mark internals
    `@internal` or move behind a `sling_gql/internal.dart`.
33. **Runtime — 32-bit FNV alias.** Collision is theoretical but would merge
    two arg sets silently; consider 64-bit or include a length/checksum.

## P4 — example app & tooling

34. **Example — Variable names in printed documents.** `$v0`, `$v1` make the
    network log hard to read; use argument names (`$first`, `$after`,
    de-duplicated) — also nicer for server-side logs.
35. **Example — `_ErrorView` duplicated** in `launches_screen.dart` and
    `me_screen.dart`; move to `widgets/`.
36. **Example — `NetworkLog.add` `debugPrint`s in release builds**; guard with
    `kDebugMode`.
37. **Example — `settle()` test helper polls with fixed 100 ms sleeps**; replace
    with a client-level "no scope loading" future once #16 exists.
38. **Example — Show more of the API**: `client.resolve()` (imperative
    prefetch) is never used or documented in the example; `Normalization`
    config, `cache.snapshot`, `onChange` likewise.
39. **Example — `.vscode/` is ignored by a global gitignore** on this machine,
    so the launch configs are not shared. Force-add them (`git add -f`) or
    document the setup in README.
40. **Example — Per-row `QueryBuilder` demo** once #19 exists; and a
    `LATENCY_MS` toggle in-app to make skeletons visible on demand.

## P5 — docs & repo hygiene

41. **Docs — AGENTS.md header still says "proof of concept, queries only"**;
    sweep README/website for the same phrasing.
42. **Docs — Getting-started should show the three-`null` story (#7), the
    waterfall rule and `prepare` on the first page**, not in guides.
43. **Repo — No workspace/melos**: three pubspecs, three test commands, no
    versioning or publish plan. Add a pub workspace (Dart 3.5+) and a single
    `make test`/script that runs all four gates (runtime, generator, example
    with the mock server, website build).
44. **Repo — CI** runs only the website deploy; add the four gates from #43
    (the example test needs the mock server started in the job).
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
51. **Runtime — Weakly held stale entries** (`WeakReference`/`Finalizer`) as
    the eviction mechanism for #23's expiry instead of timers.
52. **Runtime — Soft `refetch()`** that is a no-op when data is within
    `maxAge` (part of #23).
53. **Runtime — Subscription widget** `SubscriptionBuilder<Subscription>`
    (records once, opens the SSE stream, writes each event through
    `writeResponse`) — the widget half of #30; generator must emit the
    Subscription root.
54. **Perf — List-index granularity for inline lists** (today: the whole
    entity field). Remaining half of "fine-grained rebuilds".

## Explicitly not planned

- SSR hydration (not applicable).
- Lazy / transaction / paginated query *variants* as separate APIs:
  `resolve()` plus widget state (and #5's helper) cover the same ground.
