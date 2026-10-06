## 1.0.0

> Note: This release has breaking changes.

 - First stable release. Upgrading from 0.x: see [Upgrading to 1.0](https://tpucci.github.io/sling_gql/guides/upgrading-to-1-0/).

 - **FEAT**(sling_gql_hooks): offline on useSlingMutation's mutate, MutationState.isQueued. ([2854272f](https://github.com/tpucci/sling_gql/commit/2854272fa2633ee271eda0458799ae950464675e))
 - **FEAT**(sling_gql_hooks): errorPolicy and timeout on useSlingQuery; errorPolicy, timeout and retry on mutate. ([2b82b904](https://github.com/tpucci/sling_gql/commit/2b82b904636767d749238a26ae256945c2beff6f))
 - **DOCS**(repo): Versioning sections in the adapter, test and generator READMEs ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([a3574704](https://github.com/tpucci/sling_gql/commit/a35747046d8fa901476b73825661861c9acf78ce))
 - **BREAKING** **REFACTOR**(sling_gql_test): rename GraphQLError to MockGraphQLError ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([b144a1d8](https://github.com/tpucci/sling_gql/commit/b144a1d88bd38ce1105cfccaac50622777b3f4fd))
 - **BREAKING** **REFACTOR**(sling_gql): settle the 1.0 public surface ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([0f1e6992](https://github.com/tpucci/sling_gql/commit/0f1e6992e8cb3caee34071000742b2e10ddae482))

## 0.1.0+1

 - Update a dependency to the latest release.

## 0.1.0

Initial release.

- `useSlingQuery`: `QueryBuilder` as a hook — a selector run in the widget's own `QueryScope`, returning its value and a `QueryState`; `fetchPolicy`, `maxAge`, `debugLabel`, `scheduler`.
- `useSlingMutation`: `MutationBuilder` as a hook — `mutate` and a `MutationState`.
- `useSlingSubscription`: `SubscriptionBuilder` as a hook — the event accessor and a `SubscriptionState`, open while the widget is mounted.
