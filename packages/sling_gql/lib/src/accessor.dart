import 'cache/cache.dart';
import 'selection.dart';

/// The sink that accessors report to while a build is being recorded.
///
/// There is exactly one recorder per operation per build scope (a widget
/// build, a `prepare` call, …). It knows the operation type, holds the
/// selection tree recorded so far, and is told about every cache miss.
abstract class Recorder {
  /// `query`, `mutation` or `subscription`.
  String get operation;

  /// Root of the selection tree recorded in the current scope.
  Selection get root;

  Cache get cache;

  /// Dependency keys (`entity.field`) read so far in the current scope.
  /// Filled by the cache on every read; used to decide which scopes to
  /// rebuild when data changes.
  Set<String> get deps;

  /// Called when a field was read but is not in the cache. For object and
  /// list fields the node itself is reported (its children come as the
  /// skeleton accessors are read).
  void onMiss(Selection leaf);

  /// Called on manual writes (generated setters) so dependants can be
  /// re-rendered and, during a mutation's optimistic phase, so the write can
  /// be undone if the mutation fails.
  void onWrite(CacheWrite write);
}

/// Base class for all generated schema types.
///
/// A generated type is a thin, allocation-cheap view over a location in the
/// cache: `(selection node, cache path)`. Every getter records the field on
/// the selection tree, then reads the value at `path + field` from the cache.
///
/// Typed getters are *generated* from the schema, so there is no dynamic
/// dispatch and everything is tree-shakeable — this is what replaces JS
/// `Proxy` in GQty.
abstract class Accessor {
  Accessor(this.recorder, this.selection, this.path);

  final Recorder recorder;

  /// This object's node in the selection tree.
  final Selection selection;

  /// This object's location in the cache: aliases and list indices, walked
  /// from the operation root — or from an entity when the first element is a
  /// [Ref] (see `lookup` on [object]).
  final List<Object> path;

  /// True when this object does not exist in cache yet (skeleton state):
  /// every scalar read returns `null` and records a miss.
  bool get isSkeleton =>
      recorder.cache.read(recorder.operation, path, deps: recorder.deps) == missing;

  /// The `__typename` of the cached object, if any.
  String? get $typename => scalar<String>('__typename');

  // ---------------------------------------------------------------------------
  // Read helpers used by generated code
  // ---------------------------------------------------------------------------

  Selection _select(String field, Map<String, Arg>? args) =>
      selection.child(field, args ?? const {});

  Selection _selectObject(String field, Map<String, Arg>? args, bool keyed) =>
      selection.objectChild(
        field,
        args ?? const {},
        keyed ? recorder.cache.normalization.selectedKeyField : null,
      );

  Object? _read(Selection sel) => recorder.cache
      .read(recorder.operation, [...path, sel.alias], deps: recorder.deps);

  /// True when the cache holds a value for [field] on this object —
  /// including an explicit server `null` — false when it was never fetched.
  /// This is the per-field counterpart to `QueryState.hasMissingData`: use it
  /// to tell "not fetched yet" apart from "the server said `null`" for one
  /// field, without branching the whole widget on [isSkeleton].
  ///
  /// Reading [field] here does *not* record a miss or a dependency — calling
  /// [isFetched] alone never causes a fetch or a rebuild. Read the field for
  /// real ([scalar], [object], …) wherever you display it; an errored path
  /// (see `QueryState.error`) also reads as not fetched here.
  bool isFetched(String field, {Map<String, Arg>? args}) {
    final sel = _select(field, args);
    return recorder.cache.read(recorder.operation, [...path, sel.alias]) != missing;
  }

  /// Reads a scalar field. Returns `null` (and records a miss) when not cached.
  T? scalar<T>(String field, {Map<String, Arg>? args}) {
    final sel = _select(field, args);
    final value = _read(sel);
    if (value == missing) {
      recorder.onMiss(sel);
      return null;
    }
    return _coerce<T>(value);
  }

  /// Reads a list of scalars. Skeleton lists contain a single `null`.
  List<T?>? scalarList<T>(String field, {Map<String, Arg>? args}) {
    final sel = _select(field, args);
    final value = _read(sel);
    if (value == missing) {
      recorder.onMiss(sel);
      return [null];
    }
    if (value == null) return null;
    return (value as List).map(_coerce<T>).toList();
  }

