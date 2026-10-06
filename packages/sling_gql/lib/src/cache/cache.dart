import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import 'field_policy.dart';
import 'normalization.dart';
import 'ref.dart';

export 'field_policy.dart';
export 'normalization.dart';
export 'ref.dart';

/// Dependency key for `field` on entity `entity` — the currency used to tell
/// scopes what changed (`ROOT_QUERY.launches_c0y93u18lig6v`, `Launch:launch-181.name`).
///
/// Unambiguous even when an id contains dots (`User:a.name` + `id` vs
/// `User:a` + `name`): [field] is a cache alias — a GraphQL name, optionally
/// with an `_<hash>` suffix — and never contains `.`, so the entity is always
/// everything before the *last* dot (what list rules rely on) (#26).
///
/// A list held by an entity field has two finer keys (#54), which keep that
/// property: [elementDepKey] (read through one inline element) and
/// [lengthDepKey] (`Accessor.list` of inline objects). A write touches
/// [depKey] whenever anything under the field changed, plus the finer keys
/// of what changed in the list.
String depKey(String entity, String field) => '$entity.$field';

/// Dependency key for element [index] of the list held by [field] on
/// [entity] (`Launch:launch-181.links[2]`): what a read *through* an inline
/// element (not a [Ref]) records instead of [depKey], so a change to one
/// element rebuilds its readers only. Readers through a [Ref] element keep
/// [depKey]. Lists nested deeper (in an element, in an inline object) are
/// part of the element / field holding them.
String elementDepKey(String entity, String field, int index) =>
    '$entity.$field[$index]';

/// Dependency key for the length of the list held by [field] on [entity]
/// (`Launch:launch-181.links[length]`): what `Accessor.list` of inline
/// objects records instead of [depKey] — it builds one accessor per index
/// and reads nothing else. Touched when the length changes or the list is
/// replaced by something else.
String lengthDepKey(String entity, String field) => '$entity.$field[length]';

/// Description of one manual write (`launch.favorite = true`), enough to undo
/// it: the [previous] value is [missing] when the path did not exist.
class CacheWrite {
  const CacheWrite(this.operation, this.path, this.previous, this.touched);

  final String operation;
  final List<Object> path;
  final Object? previous;

  /// Dependency keys the write touched.
  final Set<String> touched;

  /// Restores [previous] in [cache]. Returns the keys touched by the undo.
  Set<String> undo(Cache cache) => previous == missing
      ? cache.remove(operation, path)
      : cache.write(operation, path, previous);
}

/// The entities that changed since a [Cache.version]: what a persistence
/// layer writes to bring its copy up to date, instead of a whole
/// [Cache.snapshot]. Get one from [Cache.changesSince].
///
/// [changed] holds JSON copies of the entities in the [Cache.snapshot] format
/// (refs as `{"__ref": key}`); an entity is in [changed] or in [removed],
/// never both. The operation roots (`ROOT_QUERY`, `ROOT_MUTATION`, …) are
/// usually reported field by field instead
/// ([changedFields] / [removedFields]): they hold one field per query and
/// would otherwise be copied whole whenever one query changed.
final class CacheDelta {
  const CacheDelta({
    required this.version,
    required this.changed,
    required this.removed,
    this.changedFields = const {},
    this.removedFields = const {},
    this.full = false,
  });

  /// The [Cache.version] this delta brings a copy up to: pass it to the next
  /// [Cache.changesSince] once the delta is stored.
  final int version;

  /// Entities written since the requested version, by key.
  final Map<String, Map<String, Object?>> changed;

  /// Keys of the entities evicted, collected or removed since then.
  final Set<String> removed;

  /// Operation roots changed field by field: per root key, JSON copies of
  /// the fields written since the requested version (the root's other
  /// fields are unchanged). A root is in [changed] (copied whole, e.g. in a
  /// [full] delta or after the root itself was removed), in [removed], or
  /// here (with [removedFields]): never two of these.
  final Map<String, Map<String, Object?>> changedFields;

  /// Per root key, the fields removed since the requested version (a
  /// mutation's root fields once it settled, a `CacheScope` remove, an
  /// evicted entity a root field pointed to). Never also in [changedFields].
  final Map<String, Set<String>> removedFields;

  /// The delta replaces the whole store: drop every stored entity, then
  /// write [changed] (which is then every entity). Happens after
  /// [Cache.clear], or when the requested version is older than what the
  /// cache still remembers ([Cache.compact]ed away, or forgotten removals).
  final bool full;

  bool get isEmpty =>
      !full &&
      changed.isEmpty &&
      removed.isEmpty &&
      changedFields.isEmpty &&
      removedFields.isEmpty;

  /// Applies the delta to a stored [snapshot] (e.g. a JSON file's content)
  /// in place.
  void applyTo(Map<String, Object?> snapshot) {
    if (full) snapshot.clear();
    for (final key in removed) {
      snapshot.remove(key);
    }
    snapshot.addAll(changed);
    for (final key in {...changedFields.keys, ...removedFields.keys}) {
      final stored = snapshot[key];
      final entity = switch (stored) {
        Map<String, Object?>() => stored,
        Map() => snapshot[key] = Map<String, Object?>.from(stored),
        _ => snapshot[key] = <String, Object?>{},
      };
      entity.addAll(changedFields[key] ?? const {});
      for (final field in removedFields[key] ?? const <String>{}) {
        entity.remove(field);
      }
    }
  }

