# sling_gql_link

Run [sling_gql](https://pub.dev/packages/sling_gql)'s requests through a
[`gql_link`](https://pub.dev/packages/gql_link) `Link` chain — auth, retries,
persisted queries, websockets, whatever links you already have — as the one
`Transport` a `SlingClient` takes. sling_gql itself stays `http`-only.

Docs: https://tpucci.github.io/sling_gql/guides/transport/ · Source:
https://github.com/tpucci/sling_gql

```sh
flutter pub add sling_gql_link gql_link gql_http_link
```

```dart
import 'package:gql_http_link/gql_http_link.dart';
import 'package:gql_link/gql_link.dart';
import 'package:sling_gql_link/sling_gql_link.dart';

final link = Link.from([authLink, retryLink, HttpLink(endpoint)]);

final client = SlingClient<Query>(
  endpoint: Uri.parse(endpoint), // nominal: the terminating link sends
  schema: slingSchema,
  transport: linkTransport(link),
  // Subscriptions too, when the link can run them (a websocket link routed
  // with Link.split):
  subscriptionTransport: linkSubscriptionTransport(link),
);
```

## What goes in

Each batched document is parsed into the `Request`'s `DocumentNode`, with its
`variables` and `operationName` (sling_gql's own documents are anonymous).
`SlingClient.headers` are put in the context as `HttpLinkHeaders`, so an auth
link adds to them with `request.updateContextEntry<HttpLinkHeaders>(...)`;
`content-type` and `accept` are left to the terminating link.

## What comes out

The first `Response` of the link's stream is the result: `data`, `errors`
(message, locations, path, extensions) and `extensions` are encoded back into
a JSON body the client handles exactly like an HTTP response — partial errors
pruned before caching and reported on the scope, `data: null` a
`SlingException`.

A `LinkException` becomes a `SlingLinkException` (a `SlingException`):

| Link exception | `message` | `statusCode` | `graphqlErrors` |
| --- | --- | --- | --- |
| `ServerException` with a status `>= 300` (`HttpLinkServerException`) | `HTTP <code>` | the status | the body's errors |
| `ServerException` with errors, no error status | the errors' messages | the status, if any | the errors |
| `ServerException` with neither data nor errors | `Empty response` | the status, if any | `[]` |
| `ServerException` of a failed connection | the cause's message | `null` | `[]` |
| any other `LinkException` | the cause's message | `null` | `[]` |

`linkException` keeps what the link threw (and its `originalException`).
Errors that are not `LinkException`s (a `TimeoutException` from your own
link) surface unchanged, as with the default transport.

## Subscriptions

`linkSubscriptionTransport(link)` maps the link's stream one to one: each
`Response` is an event, the stream completing completes the subscription, an
error is a transport failure (which reconnects when the subscription has a
`retryAfter`), and cancelling the subscription cancels the link's stream.
`HttpLink` cannot run subscriptions; route them to a websocket link:

```dart
final link = Link.split(
  (request) =>
      request.operation.getOperationType() == OperationType.subscription,
  websocketLink,
  Link.from([authLink, HttpLink(endpoint)]),
);
```

Or keep sling_gql's default GraphQL-over-SSE subscriptions and only pass
`transport:`.
