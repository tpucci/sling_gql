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