  @override
  String toString() =>
      'CacheDelta(version: $version, changed: ${changed.keys.toList()}, '
      'removed: ${removed.toList()}'
      '${changedFields.isEmpty ? '' : ', changedFields: ${{for (final e in changedFields.entries) e.key: e.value.keys.toList()}}'}'
      '${removedFields.isEmpty ? '' : ', removedFields: $removedFields'}'
      '${full ? ', full' : ''})';
}

/// The client-side store every accessor reads from.
///
/// Reads are synchronous (they happen inside widget builds), so the store is
/// in-memory. [snapshot] / `Cache(initial:)`, [onChange], [version] and
/// [changesSince] are the hooks a persistence layer plugs into — the layers
/// themselves are deliberately kept out of this package.
///
/// Apps touch it through `client.cache` for introspection and housekeeping
/// ([entity], [evict], [gc], [clear], [snapshot], [onChange], [fetchedAt],
/// [changesSince]);
/// typed reads and writes go through `client.cacheScope`. The path-level
/// [read] / [write] / [remove] / [writeResponse] are the accessors' and the
/// client's business (`@internal`).
///
/// The only implementation is [NormalizedCache]; `Cache()` returns one.
/// Implementing [Cache] outside sling_gql is not supported: members can be
/// added in a minor release.
abstract class Cache {
  factory Cache({Normalization normalization, Map<String, Object?>? initial}) =
      NormalizedCache;

  Normalization get normalization;

  /// Reads the value at [path] under [operation]'s root, following entity
  /// references transparently. Returns [missing] when the path does not exist.
  ///
  /// [path] is a list of aliases (`String`) and list indices (`int`); it may
  /// start with a [Ref] to address an entity directly. When [deps] is given,
  /// every dependency key traversed is added to it.
  @internal
  Object? read(String operation, List<Object> path, {Set<String>? deps});

  /// [read] of `[...path, field]` without allocating the joined path: the
  /// accessors' hot path (one call per generated getter).
  @internal
  Object? readField(
    String operation,
    List<Object> path,
    String field, {
    Set<String>? deps,
  });

  /// [readField] for a caller that uses only the *length* of the list it
  /// returns (`Accessor.list` of inline objects: its elements are read
  /// through their own paths). When [field] is an entity field holding a
  /// list, [deps] gets its [lengthDepKey] instead of its [depKey].
  @internal
  Object? readListField(
    String operation,
    List<Object> path,
    String field, {
    Set<String>? deps,
  });

  /// Writes an optimistic/manual value at a path, creating containers as
  /// needed. Returns the dependency keys touched.
  @internal
  Set<String> write(String operation, List<Object> path, Object? value);

  /// Removes the value at [path] (a map field or a list element) so it reads
  /// as [missing] again. Returns the dependency keys touched.
  @internal
  Set<String> remove(String operation, List<Object> path);

  /// Merges a GraphQL response `data` object. Objects the [Normalization]
  /// identifies are stored once as entities and referenced; the rest is
  /// merged inline. Returns the dependency keys touched (the ones whose
  /// value changed). When [at] is given, every key the response wrote —
  /// changed or not — is stamped with it (see [fetchedAt]).
  @internal
  Set<String> writeResponse(
    String operation,
    Map<String, Object?> data, {
    DateTime? at,
  });

  /// When [depKey] (`entity.field`) was last written by a server response,
  /// or `null` if never: hydrated snapshots, optimistic writes and manual
  /// [write]s carry no stamp, so they count as stale for `maxAge`. An
  /// [elementDepKey] / [lengthDepKey] answers for the field holding the list.
  DateTime? fetchedAt(String depKey);

  /// Removes an entity and every reference to it (list elements are dropped,
  /// object fields become missing so they are re-fetched on next read).
  Set<String> evict(String key);

  /// Removes entities not reachable from any operation root nor from one of
  /// the [retain]ed entity keys (extra roots: `SlingClient.gc` passes the
  /// entities live scopes read). Returns the removed keys. No scope reads a
  /// removed entity, so the client rebuilds nothing; [onChange] still
  /// reports the removed entities' fields (a persistence layer drops them).
  Set<String> gc({Iterable<String> retain = const []});

  /// True when the store holds the entity (or operation root) [key]
  /// (`Launch:launch-181`, `ROOT_QUERY`).
  bool hasEntity(String key);

  /// Keys of every stored entity, operation roots included.
  Iterable<String> get entityKeys;

  /// Read-only view of one entity (`ROOT_QUERY`, `Launch:launch-181`, …).
  Map<String, Object?>? entity(String key);

  /// Runs [body] as one change: the writes it makes (nested batches
  /// included) fire [onChange] once, with every key they touched, and bump
  /// [version] once, when the outermost batch returns or throws. The client
  /// batches each response, mutation, subscription event and optimistic
  /// callback, list-rule edits included; batch several manual writes with it.
  ///
  /// [body] must be synchronous: a batch ends when [body] returns, so the
  /// writes after an `await` would each be their own change (asserted).
  T batch<T>(T Function() body);

  /// Fires once per change — a write outside a [batch], or a whole batch —
  /// with the dependency keys (`entity.field`, see `depKey`, plus
  /// `entity.field[i]` / `entity.field[length]` for inline lists) it
  /// touched, synchronously. Nothing fires when nothing changed (a refetch returning
  /// the same data).
  ///
  /// A persistence layer debounces on it and reads [changesSince] rather
  /// than a whole [snapshot].
  Stream<Set<String>> get onChange;

