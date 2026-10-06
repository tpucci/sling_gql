## 1.0.0

> Note: This release has breaking changes.

 - First stable release. Upgrading from 0.x: see [Upgrading to 1.0](https://tpucci.github.io/sling_gql/guides/upgrading-to-1-0/).

 - **PERF**(sling_gql_sqflite): compact after each save; delete rows in chunks. ([ea4a06f4](https://github.com/tpucci/sling_gql/commit/ea4a06f4c8a024a341cef3166574276399dcd25d))
 - **PERF**(sling_gql_sqflite): save only the changed root fields; hydrate without a copy. ([6d1c3a4f](https://github.com/tpucci/sling_gql/commit/6d1c3a4ff503d6fe8af240d13f56eed1b410d89b))
 - **FEAT**(sling_gql_gen): debugLabel on the generated mutate and subscribe ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([c928a936](https://github.com/tpucci/sling_gql/commit/c928a93615585e282da671075c751ca77b70d7ca))
 - **FEAT**(sling_gql_sqflite): clear() also empties the stored mutation queue. ([9b20e98d](https://github.com/tpucci/sling_gql/commit/9b20e98da4b87dc57d0c5c860ed8a0a70be8c506))
 - **FEAT**(sling_gql_sqflite): persistence.mutationQueue ([#72](https://github.com/tpucci/sling_gql/issues/72)). ([a70f8b91](https://github.com/tpucci/sling_gql/commit/a70f8b9141e4db31d21e8492b571b2ad1e682280))
 - **DOCS**(repo): Versioning sections in the adapter, test and generator READMEs ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([a3574704](https://github.com/tpucci/sling_gql/commit/a35747046d8fa901476b73825661861c9acf78ce))
 - **BREAKING** **REFACTOR**(sling_gql): settle the 1.0 public surface ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([0f1e6992](https://github.com/tpucci/sling_gql/commit/0f1e6992e8cb3caee34071000742b2e10ddae482))
 - **BREAKING** **FEAT**(sling_gql_sqflite): migrate across schema changes, recover, one writer, codec ([#72](https://github.com/tpucci/sling_gql/issues/72)). ([40d0d46a](https://github.com/tpucci/sling_gql/commit/40d0d46a6986040d02288d71033d9c5524e56680))

## 0.1.0

Initial release.

- `SqflitePersistence.open(path, schema:)`: loads the stored rows into a `Cache` before the client starts (optionally in a background isolate), dropping root fields past `maxAge`, the oldest ones over `maxEntities`, and unreachable entities.
- Write-behind saves of `Cache.changesSince` deltas: debounced, bounded by `maxWait`, flushed on app pause/hide/detach and `flush()`; serialized, retried after a failure. One row per entity, one per `ROOT_QUERY` field.
- The store is wiped when the format version, key field or `slingSchema.hash` changed, or when its rows cannot be decoded (reported to `onError`).
- `clear()` (logout), `close()`, a pluggable `DatabaseFactory` (ffi, web, SQLCipher).
