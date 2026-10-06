import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

import 'codec.dart';
import 'load.dart';

/// Layout of the tables below. Bump it when they change: a database in
/// another format is wiped at open. 2: row values in a `data` column (text,
/// or the codec's blob), `schema_fields`, `codec` and `owner` in the meta
/// table.
const sqfliteFormatVersion = 2;

const _meta = 'sling_meta';
const _entities = 'sling_entities';
const _rootFields = 'sling_root_fields';

/// The client's offline mutations (`SqflitePersistence.mutationQueue`): one
/// row per `QueuedMutation`, in insertion (`rowid`) order. Not part of the
/// [sqfliteFormatVersion]: wiping the cache keeps it.
const _mutationQueue = 'sling_mutation_queue';

/// What [SqflitePersistence.open] found and left out.
final class SqfliteLoadReport {
  const SqfliteLoadReport({
    required this.wiped,
    required this.migrated,
    required this.recovered,
    required this.entities,
    required this.rootFields,
    required this.expiredRootFields,
    required this.cappedRootFields,
    required this.unreachableEntities,
    required this.incompatibleRootFields,
    required this.incompatibleEntities,
    required this.readTime,
    required this.hydrateTime,
  });

  /// The database was emptied first: new, written under another format
  /// version, key field or codec, under another schema hash without the
  /// fields to migrate it, or [recovered].
  final bool wiped;

  /// The database was written under another schema hash and migrated:
  /// what the current schema can still read was kept (see
  /// [incompatibleRootFields], [incompatibleEntities]).
  final bool migrated;

  /// The database could not be opened or read (a corrupt file, rows that do
  /// not decode): the error went to `onError`, the file was deleted and a
  /// new, empty one created.
  final bool recovered;

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

  /// Migration: root fields dropped because their field is gone or changed
  /// signature (or holds an object of a gone type).
  final int incompatibleRootFields;

  /// Migration: entities dropped because their type is gone.
  final int incompatibleEntities;

  /// Opening the database and reading every row.
  final Duration readTime;

  /// Decoding the rows, pruning and building the cache (in an isolate with
  /// `hydrateInIsolate`, transfer included).
  final Duration hydrateTime;

