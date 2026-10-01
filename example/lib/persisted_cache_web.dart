import 'package:sling_gql/sling_gql.dart';

/// Web: a new in-memory cache per page (see `persisted_cache.dart`) — what
/// `SlingClient(schema: slingSchema)` builds by default, spelled out: an
/// object with `__typename` and `id` is stored once as `Launch:<id>` and
/// referenced from every list and field it appears in; objects without an
/// id (`PageInfo`, `Stats`) stay inline in their parent.
Future<Cache> openCache() async =>
    Cache(normalization: const Normalization(keyField: 'id'));

/// Nothing is restored on the web: no revalidation needed.
const Duration? restoredCacheMaxAge = null;
