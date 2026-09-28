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
