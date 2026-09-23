import 'selection.dart';

/// Sentinel returned by [Cache.read] when a path does not exist.
///
/// Distinguishes "the server said null" (a real `null` stored in the cache)
/// from "we never fetched this" (a cache miss → skeleton state).
const missing = _Missing();

class _Missing {
  const _Missing();
  @override
  String toString() => '<missing>';
}

/// A non-normalized, path-addressed cache.
///
/// Data is stored as nested `Map<String, Object?>` / `List<Object?>`, keyed
/// by [Selection.alias] (field name + args hash). Writes deep-merge objects so
/// that partial selections coming from different widgets accumulate into one
/// tree rather than overwriting each other.
class Cache {
  Cache([Map<String, Object?>? initial]) : _roots = initial ?? {};

  /// One root object per operation type (`query`, `mutation`, …).
  final Map<String, Object?> _roots;

  Map<String, Object?> get snapshot => _roots;

  Object? read(String operation, List<Object> path) {
    Object? node = _roots[operation];
    if (node == null && !_roots.containsKey(operation)) return missing;
    for (final key in path) {
      if (key is int) {
        if (node is! List || key >= node.length) return missing;
        node = node[key];
      } else {
        if (node is! Map) return missing;
        if (!node.containsKey(key)) return missing;
        node = node[key];
      }
    }
    return node;
  }

  /// Writes an optimistic/manual value at a path, creating containers as
  /// needed. Returns the set of top-level aliases touched.
  Set<String> write(String operation, List<Object> path, Object? value) {
    if (path.isEmpty) return {};
    var container = _roots.putIfAbsent(operation, () => <String, Object?>{});
    for (var i = 0; i < path.length - 1; i++) {
      final key = path[i];
      final next = path[i + 1];
      if (key is int) {
        final list = container as List<Object?>;
        list[key] ??= next is int ? <Object?>[] : <String, Object?>{};
        container = list[key];
      } else {
        final map = container as Map<String, Object?>;
        map[key as String] ??= next is int ? <Object?>[] : <String, Object?>{};
        container = map[key];
      }
    }
    final last = path.last;
    if (last is int) {
      (container as List<Object?>)[last] = value;
    } else {
      (container as Map<String, Object?>)[last as String] = value;
    }
    return {if (path.first is String) path.first as String};
  }

  /// Merges a GraphQL response `data` object into the cache, following
  /// [selection] to map response aliases onto cache keys (they are identical
  /// by construction, but the tree tells us which keys are objects vs lists).
  /// Returns the set of top-level aliases that were written.
  Set<String> writeResponse(
    String operation,
    Selection selection,
    Map<String, Object?> data,
  ) {
    final root = _roots.putIfAbsent(operation, () => <String, Object?>{})
        as Map<String, Object?>;
    _mergeObject(root, data);
    return data.keys.toSet();
  }

  static void _mergeObject(Map<String, Object?> into, Map<String, Object?> from) {
    for (final entry in from.entries) {
      into[entry.key] = _merge(into[entry.key], entry.value);
    }
  }

  static Object? _merge(Object? existing, Object? incoming) {
    if (incoming is Map<String, Object?>) {
      final target = existing is Map<String, Object?> ? existing : <String, Object?>{};
      _mergeObject(target, incoming);
      return target;
    }
    if (incoming is List) {
      final old = existing is List ? existing : const [];
      return List<Object?>.generate(
        incoming.length,
        (i) => _merge(i < old.length ? old[i] : null, incoming[i]),
      );
    }
    return incoming;
  }

  void clear() => _roots.clear();
}
