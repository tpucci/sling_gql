import 'dart:convert';

import 'package:sling_gql/internal.dart' show NormalizedCache, Ref;
import 'package:sling_gql/sling_gql.dart';

/// The cache root persisted field by field; every other root
/// (`ROOT_MUTATION`, `ROOT_SUBSCRIPTION`) is never stored.
const queryRoot = 'ROOT_QUERY';

/// The rows read at open, as plain lists so they cross an isolate boundary
/// cheaply (see `SqflitePersistence.open(hydrateInIsolate:)`).
final class StoredRows {
  StoredRows({
    required this.entityKeys,
    required this.entityJson,
    required this.rootFields,
    required this.rootJson,
    required this.rootUpdatedAt,
  });

  final List<String> entityKeys;
  final List<String> entityJson;
  final List<String> rootFields;
  final List<String> rootJson;

  /// Milliseconds since epoch, per [rootFields] entry.
  final List<int> rootUpdatedAt;
}

/// What [loadCache] needs besides the rows.
final class LoadOptions {
  const LoadOptions({
    required this.keyField,
    required this.nowMs,
    required this.maxAgeMs,
    required this.maxEntities,
  });

  final String keyField;
  final int nowMs;
  final int? maxAgeMs;
  final int? maxEntities;
}

/// The hydrated cache and what was left out of it, to delete from the
/// database.
final class LoadedCache {
  LoadedCache({
    required this.cache,
    required this.expiredRootFields,
    required this.cappedRootFields,
    required this.unreachableEntities,
  });

  final Cache cache;

  /// Root fields older than `maxAge`.
  final List<String> expiredRootFields;

  /// The oldest root fields dropped to fit `maxEntities`.
  final List<String> cappedRootFields;

  /// Entities no kept root field reaches (what `Cache.gc` would collect).
  final List<String> unreachableEntities;
}

/// Builds the cache from [rows]: drops the root fields older than
/// `maxAge`, keeps the newest root fields whose entities fit in
/// `maxEntities` (dropping the older ones), and hydrates only the entities
/// the kept root fields reach — the same set `Cache.gc` would leave, without
/// decoding or hydrating the rest. Pure, so it runs in an isolate.
LoadedCache loadCache((StoredRows, LoadOptions) input) {
  final (rows, options) = input;
  final entityJson = <String, String>{
    for (var i = 0; i < rows.entityKeys.length; i++)
      rows.entityKeys[i]: rows.entityJson[i],
  };

  // Root fields, newest first (ties by name, so loads are deterministic).
  final order = List<int>.generate(rows.rootFields.length, (i) => i)
    ..sort((a, b) {
      final byAge = rows.rootUpdatedAt[b].compareTo(rows.rootUpdatedAt[a]);
      return byAge != 0
          ? byAge
          : rows.rootFields[a].compareTo(rows.rootFields[b]);
    });

  final expired = <String>[];
  final capped = <String>[];
  final root = <String, Object?>{};
  final entities = <String, Map<String, Object?>>{};
  final maxEntities = options.maxEntities;

  for (final i in order) {
    final field = rows.rootFields[i];
    final maxAge = options.maxAgeMs;
    if (maxAge != null && options.nowMs - rows.rootUpdatedAt[i] > maxAge) {
      expired.add(field);
      continue;
    }
    if (capped.isNotEmpty) {
      // An older field than one that did not fit: dropped too.
      capped.add(field);
      continue;
    }
    final value = jsonDecode(rows.rootJson[i]);
    final reached = <String, Map<String, Object?>>{};
    final fits = _reach(
      value,
      entityJson,
      entities,
      reached,
      maxEntities == null ? null : maxEntities - entities.length,
    );
    if (!fits) {
      capped.add(field);
      continue;
    }
    root[field] = value;
    entities.addAll(reached);
  }

  // The decoded maps are ours: the cache takes them over instead of copying
  // them a second time (#68).
  return LoadedCache(
    cache: NormalizedCache.adopt({
      if (root.isNotEmpty) queryRoot: root,
      ...entities,
    }, normalization: Normalization(keyField: options.keyField)),
    expiredRootFields: expired,
    cappedRootFields: capped,
    unreachableEntities: [
      for (final key in rows.entityKeys)
        if (!entities.containsKey(key)) key,
    ],
  );
}

/// Adds to [reached] the decoded entities [node] references, transitively,
/// that are not in [kept] yet. False as soon as more than [room] of them
/// (when given) would be needed.
bool _reach(
  Object? node,
  Map<String, String> entityJson,
  Map<String, Map<String, Object?>> kept,
  Map<String, Map<String, Object?>> reached,
  int? room,
) {
  final stack = <Object?>[node];
  while (stack.isNotEmpty) {
    final current = stack.removeLast();
    if (current is Map) {
      final ref = Ref.tryParse(current);
      if (ref != null) {
        final key = ref.key;
        if (kept.containsKey(key) || reached.containsKey(key)) continue;
        final json = entityJson[key];
        if (json == null) continue; // dangling: the cache reads it as missing
        if (room != null && reached.length >= room) return false;
        // `jsonDecode` maps are `Map<String, dynamic>`: no cast view.
        final entity = jsonDecode(json) as Map<String, Object?>;
        reached[key] = entity;
        stack.add(entity);
      } else {
        stack.addAll(current.values);
      }
    } else if (current is List) {
      stack.addAll(current);
    }
  }
  return true;
}
