/// sling_gql — "read the field, get the query": a GraphQL client for Flutter
/// where the widget is the query. Proof of concept: queries only.
library;

export 'src/accessor.dart' show Accessor, Recorder;
export 'src/cache/cache.dart'
    show Cache, CacheWrite, NormalizedCache, Normalization, Ref, missing, depKey;
export 'src/client.dart'
    show
        SlingClient,
        SlingException,
        QueryScope,
        MutationScope,
        RootFactory,
        WaterfallWarning,
        Transport;
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
        Mutate;
