import 'package:flutter/foundation.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_sqflite/sling_gql_sqflite.dart';
import 'package:sqflite/sqflite.dart' show deleteDatabase;

import 'generated/schema.dart';

const _path = 'sling_cache.db'; // in sqflite's getDatabasesPath()

/// iOS: the cache persisted in `sling_cache.db`, bounded by the defaults
/// (7 days per root field, 10 000 entities) and wiped when the generated
/// code's `slingSchema.hash` changes. Call after
/// `WidgetsFlutterBinding.ensureInitialized()`.
///
/// The store is only a cache: when it cannot be opened (a damaged file),
/// it is deleted and opened again, and the app starts with an empty
/// in-memory cache if that fails too — never a launch that cannot start.
Future<Cache> openCache() async {
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final persistence = await SqflitePersistence.open(
        _path,
        schema: slingSchema,
      );
      debugPrint('sling_gql_sqflite: ${persistence.loaded}');
      return persistence.cache;
    } catch (error) {
      debugPrint('sling_gql_sqflite: could not open $_path ($error)');
      if (attempt == 0) await deleteDatabase(_path).catchError((_) {});
    }
  }
  return Cache(normalization: slingSchema.normalization);
}

/// Restored data has no fetch time, so under a `maxAge` it is shown at once
/// and revalidated in the background; with plain `cacheFirst` it would never
/// be refetched.
const restoredCacheMaxAge = Duration(minutes: 5);