  /// Change counter: bumped once per change that altered an entity (see
  /// [batch]). 0 for a new cache and for a hydrated one — `Cache(initial:)`
  /// is the persisted baseline.
  int get version;

  /// The entities changed or removed since [version] (an earlier value of
  /// [Cache.version]), as JSON copies of those entities only (for the operation roots:
  /// of the fields that changed, see [CacheDelta.changedFields]). Store it,
  /// then ask again from [CacheDelta.version].
  CacheDelta changesSince(int version);

  /// Forgets the change records up to [upTo], a [version] the persisted
  /// copy holds (the [CacheDelta.version] just stored): the removals and
  /// per-entity stamps at or before it are dropped, so they are not
  /// scanned again by [changesSince]. A cache that was never compacted
  /// forgets its removals once they pass a thousand (and the entity count,
  /// e.g. after a large [gc]) and answers older versions with a
  /// [CacheDelta.full] delta (a store rewrites every entity); once
  /// compacted, only a far larger pile (a store that stopped saving) is.
  ///
  /// Afterwards [changesSince] a version older than [upTo] answers with a
  /// full delta: call it with the oldest version any copy still needs (with
  /// one store, the one it just saved).
  void compact({required int upTo});

  /// JSON-able deep copy of the whole store (refs as `{"__ref": key}`).
  /// Entities are merged in place by later writes, so it is a copy, not a
  /// view; [changesSince] copies only what changed.
  Map<String, Object?> get snapshot;

  /// Removes everything (sign-out): every scope's data reads as missing
  /// again and is refetched on its next run; [onChange] reports every key
  /// and the next [changesSince] is a [CacheDelta.full] delta.
  void clear();
}

/// Entity-normalized store: `{ "ROOT_QUERY": {...}, "Launch:launch-181": {...} }`.
///
/// Operation roots are entities too (`ROOT_QUERY`, `ROOT_MUTATION`), so one
/// walk serves every read. Non-identifiable objects live inline in their
/// parent, exactly like the path-addressed cache this replaces.
class NormalizedCache implements Cache {
  NormalizedCache({
    this.normalization = const Normalization(),
    Map<String, Object?>? initial,
  }) {
    if (initial != null) _hydrate(initial);
  }

  /// A cache hydrated from [entities] (the [snapshot] format) *without
  /// copying them*: the maps and lists are taken over and converted in
  /// place (`{"__ref": key}` maps become refs), so the caller must not
  /// touch them afterwards. For a persistence layer that just decoded
  /// them (`jsonDecode` output is mutable); `Cache(initial:)` copies.
  NormalizedCache.adopt(
    Map<String, Map<String, Object?>> entities, {
    this.normalization = const Normalization(),
  }) {
    for (final e in entities.entries) {
      _entities[e.key] = _adopted(e.value);
    }
  }

  @override
  final Normalization normalization;

  final Map<String, Map<String, Object?>> _entities = {};
  final Map<String, DateTime> _fetchedAt = {};
  final _changes = StreamController<Set<String>>.broadcast(sync: true);

  /// Set while a stamped [writeResponse] runs: every key written is added.
  Set<String>? _writing;

  // Change tracking ([batch], [version], [changesSince]). Entities changed
  // or removed since the last commit are stamped `_version + 1`.
  int _version = 0;
  int _batchDepth = 0;
  Set<String>? _held;
  bool _dirty = false;
  final Map<String, int> _changedAt = {};
  final Map<String, int> _removedAt = {};

  /// [changesSince] an older version answers with a full delta: set by
  /// [clear] and when the tombstones in [_removedAt] are dropped.
  int _fullSince = 0;

  /// Per operation root (`ROOT_QUERY`, …): the version each field last
  /// changed or was removed at. Roots hold one field per query alias and
  /// grow with the session, so [changesSince] reports them field by field
  /// ([CacheDelta.changedFields]) instead of copying them whole (#68).
  final Map<String, Map<String, int>> _fieldChangedAt = {};

  /// Per root: [changesSince] an older version copies the root whole (in
  /// [CacheDelta.changed]) — set when the root was removed and when its
  /// field stamps of removed fields were dropped.
  final Map<String, int> _fieldsSince = {};

  /// Marks the entity [key] changed; [field] is the entity field that
  /// changed (or was removed), required for a root to be reported field by
  /// field.
  void _markChanged(String key, [String? field]) {
    _changedAt[key] = _version + 1;
    if (_removedAt.isNotEmpty) _removedAt.remove(key);
    if (field != null && isRootKey(key)) {
      (_fieldChangedAt[key] ??= {})[field] = _version + 1;
    }
    _dirty = true;
  }

  void _markRemoved(String key) {
    _changedAt.remove(key);
    _removedAt[key] = _version + 1;
    if (isRootKey(key)) {
      _fieldChangedAt.remove(key);
      _fieldsSince[key] = _version + 1;
    }
    _dirty = true;
  }

  static String rootKey(String operation) => switch (operation) {
    // Constant for the three operations: `read` runs this on every getter.
    'query' => 'ROOT_QUERY',
    'mutation' => 'ROOT_MUTATION',
    'subscription' => 'ROOT_SUBSCRIPTION',
    _ => 'ROOT_${operation.toUpperCase()}',
  };
  static bool isRootKey(String key) => key.startsWith('ROOT_');

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  @override
  Object? read(String operation, List<Object> path, {Set<String>? deps}) =>
      _walk(operation, path, null, deps, false);

