## 0.2.1

 - **REFACTOR**(sling_gql): drop unused selection parameter from Cache.writeResponse ([#27](https://github.com/tpucci/sling_gql/issues/27)). ([a52046cb](https://github.com/tpucci/sling_gql/commit/a52046cb7de7d0e421e4b09d60eb8a4660f85620))
 - **PERF**(sling_gql): allocation-free read path, memoized aliases and scalar parsing ([#17](https://github.com/tpucci/sling_gql/issues/17), [#18](https://github.com/tpucci/sling_gql/issues/18)). ([f2c8fbac](https://github.com/tpucci/sling_gql/commit/f2c8fbac7ac4be5bb4491aa12fa13237d4f3d62b))
 - **FIX**(sling_gql): Cache.batch asserts a synchronous body ([#21](https://github.com/tpucci/sling_gql/issues/21)). ([ecfcf389](https://github.com/tpucci/sling_gql/commit/ecfcf3897f0722655b3f7c9ce8280a439e992c90))
 - **FIX**(sling_gql): builders see their own run's isStale and background isLoading. ([bc918a0c](https://github.com/tpucci/sling_gql/commit/bc918a0ceddb5e654cc42b2dcc9f72e48856f188))
 - **FIX**(sling_gql): partial mutation errors roll back before writing resolved fields ([#29](https://github.com/tpucci/sling_gql/issues/29)). ([389908ab](https://github.com/tpucci/sling_gql/commit/389908ab385b21ced418343cde7f38fdb75da84b))
 - **FIX**(sling_gql): 64-bit FNV-1a argument aliases; depKey is unambiguous with dotted ids ([#33](https://github.com/tpucci/sling_gql/issues/33), [#26](https://github.com/tpucci/sling_gql/issues/26)). ([f9df3ae2](https://github.com/tpucci/sling_gql/commit/f9df3ae2a7b097b284f19dd56d26df31d5de48ee))
 - **FEAT**(sling_gql): list-index dependency keys for inline lists ([#54](https://github.com/tpucci/sling_gql/issues/54)). ([d97091c4](https://github.com/tpucci/sling_gql/commit/d97091c4609e7859b23be5b003e3418ee5103105))
 - **FEAT**(sling_gql): export debugOwnerLabel from internal.dart for adapters ([#47](https://github.com/tpucci/sling_gql/issues/47)). ([b037226c](https://github.com/tpucci/sling_gql/commit/b037226c71ba381f6b818090c8c28a64b0e0c4fb))
 - **FEAT**(sling_gql): public QueryState/MutationState/SubscriptionState constructors for adapters ([#47](https://github.com/tpucci/sling_gql/issues/47)). ([0b455d5d](https://github.com/tpucci/sling_gql/commit/0b455d5debd9cc6b359c211ee369005ac4531ec5))
 - **FEAT**(sling_gql): coalesced Cache.onChange and incremental changesSince deltas ([#21](https://github.com/tpucci/sling_gql/issues/21)). ([d50a4d43](https://github.com/tpucci/sling_gql/commit/d50a4d431b630e34a0066d4a81e52d77fb62bb8d))
 - **FEAT**(sling_gql): request log and in-app request overlay attributing requests to widgets ([#46](https://github.com/tpucci/sling_gql/issues/46)). ([3572870e](https://github.com/tpucci/sling_gql/commit/3572870e31d0b05b3dd514ff6266b6c89dc3f04b))
 - **FEAT**(sling_gql): automatic cache gc after N responses, keeping what live scopes read ([#22](https://github.com/tpucci/sling_gql/issues/22)). ([37d7e390](https://github.com/tpucci/sling_gql/commit/37d7e3904e13b6d3e57e1e910355c656cb50275f))
 - **FEAT**(sling_gql): type-qualified response keys for fields repeated across fragments ([#57](https://github.com/tpucci/sling_gql/issues/57)). ([3f07c0d0](https://github.com/tpucci/sling_gql/commit/3f07c0d0619443d3df7d560bdbc3f856e454aa8e))
 - **FEAT**(sling_gql): MutationState.data, latest call wins ([#28](https://github.com/tpucci/sling_gql/issues/28)). ([32337429](https://github.com/tpucci/sling_gql/commit/323374295a48b3965f73d005098e364ecc352c55))
 - **FEAT**(sling_gql): SlingClient(schema:) takes the root factory and key field ([#25](https://github.com/tpucci/sling_gql/issues/25)). ([be7a00ce](https://github.com/tpucci/sling_gql/commit/be7a00ce4946a395ee3058818dd36b112059dd2b))
 - **FEAT**(sling_gql): QueryBuilder(scheduler:) ([#24](https://github.com/tpucci/sling_gql/issues/24)). ([ab11bcc7](https://github.com/tpucci/sling_gql/commit/ab11bcc7f37650443ffe9f7e898a9adf585fe28e))
 - **DOCS**(sling_gql): onChange lists the inline-list element/length keys ([#54](https://github.com/tpucci/sling_gql/issues/54)). ([b60fa0f2](https://github.com/tpucci/sling_gql/commit/b60fa0f2488f98c9664e618233b2d65c6ca2a436))

## 0.2.0

> Note: This release has breaking changes.

 - **PERF**(sling_gql): per-row rebuilds with SlingRow; structural compare for inline containers ([#19](https://github.com/tpucci/sling_gql/issues/19), [#20](https://github.com/tpucci/sling_gql/issues/20)). ([e8729bc0](https://github.com/tpucci/sling_gql/commit/e8729bc0034c84f60df8c79c55e6d0fc19d4e3da))
 - **FEAT**(sling_gql): unions and interfaces via inline fragments ([#31](https://github.com/tpucci/sling_gql/issues/31)). ([608f3a9c](https://github.com/tpucci/sling_gql/commit/608f3a9cc7d5af49b0bfbcb82fa021cabfe00bcc))
 - **FEAT**(sling_gql): subscriptions over SSE, SubscriptionBuilder, list rules. ([de298c66](https://github.com/tpucci/sling_gql/commit/de298c666b0d4a1c4432e50c4b83139f9e84d6a0))
 - **FEAT**(sling_gql): fetch policies and maxAge stale-while-revalidate ([#23](https://github.com/tpucci/sling_gql/issues/23), [#52](https://github.com/tpucci/sling_gql/issues/52)). ([21a4d4d6](https://github.com/tpucci/sling_gql/commit/21a4d4d6146395d325ee81eb21d3cda373394259))
 - **FEAT**(sling_gql): SlingClient.isIdle / whenIdle. ([54db8e5a](https://github.com/tpucci/sling_gql/commit/54db8e5a47df098ce6f705f8fc40e98b52309954))
 - **BREAKING** **REFACTOR**(sling_gql): split the public API surface ([#32](https://github.com/tpucci/sling_gql/issues/32)). ([048cfac8](https://github.com/tpucci/sling_gql/commit/048cfac89157d3329ca3ef179a780ec8447fdbb1))

## 0.1.1

- `example/main.dart`: a complete, self-contained app (query, mutation, optimistic write) shown on the pub.dev Example tab.
- Repository: pub workspace + melos, CI on every push, releases via `melos version`.

## 0.1.0

Initial release — proof of concept.

- `QueryBuilder` / `MutationBuilder` / `SlingScope`: read typed accessors
  during `build()`, get the query.
- Selection recording, per-frame batching into one GraphQL document, argument
  → variable extraction with deterministic aliases.
- Normalized cache (`__typename:id` entities, by-id lookups, `evict`, `gc`,
  `snapshot` / `onChange`), per-field rebuild notifications.
- Skeleton state before data arrives, `prepare` for conditional reads,
  waterfall warnings in dev mode.
- Mutations with optimistic writes, journaled and rolled back on failure.
- Partial `errors[]` handling, sticky errors with `refetch`, retry cooldown.
- Cursor pagination helpers, `CacheScope.list` for list membership updates.
