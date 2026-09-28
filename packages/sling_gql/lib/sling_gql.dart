/// sling_gql — "read the field, get the query": a GraphQL client for Flutter
/// where the widget is the query. Proof of concept.
///
/// This is the app-facing surface: the client and its widgets, the base class
/// and types generated code builds on, cache access. Building blocks the
/// runtime is made of (the normalized store, refs, the `missing` sentinel,
/// write journal entries) live in `package:sling_gql/internal.dart`.
library;

export 'src/accessor.dart' show Accessor, Recorder;
export 'src/cache/cache.dart' show Cache, Normalization;
export 'src/client.dart'
    show
        SlingClient,
        SlingException,
        FetchPolicy,
        CacheScope,
        CacheList,
        ListRule,
        ListPosition,
        QueryScope,
        RootFactory,
        SlingSchema,
        WaterfallWarning,
        Transport,
        SubscriptionTransport,
        sseSubscriptionTransport,
        SlingSubscription,
        FlushScheduler,
        microtaskScheduler;
export 'src/pagination.dart'
    show
        PaginationController,
        ConnectionPage,
        PageSelector,
        PaginatedState,
        PaginatedQueryBuilder,
        PaginatedWidgetBuilder;
export 'src/selection.dart' show Arg, Selection, PrintedOperation;
export 'src/widgets.dart'
    show
        SlingScope,
        QueryBuilder,
        QueryState,
        QueryWidgetBuilder,
        MutationBuilder,
        MutationState,
        MutationWidgetBuilder,
        Mutate,
        SubscriptionBuilder,
        SubscriptionState,
        SubscriptionWidgetBuilder,
        frameEndScheduler;
