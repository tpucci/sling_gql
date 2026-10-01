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
  `onSaveError`) leaves its changes pending for the next one.
- One row per entity (`sling_entities`: `key`, `json`, `updated_at`), one row
  per `ROOT_QUERY` field (`sling_root_fields`: `field`, `json`, `updated_at`):
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
the counts and timings.

## Invalidation

The database stores a format version, the key field and `slingSchema.hash`
(a fingerprint `sling_gql_gen` emits of the generated file). When any of them
differs at open — the schema, `--key-field`, a `--scalar` mapping or the
generator changed — the store is wiped and the app starts cold.

## Options

| Option | Default | |
| --- | --- | --- |
| `databaseFactory` | sqflite's | `sqflite_common_ffi` for desktop/tests, `sqflite_common_ffi_web`, an SQLCipher factory for encryption |
| `maxAge` / `maxEntities` | 7 days / 10 000 | bounds applied at open |
| `debounce` / `maxWait` | 1 s / 5 s | save timing |
| `hydrateInIsolate` | `false` | decode and build the cache in a background isolate (`compute`) |
| `flushOnLifecycle` | `true` | save when the app goes to the background |
| `onSaveError` | `FlutterError.reportError` | background save failures |

## Numbers

Host benchmark (`flutter test benchmark/persistence_bench_test.dart`, JIT,
macOS, `sqflite_common_ffi`; ~600 B of JSON per entity):

| | 1 000 entities (0.6 MB) | 10 000 entities (5.6 MB) |
| --- | --- | --- |
| open: read rows | 4 ms | 15 ms |
| open: decode + prune + hydrate | 8 ms | 63–86 ms |
| same with `hydrateInIsolate` (off the UI thread) | 10 ms | 76 ms |
| save of a 20-entity delta | 2 ms | 2.5 ms |
| first save (every entity) | 39 ms | 210 ms |

A delta's cost depends on what changed, not on the store's size.