  @override
  String toString() =>
      'SqfliteLoadReport(${recovered ? 'recovered, ' : ''}'
      '${wiped ? 'wiped, ' : ''}${migrated ? 'migrated, ' : ''}'
      '$entities entities, $rootFields root fields; dropped '
      '$expiredRootFields expired + $cappedRootFields capped + '
      '$incompatibleRootFields incompatible root fields, '
      '$unreachableEntities unreachable + $incompatibleEntities incompatible '
      'entities; read ${readTime.inMilliseconds} ms, hydrate '
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
/// - **Schema changes** migrate the store when the generated code carries
///   `slingSchema.fields`: cached fields whose signature did not change are
///   kept, the rest is dropped (see [open]).
/// - **One writer per database file**: the last [open] wins (see
///   [superseded]).
final class SqflitePersistence {
  SqflitePersistence._(
    this._db,
    this._owner,
    this.cache,
    this.loaded,
    this._now,
    this._onError, {
    required this.debounce,
    required this.maxWait,
    required this.compact,
    required this.codec,
    required bool flushOnLifecycle,
    required List<QueuedMutation> queuedMutations,
  }) : _storedRootFields = {...?cache.entity(queryRoot)?.keys} {
    mutationQueue = _SqfliteMutationQueue(this, queuedMutations);
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
  /// [sqfliteFormatVersion], `schema.keyField` or [codec] id. Under another
  /// `schema.hash` (the generated code changed: aliases and keyed types may
  /// have too) it is **migrated** when both the store and [schema] carry
  /// `SlingSchema.fields`: a cached field is kept only when its field (name,
  /// arguments with their defaults, type) is the same in both schemas;
  /// entities of a type that is gone and root fields whose field is gone,
  /// changed, or holds an inline object of a gone type are dropped. Without
  /// fields on either side it is wiped. Kept data is revalidated like any
  /// restored data (`maxAge`).
  ///
  /// **Corruption**: when the file cannot be opened as a database or a row
  /// cannot be decoded (a corrupted page, a hand edit, a [codec] that
  /// throws), the error goes to [onError], the file is deleted and a new one
  /// created ([SqfliteLoadReport.recovered]): the store is a cache, starting
  /// cold beats failing every launch. Only a failure to create that new
  /// database (permissions, a full disk) makes [open] throw, and a database
  /// another connection keeps locked (`SQLITE_BUSY` / `SQLITE_LOCKED`):
  /// that file is healthy, so it is left alone.
  ///
  /// **One instance per file**: opening a path this isolate already has open
  /// (and not [close]d) throws a [StateError]. Across isolates and processes
  /// the last [open] takes the database over: the previous instance notices
  /// at its next save, stores nothing more and reports
  /// [SqfliteSupersededException] to its [onError] ([superseded]).
  ///
  /// [codec] transforms every row value (encryption, see [SqfliteCodec]).
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
  /// faster for small stores. The [codec] then runs in that isolate too.
  ///
  /// With [flushOnLifecycle] (default) an [AppLifecycleListener] flushes when
  /// the app is hidden, paused or detached: the binding must be initialized
  /// (`WidgetsFlutterBinding.ensureInitialized()`, which sqflite needs
  /// anyway). Background save failures, recovered stores and supersession go
  /// to [onError] (default: `FlutterError.reportError`); [now] is the clock
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
    SqfliteCodec? codec,
    void Function(Object error, StackTrace stack)? onError,
    DateTime Function() now = DateTime.now,
  }) async {
    final reportError = onError ?? _reportError;
    assert(maxEntities == null || maxEntities >= 0);
    final factory = databaseFactory ?? sqflite.databaseFactory;
    final owner = _newOwnerToken();
    final watch = Stopwatch()..start();
    var recovered = false;
    // Not a database, or rows this package cannot read: report, delete the
    // file and start cold rather than fail every launch.
    Future<void> recover(Object error, StackTrace stack) async {
      reportError(error, stack);
      recovered = true;
      try {
        await factory.deleteDatabase(path);
      } catch (_) {} // the next attempt reports what is wrong
    }

    while (true) {
      final Database db;
      try {
        db = await factory.openDatabase(path);
      } catch (error, stack) {
        if (recovered) rethrow; // already a fresh file
        await recover(error, stack);
        continue;
      }
      if (!_openDatabases.add(db)) {
        // sqflite's shared instance: the other persistence's, not ours to
        // close.
        throw StateError(
          'SqflitePersistence: ${db.path} is already open in this isolate; '
          'close() the other instance first.',
        );
      }
      try {
        final prepared = await _prepare(db, schema, codec, owner);
        final queued = await _loadQueue(
          db,
          codec,
          rollbackStale: prepared.wiped,
          onError: reportError,
        );
        final rows = await _readRows(db);
        final readTime = watch.elapsed;
        final options = LoadOptions(
          keyField: schema.keyField,
          nowMs: now().millisecondsSinceEpoch,
          maxAgeMs: maxAge?.inMilliseconds,
          maxEntities: maxEntities,
          codec: codec,
          migrateFrom: prepared.migrateFrom,
          migrateTo: prepared.migrateFrom == null ? null : schema.fields,
        );
        final loaded = hydrateInIsolate
            ? await compute(loadCache, (rows, options))
            : loadCache((rows, options));
        final hydrateTime = watch.elapsed - readTime;
        await _storeLoad(
          db,
          loaded,
          migratedTo: prepared.migrateFrom == null ? null : schema,
        );
        return SqflitePersistence._(
          db,
          owner,
          loaded.cache,
          SqfliteLoadReport(
            wiped: prepared.wiped || recovered,
            migrated: prepared.migrateFrom != null,
            recovered: recovered,
            entities:
                rows.entityKeys.length -
                loaded.unreachableEntities.length -
                loaded.incompatibleEntities.length,
            rootFields:
                rows.rootFields.length -
                loaded.expiredRootFields.length -
                loaded.cappedRootFields.length -
                loaded.incompatibleRootFields.length,
            expiredRootFields: loaded.expiredRootFields.length,
            cappedRootFields: loaded.cappedRootFields.length,
            unreachableEntities: loaded.unreachableEntities.length,
            incompatibleRootFields: loaded.incompatibleRootFields.length,
            incompatibleEntities: loaded.incompatibleEntities.length,
            readTime: readTime,
            hydrateTime: hydrateTime,
          ),
          now,
          reportError,
          debounce: debounce,
          maxWait: maxWait,
          compact: compact,
          codec: codec,
          flushOnLifecycle: flushOnLifecycle,
          queuedMutations: queued,
        );
      } catch (error, stack) {
        _openDatabases.remove(db);
        try {
          await db.close();
        } catch (_) {}
        // Already a fresh file, or a healthy one another connection holds.
        if (recovered || _isBusy(error)) rethrow;
        await recover(error, stack);
      }
    }
  }