  @override
  Object? readField(
    String operation,
    List<Object> path,
    String field, {
    Set<String>? deps,
  }) => _walk(operation, path, field, deps, false);

  @override
  Object? readListField(
    String operation,
    List<Object> path,
    String field, {
    Set<String>? deps,
  }) => _walk(operation, path, field, deps, true);

  /// Interned dependency keys per `(entity, field)`: reads add the same
  /// strings to scopes' deps build after build, so they are built once
  /// (hash cached, identical on lookup) instead of on every read (#17).
  final Map<String, Map<String, String>> _depKeys = {};

  String _internedDep(String entity, String field) =>
      (_depKeys[entity] ??= {})[field] ??= depKey(entity, field);

  /// Interned [elementDepKey]s / [lengthDepKey] per `(entity, field)`
  /// holding a list, apart from [_depKeys] so scalar reads stay one lookup.
  final Map<String, Map<String, _ListDepKeys>> _listDepKeys = {};

  _ListDepKeys _listDeps(String entity, String field) =>
      (_listDepKeys[entity] ??= {})[field] ??= _ListDepKeys(entity, field);

  /// The key a read of the entity field [field] holding [list] records:
  /// [next] is the path element after it (`null` when the read ends there).
  String _listDep(
    String entity,
    String field,
    List<Object?> list,
    Object? next,
    bool lengthOnly,
  ) {
    if (next == null) {
      return lengthOnly
          ? _listDeps(entity, field).length
          : _internedDep(entity, field);
    }
    if (next is int && next < list.length && list[next] is! Ref) {
      return _listDeps(entity, field).element(next);
    }
    return _internedDep(entity, field);
  }

