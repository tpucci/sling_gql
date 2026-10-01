## 0.1.0

Initial release.

- `SqflitePersistence.open(path, schema:)`: loads the stored rows into a `Cache` before the client starts (optionally in a background isolate), dropping root fields past `maxAge`, the oldest ones over `maxEntities`, and unreachable entities.
- Write-behind saves of `Cache.changesSince` deltas: debounced, bounded by `maxWait`, flushed on app pause/hide/detach and `flush()`; serialized, retried after a failure. One row per entity, one per `ROOT_QUERY` field.
- The store is wiped when the format version, key field or `slingSchema.hash` changed.
- `clear()` (logout), `close()`, a pluggable `DatabaseFactory` (ffi, web, SQLCipher).
