/// sling_gql's cache persisted in SQLite through sqflite.
///
/// `await SqflitePersistence.open(path, schema: slingSchema)` loads the
/// stored rows into a `Cache` before the client exists, then keeps the
/// database up to date with debounced `Cache.changesSince` deltas. Reads stay
/// synchronous and in memory; the database is a bounded write-behind copy.
library;

export 'src/sqflite_persistence.dart'
    show SqflitePersistence, SqfliteLoadReport, sqfliteFormatVersion;