  /// Walks [path] (then [last], when given) from the operation root.
  /// Allocation-free: this runs once per generated getter.
  Object? _walk(
    String operation,
    List<Object> path,
    String? last,
    Set<String>? deps,
    bool lengthOnly,
  ) {
    var start = 0;
    String entityKey;
    if (path.isNotEmpty && path.first is Ref) {
      entityKey = (path.first as Ref).key;
      start = 1;
    } else {
      entityKey = rootKey(operation);
    }

    Object? node = _entities[entityKey];
    var atEntity = true;
    final length = path.length;
    final end = last == null ? length : length + 1;
    for (var i = start; i < end; i++) {
      final key = i < length ? path[i] : last!;
      if (node is Ref) {
        entityKey = node.key;
        node = _entities[entityKey];
        atEntity = true;
      }
      if (key is String) {
        if (node is! Map) {
          if (atEntity && deps != null) deps.add(_internedDep(entityKey, key));
          return missing;
        }
        final value = node[key];
        if (atEntity && deps != null) {
          if (value is List) {
            final j = i + 1;
            final next = j < length
                ? path[j]
                : j < end
                ? last
                : null;
            deps.add(_listDep(entityKey, key, value, next, lengthOnly));
          } else {
            deps.add(_internedDep(entityKey, key));
          }
        }
        // One lookup on a hit; `containsKey` only to tell `null` from absent.
        if (value == null && !node.containsKey(key)) return missing;
        node = value;
      } else if (key is int) {
        if (node is! List || key >= node.length) return missing;
        node = node[key];
      } else {
        throw ArgumentError.value(key, 'path', 'must be String, int or Ref');
      }
      atEntity = false;
    }
    if (node is Ref) return _entities[node.key] ?? missing;
    if (node == null && atEntity) return missing; // root/entity does not exist
    return node;
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  @override
  Set<String> write(String operation, List<Object> path, Object? value) {
    final touched = <String>{};
    if (path.isEmpty) return touched;

    var start = 0;
    String entityKey;
    if (path.first is Ref) {
      entityKey = (path.first as Ref).key;
      start = 1;
    } else {
      entityKey = rootKey(operation);
    }
    if (start >= path.length) return touched;

    Object? container = _entities.putIfAbsent(entityKey, () => {});
    String? topField;
    // The list [topField] held before this write (and its length then), and
    // the index of it the path goes through: which list keys to touch.
    List<Object?>? topList;
    var topLength = 0;
    int? topIndex;
    for (var i = start; i < path.length - 1; i++) {
      final key = path[i];
      final next = path[i + 1];
      if (container is Ref) {
        entityKey = container.key;
        container = _entities.putIfAbsent(entityKey, () => {});
        topField = null;
        topList = null;
        topIndex = null;
      }
      if (key is String) {
        final map = container as Map<String, Object?>;
        if (topField == null) {
          topField = key;
          final held = map[key];
          if (held is List<Object?>) {
            topList = held;
            topLength = held.length;
          }
        }
        container = map[key] ??= next is int
            ? <Object?>[]
            : <String, Object?>{};
      } else {
        final list = container as List<Object?>;
        final index = key as int;
        if (identical(list, topList)) topIndex = index;
        while (list.length <= index) {
          list.add(null);
        }
        container = list[index] ??= next is int
            ? <Object?>[]
            : <String, Object?>{};
      }
    }
    if (container is Ref) {
      entityKey = container.key;
      container = _entities.putIfAbsent(entityKey, () => {});
      topField = null;
      topList = null;
      topIndex = null;
    }

    final last = path.last;
    if (last is String) {
      final map = container as Map<String, Object?>;
      final previous = map[last];
      if (topField != null) {
        map[last] = _normalize(previous, value, touched);
      } else {
        // A field of the entity itself.
        topField = last;
        if (previous is List<Object?> && value is List<Object?>) {
          map[last] = _mergeList(entityKey, last, previous, value, touched);
        } else {
          if (previous is List<Object?>) {
            _touchList(entityKey, last, previous, 0, touched);
          }
          map[last] = _normalize(previous, value, touched);
        }
      }
    } else {
      final list = container as List<Object?>;
      final index = last as int;
      while (list.length <= index) {
        list.add(null);
      }
      final previous = list[index];
      list[index] = _normalize(previous, value, touched);
      if (identical(list, topList)) {
        // Readers of a ref element depend on the whole field.
        topIndex = previous is Ref ? null : index;
      }
    }
    if (topField != null) touched.add(depKey(entityKey, topField));
    if (topList != null) {
      final keys = _listDeps(entityKey, topField!);
      if (topList.length != topLength) touched.add(keys.length);
      if (topIndex != null && topIndex < topLength) {
        touched.add(keys.element(topIndex));
      }
    }
    _markChanged(entityKey, topField);
    _emit(touched);
    return touched;
  }

  @override
  Set<String> remove(String operation, List<Object> path) {
    final touched = <String>{};
    if (path.isEmpty) return touched;

    var start = 0;
    String entityKey;
    if (path.first is Ref) {
      entityKey = (path.first as Ref).key;
      start = 1;
    } else {
      entityKey = rootKey(operation);
    }
    if (start >= path.length) return touched;

    Object? container = _entities[entityKey];
    String? topField;
    // As in [write]: the list [topField] holds and the index walked through.
    List<Object?>? topList;
    int? topIndex;
    for (var i = start; i < path.length - 1; i++) {
      final key = path[i];
      if (container is Ref) {
        entityKey = container.key;
        container = _entities[entityKey];
        topField = null;
        topList = null;
        topIndex = null;
      }
      if (key is String) {
        if (container is! Map) return touched;
        final held = container[key];
        if (topField == null) {
          topField = key;
          if (held is List<Object?>) topList = held;
        }
        container = held;
      } else {
        final index = key as int;
        if (container is! List || index >= container.length) return touched;
        if (identical(container, topList)) topIndex = index;
        container = container[index];
      }
    }
    if (container is Ref) {
      entityKey = container.key;
      container = _entities[entityKey];
      topField = null;
      topList = null;
      topIndex = null;
    }

    final last = path.last;
    if (last is String) {
      if (container is! Map || !container.containsKey(last)) return touched;
      final previous = container.remove(last);
      if (topField == null) {
        topField = last;
        if (previous is List<Object?>) {
          _touchList(entityKey, last, previous, 0, touched);
        }
      }
    } else {
      final index = last as int;
      if (container is! List<Object?> || index >= container.length) {
        return touched;
      }
      if (identical(container, topList)) {
        // The elements from [index] on shift: all of them changed.
        _touchList(entityKey, topField!, container, index, touched);
      }
      container.removeAt(index);
    }
    if (topField != null) touched.add(depKey(entityKey, topField));
    if (topIndex != null) {
      touched.add(_listDeps(entityKey, topField!).element(topIndex));
    }
    _markChanged(entityKey, topField);
    _emit(touched);
    return touched;
  }

  @override
  Set<String> writeResponse(
    String operation,
    Map<String, Object?> data, {
    DateTime? at,
  }) {
    final touched = <String>{};
    final written = at == null ? null : <String>{};
    _writing = written;
    try {
      _mergeEntity(rootKey(operation), data, touched);
    } finally {
      _writing = null;
    }
    if (written != null) {
      for (final key in written) {
        _fetchedAt[key] = at!;
      }
    }
    _emit(touched);
    return touched;
  }

  @override
  DateTime? fetchedAt(String depKey) {
    final at = _fetchedAt[depKey];
    // A field alias never ends with `]`: an element/length key, stamped
    // with the field that holds the list.
    if (at != null || !depKey.endsWith(']')) return at;
    return _fetchedAt[depKey.substring(0, depKey.lastIndexOf('['))];
  }

  void _mergeEntity(
    String key,
    Map<String, Object?> fields,
    Set<String> touched,
  ) {
    final existing = _entities[key];
    final entity = existing ?? (_entities[key] = {});
    if (existing == null) _markChanged(key);
    for (final e in fields.entries) {
      final had = entity.containsKey(e.key);
      final previous = entity[e.key];
      final outer = _changed;
      final incoming = switch (e.value) {
        final PolicyWrite write => _applyPolicy(previous, write, touched),
        final value => value,
      };
      _changed = false;
      final Object? value;
      if (previous is List<Object?> && incoming is List<Object?>) {
        value = _mergeList(key, e.key, previous, incoming, touched);
      } else {
        value = _normalize(previous, incoming, touched);
        if (previous is List<Object?> && _changed) {
          _touchList(key, e.key, previous, 0, touched);
        }
      }
      // Inline containers are merged in place: `_normalize` tells whether
      // anything under this field actually differs (an identical `pageInfo`
      // or `stats` in a refetch must not rebuild its readers).
      final changed = !had || _changed;
      _changed = outer;
      entity[e.key] = value;
      final dep = depKey(key, e.key);
      _writing?.add(dep);
      if (changed) {
        touched.add(dep);
        _markChanged(key, e.key);
      }
    }
  }

  /// Set by [_normalize] when the value it returns differs from `existing`
  /// (a leaf, a ref, a key or list length); read and reset per entity field
  /// by [_mergeEntity]. Changes *inside* a referenced entity do not count:
  /// they are that entity's own touched keys.
  bool _changed = false;

  /// Normalizes [incoming] against [existing]: keyed objects become entity
  /// refs, inline objects deep-merge, lists merge element-wise by index.
  Object? _normalize(Object? existing, Object? incoming, Set<String> touched) {
    if (incoming is PolicyWrite) {
      return _normalize(
        existing,
        _applyPolicy(existing, incoming, touched),
        touched,
      );
    }
    if (incoming is Map<String, Object?>) {
      final key = normalization.identify(incoming);
      if (key != null) {
        _mergeEntity(key, incoming, touched);
        final ref = Ref(key);
        if (existing != ref) _changed = true;
        return ref;
      }
      final Map<String, Object?> target;
      if (existing is Map<String, Object?>) {
        target = existing;
      } else {
        target = {};
        _changed = true;
      }
      for (final e in incoming.entries) {
        if (!target.containsKey(e.key)) _changed = true;
        target[e.key] = _normalize(target[e.key], e.value, touched);
      }
      return target;
    }
    if (incoming is List) {
      final old = existing is List ? existing : const <Object?>[];
      if (existing is! List || old.length != incoming.length) _changed = true;
      return List<Object?>.generate(
        incoming.length,
        (i) => _normalize(i < old.length ? old[i] : null, incoming[i], touched),
      );
    }
    if (incoming != existing) _changed = true;
    return incoming;
  }

  /// The value [write]'s pages merge [existing] (the cached field) into,
  /// normalized: each page is normalized on its own (its entities merged,
  /// inline parts fresh), then combined by the policy. The result is merged
  /// into the field like a plain response, so only real changes touch keys.
  Object? _applyPolicy(
    Object? existing,
    PolicyWrite write,
    Set<String> touched,
  ) {
    final outer = _changed;
    // A copy: the result is merged into [existing] in place, and a policy
    // reusing its inline elements at other indices would alias them.
    var value = _copyInline(existing);
    // Fills first, against the entry they were fetched for, then the pages
    // to merge, in document order.
    final fills = <({Map<String, Object?> args, Object? value})>[];
    for (final page in write.pages) {
      if (!page.fill) continue;
      fills.add((
        args: page.args,
        value: _normalize(null, page.value, touched),
      ));
    }
    if (fills.isNotEmpty) value = write.policy.fill(value, fills);
    for (final page in write.pages) {
      if (page.fill) continue;
      value = write.policy.merge(
        value,
        _normalize(null, page.value, touched),
        FieldMergeContext(field: write.field, args: page.args),
      );
    }
    _changed = outer;
    return value;
  }

  /// Deep copy of the inline containers of a cached value (refs and
  /// scalars shared).
  static Object? _copyInline(Object? node) => switch (node) {
    Map() => <String, Object?>{
      for (final e in node.entries) e.key as String: _copyInline(e.value),
    },
    List() => <Object?>[for (final e in node) _copyInline(e)],
    _ => node,
  };

  /// [_normalize] of the list [incoming] into [old], the list the entity
  /// field [field] of [entity] holds, element by element: also touches the
  /// [elementDepKey] of each inline element that changed and, when the
  /// length changes, the [lengthDepKey] (see [_touchList]).
  List<Object?> _mergeList(
    String entity,
    String field,
    List<Object?> old,
    List<Object?> incoming,
    Set<String> touched,
  ) {
    final outer = _changed;
    final resized = old.length != incoming.length;
    var changed = resized;
    _ListDepKeys? keys;
    final merged = List<Object?>.filled(incoming.length, null);
    for (var i = 0; i < incoming.length; i++) {
      final previous = i < old.length ? old[i] : null;
      _changed = false;
      merged[i] = _normalize(previous, incoming[i], touched);
      if (!_changed) continue;
      changed = true;
      // Readers of a new index or a ref element depend on the whole field.
      if (i < old.length && previous is! Ref) {
        touched.add((keys ??= _listDeps(entity, field)).element(i));
      }
    }
    if (resized) _touchList(entity, field, old, incoming.length, touched);
    _changed = outer || changed;
    return merged;
  }

  /// Touches what the readers of [old], the list the entity field [field] of
  /// [entity] held, recorded from index [from] on, now that it changed from
  /// there or was replaced: its [lengthDepKey] and the [elementDepKey] of
  /// each inline element (readers of a [Ref] element recorded [depKey]).
  void _touchList(
    String entity,
    String field,
    List<Object?> old,
    int from,
    Set<String> touched,
  ) {
    final keys = _listDeps(entity, field);
    touched.add(keys.length);
    for (var i = from; i < old.length; i++) {
      if (old[i] is! Ref) touched.add(keys.element(i));
    }
  }

  // ---------------------------------------------------------------------------
  // Eviction / GC
  // ---------------------------------------------------------------------------

  @override
  Set<String> evict(String key) {
    final touched = <String>{};
    final removed = _entities.remove(key);
    _depKeys.remove(key);
    if (removed == null) return touched;
    _markRemoved(key);
    for (final e in removed.entries) {
      final dep = depKey(key, e.key);
      touched.add(dep);
      _fetchedAt.remove(dep);
      final value = e.value;
      if (value is List<Object?>) _touchList(key, e.key, value, 0, touched);
    }
    _listDepKeys.remove(key);
    final ref = Ref(key);
    for (final e in _entities.entries) {
      List<String>? scrubbed;
      for (final field in e.value.keys.toList()) {
        final value = e.value[field];
        if (value == ref) {
          e.value.remove(field);
          touched.add(depKey(e.key, field));
          (scrubbed ??= []).add(field);
        } else {
          final length = value is List ? value.length : 0;
          if (!_scrub(value, ref)) continue;
          touched.add(depKey(e.key, field));
          (scrubbed ??= []).add(field);
          if (length > 0) {
            // Elements shifted or changed inside: all of them, to be safe.
            final keys = _listDeps(e.key, field);
            touched.add(keys.length);
            for (var i = 0; i < length; i++) {
              touched.add(keys.element(i));
            }
          }
        }
      }
      if (scrubbed != null) {
        for (final field in scrubbed) {
          _markChanged(e.key, field);
        }
      }
    }
    _emit(touched);
    return touched;
  }

  /// Removes [ref] from lists / inline objects under [node]. True if changed.
  static bool _scrub(Object? node, Ref ref) {
    var changed = false;
    if (node is List<Object?>) {
      final before = node.length;
      node.removeWhere((e) => e == ref);
      changed = node.length != before;
      for (final e in node) {
        changed |= _scrub(e, ref);
      }
    } else if (node is Map<String, Object?>) {
      for (final field in node.keys.toList()) {
        final value = node[field];
        if (value == ref) {
          node.remove(field);
          changed = true;
        } else {
          changed |= _scrub(value, ref);
        }
      }
    }
    return changed;
  }

  @override
  Set<String> gc({Iterable<String> retain = const []}) {
    final live = <String>{};
    void mark(Object? node) {
      if (node is Ref) {
        if (live.add(node.key)) mark(_entities[node.key]);
      } else if (node is Map) {
        node.values.forEach(mark);
      } else if (node is List) {
        node.forEach(mark);
      }
    }

    for (final key in [..._entities.keys.where(isRootKey), ...retain]) {
      final entity = _entities[key];
      if (entity != null && live.add(key)) mark(entity);
    }
    final dead = _entities.keys.where((k) => !live.contains(k)).toSet();
    final touched = <String>{};
    for (final key in dead) {
      final removed = _entities.remove(key)!;
      _depKeys.remove(key);
      // No live reader: the list keys are not reported (see [Cache.gc]).
      _listDepKeys.remove(key);
      _markRemoved(key);
      for (final field in removed.keys) {
        final dep = depKey(key, field);
        _fetchedAt.remove(dep);
        touched.add(dep);
      }
    }
    _emit(touched);
    return dead;
  }

  // ---------------------------------------------------------------------------
  // Introspection / persistence hooks
  // ---------------------------------------------------------------------------

  @override
  bool hasEntity(String key) => _entities.containsKey(key);

  @override
  Iterable<String> get entityKeys => _entities.keys;

  @override
  Map<String, Object?>? entity(String key) {
    final e = _entities[key];
    return e == null ? null : UnmodifiableMapView(e);
  }

  @override
  Stream<Set<String>> get onChange => _changes.stream;

  @override
  T batch<T>(T Function() body) {
    _batchDepth++;
    try {
      final result = body();
      assert(
        result is! Future,
        'Cache.batch: the body must be synchronous — the batch ends when it '
        'returns, not after its awaits',
      );
      return result;
    } finally {
      if (--_batchDepth == 0) {
        final held = _held;
        _held = null;
        _commit(held ?? const {});
      }
    }
  }

  /// Ends one write: held until the outermost [batch] ends, committed now
  /// outside one.
  void _emit(Set<String> touched) {
    if (_batchDepth > 0) {
      if (touched.isNotEmpty) (_held ??= {}).addAll(touched);
      return;
    }
    _commit(touched);
  }

  void _commit(Set<String> touched) {
    if (_dirty) {
      _dirty = false;
      _version++;
      // Tombstones outnumbering the entities: forget them, and answer older
      // versions with a full delta instead (bounded memory under churn).
      // Once a store [compact]s, it prunes them at every save: only a much
      // larger pile (a store that stopped saving) is forgotten (#69).
      final limit = _compacted ? _maxTombstonesCompacted : _maxTombstones;
      if (_removedAt.length > limit && _removedAt.length > _entities.length) {
        _removedAt.clear();
        _fullSince = _version;
      }
      // Same for the stamps of fields a root no longer has.
      for (final e in _fieldChangedAt.entries) {
        final root = _entities[e.key];
        final stamps = e.value;
        if (stamps.length > limit && stamps.length > 2 * (root?.length ?? 0)) {
          stamps.removeWhere(
            (field, _) => !(root?.containsKey(field) ?? false),
          );
          _fieldsSince[e.key] = _version;
        }
      }
    }
    if (touched.isNotEmpty && _changes.hasListener) _changes.add(touched);
  }

  static const _maxTombstones = 1000;
  static const _maxTombstonesCompacted = 100000;

  /// [compact] was called: a store acknowledges what it saved.
  bool _compacted = false;

  @override
  int get version => _version;

  @override
  CacheDelta changesSince(int version) {
    if (version < _fullSince) {
      return CacheDelta(
        version: _version,
        changed: {
          for (final e in _entities.entries) e.key: _entityJson(e.value),
        },
        removed: {},
        full: true,
      );
    }
    final changed = <String, Map<String, Object?>>{};
    Map<String, Map<String, Object?>>? changedFields;
    Map<String, Set<String>>? removedFields;
    for (final e in _changedAt.entries) {
      if (e.value <= version) continue;
      final key = e.key;
      final entity = _entities[key]!;
      final stamps = _fieldChangedAt[key];
      if (!isRootKey(key) || version < (_fieldsSince[key] ?? 0)) {
        changed[key] = _entityJson(entity);
        continue;
      }
      // A root, field by field: the fields stamped since [version].
      final fields = <String, Object?>{};
      Set<String>? gone;
      if (stamps != null) {
        for (final s in stamps.entries) {
          if (s.value <= version) continue;
          if (entity.containsKey(s.key)) {
            fields[s.key] = _toJson(entity[s.key]);
          } else {
            (gone ??= {}).add(s.key);
          }
        }
      }
      // An empty entry for a root created empty, so it exists in the copy.
      if (fields.isNotEmpty || gone == null) {
        (changedFields ??= {})[key] = fields;
      }
      if (gone != null) (removedFields ??= {})[key] = gone;
    }
    return CacheDelta(
      version: _version,
      changed: changed,
      removed: {
        for (final e in _removedAt.entries)
          if (e.value > version) e.key,
      },
      changedFields: changedFields ?? const {},
      removedFields: removedFields ?? const {},
    );
  }

  @override
  void compact({required int upTo}) {
    _compacted = true;
    final v = upTo < _version ? upTo : _version;
    if (v <= 0) return;
    _changedAt.removeWhere((_, at) => at <= v);
    _removedAt.removeWhere((_, at) => at <= v);
    for (final stamps in _fieldChangedAt.values) {
      stamps.removeWhere((_, at) => at <= v);
    }
    _fieldChangedAt.removeWhere((_, stamps) => stamps.isEmpty);
    // Versions before [v] now get a full delta, which covers these.
    _fieldsSince.removeWhere((_, since) => since <= v);
    if (v > _fullSince) _fullSince = v;
  }

  @override
  Map<String, Object?> get snapshot => {
    for (final e in _entities.entries) e.key: _entityJson(e.value),
  };

  /// [_toJson] of one entity: a map copy (fast for the scalar fields most
  /// entities are made of), then the refs and containers converted.
  static Map<String, Object?> _entityJson(Map<String, Object?> entity) {
    final json = Map<String, Object?>.of(entity);
    for (final e in entity.entries) {
      final value = e.value;
      if (value is Ref || value is Map || value is List) {
        json[e.key] = _toJson(value);
      }
    }
    return json;
  }

  static Object? _toJson(Object? node) => switch (node) {
    Ref() => node.toJson(),
    Map() => {for (final e in node.entries) e.key as String: _toJson(e.value)},
    List() => [for (final e in node) _toJson(e)],
    _ => node,
  };

  void _hydrate(Map<String, Object?> json) {
    for (final e in json.entries) {
      final fields = e.value;
      if (fields is! Map) continue;
      _entities[e.key] = _fromJson(fields) as Map<String, Object?>;
    }
  }

  /// [_fromJson] in place: [map] itself becomes the entity.
  static Map<String, Object?> _adopted(Map<String, Object?> map) {
    for (final e in map.entries) {
      final value = e.value;
      if (value is Map || value is List) map[e.key] = _adoptJson(value);
    }
    return map;
  }

  static Object? _adoptJson(Object? node) {
    if (node is Map) {
      final ref = Ref.tryParse(node);
      if (ref != null) return ref;
      return _adopted(
        node is Map<String, Object?> ? node : Map<String, Object?>.from(node),
      );
    }
    if (node is List<Object?>) {
      for (var i = 0; i < node.length; i++) {
        final value = node[i];
        if (value is Map || value is List) node[i] = _adoptJson(value);
      }
      return node;
    }
    return node;
  }

  static Object? _fromJson(Object? node) {
    if (node is Map) {
      final ref = Ref.tryParse(node);
      if (ref != null) return ref;
      return <String, Object?>{
        for (final e in node.entries) e.key as String: _fromJson(e.value),
      };
    }
    if (node is List) return <Object?>[for (final e in node) _fromJson(e)];
    return node;
  }

  @override
  void clear() {
    final touched = <String>{};
    for (final e in _entities.entries) {
      for (final f in e.value.entries) {
        touched.add(depKey(e.key, f.key));
        final value = f.value;
        if (value is List<Object?>) _touchList(e.key, f.key, value, 0, touched);
      }
    }
    _entities.clear();
    _depKeys.clear();
    _listDepKeys.clear();
    _fetchedAt.clear();
    _changedAt.clear();
    _removedAt.clear();
    _fieldChangedAt.clear();
    _fieldsSince.clear();
    _fullSince = _version + 1;
    _dirty = true;
    _emit(touched);
  }
}

/// The interned [lengthDepKey] and [elementDepKey]s of one entity field
/// holding a list (see `NormalizedCache._listDepKeys`).
final class _ListDepKeys {
  _ListDepKeys(this.entity, this.field) : length = lengthDepKey(entity, field);

  final String entity;
  final String field;
  final String length;
  final List<String?> _elements = [];

  String element(int index) {
    while (_elements.length <= index) {
      _elements.add(null);
    }
    return _elements[index] ??= elementDepKey(entity, field, index);
  }
}
