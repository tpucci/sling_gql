import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

import 'load.dart';

/// Layout of the tables below. Bump it when they change: a database in
/// another format is wiped at open.
const sqfliteFormatVersion = 1;

const _meta = 'sling_meta';
const _entities = 'sling_entities';
const _rootFields = 'sling_root_fields';

/// What [SqflitePersistence.open] found and left out.
final class SqfliteLoadReport {
  const SqfliteLoadReport({
    required this.wiped,
    required this.entities,
    required this.rootFields,
    required this.expiredRootFields,
    required this.cappedRootFields,
    required this.unreachableEntities,
    required this.readTime,
    required this.hydrateTime,
  });

  /// The database was emptied first: new, or written under another format
  /// version, key field or schema hash.
  final bool wiped;

  /// Entities hydrated into [SqflitePersistence.cache] (roots excluded).
  final int entities;

  /// `ROOT_QUERY` fields hydrated.
  final int rootFields;

  /// Root fields dropped because older than `maxAge`.
  final int expiredRootFields;

  /// The oldest root fields dropped to fit `maxEntities`.
  final int cappedRootFields;

  /// Entities dropped because no kept root field reaches them.
  final int unreachableEntities;

  /// Opening the database and reading every row.
  final Duration readTime;

  /// Decoding the rows, pruning and building the cache (in an isolate with
  /// `hydrateInIsolate`, transfer included).
  final Duration hydrateTime;

  @override
  String toString() =>
      'SqfliteLoadReport(${wiped ? 'wiped, ' : ''}$entities entities, '
      '$rootFields root fields; dropped $expiredRootFields expired + '
      '$cappedRootFields capped root fields, $unreachableEntities '
      'unreachable entities; read ${readTime.inMilliseconds} ms, hydrate '
      '${hydrateTime.inMilliseconds} ms)';
}

/// A sling_gql [Cache] persisted in SQLite: the cache stays the in-memory
/// store every read goes to; the database is a durable write-behind copy.
///
/// ```dart
/// WidgetsFlutterBinding.ensureInitialized();
/// final persistence = await SqflitePersistence.open(
///   'sling_cache.db',
///   schema: slingSchema,
/// );
/// final client = SlingClient(
///   endpoint: endpoint,
///   schema: slingSchema,
///   cache: persistence.cache,
///   maxAge: const Duration(minutes: 5), // revalidates restored data
/// );
/// ```
///
/// - **Open** reads every row, drops what is past the bounds, and builds the
///   cache before the client exists ([open]). The returned persistence is
///   already listening to the cache: there is nothing to attach.
/// - **Saves** are deltas (`Cache.changesSince`), never a whole snapshot:
///   debounced on `Cache.onChange` ([debounce] after the last change, at
///   most [maxWait] after the first), on app pause / hide / detach, and on
///   [flush]. One transaction each, one after another; a failed save is
///   retried by the next one.
/// - **Rows**: one per entity, one per `ROOT_QUERY` field (a response
///   rewrites the fields it changed, and root fields age one by one).
///   `ROOT_MUTATION` and `ROOT_SUBSCRIPTION` are never stored.
/// - **Bounds** apply at open: root fields older than `maxAge` are dropped,
///   then the oldest ones until the entities they reach fit in
///   `maxEntities`; unreachable entities go with them.
final class SqflitePersistence {
  SqflitePersistence._(
    this._db,
    this.cache,
    this.loaded,
    this._now,
    this._onError, {
    required this.debounce,
    required this.maxWait,
    required this.compact,
    required bool flushOnLifecycle,
  }) : _storedRootFields = {...?cache.entity(queryRoot)?.keys} {
    if (flushOnLifecycle) {
      _lifecycle = AppLifecycleListener(onStateChange: _lifecycleChanged);
    }
    _subscription = cache.onChange.listen(_changed);
  }

