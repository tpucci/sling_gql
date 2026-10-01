import 'package:flutter/foundation.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_sqflite/sling_gql_sqflite.dart';

import 'generated/schema.dart';

/// iOS: the cache persisted in `sling_cache.db` (in sqflite's
/// `getDatabasesPath()`), bounded by the defaults (7 days per root field,
/// 10 000 entities) and wiped when the generated code's `slingSchema.hash`
/// changes. Call after `WidgetsFlutterBinding.ensureInitialized()`.
Future<Cache> openCache() async {
  final persistence = await SqflitePersistence.open(
    'sling_cache.db',
    schema: slingSchema,
  );
  debugPrint('sling_gql_sqflite: ${persistence.loaded}');
  return persistence.cache;
}

/// Restored data has no fetch time, so under a `maxAge` it is shown at once
/// and revalidated in the background; with plain `cacheFirst` it would never
/// be refetched.
const restoredCacheMaxAge = Duration(minutes: 5);
