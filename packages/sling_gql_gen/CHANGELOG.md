## 1.0.0

> Note: This release has breaking changes.

 - First stable release. Upgrading from 0.x: see [Upgrading to 1.0](https://tpucci.github.io/sling_gql/guides/upgrading-to-1-0/).

 - **FEAT**(sling_gql_gen): debugLabel on the generated mutate and subscribe ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([c928a936](https://github.com/tpucci/sling_gql/commit/c928a93615585e282da671075c751ca77b70d7ca))
 - **FEAT**(sling_gql_gen): forward offline and onQueued in client.mutate. ([40be6a8d](https://github.com/tpucci/sling_gql/commit/40be6a8dacf5f727e65b840eb0dc0f3d59265f23))
 - **FEAT**(sling_gql_gen): forward errorPolicy, timeout and retry in client.mutate. ([aa3269a8](https://github.com/tpucci/sling_gql/commit/aa3269a895301d1176c05fca3181936e660d9af9))
 - **FEAT**(sling_gql_gen): emit field signatures in slingSchema.fields ([#72](https://github.com/tpucci/sling_gql/issues/72)). ([944b4efd](https://github.com/tpucci/sling_gql/commit/944b4efd0b2eabc479d0fe9f0cf05924ba4ef0b6))
 - **DOCS**(repo): Versioning sections in the adapter, test and generator READMEs ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([a3574704](https://github.com/tpucci/sling_gql/commit/a35747046d8fa901476b73825661861c9acf78ce))
 - **BREAKING** **REFACTOR**(sling_gql_gen): narrow the library exports; --runtime-import ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([514ef10b](https://github.com/tpucci/sling_gql/commit/514ef10beef39661f37090c2e81e2c1aadf51fd8))

## 0.1.4

 - **FEAT**(sling_gql_gen): emit slingSchema.hash. ([96b514dc](https://github.com/tpucci/sling_gql/commit/96b514dc9a86f89cb404b055de04f8c969578b49))

## 0.1.3

 - **FEAT**(sling_gql_gen): slingSchema carries --key-field, emitted without a Mutation type too ([#25](https://github.com/tpucci/sling_gql/issues/25)). ([27ce5a4d](https://github.com/tpucci/sling_gql/commit/27ce5a4d16adde9c017bbb7794bdebb09c74e135))

## 0.1.2

 - **FEAT**(sling_gql_gen): emit unions and interfaces ([#31](https://github.com/tpucci/sling_gql/issues/31)). ([c0553a6d](https://github.com/tpucci/sling_gql/commit/c0553a6d6fd304d82489231c3390b8b4645c3ea2))
 - **FEAT**(sling_gql_gen): emit the Subscription root and client.subscribe. ([93c2af75](https://github.com/tpucci/sling_gql/commit/93c2af750352033d3025d6cd19263f24710609e1))

## 0.1.1

- `example/README.md`: schema → CLI → generated output walkthrough, shown on the pub.dev Example tab.
- README uses `flutter pub add --dev sling_gql_gen` / `dart run sling_gql_gen`.
- Repository: pub workspace + melos, CI on every push, releases via `melos version`.

## 0.1.0

Initial release — proof of concept.

- `sling_gql_gen` CLI: GraphQL introspection JSON → typed `Accessor` classes
  for the `sling_gql` runtime.
- `--scalar Name=DartType[:converter]` custom scalar mapping.
- `--key-field` to pick the entity key; emits `keyed:` / `lookup:` facts
  for cache normalization.
- Generates the `Query` and `Mutation` roots plus a `client.mutate(...)`
  extension.
