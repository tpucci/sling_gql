# sling_gql_gen

A Dart CLI code generator: turns a GraphQL introspection JSON document into
`sling_gql`-compatible typed `Accessor` classes (see `packages/sling_gql`).

## Usage

From the `example/` directory (verified against `example/graphql/schema.json`,
the SpaceX API introspection result):

```sh
cd example
dart run ../packages/sling_gql_gen/bin/sling_gql_gen.dart \
  --schema graphql/schema.json \
  --out lib/generated/schema.dart
```

This writes `lib/generated/schema.dart` and formats it with `dart format`
(a formatting failure is logged but does not fail the run).

Flags:

- `--schema` (required): path to a GraphQL introspection JSON file, i.e. the
  standard `{"__schema": {...}}` result of the introspection query.
- `--out` (required): path of the Dart file to generate. Parent directories
  are created as needed.
- `--part-of-import` (optional): overrides the `sling_gql` import in the
  generated file. Defaults to `package:sling_gql/sling_gql.dart`.

## What it generates

- `class Query extends Accessor` for the schema's query root type, with
  `Query(super.recorder, super.selection, super.path);` and
  `Query.root(Recorder r) : super(r, r.root, const []);` constructors.
- One `class <Name> extends Accessor` per other `OBJECT` type (skipping the
  mutation/subscription roots and introspection `__*` types), with a getter
  per argument-less field and a method (named optional / `required` params)
  per field with arguments. Scalar and enum fields without arguments also
  get a setter for optimistic writes, except where a write could never be
  right: the key field (`--key-field`, default `id`) of a keyed type
  (writing it would corrupt the entity key), every field of `PageInfo`, and
  `totalCount`/`pageInfo` on connection-shaped types (those with `pageInfo`
  plus `nodes` or `edges`).
- `enum <EnumName> { value('VALUE'), …, unknown('') }` for each `ENUM`
  type. Constants are the lowerCamelCase of the wire name
  (`PARTIAL_FAILURE` → `partialFailure`); `graphqlName` is the wire value,
  `fromGraphQL(String)` maps a wire value back (returning `unknown` for a
  value added to the schema after generation, so a `switch` stays
  exhaustive), and `toGraphQL()` is what arguments and input fields
  serialize with — it throws an `ArgumentError` for `unknown`. Enum fields
  are read through `Accessor.enumValue`/`enumList` (same miss/skeleton
  semantics as scalars) and their setters write the wire name. Constants
  that would clash with a Dart keyword or an enum member (`unknown`,
  `values`, `index`, `name`, …) get a trailing `$`: `UNKNOWN` → `unknown$`.
- `class <InputName> { const <InputName>({...}); ...; toJson() {...} }` for
  each `INPUT_OBJECT` type.

All getters are nullable (`T?`, `R?`, `List<R>?`) regardless of the schema's
non-null markers, since cache data may be missing — see
`packages/sling_gql/lib/src/accessor.dart`.

## Development

```sh
cd packages/sling_gql_gen
dart pub get
dart analyze
dart test
```
