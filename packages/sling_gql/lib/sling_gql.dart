/// sling_gql — a GQty-style "read the field, get the query" GraphQL client
/// for Flutter. Proof of concept: queries only.
library;

export 'src/accessor.dart' show Accessor, Recorder;
export 'src/cache.dart' show Cache, missing;
export 'src/client.dart' show SlingClient, SlingException, QueryScope, RootFactory;
export 'src/selection.dart' show Arg, Selection, PrintedOperation;
export 'src/widgets.dart' show SlingScope, QueryBuilder, QueryState, QueryWidgetBuilder;