  /// The databases open in this isolate by a live instance. sqflite hands
  /// out one shared [Database] per path, so a second instance on the same
  /// path would share (and close) the first one's connection.
  static final _openDatabases = Set<Database>.identity();

  /// `SQLITE_BUSY` / `SQLITE_LOCKED` (primary or extended code): another
  /// connection holds the file, which says nothing about its contents.
  static bool _isBusy(Object error) {
    if (error is! DatabaseException) return false;
    final code = error.getResultCode();
    return code != null && (code & 0xff == 5 || code & 0xff == 6);
  }

  static String _newOwnerToken() {
    final random = Random.secure();
    return [
      DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      for (var i = 0; i < 4; i++) random.nextInt(1 << 32).toRadixString(36),
    ].join('-');
  }

  /// The hydrated cache: pass it to `SlingClient(cache:)`.
  final Cache cache;

  /// The client's offline mutations, kept in this database: pass it to
  /// `SlingClient(mutationQueue:)` so the calls queued by
  /// `mutateWith(offline: true)` survive the app being killed. Its `load`
  /// returns what [open] read (oldest first); entries are written at once,
  /// in order with the cache saves (an entry lands before the save holding
  /// its optimistic writes), and only while this instance owns the
  /// database ([superseded]). Write failures go to `onError`.
  ///
  /// When [open] wipes the cache (another format, key field or schema
  /// without fields to migrate along) the queued mutations are kept but
  /// their rollback logs are dropped: the optimistic values they would
  /// undo are gone with the cache. Under another [codec] id they cannot be
  /// decoded and are dropped; a row that does not decode is reported to
  /// `onError` and deleted. A recovered (deleted) file loses them. [clear]
  /// empties it.
  late final MutationQueueStore mutationQueue;

  /// What [open] loaded and dropped, with timings.
  final SqfliteLoadReport loaded;

  /// Quiet time after the last cache change before a save starts.
  final Duration debounce;

  /// Longest a change waits for a save while changes keep coming.
  final Duration maxWait;

  /// Each stored save compacts the cache up to its version (see [open]).
  final bool compact;

  /// Transforms row values (see [SqfliteCodec]); `null` stores plain JSON.
  final SqfliteCodec? codec;

  /// True once another [open] of this database file (from another isolate
  /// or process) took it over: this instance stores nothing more — its
  /// cache stays usable, unpersisted. Noticed at the first save after the
  /// takeover, which reports a [SqfliteSupersededException] to `onError`.
  bool get superseded => _superseded;
  bool _superseded = false;

  final Database _db;

