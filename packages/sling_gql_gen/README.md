# sling_gql_gen

A Dart CLI code generator: turns a GraphQL introspection JSON document into
typed `Accessor` classes for the [`sling_gql`](https://pub.dev/packages/sling_gql)
runtime. Docs: https://tpucci.github.io/sling_gql/

## Usage

Add it as a dev dependency of your Flutter app and run it against your
schema's introspection JSON:

```sh
flutter pub add --dev sling_gql_gen
dart run sling_gql_gen \
  --schema graphql/schema.json \
  --out lib/generated/schema.dart
```

(Inside this repository, the example app runs the same command as
`dart run ../packages/sling_gql_gen/bin/sling_gql_gen.dart …`, or
`melos run generate`.)

This writes `lib/generated/schema.dart` and formats it with `dart format`
(a formatting failure is logged but does not fail the run). The generated
file starts with a header comment explaining the `$`-rename scheme
(`type$`, `$typename`, `$eq`, ...) in one place, so a reader never has to
go digging for why an identifier looks the way it does.

Flags:

- `--schema` (one of `--schema` / `--endpoint`): path to the schema. A
  `.json` file is read as introspection JSON, i.e. the standard
  `{"__schema": {...}}` result of the introspection query; any other
  extension as SDL (`schema.graphql`), e.g. the schema file a backend
  keeps in its repository. Both produce the same output.
- `--endpoint` (one of `--schema` / `--endpoint`): GraphQL URL to introspect
  instead; `-H` / `--header` (repeatable) adds HTTP headers to that request
  (`-H "Authorization: Bearer …"`).
- `--out` (required): path of the Dart file to generate. Parent directories
  are created as needed.
- `--runtime-import` (optional): overrides the `sling_gql` import in the
  generated file. Defaults to `package:sling_gql/sling_gql.dart`.
- `--key-field` (optional, default `id`): the field that makes an object
  type a normalized entity (see below).
- `--scalar` (optional, repeatable): custom scalar mapping,
  `Name=DartType[:converterExpr]`. `--scalar DateTime=DateTime` uses the
  built-in `DateTime.parse`/`.toIso8601String()` converter; a `DartType`
  other than `DateTime` needs a converter, e.g.
  `--scalar Money=Decimal:MoneyConverter` calls
  `MoneyConverter.parse`/`MoneyConverter.serialize` (a class with those two
  static methods you provide). Scalars without a `--scalar` flag keep the
  default in the table below.

## What it generates

- `class Query extends Accessor` for the schema's query root type, with
  `Query(super.recorder, super.selection, super.path);` and
  `Query.root(Recorder r) : super(r, r.root, const []);` constructors.
  `Mutation` and `Subscription` roots get the same shape, plus
  `extension SlingMutations` (`client.mutate(...)`) and
  `extension SlingSubscriptions` (`client.subscribe(...)`), and the
  `slingSchema` constant bundling the roots and `--key-field` for
  `SlingClient(schema: slingSchema)` (the client's cache then normalizes on
  the same key field; no hand-kept `Normalization(keyField:)`), and
  `hash:` — a 64-bit FNV-1a of the generated file itself, so it changes
  whenever the schema, `--key-field`, a `--scalar` mapping or the generator
  changes the output, and is the same on every run and platform; and
  `fields:` — every field of every object type with its signature
  (`'(id: ID!) Launch'`, `'[String!]!'`; the query root as `ROOT_QUERY`,
  interfaces and unions without fields), a `const` map at the end of the
  file. Persistence adapters (`sling_gql_sqflite`) migrate a store written
  under another hash along `fields`, keeping what the new code can still
  read.
- One `class <Name> extends Accessor` per other `OBJECT` type (skipping the
  operation roots and introspection `__*` types), with a getter
  per argument-less field and a method (named optional / `required` params)
  per field with arguments. Scalar and enum fields without arguments also
  get a setter for optimistic writes, except where a write could never be
  right: the key field (`--key-field`, default `id`) of a keyed type
  (writing it would corrupt the entity key), every field of `PageInfo`, and
  `totalCount`/`pageInfo` on connection-shaped types (those with `pageInfo`
  plus `nodes` or `edges`).
- One `class <Name> extends Accessor` per `UNION` and `INTERFACE` type:
  the interface's own fields as above, one getter per possible type
  (`Launch? get asLaunch => on('Launch', Launch.new, keyed: true);`, the
  inline fragment `... on Launch`, `null` for another type) and
  `T? when<T>({T Function(Launch launch)? launch, …, T Function()? orElse})`
  dispatching on `__typename` through `Accessor.whenType` (every branch runs
  on a skeleton, so one request covers all of them). An interface declaring
  the key field is keyed like an object type (never a `lookup`). A getter
  clashing with a field, or a parameter with a keyword, another parameter,
  `orElse` or its own type, gets a trailing `$`.
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
- `extension SlingCacheAccess on CacheScope<Query>` with one method per
  keyed type (an `OBJECT` with a scalar `--key-field`), returning the cached
  entity or `null` without ever fetching:
  `Launch? launch(String id) => entity('Launch', id, Launch.new);` — used as
  `client.cacheScope.launch('launch-181')`. The method is the type name with
  a lowercase first letter; a clash with a Dart keyword, a `CacheScope`
  member (`query`, `list`, `entity`, `evict`, …) or another type's method
  gets a trailing `$` (`Entity` → `entity$`). Omitted when no type is keyed.

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

## Versioning

From 1.0 `sling_gql_gen` follows semantic versioning and shares its major
version with `sling_gql`. Public: the CLI flags and the shape of the
generated code, and the library's `generate`, `generatedCodeHash`,
`IntrospectionSchema` (with its `Gql*` / `TypeRef` types), `ScalarMapping`
and `introspectionQuery`; `src/` is not. Code generated by 1.y runs on
`sling_gql` 1.x for every x ≥ y; when a minor emits code that needs a newer
runtime, its changelog names the minimum `sling_gql` version. Deprecated APIs keep working for at least one minor release and are
removed only in the next major. Full policy:
[Versioning & deprecation](https://tpucci.github.io/sling_gql/internals/versioning/); coming from 0.x:
[Upgrading to 1.0](https://tpucci.github.io/sling_gql/guides/upgrading-to-1-0/). Security issues:
[SECURITY.md](https://github.com/tpucci/sling_gql/blob/main/SECURITY.md).
