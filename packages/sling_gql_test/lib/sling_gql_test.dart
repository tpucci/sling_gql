/// Test helpers for sling_gql.
///
/// - [MockGraphQLServer]: an in-memory server that answers the client's own
///   documents from plain Dart data (values or resolvers), so tests never
///   compute aliases or regex the query. `server.client(Query.root)` gives a
///   wired `SlingClient`, `server.requests` the log; `subscription:` fields
///   are `Stream`s the client's subscriptions receive as events.
/// - [pumpUntilSettled] / `tester.pumpUntilSettled(client)`: pump until no
///   request is pending and the last frame caused none.
/// - [useRealNetwork], [disposeAfterTest]: the folklore of `flutter test`
///   against a real server, wrapped.
library;

export 'src/document.dart'
    show ParsedOperation, ParsedField, GraphQLSyntaxError, parseOperation;
export 'src/mock_server.dart'
    show
        MockGraphQLServer,
        MockRequest,
        MockFailure,
        Resolver,
        MockGraphQLError;
export 'src/pump.dart'
    show pumpUntilSettled, SlingWidgetTester, useRealNetwork, disposeAfterTest;