  /// Written to `sling_meta.owner` by [open]: a save stores only while the
  /// database still names this instance.
  final String _owner;
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
    if (_superseded || !_db.isOpen) return;
    // Taken together, synchronously: the touched root fields are exactly
    // those of the changes up to `delta.version`.
    final delta = cache.changesSince(_savedVersion);
    final rootFields = _dirtyRootFields;
    _dirtyRootFields = {};
    if (delta.isEmpty) return;
    final now = _now().millisecondsSinceEpoch;
    final Set<String>? storedRootFields;
    try {
      storedRootFields = await _db.transaction((txn) async {
        // In the write transaction: no other instance can take the database
        // over between this check and the commit.
        if (!await _owns(txn)) return null;
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
    if (storedRootFields == null) {
      _supersede();
      return;
    }
    _storedRootFields = storedRootFields;
    _savedVersion = delta.version;
    if (compact) cache.compact(upTo: delta.version);
  }

  void _supersede() {
    _superseded = true;
    _cancelTimers();
    _onError(SqfliteSupersededException(_db.path), StackTrace.current);
  }

  /// Runs [write] in a transaction after the saves already queued (the
  /// mutation queue's writes share the save chain, so they are ordered with
  /// the cache saves). Reports failures to `onError` instead of throwing.
  Future<void> _enqueueWrite(void Function(Batch batch) write) {
    Future<void> run() async {
      if (_superseded || !_db.isOpen) return;
      final stored = await _db.transaction((txn) async {
        if (!await _owns(txn)) return false;
        final batch = txn.batch();
        write(batch);
        await batch.commit(noResult: true);
        return true;
      });
      if (!stored) _supersede();
    }

    final done = _saving.then((_) => run());
    _saving = done.then<void>((_) {}, onError: (Object _) {});
    return done.catchError(_onError);
  }

  /// Whether the database still names this instance as its writer.
  Future<bool> _owns(Transaction txn) async {
    final owner = await txn.query(
      _meta,
      columns: ['value'],
      where: "key = 'owner'",
    );
    return owner.singleOrNull?['value'] == _owner;
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
        'data': encodeRow(entity, codec),
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
          'data': encodeRow(value, codec),
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
        'data': encodeRow(value, codec),
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

  /// Logout: empties the cache (every query refetches), the stored
  /// [mutationQueue] and the database. Call the client's
  /// `clearMutationQueue()` first: it also rolls back the queued calls'
  /// optimistic writes, fails their futures and stops replaying them (this
  /// only empties the table the next run would replay).
  Future<void> clear() {
    cache.clear();
    unawaited(mutationQueue.clear());
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
      _openDatabases.remove(_db);
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
  /// key field or codec differ, or the schema hash with no fields to migrate
  /// along; then makes [owner] the database's writer. `migrateFrom` is the
  /// fields the rows were written under when they are to be migrated.
  static Future<({bool wiped, SchemaFields? migrateFrom})> _prepare(
    Database db,
    SlingSchema<Accessor, Accessor> schema,
    SqfliteCodec? codec,
    String owner,
  ) async {
    final fields = schema.fields;
    final expected = {
      'format_version': '$sqfliteFormatVersion',
      'key_field': schema.keyField,
      'codec': codec?.id ?? '',
    };
    final hash = schema.hash ?? '';
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $_meta '
      '(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    final stored = {
      for (final row in await db.query(_meta))
        row['key']! as String: row['value']! as String,
    };
    final compatible = expected.entries.every((e) => stored[e.key] == e.value);
    final storedFields = stored['schema_fields'];
    final ({bool wiped, SchemaFields? migrateFrom}) result;
    if (compatible && stored['schema_hash'] == hash) {
      result = (wiped: false, migrateFrom: null);
    } else if (compatible && storedFields != null && fields != null) {
      // Meta moves to the new schema once the rows are (see _storeLoad).
      result = (wiped: false, migrateFrom: _decodeFields(storedFields));
    } else {
      result = (wiped: true, migrateFrom: null);
    }
    final codecChanged =
        stored['codec'] != null && stored['codec'] != expected['codec'];
    await db.transaction((txn) async {
      final batch = txn.batch();
      // Rows written under another codec cannot be decoded.
      if (codecChanged) batch.execute('DROP TABLE IF EXISTS $_mutationQueue');
      batch.execute(
        'CREATE TABLE IF NOT EXISTS $_mutationQueue (id TEXT PRIMARY KEY, '
        'data BLOB NOT NULL, created_at INTEGER NOT NULL)',
      );
      if (result.wiped) {
        batch
          ..execute('DROP TABLE IF EXISTS $_entities')
          ..execute('DROP TABLE IF EXISTS $_rootFields')
          ..execute(
            'CREATE TABLE $_entities (key TEXT PRIMARY KEY, '
            'data BLOB NOT NULL, updated_at INTEGER NOT NULL)',
          )
          ..execute(
            'CREATE TABLE $_rootFields (field TEXT PRIMARY KEY, '
            'data BLOB NOT NULL, updated_at INTEGER NOT NULL)',
          )
          ..delete(_meta);
        for (final MapEntry(:key, :value) in {
          ...expected,
          'schema_hash': hash,
          if (fields != null) 'schema_fields': jsonEncode(fields),
        }.entries) {
          batch.insert(_meta, {'key': key, 'value': value});
        }
      }
      batch.insert(_meta, {
        'key': 'owner',
        'value': owner,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    });
    return result;
  }

  /// The queued mutations, oldest first. A row that does not decode is
  /// reported and deleted; with [rollbackStale] (the cache was wiped) the
  /// rollback logs are dropped from the rows.
  static Future<List<QueuedMutation>> _loadQueue(
    Database db,
    SqfliteCodec? codec, {
    required bool rollbackStale,
    required void Function(Object error, StackTrace stack) onError,
  }) async {
    final rows = await db.query(
      _mutationQueue,
      columns: ['id', 'data'],
      orderBy: 'rowid',
    );
    final entries = <QueuedMutation>[];
    final unreadable = <String>[];
    final stripped = <QueuedMutation>[];
    for (final row in rows) {
      final id = row['id']! as String;
      try {
        var entry = QueuedMutation.fromJson(
          (decodeRow(row['data'], codec)! as Map).cast<String, Object?>(),
        );
        if (rollbackStale && entry.rollback.isNotEmpty) {
          entry = QueuedMutation.fromJson(
            {...entry.toJson()}..remove('rollback'),
          );
          stripped.add(entry);
        }
        entries.add(entry);
      } catch (error, stack) {
        onError(error, stack);
        unreadable.add(id);
      }
    }
    if (unreadable.isNotEmpty || stripped.isNotEmpty) {
      final batch = db.batch();
      _deleteRows(batch, _mutationQueue, 'id', unreadable);
      for (final entry in stripped) {
        batch.update(
          _mutationQueue,
          {'data': encodeRow(entry.toJson(), codec)},
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      }
      await batch.commit(noResult: true);
    }
    return entries;
  }

  static SchemaFields _decodeFields(String json) => {
    for (final MapEntry(:key, :value)
        in (jsonDecode(json) as Map<String, Object?>).entries)
      key: (value! as Map<String, Object?>).cast<String, String>(),
  };

  static Future<StoredRows> _readRows(Database db) async {
    final entities = await db.query(_entities, columns: ['key', 'data']);
    final roots = await db.query(
      _rootFields,
      columns: ['field', 'data', 'updated_at'],
    );
    return StoredRows(
      entityKeys: [for (final r in entities) r['key']! as String],
      entityData: [for (final r in entities) r['data']],
      rootFields: [for (final r in roots) r['field']! as String],
      rootData: [for (final r in roots) r['data']],
      rootUpdatedAt: [for (final r in roots) r['updated_at']! as int],
    );
  }

  /// Deletes what [loaded] left out, rewrites the rows the migration pruned
  /// and, after a migration, records the schema the rows now follow.
  static Future<void> _storeLoad(
    Database db,
    LoadedCache loaded, {
    required SlingSchema<Accessor, Accessor>? migratedTo,
  }) async {
    final fields = [
      ...loaded.expiredRootFields,
      ...loaded.cappedRootFields,
      ...loaded.incompatibleRootFields,
    ];
    final entities = [
      ...loaded.unreachableEntities,
      ...loaded.incompatibleEntities,
    ];
    if (fields.isEmpty && entities.isEmpty && migratedTo == null) return;
    await db.transaction((txn) async {
      final batch = txn.batch();
      _deleteRows(batch, _rootFields, 'field', fields);
      _deleteRows(batch, _entities, 'key', entities);
      // `updated_at` stays: the data is as old as it was.
      for (final MapEntry(:key, :value) in loaded.rewrittenRootFields.entries) {
        batch.update(
          _rootFields,
          {'data': value},
          where: 'field = ?',
          whereArgs: [key],
        );
      }
      for (final MapEntry(:key, :value) in loaded.rewrittenEntities.entries) {
        batch.update(
          _entities,
          {'data': value},
          where: 'key = ?',
          whereArgs: [key],
        );
      }
      if (migratedTo != null) {
        for (final MapEntry(:key, :value) in {
          'schema_hash': migratedTo.hash ?? '',
          'schema_fields': jsonEncode(migratedTo.fields),
        }.entries) {
          batch.insert(_meta, {
            'key': key,
            'value': value,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
  }
}

/// [SqflitePersistence.mutationQueue].
final class _SqfliteMutationQueue implements MutationQueueStore {
  _SqfliteMutationQueue(this._persistence, this._entries);

  final SqflitePersistence _persistence;

  /// What the table holds once the queued writes land, oldest first.
  final List<QueuedMutation> _entries;

  @override
  List<QueuedMutation> load() => List.of(_entries);

  @override
  Future<void> add(QueuedMutation entry) {
    _entries.add(entry);
    return _persistence._enqueueWrite(
      (batch) => batch.insert(_mutationQueue, {
        'id': entry.id,
        'data': encodeRow(entry.toJson(), _persistence.codec),
        'created_at': entry.createdAt.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
  }

  @override
  Future<void> clear() {
    _entries.clear();
    return _persistence._enqueueWrite((batch) => batch.delete(_mutationQueue));
  }

  @override
  Future<void> remove(String id) {
    _entries.removeWhere((e) => e.id == id);
    return _persistence._enqueueWrite(
      (batch) => batch.delete(_mutationQueue, where: 'id = ?', whereArgs: [id]),
    );
  }
}

/// Reported to `onError` by a [SqflitePersistence] whose database was opened
/// again elsewhere (another isolate or process): the newer instance is the
/// writer, this one stops saving ([SqflitePersistence.superseded]).
final class SqfliteSupersededException implements Exception {
  const SqfliteSupersededException(this.path);

  /// The database file.
  final String path;

  @override
  String toString() =>
      'SqfliteSupersededException: $path was opened by another '
      'SqflitePersistence; this one no longer saves.';
}
