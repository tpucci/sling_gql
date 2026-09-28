## 0.1.0

Initial release.

- `MockGraphQLServer`: in-memory server resolving the client's documents against plain Dart data / resolvers; `GraphQLError`, request log, `latency`.
- `pumpUntilSettled` / `tester.pumpUntilSettled(client)` on top of `SlingClient.isIdle` / `whenIdle`.
- `useRealNetwork()`, `disposeAfterTest()`.
