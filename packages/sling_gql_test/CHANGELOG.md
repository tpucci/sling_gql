## 1.0.0

> Note: This release has breaking changes.

 - First stable release. Upgrading from 0.x: see [Upgrading to 1.0](https://tpucci.github.io/sling_gql/guides/upgrading-to-1-0/).

 - **FEAT**(sling_gql_test): MockGraphQLServer.failNext, request headers, GraphQLError(code:). ([98fa786a](https://github.com/tpucci/sling_gql/commit/98fa786a394491d5c2eae25e4a5f5ce1a546ea85))
 - **DOCS**(repo): Versioning sections in the adapter, test and generator READMEs ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([a3574704](https://github.com/tpucci/sling_gql/commit/a35747046d8fa901476b73825661861c9acf78ce))
 - **BREAKING** **REFACTOR**(sling_gql_test): rename GraphQLError to MockGraphQLError ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([b144a1d8](https://github.com/tpucci/sling_gql/commit/b144a1d88bd38ce1105cfccaac50622777b3f4fd))
 - **BREAKING** **REFACTOR**(sling_gql): settle the 1.0 public surface ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([0f1e6992](https://github.com/tpucci/sling_gql/commit/0f1e6992e8cb3caee34071000742b2e10ddae482))

## 0.1.1+2

 - Update a dependency to the latest release.

## 0.1.1+1

 - Update a dependency to the latest release.

## 0.1.1

 - **FEAT**(sling_gql_test): inline fragments in MockGraphQLServer. ([5009ade1](https://github.com/tpucci/sling_gql/commit/5009ade15e943755d0e427e547cd43242a900df5))
 - **FEAT**(sling_gql_test): MockGraphQLServer(subscription:) with Stream fields. ([09ba6e76](https://github.com/tpucci/sling_gql/commit/09ba6e763258e5367068dc3d230beb91de7029c6))
 - **FEAT**(sling_gql_test): test helpers package ([#16](https://github.com/tpucci/sling_gql/issues/16)). ([ff3dd319](https://github.com/tpucci/sling_gql/commit/ff3dd319b823de7df120f1821ad99ade2faf80d6))

## 0.1.0

Initial release.

- `MockGraphQLServer`: in-memory server resolving the client's documents against plain Dart data / resolvers; `GraphQLError`, request log, `latency`.
- `pumpUntilSettled` / `tester.pumpUntilSettled(client)` on top of `SlingClient.isIdle` / `whenIdle`.
- `useRealNetwork()`, `disposeAfterTest()`.