  /// Opens (or creates) the database at [path] and builds [cache] from it.
  ///
  /// [path] is handed to [databaseFactory] (default: sqflite's, where a
  /// relative path lives in `getDatabasesPath()`; `inMemoryDatabasePath`
  /// for a store that lasts one run). Pass another factory for SQLCipher,
  /// the web (`sqflite_common_ffi_web`) or tests (`sqflite_common_ffi`).
  ///
  /// The database is wiped first when it was written under another
  /// [sqfliteFormatVersion], `schema.keyField` or `schema.hash` (the
  /// generated code changed: aliases and keyed types may have too), and
  /// when its rows cannot be decoded (reported to [onError]): the store is a
  /// cache, starting cold beats failing every launch. A file that is not a
  /// database at all fails [open]; delete it (`deleteDatabase(path)`) and
  /// open again.
  ///
  /// Bounds (`null` disables one): root fields last written more than
  /// [maxAge] ago are dropped; then, while the entities the remaining root
  /// fields reach exceed [maxEntities], the oldest root fields are dropped;
  /// entities no root field reaches are dropped (what `Cache.gc` does).
  /// What is dropped is deleted from the database before [open] returns.
  ///
  /// [hydrateInIsolate] decodes the rows and builds the cache in a
  /// background isolate (`compute`), keeping a large store's decode off the
  /// UI thread; the default builds it on the calling isolate, which is
  /// faster for small stores.
  ///
  /// With [flushOnLifecycle] (default) an [AppLifecycleListener] flushes when
  /// the app is hidden, paused or detached: the binding must be initialized
  /// (`WidgetsFlutterBinding.ensureInitialized()`, which sqflite needs
  /// anyway). Background save failures and undecodable stores go to
  /// [onError] (default: `FlutterError.reportError`); [now] is the clock
  /// behind `updated_at` and [maxAge], only worth overriding in tests.
  ///
  /// With [compact] (default) every stored save calls `Cache.compact` with
  /// the version it stored, so the cache forgets the change records the
  /// database already holds: a large `gc` then costs a delete per entity
  /// instead of a rewrite of every entity. Turn it off when something else
  /// reads `cache.changesSince` from versions this store already saved (a
  /// debug screen): those would get full deltas.
  static Future<SqflitePersistence> open(
    String path, {
    required SlingSchema<Accessor, Accessor> schema,
    DatabaseFactory? databaseFactory,
    Duration? maxAge = const Duration(days: 7),
    int? maxEntities = 10000,
    Duration debounce = const Duration(seconds: 1),
    Duration maxWait = const Duration(seconds: 5),
    bool hydrateInIsolate = false,
    bool flushOnLifecycle = true,
    bool compact = true,
    void Function(Object error, StackTrace stack)? onError,
    DateTime Function() now = DateTime.now,
  }) async {
    final reportError = onError ?? _reportError;
    assert(maxEntities == null || maxEntities >= 0);
    final factory = databaseFactory ?? sqflite.databaseFactory;
    final watch = Stopwatch()..start();
    final db = await factory.openDatabase(path);
    try {
      var wiped = await _prepare(db, schema);
      var rows = await _readRows(db);
      final readTime = watch.elapsed;
      final options = LoadOptions(
        keyField: schema.keyField,
        nowMs: now().millisecondsSinceEpoch,
        maxAgeMs: maxAge?.inMilliseconds,
        maxEntities: maxEntities,
      );
      LoadedCache loaded;
      try {
        loaded = hydrateInIsolate
            ? await compute(loadCache, (rows, options))
            : loadCache((rows, options));
      } catch (error, stack) {
        // A row that is not the JSON this package wrote (a corrupted page,
        // a hand edit): drop the store rather than fail every launch.
        reportError(error, stack);
        wiped = await _prepare(db, schema, force: true);
        rows = await _readRows(db);
        loaded = loadCache((rows, options));
      }
      final hydrateTime = watch.elapsed - readTime;
      await _deleteDropped(db, loaded);
      return SqflitePersistence._(
        db,
        loaded.cache,
        SqfliteLoadReport(
          wiped: wiped,
          entities: rows.entityKeys.length - loaded.unreachableEntities.length,
          rootFields:
              rows.rootFields.length -
              loaded.expiredRootFields.length -
              loaded.cappedRootFields.length,
          expiredRootFields: loaded.expiredRootFields.length,
          cappedRootFields: loaded.cappedRootFields.length,
          unreachableEntities: loaded.unreachableEntities.length,
          readTime: readTime,
          hydrateTime: hydrateTime,
        ),
        now,
        reportError,
        debounce: debounce,
        maxWait: maxWait,
        compact: compact,
        flushOnLifecycle: flushOnLifecycle,
      );
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  /// The hydrated cache: pass it to `SlingClient(cache:)`.
  final Cache cache;

  /// What [open] loaded and dropped, with timings.
  final SqfliteLoadReport loaded;

  /// Quiet time after the last cache change before a save starts.
  final Duration debounce;

  /// Longest a change waits for a save while changes keep coming.
  final Duration maxWait;

  /// Each stored save compacts the cache up to its version (see [open]).
  final bool compact;

  final Database _db;
  final DateTime Function() _now;
  final void Function(Object error, StackTrace stack) _onError;
  late final StreamSubscription<Set<String>> _subscription;
  AppLifecycleListener? _lifecycle;

  Timer? _debounceTimer;
  Timer? _maxWaitTimer;
  bool _closed = false;

  /// The tail of the save chain: saves never overlap, so an older delta
  /// can never land after a newer one.
  Future<void> _saving = Future.value();

  /// The [Cache.version] the database holds: the next save writes
  /// `cache.changesSince(savedVersion)`. Equal to `cache.version` when
  /// nothing is waiting to be saved.
  int get savedVersion => _savedVersion;
  int _savedVersion = 0;

  /// `ROOT_QUERY` fields touched since the last stored save: which root
  /// rows a delta holding a whole `ROOT_QUERY` copy (a full delta) rewrites;
  /// other deltas name their root fields (`CacheDelta.changedFields`).
  Set<String> _dirtyRootFields = {};

  /// The `ROOT_QUERY` fields the database has a row for. A root field that
  /// was not touched keeps its row, and so its `updated_at` (the `maxAge`
  /// clock), even through a full delta.
  Set<String> _storedRootFields;

  /// The underlying database, for inspection (`SELECT`s in tests, debug
  /// screens). Writing to the `sling_*` tables is undefined.
  Database get database => _db;

  static const _rootPrefix = '$queryRoot.';

  void _changed(Set<String> keys) {
    for (final key in keys) {
      if (!key.startsWith(_rootPrefix)) continue;
      // `ROOT_QUERY.<alias>`, or `<alias>[i]` / `<alias>[length]` for a list
      // the root field holds: aliases never contain `.` or `[`.
      final bracket = key.indexOf('[', _rootPrefix.length);
      _dirtyRootFields.add(
        key.substring(_rootPrefix.length, bracket < 0 ? key.length : bracket),
      );
    }
    if (_closed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, _timerFired);
    _maxWaitTimer ??= Timer(maxWait, _timerFired);
  }

  void _timerFired() {
    _cancelTimers();
    _enqueueSave().catchError(_onError);
  }

  void _lifecycleChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // The app may be killed from here on: save now (a no-op when
        // nothing changed).
        _cancelTimers();
        _enqueueSave().catchError(_onError);
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _cancelTimers() {
    _debounceTimer?.cancel();
    _maxWaitTimer?.cancel();
    _debounceTimer = null;
    _maxWaitTimer = null;
  }

  /// Saves what changed now, without waiting for the debounce; completes
  /// when the database holds it (after the saves already running). Throws
  /// what the save threw; the changes stay pending for the next save.
  Future<void> flush() {
    _cancelTimers();
    return _enqueueSave();
  }

  Future<void> _enqueueSave() {
    final save = _saving.then((_) => _save());
    _saving = save.then<void>((_) {}, onError: (Object _) {});
    return save;
  }

  Future<void> _save() async {
    if (!_db.isOpen) return;
    // Taken together, synchronously: the touched root fields are exactly
    // those of the changes up to `delta.version`.
    final delta = cache.changesSince(_savedVersion);
    final rootFields = _dirtyRootFields;
    _dirtyRootFields = {};
    if (delta.isEmpty) return;
    final now = _now().millisecondsSinceEpoch;
    final Set<String> storedRootFields;
    try {
      storedRootFields = await _db.transaction((txn) async {
        final batch = txn.batch();
        final stored = _writeDelta(batch, delta, rootFields, now);
        await batch.commit(noResult: true);
        return stored;
      });
    } catch (_) {
      // Not stored: the next save starts from the same version again.
      _dirtyRootFields.addAll(rootFields);
      rethrow;
    }
    _storedRootFields = storedRootFields;
    _savedVersion = delta.version;
    if (compact) cache.compact(upTo: delta.version);
  }

  /// Adds [delta] to [batch]; returns the root fields stored once it is
  /// committed.
  Set<String> _writeDelta(
    Batch batch,
    CacheDelta delta,
    Set<String> dirtyRootFields,
    int now,
  ) {
    // A full delta carries every entity: the others are gone. Root rows are
    // reconciled field by field below, so untouched ones keep their age.
    if (delta.full) batch.delete(_entities);
    _deleteRows(batch, _entities, 'key', [
      for (final key in delta.removed)
        if (!_isRoot(key)) key,
    ]);
    for (final MapEntry(:key, value: entity) in delta.changed.entries) {
      if (_isRoot(key)) continue;
      batch.insert(_entities, {
        'key': key,
        'json': jsonEncode(entity),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final changedFields = delta.changedFields[queryRoot];
    final removedFields = delta.removedFields[queryRoot];
    if (changedFields != null || removedFields != null) {
      // The usual delta: the root field by field (#68).
      final stored = {..._storedRootFields};
      for (final MapEntry(key: field, :value)
          in (changedFields ?? const {}).entries) {
        batch.insert(_rootFields, {
          'field': field,
          'json': jsonEncode(value),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        stored.add(field);
      }
      _deleteRows(batch, _rootFields, 'field', [
        for (final field in removedFields ?? const <String>{})
          if (stored.remove(field)) field,
      ]);
      return stored;
    }

    // The root copied whole (a full delta, a root removed and written
    // again), or not changed.
    final root = delta.changed[queryRoot];
    if (root == null) {
      if (!delta.full && !delta.removed.contains(queryRoot)) {
        return _storedRootFields; // the root did not change
      }
      batch.delete(_rootFields);
      return {};
    }
    // Rewrite the fields touched since the last save (and any field without
    // a row); delete the rows of fields the root no longer has.
    for (final MapEntry(key: field, :value) in root.entries) {
      if (!dirtyRootFields.contains(field) &&
          _storedRootFields.contains(field)) {
        continue;
      }
      batch.insert(_rootFields, {
        'field': field,
        'json': jsonEncode(value),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    _deleteRows(batch, _rootFields, 'field', [
      for (final field in _storedRootFields)
        if (!root.containsKey(field)) field,
    ]);
    return root.keys.toSet();
  }

  static bool _isRoot(String key) => key.startsWith('ROOT_');

  /// Deletes the rows of [table] whose [column] is in [values], a few
  /// hundred per statement: one `DELETE` per row made a large `gc` cost as
  /// much as rewriting the live entities (#69). 500 stays under SQLite's
  /// oldest bound-variable limit (999).
  static void _deleteRows(
    Batch batch,
    String table,
    String column,
    List<String> values,
  ) {
    const chunk = 500;
    for (var start = 0; start < values.length; start += chunk) {
      final end = start + chunk < values.length ? start + chunk : values.length;
      final args = values.sublist(start, end);
      batch.delete(
        table,
        where: '$column IN (${List.filled(args.length, '?').join(', ')})',
        whereArgs: args,
      );
    }
  }

  /// Logout: empties the cache (every query refetches) and the database.
  Future<void> clear() {
    cache.clear();
    return flush();
  }

  /// Saves what is pending, stops listening and closes the database. The
  /// cache stays usable, unpersisted.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _lifecycle?.dispose();
    await _subscription.cancel();
    try {
      await flush();
    } finally {
      await _db.close();
    }
  }

  static void _reportError(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'sling_gql_sqflite',
        context: ErrorDescription('while persisting the cache'),
      ),
    );
  }

  /// Creates the tables, or recreates them when the stored format version,
  /// key field or schema hash differ (or when [force]d). True when the
  /// database was (re)made.
  static Future<bool> _prepare(
    Database db,
    SlingSchema<Accessor, Accessor> schema, {
    bool force = false,
  }) async {
    final expected = {
      'format_version': '$sqfliteFormatVersion',
      'key_field': schema.keyField,
      'schema_hash': schema.hash ?? '',
    };
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $_meta '
      '(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    final stored = {
      for (final row in await db.query(_meta))
        row['key']! as String: row['value']! as String,
    };
    if (!force && mapEquals(stored, expected)) return false;
    await db.transaction((txn) async {
      final batch = txn.batch()
        ..execute('DROP TABLE IF EXISTS $_entities')
        ..execute('DROP TABLE IF EXISTS $_rootFields')
        ..execute(
          'CREATE TABLE $_entities (key TEXT PRIMARY KEY, '
          'json TEXT NOT NULL, updated_at INTEGER NOT NULL)',
        )
        ..execute(
          'CREATE TABLE $_rootFields (field TEXT PRIMARY KEY, '
          'json TEXT NOT NULL, updated_at INTEGER NOT NULL)',
        )
        ..delete(_meta);
      for (final e in expected.entries) {
        batch.insert(_meta, {'key': e.key, 'value': e.value});
      }
      await batch.commit(noResult: true);
    });
    return true;
  }

  static Future<StoredRows> _readRows(Database db) async {
    final entities = await db.query(_entities, columns: ['key', 'json']);
    final roots = await db.query(
      _rootFields,
      columns: ['field', 'json', 'updated_at'],
    );
    return StoredRows(
      entityKeys: [for (final r in entities) r['key']! as String],
      entityJson: [for (final r in entities) r['json']! as String],
      rootFields: [for (final r in roots) r['field']! as String],
      rootJson: [for (final r in roots) r['json']! as String],
      rootUpdatedAt: [for (final r in roots) r['updated_at']! as int],
    );
  }

  static Future<void> _deleteDropped(Database db, LoadedCache loaded) async {
    final fields = [...loaded.expiredRootFields, ...loaded.cappedRootFields];
    if (fields.isEmpty && loaded.unreachableEntities.isEmpty) return;
    await db.transaction((txn) async {
      final batch = txn.batch();
      _deleteRows(batch, _rootFields, 'field', fields);
      _deleteRows(batch, _entities, 'key', loaded.unreachableEntities);
      await batch.commit(noResult: true);
    });
  }
}
