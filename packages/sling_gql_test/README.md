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
`MockGraphQLError('…')` (optionally `code: 'FORBIDDEN'`) from a resolver for an
`errors[]` entry with a path. `latency:` delays responses on the fake clock.

`failNext` fails the next requests, for error-handling, retry and auth tests
(each recorded with `.failed` and its `.headers`):

```dart
server.failNext(const MockFailure.status(503), times: 2);
server.failNext(const MockFailure.graphQL('expired', code: 'UNAUTHENTICATED'));
server.failNext(const MockFailure.network());
```

`server.client(...)` takes `retry:`, `timeout:`, `errorPolicy:` and `auth:`.

### Subscriptions

`subscription:` fields are `Stream`s (or resolvers returning one); each value
is projected to the document's selection and delivered to the client as one
event, through `server.subscriptionTransport` (wired by `server.client`):

```dart
final status = StreamController<Map<String, Object?>>();
final server = MockGraphQLServer(
  query: {...},
  subscription: {'launchStatusChanged': status.stream},
);

await tester.pumpWidget(...); // a SubscriptionBuilder<Subscription> somewhere
expect(server.openSubscriptions, 1);
status.add({'__typename': 'Launch', 'id': 'launch-1', 'status': 'SUCCESS'});
await tester.pump(Duration.zero); // deliver the event, rebuild
```

Closing the stream completes the subscription; a stream error ends it with a
transport error. `server.openSubscriptions` counts the ones still open —
assert it is `0` once the widget is gone.

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

## Versioning

From 1.0 `sling_gql_test` follows semantic versioning and shares its major
version with `sling_gql`. Public: what `package:sling_gql_test/sling_gql_test.dart`
exports; the documents `MockGraphQLServer` parses are whatever the runtime
prints, so assert on `MockRequest.rootFields` / `selects(...)`, not on
aliases. Deprecated APIs keep working for at least one minor release and are
removed only in the next major. Full policy:
[Versioning & deprecation](https://tpucci.github.io/sling_gql/internals/versioning/); coming from 0.x:
[Upgrading to 1.0](https://tpucci.github.io/sling_gql/guides/upgrading-to-1-0/). Security issues:
[SECURITY.md](https://github.com/tpucci/sling_gql/blob/main/SECURITY.md).
