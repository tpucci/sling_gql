# sling_gql

A GraphQL client for Flutter where **the widget is the query**. Inspired by
[GQty](https://gqty.dev). **Proof of concept** — APIs will change.

Docs: https://tpucci.github.io/sling_gql/ · Source:
https://github.com/tpucci/sling_gql

> Read a field, get the query. No operation documents, no fragments, no
> builder-per-query boilerplate: widgets read typed accessors during
> `build()`, sling_gql records what was read, batches everything read in the
> frame into one GraphQL document, fetches it, fills a normalized cache, and
> rebuilds only the widgets that read the affected data.

```dart
QueryBuilder<Query>(
  builder: (context, query, state) {
    final launch = query.latestLaunch;
    return ListTile(
      title: Text(launch?.name ?? '…'),
      subtitle: Text(launch?.rocket?.name ?? '…'),
    );
  },
)
```

…sends, once, at the end of the frame:

```graphql
query {
  latestLaunch { __typename name rocket { __typename name } }
}
```

## Getting started

1. Add the runtime and the generator:

   ```sh
   flutter pub add sling_gql
   flutter pub add --dev sling_gql_gen
   ```

2. Generate typed accessors from your schema's introspection JSON
   (the standard `{"__schema": …}` result):

   ```sh
   dart run sling_gql_gen --schema graphql/schema.json \
     --out lib/generated/schema.dart --scalar DateTime=DateTime
   ```

3. Create a client and provide it to the tree:

   ```dart
   import 'package:sling_gql/sling_gql.dart';
   import 'generated/schema.dart';

   void main() {
     final client = SlingClient<Query>(
       endpoint: Uri.parse('https://example.com/graphql'),
       rootFactory: Query.root,
     );
     runApp(SlingScope<Query>(
       client: client,
       schema: slingSchema,
       child: const MyApp(),
     ));
   }
   ```

4. Read fields in `build()` with `QueryBuilder`; mutate with
   `MutationBuilder` or `client.mutate((m) => m.toggleFavorite(id: id)?.favorite)`.

5. Test with [`sling_gql_test`](https://pub.dev/packages/sling_gql_test):
   `MockGraphQLServer` answers the recorded documents from plain maps,
   `tester.pumpUntilSettled(client)` waits for the round trip.

## What's in the box

- Selection recording during `build()`, including accessors handed to child
  widgets and lazily built sliver rows.
- One HTTP request per frame, arguments turned into variables.
- Normalized cache (`Launch:launch-181`), per-field rebuild notifications,
  `evict`, `gc`, `snapshot` / `onChange` for persistence.
- Skeleton state (`null` scalars, one-element lists) before data arrives;
  `state.isSkeleton`, `state.isLoading`, `state.error`, `state.refetch()`.
- `prepare:` to fetch fields hidden behind conditionals in the first round
  trip; dev-mode waterfall warnings.
- Mutations with optimistic writes (journaled, rolled back on failure).
- Partial `errors[]` handling, sticky errors, retry cooldown.
- Fetch policies per widget (`cacheFirst`, `cacheAndNetwork`, `networkOnly`)
  and `maxAge` stale-while-revalidate with `state.isStale` / `revalidate()`.
- Cursor pagination helpers, `CacheScope.list` for list membership.

Not yet: subscriptions, unions/interfaces.

## Rules of thumb

- **Read every field you need at the top of `build`.** A field read only
  inside an `if` on fetched data or in a callback costs a second round trip.
  Use `prepare:` for the rest.
- All generated getters are nullable, even for `!` schema types: a value can
  always be absent from cache. Tell a server `null` from "not fetched yet"
  with `state.hasMissingData`.

See the [documentation site](https://tpucci.github.io/sling_gql/) for the
full guide and the `example/` app in the repository.
