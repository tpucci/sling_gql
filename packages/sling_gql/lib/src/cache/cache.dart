import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import '../selection.dart';
import 'normalization.dart';
import 'ref.dart';

export 'normalization.dart';
export 'ref.dart';

/// Dependency key for `field` on entity `entity` — the currency used to tell
/// scopes what changed (`ROOT_QUERY.launches_1qouruf`, `Launch:launch-181.name`).
String depKey(String entity, String field) => '$entity.$field';

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

/// The client-side store every accessor reads from.
///
/// Reads are synchronous (they happen inside widget builds), so the store is
/// in-memory. [snapshot] / `Cache(initial:)` and [onChange] are the hooks a
/// persistence layer plugs into — they are deliberately kept out of this
/// package.
///
/// Apps touch it through `client.cache` for introspection and housekeeping
/// ([entity], [evict], [gc], [clear], [snapshot], [onChange], [fetchedAt]);
/// typed reads and writes go through `client.cacheScope`. The path-level
/// [read] / [write] / [remove] / [writeResponse] are the accessors' and the
/// client's business (`@internal`).
///
/// The only implementation today is [NormalizedCache]; `Cache()` returns one.
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
    Selection selection,
    Map<String, Object?> data, {
    DateTime? at,
  });

  /// When [depKey] (`entity.field`) was last written by a server response,
  /// or `null` if never: hydrated snapshots, optimistic writes and manual
  /// [write]s carry no stamp, so they count as stale for `maxAge`.
  DateTime? fetchedAt(String depKey);

  /// Removes an entity and every reference to it (list elements are dropped,
  /// object fields become missing so they are re-fetched on next read).
  Set<String> evict(String key);

  /// Removes entities not reachable from any operation root. Returns their keys.
  Set<String> gc();

  bool hasEntity(String key);
  Iterable<String> get entityKeys;

  /// Read-only view of one entity (`ROOT_QUERY`, `Launch:launch-181`, …).
  Map<String, Object?>? entity(String key);

  /// Fires after every write with the dependency keys touched.
  Stream<Set<String>> get onChange;

  /// JSON-able deep copy of the whole store (refs as `{"__ref": key}`).
  Map<String, Object?> get snapshot;

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

  @override
  final Normalization normalization;

  final Map<String, Map<String, Object?>> _entities = {};
  final Map<String, DateTime> _fetchedAt = {};
  final _changes = StreamController<Set<String>>.broadcast(sync: true);

  /// Set while a stamped [writeResponse] runs: every key written is added.
  Set<String>? _writing;

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
      _walk(operation, path, null, deps);

  @override
  Object? readField(
    String operation,
    List<Object> path,
    String field, {
    Set<String>? deps,
  }) => _walk(operation, path, field, deps);

  /// Interned dependency keys per `(entity, field)`: reads add the same
  /// strings to scopes' deps build after build, so they are built once
  /// (hash cached, identical on lookup) instead of on every read (#17).
  final Map<String, Map<String, String>> _depKeys = {};

  String _internedDep(String entity, String field) =>
      (_depKeys[entity] ??= {})[field] ??= depKey(entity, field);

  /// Walks [path] (then [last], when given) from the operation root.
  /// Allocation-free: this runs once per generated getter.
  Object? _walk(
    String operation,
    List<Object> path,
    String? last,
    Set<String>? deps,
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
        if (atEntity && deps != null) deps.add(_internedDep(entityKey, key));
        if (node is! Map) return missing;
        final value = node[key];
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
    for (var i = start; i < path.length - 1; i++) {
      final key = path[i];
      final next = path[i + 1];
      if (container is Ref) {
        entityKey = container.key;
        container = _entities.putIfAbsent(entityKey, () => {});
        topField = null;
      }
      if (key is String) {
        final map = container as Map<String, Object?>;
        topField ??= key;
        container = map[key] ??= next is int
            ? <Object?>[]
            : <String, Object?>{};
      } else {
        final list = container as List<Object?>;
        final index = key as int;
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
    }

    final last = path.last;
    if (last is String) {
      final map = container as Map<String, Object?>;
      map[last] = _normalize(map[last], value, touched);
      topField ??= last;
    } else {
      final list = container as List<Object?>;
      final index = last as int;
      while (list.length <= index) {
        list.add(null);
      }
      list[index] = _normalize(list[index], value, touched);
    }
    if (topField != null) touched.add(depKey(entityKey, topField));
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
    for (var i = start; i < path.length - 1; i++) {
      final key = path[i];
      if (container is Ref) {
        entityKey = container.key;
        container = _entities[entityKey];
        topField = null;
      }
      if (key is String) {
        if (container is! Map) return touched;
        topField ??= key;
        container = container[key];
      } else {
        final index = key as int;
        if (container is! List || index >= container.length) return touched;
        container = container[index];
      }
    }
    if (container is Ref) {
      entityKey = container.key;
      container = _entities[entityKey];
      topField = null;
    }

    final last = path.last;
    if (last is String) {
      if (container is! Map || !container.containsKey(last)) return touched;
      container.remove(last);
      topField ??= last;
    } else {
      final index = last as int;
      if (container is! List || index >= container.length) return touched;
      container.removeAt(index);
    }
    if (topField != null) touched.add(depKey(entityKey, topField));
    _emit(touched);
    return touched;
  }

  @override
  Set<String> writeResponse(
    String operation,
    Selection selection,
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
  DateTime? fetchedAt(String depKey) => _fetchedAt[depKey];

  void _mergeEntity(
    String key,
    Map<String, Object?> fields,
    Set<String> touched,
  ) {
    final entity = _entities.putIfAbsent(key, () => {});
    for (final e in fields.entries) {
      final had = entity.containsKey(e.key);
      final existing = entity[e.key];
      final outer = _changed;
      _changed = false;
      final value = _normalize(existing, e.value, touched);
      // Inline containers are merged in place: `_normalize` tells whether
      // anything under this field actually differs (an identical `pageInfo`
      // or `stats` in a refetch must not rebuild its readers).
      final changed = !had || _changed;
      _changed = outer;
      entity[e.key] = value;
      final dep = depKey(key, e.key);
      _writing?.add(dep);
      if (changed) touched.add(dep);
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

  // ---------------------------------------------------------------------------
  // Eviction / GC
  // ---------------------------------------------------------------------------

  @override
  Set<String> evict(String key) {
    final touched = <String>{};
    final removed = _entities.remove(key);
    _depKeys.remove(key);
    if (removed == null) return touched;
    for (final field in removed.keys) {
      final dep = depKey(key, field);
      touched.add(dep);
      _fetchedAt.remove(dep);
    }
    final ref = Ref(key);
    for (final e in _entities.entries) {
      for (final field in e.value.keys.toList()) {
        final value = e.value[field];
        if (value == ref) {
          e.value.remove(field);
          touched.add(depKey(e.key, field));
        } else if (_scrub(value, ref)) {
          touched.add(depKey(e.key, field));
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
  Set<String> gc() {
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

    for (final key in _entities.keys.where(isRootKey)) {
      live.add(key);
      mark(_entities[key]);
    }
    final dead = _entities.keys.where((k) => !live.contains(k)).toSet();
    for (final key in dead) {
      _entities.remove(key);
      _depKeys.remove(key);
    }
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

  void _emit(Set<String> touched) {
    if (touched.isNotEmpty && _changes.hasListener) _changes.add(touched);
  }

  @override
  Map<String, Object?> get snapshot => {
    for (final e in _entities.entries) e.key: _toJson(e.value),
  };

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
    final touched = <String>{
      for (final e in _entities.entries)
        for (final field in e.value.keys) depKey(e.key, field),
    };
    _entities.clear();
    _depKeys.clear();
    _fetchedAt.clear();
    _emit(touched);
  }
}
