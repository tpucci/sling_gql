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