  /// Reads a scalar field whose wire form (type [W], read via [scalar] —
  /// usually `String`) is converted to a richer Dart type [T] by [parse].
  /// Backs both [enumValue] and a generator `--scalar` mapping (e.g.
  /// `DateTime`). Same miss/skeleton semantics as [scalar].
  T? scalarAs<T, W>(String field, T Function(W) parse, {Map<String, Arg>? args}) {
    final raw = scalar<W>(field, args: args);
    return raw == null ? null : parse(raw);
  }

  /// Reads a list of such values (see [scalarAs]). Same miss/skeleton
  /// semantics as [scalarList].
  List<T?>? scalarListAs<T, W>(String field, T Function(W) parse, {Map<String, Arg>? args}) {
    final raw = scalarList<W>(field, args: args);
    return raw?.map((e) => e == null ? null : parse(e)).toList();
  }

  /// Reads an enum field: the cached wire `String` mapped through [parse]
  /// (the generated `fromGraphQL`). Same miss/skeleton semantics as [scalar].
  T? enumValue<T>(String field, T Function(String) parse, {Map<String, Arg>? args}) =>
      scalarAs<T, String>(field, parse, args: args);

  /// Reads a list of enums, mapping each wire `String` through [parse].
  /// Same miss/skeleton semantics as [scalarList].
  List<T?>? enumList<T>(String field, T Function(String) parse, {Map<String, Arg>? args}) =>
      scalarListAs<T, String>(field, parse, args: args);

  /// Reads an object field. Returns a skeleton accessor when not cached,
  /// `null` only when the server explicitly returned `null`.
  ///
  /// [keyed] marks the returned type as a normalizable entity (its key field
  /// is always selected). [lookup] names the entity type a by-id field
  /// resolves to (`launch(id:)` → `Launch`): when the field itself is not
  /// cached but the entity is, the accessor is redirected to the entity so no
  /// request is made for data already fetched through another path.
  R? object<R extends Accessor>(
    String field,
    R Function(Recorder, Selection, List<Object>) ctor, {
    Map<String, Arg>? args,
    bool keyed = false,
    String? lookup,
  }) {
    final sel = _selectObject(field, args, keyed || lookup != null);
    final value = _read(sel);
    if (value == null) return null; // explicit null from the server
    if (value == missing) {
      if (lookup != null) {
        final key = recorder.cache.normalization.lookup(lookup, sel.args);
        if (key != null && recorder.cache.hasEntity(key)) {
          return ctor(recorder, sel, [Ref(key)]);
        }
      }
      recorder.onMiss(sel); // skeleton
    }
    // Either cached object or `missing` → skeleton; both read through the cache.
    return ctor(recorder, sel, [...path, sel.alias]);
  }

  /// Reads a list of objects. Skeleton lists contain a single skeleton element
  /// so `list.map((e) => e.name)` still records the element selection.
  List<R>? list<R extends Accessor>(
    String field,
    R Function(Recorder, Selection, List<Object>) ctor, {
    Map<String, Arg>? args,
    bool keyed = false,
  }) {
    final sel = _selectObject(field, args, keyed);
    final value = _read(sel);
    if (value == missing) {
      recorder.onMiss(sel);
      return [ctor(recorder, sel, [...path, sel.alias, 0])];
    }
    if (value == null) return null;
    final items = value as List;
    return List.generate(
      items.length,
      (i) => ctor(recorder, sel, [...path, sel.alias, i]),
    );
  }

  // ---------------------------------------------------------------------------
  // Write helpers (optimistic updates) used by generated setters
  // ---------------------------------------------------------------------------

  void write(String field, Object? value) {
    final target = [...path, field];
    final cache = recorder.cache;
    final previous = cache.read(recorder.operation, target);
    final touched = cache.write(recorder.operation, target, value);
    recorder.onWrite(CacheWrite(recorder.operation, target, previous, touched));
  }

  static T? _coerce<T>(Object? value) {
    if (value == null) return null;
    if (value is T) return value as T;
    // JSON numbers: `1` decodes as int but the schema may say Float.
    if (T == double && value is num) return value.toDouble() as T;
    if (T == int && value is num) return value.toInt() as T;
    throw StateError('Expected $T but cache holds ${value.runtimeType}: $value');
  }

  @override
  String toString() => '${selection.field}@$path${isSkeleton ? ' (skeleton)' : ''}';
}
