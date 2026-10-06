# API audit for 1.0 (TODO #73)

## Decisions (owner, 2026-10)

- **All proposals approved** (B1–B6, G1–G3, T1, A1–A2) — and applied **without
  deprecation shims**: there are no external users yet, so renamed/removed
  APIs are gone outright (`SubscriptionState.retry`, the public `QueryScope`
  constructor, `SlingScope(mutationRoot:)`, `--part-of-import`,
  `sling_gql_test`'s `GraphQLError`). Commits carry `!` + `BREAKING CHANGE:`
  footers. The deprecation policy (≥ 1 minor, removed in the next major)
  applies from 1.0 on.
- "Proof of concept" wording is dropped everywhere (pubspecs, READMEs,
  library docs, website, AGENTS.md).
- All six packages go to **1.0.0 together** and share a major version
  (policy: `website/src/content/docs/internals/versioning.mdx`).
- Benchmarks in CI: ratio metrics, median of 5 runs, fail above 1.5× the
  committed baseline (`scripts/bench.mjs`, `scripts/bench-baseline.json`).

Where this document says "deprecated alias kept", "deprecate" or "hidden,
deprecated" below, read "removed": that was the proposal, the decision above
replaced it.

Scope: the public surface of the six packages as of `main` @ `2a6347b`
(after #50, #70, #71, #72). Published baselines: `sling_gql` 0.2.2,
`sling_gql_gen` 0.1.4, `sling_gql_test` 0.1.1+2, `sling_gql_hooks` 0.1.0+1,
`sling_gql_link` 0.1.0+1, `sling_gql_sqflite` 0.1.0.

**Unreleased since those tags** (47 commits): type policies / pagination
merge (#50), the typed error model, `errorPolicy`, `timeout`, `retry`,
`SlingAuth` (#70), the persistence migration and the offline mutation queue
(#72). Anything introduced there was never on pub.dev, so it can still be
renamed without a deprecation shim. Marked *(new)* below.

Verdicts: **keep** · **internal** (move to `internal.dart` / mark
`@internal`) · **protect** (`@protected`: for generated subclasses only) ·
**hide** (private) · **rename** · **deprecate** · **add** (additive fix).

Method: read every exported declaration; `public_member_api_docs` run on each
`lib/` (counts below); usages searched across packages, example, website.

## sling_gql — `package:sling_gql/sling_gql.dart`

### Client and scopes

| Symbol | Verdict | Reason |
| --- | --- | --- |
| `SlingClient` (ctor: `endpoint`, `rootFactory`/`schema`, `cache`, `httpClient`, `transport`, `subscriptionTransport`, `headers`, `onOperation`, `warnOnWaterfall`, `onWaterfall`, `retryFailedAfter`, `fetchPolicy`, `maxAge`, `listRules`, `typePolicies`, `subscriptionRetryAfter`, `gcAfterWrites`, `logRequests`, `errorPolicy`, `timeout`, `retry`, `mutationQueue`, `mutationQueueBackoff`) | keep | The app's one entry point. All config is `final`; `Duration` everywhere for time. |
| `SlingClient.dispose()` | keep, **fix semantics** | Closes the `httpClient` it was *given* too (it only owns the one it creates). Proposal B6. |
| `SlingClient.endpoint`, `.rootFactory`, `.cache` | keep, document | No dartdoc today. |
| `SlingClient.onOperation` | keep | Overlaps `requests`, but it is synchronous, cheap and used by the guides/demos to count documents. |
| `SlingClient.createScope` / `resolve` / `mutateWith` / `subscribeWith` / `cacheScope` / `gc` / `isIdle` / `whenIdle` / `requests` / `activeSubscriptions` / `listRules` / `addListRule` | keep | Parameter names and order are consistent: `body` positional, then `fetchPolicy, maxAge, errorPolicy, timeout` (queries) / `optimistic, refetchQueries, debugLabel, errorPolicy, timeout, retry, offline, onQueued` (mutations). |
| `replayQueue` / `clearMutationQueue` / `queuedMutations` / `onQueuedMutationFailed` *(new)* | keep | |
| `SlingSchema<Q, M>` | keep | Subscription root untyped (`RootFactory<Accessor>?`): adding a third type parameter would break every hand-written `SlingSchema<Query, Mutation>`; the generated constant is the only producer. |
| `SlingSchema.hash` / `.fields` | keep | Persistence contract (documented). |
| `RootFactory` | keep | |
| `FetchPolicy`, `ErrorPolicy` *(new)*, `RetryPolicy` *(new)*, `SlingAuth` *(new)* | keep | `RetryPolicy.delayFor` stays public (custom transports reuse the backoff). |
| `QueryScope` | keep type; **deprecate constructor** | A `QueryScope(client, …)` built directly is not registered with the client (never notified, never fetched for): only `createScope` works. Nobody calls it. Proposal B2. |
| `QueryScope.run/refetch/revalidate/row/dispose/whenSettled/isLoading/hasMissingData/isStale/error`, `ownerOf` | keep | Adapter surface (`sling_gql_hooks` runs a scope itself). |
| `QueryScope.onMiss/onWrite/deps/root/cache/operation/typePolicies` | keep | `Recorder` implementation; documented as runtime-only on `Recorder`. |
| `CacheScope`, `CacheList`, `ListRule`, `ListPosition` | keep | `CacheScope(client)` duplicates `client.cacheScope` but is harmless. |
| `ListRule.evaluate` | **internal** | Client-only helper (`@internal`). B4. |
| `WaterfallWarning`, `SlingRequest` | keep | `SlingRequest.kind` is a `String` (`query`/`mutation`/`subscription`) like `Recorder.operation`; an enum would be nicer but the string is also the cache root's name. `startedAt`, `isDone` undocumented. |
| `Transport`, `SubscriptionTransport`, `sseSubscriptionTransport` | keep | **Leak `package:http` types** (`http.Request`/`http.Response`/`http.Client`) — deliberate: the runtime is http-based, `sling_gql_link` adapts the rest. Consequence for the policy: a new `http` major is a `sling_gql` major. |
| `SlingSubscription` | keep | `onStatusChanged` is a **mutable single-listener callback** (the builder and the hook set it). Odd next to the `Stream`s elsewhere, but only adapters use it; documented as such instead of a breaking change. |
| `FlushScheduler`, `microtaskScheduler`, `frameEndScheduler` | keep | |

### Widgets

| Symbol | Verdict | Reason |
| --- | --- | --- |
| `SlingScope` (`client`, `child`, `schema`, `mutationRoot`), `of`, `clientOf`, `mutationRootOf`, `subscriptionRootOf` | keep; **deprecate `mutationRoot:`** | Predates `schema:`; `schema:` (or the client's own `schema`) supplies the mutation root *and* the subscription root. Two ways to do one thing. Proposal B3. |
| `QueryBuilder` (`builder`, `prepare`, `debugLabel`, `fetchPolicy`, `maxAge`, `errorPolicy`, `timeout`, `scheduler`) | keep | Same knobs, same names as `createScope` / `useSlingQuery`. |
| `QueryState`, `QueryWidgetBuilder` | keep | `const QueryState(scope)` is public for adapters. |
| `SlingRow`, `RowWidgetBuilder` | keep | |
| `MutationBuilder` (`root`, `builder`, `debugLabel`), `Mutate`, `MutationState`, `MutationWidgetBuilder` | keep | |
| `SubscriptionBuilder`, `SubscriptionWidgetBuilder` | keep | |
| `SubscriptionState.retry` | **rename → `reconnect`** (deprecated alias) | `retry` is a `RetryPolicy` everywhere else since #70 (`SlingClient.retry`, `mutateWith(retry:)`); this one is a `void Function()` that calls `SlingSubscription.reconnect()`. Proposal B1. |
| `PaginatedQueryBuilder`, `PaginatedState`, `PaginationController`, `ConnectionPage`, `PageSelector`, `PaginatedWidgetBuilder` | keep; **add** | `PaginatedQueryBuilder` wraps a `QueryBuilder` but forwards none of its knobs (`debugLabel`, `fetchPolicy`, `maxAge`, `errorPolicy`, `timeout`, `scheduler`); `PaginatedState` lacks `isSkeleton` / `isStale` / `revalidate` that `QueryState` has. Additive (A1). |
| `SlingRequestOverlay` | keep | |
| `maybeSlingClientOf` (src only, not exported) | keep hidden | Used by the overlay across files. |

### Generated-code contract

| Symbol | Verdict | Reason |
| --- | --- | --- |
| `Accessor` (ctor `(recorder, selection, path)`, `recorder`, `selection`, `path`, `isSkeleton`, `$typename`, `isFetched`) | keep | What generated classes extend and apps read (`isSkeleton`, `isFetched`). |
| `Accessor.scalar/scalarList/scalarAs/scalarListAs/enumValue/enumList/object/list/on/whenType/write` | **protect** (`@protected`) | Generated getters/setters call them from the subclass; on an app's `launch.scalar('x')` they bypass the typed API (and the generator's key/lookup flags). `@protected` = an analyzer warning outside subclasses, no runtime change. Proposal B5. |
| `Recorder` | keep | Abstract class generated constructors take (`Query.root(Recorder r)`); its `onWrite(CacheWrite)` names an `internal.dart` type: apps never implement it (stated in its doc). |
| `Arg` | keep | Generated args map. Undocumented → document. |
| `Selection` | keep type; **internal members** | Generated constructors pass it through; apps read `field`/`alias`/`args`/`children` at most (debug). The tree-building and policy machinery — `cacheKey` (mutable), `fillOnly`, `isObject`, `keyField` (mutable fields), `child`, `objectChild`, `fragment`, `childByAlias`, `bindPolicy`, `policy`, `policyBound`, `sameEntry`, `ensurePath`, `mergeFrom`, `ensureFillPath`, `covers`, `childAliases`, `argValues`, `fnv1a64` — is the runtime's: mark `@internal`. Proposal B4. |
| `PrintedOperation` (`document`, `variables`, ctor) | keep; **internal** `from`, `toCacheKeys`, `renamesFields` | Seen by apps through `onOperation` / `SlingRequest.operation`; printing and response remapping are runtime internals. B4. |

### Cache

| Symbol | Verdict | Reason |
| --- | --- | --- |
| `Cache` (factory `Cache({normalization, initial})`, `fetchedAt`, `evict`, `gc`, `hasEntity`, `entityKeys`, `entity`, `batch`, `onChange`, `version`, `changesSince`, `compact`, `snapshot`, `clear`, `normalization`) | keep | Path-level `read/readField/readListField/write/remove/writeResponse` already `@internal`. **Not meant to be implemented outside the package** (new members can arrive in minors): say so in its doc and in the policy rather than adding a class modifier (the client's `_BypassCache` implements it from another library). |
| `CacheDelta` | keep | Persistence contract. |
| `Normalization` (`keyField`, `identify`, `none`, `lookup`, `selectedKeyField`, `enabled`) | keep | |
| `FieldPolicy`, `FieldMerge`, `FieldMergeContext`, `TypePolicy`, `RelayStylePagination` *(new)* | keep | `covers`/`pageArgs`/`pages`/`fill`/`merges`/`isKeyArg` are documented override points for custom paginations. |

### Errors and offline queue *(new)*

| Symbol | Verdict | Reason |
| --- | --- | --- |
| sealed `SlingException` + 7 `final` subclasses, `SlingGraphQLError` | keep | Sealed hierarchy: adding a subclass later is a breaking change for exhaustive `switch`es — policy must say so. `SlingException.from`, `SlingHttpException.fromBody` stay public for custom transports. |
| `QueuedMutation`, `MutationQueueStore`, `InMemoryMutationQueueStore`, `QueuedMutationFailure` | keep | Store interface is for persistence adapters (`sling_gql_sqflite`). `encodeRollback`/`decodeRollback`/`rollbackEntities` stay unexported. |

### `package:sling_gql/internal.dart`

| Symbol | Verdict | Reason |
| --- | --- | --- |
| `NormalizedCache`, `CacheWrite`, `PolicyWrite`, `depKey`, `elementDepKey`, `lengthDepKey`, `Ref`, `missing`, `ListLocator`, `MutationScope`, `SubscriptionScope`, `RowScope`, `debugOwnerLabel` | keep internal | Nothing an app needs: `sling_gql_sqflite` uses `NormalizedCache.adopt`, `sling_gql_hooks` uses `debugOwnerLabel`; both are first-party and move in lockstep. No app-facing feature requires `internal.dart` (checked: example app imports only the main library). |

Undocumented public members (`public_member_api_docs`): 124, mostly
constructors and self-explanatory fields. The ones whose semantics are not
obvious get a doc comment (A2): `SlingClient.endpoint/rootFactory/cache`,
`Arg`, `Cache.hasEntity/entityKeys/clear`, `SlingRequest.startedAt/isDone`,
`ListRule.position`, `SlingRequestOverlay.client/enabled`.

## sling_gql_gen

| Symbol | Verdict | Reason |
| --- | --- | --- |
| CLI `--schema`, `--endpoint`, `-H/--header`, `--out`, `--key-field`, `--scalar` | keep | |
| CLI `--part-of-import` | **rename → `--runtime-import`** (old flag kept, hidden, deprecated) | It overrides the `import 'package:sling_gql/sling_gql.dart'` line; nothing to do with `part of`. Proposal G2. |
| Library: `generate`, `generatedCodeHash`, `IntrospectionSchema`, `ScalarMapping`, `introspectionQuery` | keep | The programmatic API (build_runner-style use, the soak test). |
| Library: `naming.dart` (`dartKeywords`, `sanitize*`, `dartStringLiteral`, `docCommentLines`, …), `scalars.dart` (`scalarDartType`, `isKnownScalar`, `ScalarRegistry`), `type_ref.dart`, `type_resolver.dart`, `Gql*` model classes | **hide from the library export** | Emitter internals exported wholesale (`export 'src/naming.dart';`): every rename in the emitter is a breaking change today. Tests import `src/`. Proposal G1 (the model classes stay reachable as the types of `IntrospectionSchema`'s members: export `GqlType`, `GqlField`, `GqlInputValue`, `GqlEnumValue`, `TypeRef` too, the rest goes). |
| Generated `SlingMutations.mutate` / `SlingSubscriptions.subscribe` | **add `debugLabel:`** | `mutateWith`/`subscribeWith` take it; the typed wrappers drop it. Additive, regenerates the example and soak schemas. Proposal G3. |
| Generated header | keep | Compatibility statement goes to the policy (see below), not into every file. |

## sling_gql_test

| Symbol | Verdict | Reason |
| --- | --- | --- |
| `MockGraphQLServer` (`query`, `mutation`, `subscription` maps, `latency` mutable, `requests`, `lastRequest`, `failNext`, `pendingFailures`, `httpClient`, `transport`, `subscriptionTransport`, `client`, `handle`, `execute`, `subscribe`, `openSubscriptions`) | keep | Mutable maps / `latency` are intentional (tests change answers mid-way). |
| `MockRequest`, `MockFailure` *(new)*, `Resolver` | keep | |
| `GraphQLError` | **rename → `MockGraphQLError`** (deprecated typedef alias) | Clashes with `gql_exec`'s `GraphQLError`, which every `sling_gql_link` user imports (`sling_gql_link`'s own test needs `as mock`). Proposal T1. |
| `ParsedOperation`, `ParsedField`, `parseOperation`, `GraphQLSyntaxError` | keep | `MockRequest.operation` is a `ParsedOperation`. |
| `pumpUntilSettled`, `SlingWidgetTester`, `useRealNetwork`, `disposeAfterTest` | keep | `dart:io` (`useRealNetwork`): VM tests only, documented. |

## sling_gql_hooks

| Symbol | Verdict | Reason |
| --- | --- | --- |
| `useSlingQuery(select, {fetchPolicy, maxAge, errorPolicy, timeout, debugLabel, scheduler})` | keep | Same names/defaults as `QueryBuilder` (`select` plays `builder`+`prepare`). |
| `useSlingMutation({root, debugLabel})` | keep | Mirrors `MutationBuilder`. |
| `useSlingSubscription(select, {root, onEvent, retryAfter, debugLabel})` | keep | Mirrors `SubscriptionBuilder`; picks up B1 (`state.reconnect`). |

## sling_gql_link

| Symbol | Verdict | Reason |
| --- | --- | --- |
| `linkTransport`, `linkSubscriptionTransport`, `slingExceptionFromLink` | keep | Small, consistent. Leaks `gql_link` types by design (the adapter's purpose). |

## sling_gql_sqflite

| Symbol | Verdict | Reason |
| --- | --- | --- |
| `SqflitePersistence.open(path, {schema, databaseFactory, maxAge, maxEntities, debounce, maxWait, hydrateInIsolate, flushOnLifecycle, compact, codec, onError, now})` | keep | |
| `cache`, `mutationQueue` *(new)*, `loaded`, `debounce`, `maxWait`, `compact`, `codec`, `superseded`, `savedVersion`, `database`, `flush`, `clear`, `close` | keep | `database` exposes sqflite's `Database` — an adapter's own dependency, documented "inspection only". |
| `SqfliteLoadReport`, `SqfliteSupersededException`, `SqfliteCodec` *(new)*, `sqfliteFormatVersion` | keep | |

## Inconsistencies found (and what happens to them)

1. `SubscriptionState.retry` is a callback, `retry` is a `RetryPolicy` elsewhere → B1.
2. Three ways to name a root factory: `SlingClient(rootFactory:)`, `SlingScope(mutationRoot:)`, `MutationBuilder(root:)`. `schema:` supersedes the first two; `root:` on a builder is a per-widget override → deprecate only `mutationRoot:` (B3), keep `rootFactory:` for hand-written roots.
3. `QueryScope`'s public constructor builds an unregistered scope → B2.
4. Generated typed wrappers drop `debugLabel:` → G3.
5. `PaginatedQueryBuilder` forwards none of `QueryBuilder`'s knobs; `PaginatedState` lacks `isSkeleton`/`isStale`/`revalidate` → A1.
6. `SlingClient.dispose()` closes an `httpClient` it does not own → B6.
7. `onStatusChanged` (mutable callback) vs `onChange`/`requests`/`onQueuedMutationFailed` (streams) → kept, documented (adapter-only).
8. `Selection` exposes mutable fields (`cacheKey`, `fillOnly`, `isObject`, `keyField`) and tree surgery → B4.
9. Generator library exports its whole implementation → G1; misnamed `--part-of-import` → G2.
10. `sling_gql_test.GraphQLError` vs `gql_exec.GraphQLError` → T1.
11. Time is `Duration` everywhere, counts `int`; nullable means "off" consistently (`maxAge`, `timeout`, `retryFailedAfter`, `gcAfterWrites`, `subscriptionRetryAfter`, sqflite `maxAge`/`maxEntities`). No change.
12. Sealed `SlingException`: adding a subtype is breaking for exhaustive switches → stated in the semver policy.

## Proposed changes

Breaking (pre-1.0, `!` + `BREAKING CHANGE:` footers; deprecated shims where
cheap, removed in 2.0):

- **B1** `SubscriptionState.retry` → `reconnect` (deprecated `retry` getter
  and constructor parameter kept).
- **B2** `QueryScope` constructor deprecated → `SlingClient.createScope`.
- **B3** `SlingScope(mutationRoot:)` deprecated → `schema:` (or the
  client's `schema`).
- **B4** `@internal` on `Selection`'s tree/policy members,
  `PrintedOperation.from/toCacheKeys/renamesFields`, `ListRule.evaluate`.
- **B5** `@protected` on `Accessor`'s read/write helpers.
- **B6** `SlingClient.dispose()` closes only an `http.Client` it created.
- **G1** `sling_gql_gen` library exports only `generate`,
  `generatedCodeHash`, `IntrospectionSchema` (+ its model types),
  `ScalarMapping`, `introspectionQuery`.
- **G2** `--part-of-import` → `--runtime-import` (old flag hidden,
  deprecated, still works).
- **T1** `GraphQLError` → `MockGraphQLError` (deprecated typedef).

Additive: **G3** `debugLabel:` on generated `mutate`/`subscribe`; **A1**
`PaginatedQueryBuilder` knobs + `PaginatedState.isSkeleton/isStale/revalidate`;
**A2** doc comments on the members above.

Kept despite oddness: `http` types in `Transport`; untyped subscription root
in `SlingSchema`; `onStatusChanged` callback; string `operation`/`kind`;
`CacheScope` public constructor; `onOperation` next to `requests`;
`SlingRequest` mutable until done; `Cache` implementable in principle (doc
says don't).

## Policy outline (Phase 2)

- Public = what `package:<pkg>/<pkg>.dart` exports, minus `@internal`,
  `@protected` (generated subclasses only) and `@visibleForTesting`
  members. `package:sling_gql/internal.dart` and `src/` imports: no
  promise, may change in any minor.
- Semver from 1.0: breaking → major; additive → minor; fixes → patch.
  Breaking includes: removing/renaming a public symbol or parameter,
  adding a required parameter, a new subtype of a sealed class
  (`SlingException`), a new member on an interface apps implement
  (`MutationQueueStore`, `SqfliteCodec`, `Transport` typedefs), changing
  documented behaviour, a persisted-format change that is not migrated
  (`sqfliteFormatVersion` bump wipes: minor, called out), a new major of a
  dependency whose types are public (`http`, `gql_link`, `sqflite`,
  `flutter_hooks`).
- Deprecation: `@Deprecated('Use X; removed in <next major>')`, kept for
  at least one minor release and removed only in the next major.
- Generated code: `sling_gql` 1.x compiles and runs the output of every
  `sling_gql_gen` 1.y with y ≤ x (the `Accessor` helper signatures the
  generator calls are part of the runtime's public API). A newer generator
  may need a newer runtime: its CHANGELOG states the minimum `sling_gql`
  minor. The two share a major.
