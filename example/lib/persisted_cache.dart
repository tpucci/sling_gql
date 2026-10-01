/// The cache the app starts with.
///
/// On iOS: the previous run's cache, loaded from SQLite by
/// `sling_gql_sqflite` before the client exists and saved back as deltas
/// while the app runs. On the web: a fresh in-memory cache — every tab has
/// its own in-page mock API, so there is nothing worth keeping.
///
/// The widget tests never call [openCache] (they build their own client),
/// so persistence never leaks state from one test run into the next.
library;

export 'persisted_cache_io.dart'
    if (dart.library.js_interop) 'persisted_cache_web.dart';
