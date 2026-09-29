## 0.1.1

 - **FEAT**(sling_gql_test): inline fragments in MockGraphQLServer. ([5009ade1](https://github.com/tpucci/sling_gql/commit/5009ade15e943755d0e427e547cd43242a900df5))
 - **FEAT**(sling_gql_test): MockGraphQLServer(subscription:) with Stream fields. ([09ba6e76](https://github.com/tpucci/sling_gql/commit/09ba6e763258e5367068dc3d230beb91de7029c6))
 - **FEAT**(sling_gql_test): test helpers package ([#16](https://github.com/tpucci/sling_gql/issues/16)). ([ff3dd319](https://github.com/tpucci/sling_gql/commit/ff3dd319b823de7df120f1821ad99ade2faf80d6))

## 0.1.0

Initial release.

- `MockGraphQLServer`: in-memory server resolving the client's documents against plain Dart data / resolvers; `GraphQLError`, request log, `latency`.
- `pumpUntilSettled` / `tester.pumpUntilSettled(client)` on top of `SlingClient.isIdle` / `whenIdle`.
- `useRealNetwork()`, `disposeAfterTest()`.
