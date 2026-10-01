/// Internals of sling_gql: the pieces the runtime, its tests and future
/// adapters (persistence, subscriptions) are built from, kept out of
/// `package:sling_gql/sling_gql.dart` so the app-facing surface stays small.
///
/// - [NormalizedCache], [Ref], [missing], [depKey] (and [elementDepKey],
///   [lengthDepKey]): the store's building
///   blocks. Apps use the [Cache] interface (`client.cache.snapshot`,
///   `evict`, `onChange`…) and never these.
/// - [CacheWrite], [MutationScope], [SubscriptionScope], [RowScope],
///   [ListLocator]: the recorder machinery behind optimistic writes,
///   mutations, subscriptions, `SlingRow` and `CacheScope.list`.
/// - [debugOwnerLabel]: the default scope label of the widgets, for adapters
///   (`sling_gql_hooks`).
///
/// No stability promise: anything here can change in a minor release.
library;

import 'src/cache/cache.dart' show Cache;

export 'src/accessor.dart' show ListLocator;
export 'src/cache/cache.dart'
    show NormalizedCache, CacheWrite, depKey, elementDepKey, lengthDepKey;
export 'src/cache/ref.dart' show Ref, missing;
export 'src/client.dart' show MutationScope, SubscriptionScope, RowScope;
export 'src/widgets.dart' show debugOwnerLabel;
