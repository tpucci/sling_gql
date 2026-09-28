# sling_gql_test

Test helpers for [sling_gql](https://pub.dev/packages/sling_gql).

Docs: https://tpucci.github.io/sling_gql/guides/testing/ · Source:
https://github.com/tpucci/sling_gql

```sh
flutter pub add --dev sling_gql_test
```

## `MockGraphQLServer`

An in-memory GraphQL server that answers the documents `SlingClient` prints
from plain Dart data — no aliases to compute, no regexes over the query.
Values are maps with `__typename`, lists, scalars, or resolvers taking the
field's arguments:

```dart
final server = MockGraphQLServer(
  query: {
    'me': {'__typename': 'User', 'id': '1', 'name': 'Ada'},
    'launch': (args) => launches[args['id']],
  },
  mutation: {
    'toggleFavorite': (args) => toggle(launches[args['launchId']]!),
  },
);
final client = server.client(Query.root); // disposed after the test

await tester.pumpWidget(SlingScope<Query>(client: client, schema: slingSchema, child: app));
await tester.pumpUntilSettled(client);

expect(server.requests, hasLength(1));
expect(server.lastRequest.selects('launch.rocket.name'), isTrue);
```

Only the selected fields are returned, under the document's aliases. Unknown
fields and objects without `__typename` fail the test loudly. Throw
`GraphQLError('…')` from a resolver for an `errors[]` entry with a path.
`latency:` delays responses on the fake clock.

## `pumpUntilSettled`

`tester.pumpUntilSettled(client)` pumps until the client has no request in
flight (queries and mutations) and the last frame caused no new one — unlike
`pumpAndSettle()`, which returns before the response lands. Works with the
mock server, a hand-rolled `MockClient`, or a real server.

## Real network

`useRealNetwork()` at the top of `main()` lifts the socket block `flutter
test` installs and turns keep-alive off, so tests against a running server
need no `client.dispose()` dance. `disposeAfterTest(client)` registers the
dispose as a tear-down for plain `test()`s.
