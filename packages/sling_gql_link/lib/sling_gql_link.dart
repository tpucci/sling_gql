/// sling_gql over `gql_link`: [linkTransport] and [linkSubscriptionTransport]
/// turn a `Link` chain (auth, retries, persisted queries, websockets) into
/// the one `Transport` / `SubscriptionTransport` a `SlingClient` takes, so
/// the runtime itself stays `http`-only.
library;

export 'src/link_transport.dart'
    show linkTransport, linkSubscriptionTransport, slingExceptionFromLink;
