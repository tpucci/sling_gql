import 'cache.dart';
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

  /// Called when a field was read but is not in the cache. For object and
  /// list fields the node itself is reported (its children come as the
  /// skeleton accessors are read).
  void onMiss(Selection leaf);

  /// Called on optimistic writes so dependants can be re-rendered.
  void onWrite(Set<String> touchedRootAliases);
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

  /// This object's location in the cache (aliases and list indices).
  final List<Object> path;

  /// True when this object does not exist in cache yet (skeleton state):
  /// every scalar read returns `null` and records a miss.
  bool get isSkeleton => recorder.cache.read(recorder.operation, path) == missing;

  /// The `__typename` of the cached object, if any.
  String? get $typename => scalar<String>('__typename');

  // ---------------------------------------------------------------------------
  // Read helpers used by generated code
  // ---------------------------------------------------------------------------

  Selection _select(String field, Map<String, Arg>? args) =>
      selection.child(field, args ?? const {});

  Selection _selectObject(String field, Map<String, Arg>? args) =>
      selection.objectChild(field, args ?? const {});

  Object? _read(Selection sel) =>
      recorder.cache.read(recorder.operation, [...path, sel.alias]);

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

  /// Reads an object field. Returns a skeleton accessor when not cached,
  /// `null` only when the server explicitly returned `null`.
  R? object<R extends Accessor>(
    String field,
    R Function(Recorder, Selection, List<Object>) ctor, {
    Map<String, Arg>? args,
  }) {
    final sel = _selectObject(field, args);
    final value = _read(sel);
    if (value == null) return null; // explicit null from the server
    if (value == missing) recorder.onMiss(sel); // skeleton
    // Either cached object or `missing` → skeleton; both read through the cache.
    return ctor(recorder, sel, [...path, sel.alias]);
  }

  /// Reads a list of objects. Skeleton lists contain a single skeleton element
  /// so `list.map((e) => e.name)` still records the element selection.
  List<R>? list<R extends Accessor>(
    String field,
    R Function(Recorder, Selection, List<Object>) ctor, {
    Map<String, Arg>? args,
  }) {
    final sel = _selectObject(field, args);
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
    final touched =
        recorder.cache.write(recorder.operation, [...path, field], value);
    recorder.onWrite(touched);
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
