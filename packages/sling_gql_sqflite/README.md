# sling_gql_sqflite

Persist [sling_gql](https://pub.dev/packages/sling_gql)'s normalized cache in
SQLite with [sqflite](https://pub.dev/packages/sqflite): the app's second
launch paints from the previous run's data, with no skeleton and no request
(or a background revalidation under `maxAge`).

Reads stay synchronous and in memory — they happen inside `build()`. The
database is a durable **write-behind copy**: loaded once before the client
starts, then kept up to date with small deltas. Memory is the persisted
size, so the *store* is bounded (by age and entity count).

Docs: https://tpucci.github.io/sling_gql/guides/persistence/ · Source:
https://github.com/tpucci/sling_gql

```sh
flutter pub add sling_gql_sqflite
```

```dart
import 'package:sling_gql_sqflite/sling_gql_sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final persistence = await SqflitePersistence.open(
    'sling_cache.db', // relative: in sqflite's getDatabasesPath()
    schema: slingSchema,
  );
  final client = SlingClient<Query>(
    endpoint: Uri.parse(endpoint),
    schema: slingSchema,
    cache: persistence.cache,
    // Restored data carries no fetch time: under maxAge it is shown, then
    // revalidated in the background. Plain cacheFirst never refetches it.
    maxAge: const Duration(minutes: 5),
  );
  runApp(SlingScope(client: client, child: const App()));
}

// Logout: empty the cache (every query refetches) and the database.
await persistence.clear();
```

## How it saves

- `open` returns a persistence already listening to `cache.onChange`: there is
  nothing to attach.
- Every save is `cache.changesSince(savedVersion)` — the entities changed or
  removed since the last stored save, never a whole snapshot — written in one
  transaction (`batch.commit(noResult: true)`).
- Saves start `debounce` (1 s) after the last change, at most `maxWait` (5 s)
  after the first one, when the app is hidden, paused or detached
  (`AppLifecycleListener`), and on `flush()`. They run one after another, so
  an older delta never lands after a newer one; a failed save (reported to
  `onError`) leaves its changes pending for the next one.
- One row per entity (`sling_entities`: `key`, `data`, `updated_at`), one row
  per `ROOT_QUERY` field (`sling_root_fields`: `field`, `data`, `updated_at`;
  `data` is the JSON, or the codec's bytes):
  a response rewrites the root fields it touched, not the whole root.
  `ROOT_MUTATION` and `ROOT_SUBSCRIPTION` are never stored.

## Bounds

Applied when the store is opened (`null` disables one):

- `maxAge` (7 days): root fields whose row was last written longer ago are
  dropped;
- `maxEntities` (10 000): while the entities the remaining root fields reach
  are more, the oldest root fields are dropped;
- entities no kept root field reaches are dropped (what `cache.gc()` does).

Dropped rows are deleted before `open` returns; `persistence.loaded` reports
the counts and timings. `maxEntities` counts entities only: inline data under
root fields is bounded by `maxAge` alone.

## Corruption

A file that is not a database, or a row that cannot be decoded (a damaged
page, a hand edit, a codec that throws), never fails the launch: the error
goes to `onError`, the file is deleted and recreated, and the app starts cold
(`loaded.recovered`). Only a failure to create that fresh database
(permissions, a full disk) makes `open` throw, and a database another
connection keeps locked (`SQLITE_BUSY` / `SQLITE_LOCKED`), which is left
alone.

## Schema changes

The database stores a format version, the key field, the codec id,
`slingSchema.hash` (a fingerprint `sling_gql_gen` emits of the generated file)
and `slingSchema.fields` (every field of every object type with its
signature: arguments, defaults, type). When the hash differs at open — the
schema, `--key-field`, a `--scalar` mapping or the generator changed — the
store is **migrated**: a cached field is kept only when its field has the same
signature in both schemas; entities of a gone type, root fields whose field is
gone or changed, and fields holding inline objects of a gone type are dropped
(they read as missing and are fetched again). `loaded.migrated`,
`incompatibleRootFields` and `incompatibleEntities` report it.

Another key field, format version or codec id, or a hash change with no
`fields` on either side (a hand-written schema, a store written by an older
version), wipes the store and the app starts cold.

## One writer per file

Opening a path this isolate already has open throws a `StateError` (sqflite
shares one connection per path). Across isolates and processes the last
`open` wins: it records itself as the writer, and the previous instance's
next save notices inside its transaction, stores nothing, reports a
`SqfliteSupersededException` to `onError` once and sets `superseded`; its
cache stays usable, unpersisted.

## Encryption

`codec:` takes an `SqfliteCodec` (`id`, synchronous `encode` / `decode` of
each row's UTF-8 JSON bytes): plug in the cipher your app already uses — this
package ships none. Rows are then blobs. A store written under another codec
id (a rotated key) or none is wiped at open; a `decode` that throws counts as
corruption. With `hydrateInIsolate` the codec must be sendable to the
background isolate. For whole-file encryption pass an SQLCipher
`databaseFactory` instead.

## Options

| Option | Default | |
| --- | --- | --- |
| `databaseFactory` | sqflite's | `sqflite_common_ffi` for desktop/tests, `sqflite_common_ffi_web`, an SQLCipher factory for whole-file encryption |
| `codec` | none | row-value transform (encryption), see above |
| `maxAge` / `maxEntities` | 7 days / 10 000 | bounds applied at open |
| `debounce` / `maxWait` | 1 s / 5 s | save timing |
| `hydrateInIsolate` | `false` | decode and build the cache in a background isolate (`compute`) |
| `flushOnLifecycle` | `true` | save when the app goes to the background |
| `compact` | `true` | `cache.compact` after each save; off if something else reads `changesSince` |
| `onError` | `FlutterError.reportError` | background save failures, recovered stores, `SqfliteSupersededException` |

## Numbers

Host benchmark (`flutter test benchmark/persistence_bench_test.dart`, JIT,
macOS, `sqflite_common_ffi`; ~600 B of JSON per entity):

| | 1 000 entities (0.6 MB) | 10 000 entities (5.6 MB) |
| --- | --- | --- |
| open: read rows | 4 ms | 14 ms |
| open: decode + prune + hydrate | 5–6 ms | 46–76 ms |
| same with `hydrateInIsolate` (off the UI thread) | 6–8 ms | 55–86 ms |
| `changesSince`: new root field + 20 changed entities | 0.03 ms | 0.03 ms |
| save of that delta | 2 ms | 2–3 ms |
| save after a `gc` of 60% of the entities | 4–5 ms | 37–44 ms |
| first save, or a full delta (every entity) | 38–47 ms | 165–190 ms |

A save costs what changed (the runtime reports `ROOT_QUERY` field by field,
and each save compacts the cache's change records, so a big `gc` is a few
`DELETE … IN (…)` statements, not a rewrite of every live entity); opening is
mostly `jsonDecode` of the rows. Only `clear()` (or a store opened with
`compact: false` once the cache forgot over a thousand removals) gets a full
delta.
