import 'dart:convert';
import 'dart:typed_data';

import 'package:sling_gql/internal.dart' show NormalizedCache, Ref;
import 'package:sling_gql/sling_gql.dart';

import 'codec.dart';

/// The cache root persisted field by field; every other root
/// (`ROOT_MUTATION`, `ROOT_SUBSCRIPTION`) is never stored.
const queryRoot = 'ROOT_QUERY';

/// `SlingSchema.fields`: type name → field name → signature.
typedef SchemaFields = Map<String, Map<String, String>>;

/// The stored form of [value]: its JSON as text, or the [codec]'s bytes.
Object encodeRow(Object? value, SqfliteCodec? codec) {
  if (codec == null) return jsonEncode(value);
  final json = JsonUtf8Encoder().convert(value);
  return codec.encode(json is Uint8List ? json : Uint8List.fromList(json));
}

/// The value [encodeRow] stored as [data]. Throws on anything else (a row
/// written under another codec, a corrupted page, a hand edit).
Object? decodeRow(Object? data, SqfliteCodec? codec) {
  if (codec == null) {
    if (data is String) return jsonDecode(data);
  } else if (data is Uint8List) {
    return _utf8Json.convert(codec.decode(data));
  }
  throw FormatException(
    'Unexpected stored row: ${data.runtimeType} '
    '(${codec == null ? 'no codec' : 'codec ${codec.id}'})',
  );
}

final _utf8Json = const Utf8Decoder().fuse(const JsonDecoder());

/// The rows read at open, as plain lists so they cross an isolate boundary
/// cheaply (see `SqflitePersistence.open(hydrateInIsolate:)`). Each `*Data`
/// entry is what [encodeRow] stored.
final class StoredRows {
  StoredRows({
    required this.entityKeys,
    required this.entityData,
    required this.rootFields,
    required this.rootData,
    required this.rootUpdatedAt,
  });

  final List<String> entityKeys;
  final List<Object?> entityData;
  final List<String> rootFields;
  final List<Object?> rootData;

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
    this.codec,
    this.migrateFrom,
    this.migrateTo,
  }) : assert((migrateFrom == null) == (migrateTo == null));

  final String keyField;
  final int nowMs;
  final int? maxAgeMs;
  final int? maxEntities;
  final SqfliteCodec? codec;

  /// The fields the rows were written under and the current ones, when the
  /// schema hash changed: the rows are migrated (see [loadCache]).
  final SchemaFields? migrateFrom;
  final SchemaFields? migrateTo;
}

/// The hydrated cache and what was left out of it, to delete from the
/// database.
final class LoadedCache {
  LoadedCache({
    required this.cache,
    required this.expiredRootFields,
    required this.cappedRootFields,
    required this.unreachableEntities,
    required this.incompatibleRootFields,
    required this.incompatibleEntities,
    required this.rewrittenRootFields,
    required this.rewrittenEntities,
  });

  final Cache cache;

  /// Root fields older than `maxAge`.
  final List<String> expiredRootFields;

  /// The oldest root fields dropped to fit `maxEntities`.
  final List<String> cappedRootFields;

  /// Entities no kept root field reaches (what `Cache.gc` would collect),
  /// [incompatibleEntities] excluded.
  final List<String> unreachableEntities;

  /// Migration: root fields gone from the schema, or whose signature or
  /// inline data's types changed.
  final List<String> incompatibleRootFields;

  /// Migration: reached entities whose type is gone.
  final List<String> incompatibleEntities;

  /// Migration: kept rows some fields were pruned from, with their new
  /// stored value ([encodeRow]).
  final Map<String, Object> rewrittenRootFields;
  final Map<String, Object> rewrittenEntities;
}

/// Builds the cache from [rows]: drops the root fields older than
/// `maxAge`, keeps the newest root fields whose entities fit in
/// `maxEntities` (dropping the older ones), and hydrates only the entities
/// the kept root fields reach — the same set `Cache.gc` would leave, without
/// decoding or hydrating the rest. Pure, so it runs in an isolate.
///
/// With `migrateFrom`/`migrateTo` every decoded row is migrated first:
/// a cached field is kept only when its field has the same signature in
/// both schemas (inline objects are pruned by their `__typename`, which
/// must exist in both); a root field whose field is gone, or whose value
/// holds an inline object of a gone type, is dropped; an entity whose type
/// is gone is dropped (references to it read as missing).
LoadedCache loadCache((StoredRows, LoadOptions) input) {
  final (rows, options) = input;
  final codec = options.codec;
  final from = options.migrateFrom, to = options.migrateTo;
  final migration = from == null || to == null ? null : _Migration(from, to);
  final reach = _Reach(
    {
      for (var i = 0; i < rows.entityKeys.length; i++)
        rows.entityKeys[i]: rows.entityData[i],
    },
    codec,
    migration,
  );

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
  final incompatible = <String>[];
  final rewritten = <String>{};
  final root = <String, Object?>{};
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
    final value = decodeRow(rows.rootData[i], codec);
    if (migration != null) {
      migration.changed = false;
      if (!migration.rootField(field, value)) {
        incompatible.add(field);
        continue;
      }
      if (migration.changed) rewritten.add(field);
    }
    final reached = <String, Map<String, Object?>>{};
    final fits = reach(
      value,
      reached,
      maxEntities == null ? null : maxEntities - reach.kept.length,
    );
    if (!fits) {
      capped.add(field);
      continue;
    }
    root[field] = value;
    reach.kept.addAll(reached);
  }

  // Encoded before the cache adopts the maps (it swaps `{"__ref": …}` maps
  // for `Ref`s in place).
  final rewrittenRootFields = {
    for (final field in rewritten)
      if (root.containsKey(field)) field: encodeRow(root[field], codec),
  };
  final rewrittenEntities = {
    for (final key in reach.rewritten)
      if (reach.kept[key] case final entity?) key: encodeRow(entity, codec),
  };

  // The decoded maps are ours: the cache takes them over instead of copying
  // them a second time (#68).
  return LoadedCache(
    cache: NormalizedCache.adopt({
      if (root.isNotEmpty) queryRoot: root,
      ...reach.kept,
    }, normalization: Normalization(keyField: options.keyField)),
    expiredRootFields: expired,
    cappedRootFields: capped,
    unreachableEntities: [
      for (final key in rows.entityKeys)
        if (!reach.kept.containsKey(key) && !reach.incompatible.contains(key))
          key,
    ],
    incompatibleRootFields: incompatible,
    incompatibleEntities: reach.incompatible.toList(),
    rewrittenRootFields: rewrittenRootFields,
    rewrittenEntities: rewrittenEntities,
  );
}

/// Decodes (and migrates) the entities root fields reference, on demand.
final class _Reach {
  _Reach(this.entityData, this.codec, this.migration);

  final Map<String, Object?> entityData;
  final SqfliteCodec? codec;
  final _Migration? migration;

  /// The entities hydrated so far.
  final Map<String, Map<String, Object?>> kept = {};

  /// Entities whose type is gone from the schema (migration).
  final Set<String> incompatible = {};

  /// Entities some fields were pruned from (migration).
  final Set<String> rewritten = {};

  /// Adds to [reached] the decoded entities [node] references, transitively,
  /// that are not [kept] yet. False as soon as more than [room] of them
  /// (when given) would be needed.
  bool call(
    Object? node,
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
          if (incompatible.contains(key)) continue;
          final data = entityData[key];
          if (data == null) continue; // dangling: the cache reads it as missing
          if (room != null && reached.length >= room) return false;
          final entity = _decodeEntity(key, data);
          if (entity == null) continue; // its type is gone: missing too
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

  Map<String, Object?>? _decodeEntity(String key, Object data) {
    // `jsonDecode` maps are `Map<String, dynamic>`: no cast view.
    final entity = decodeRow(data, codec) as Map<String, Object?>;
    final migration = this.migration;
    if (migration == null) return entity;
    final colon = key.indexOf(':');
    migration.changed = false;
    if (colon <= 0 || !migration.object(entity, key.substring(0, colon))) {
      incompatible.add(key);
      return null;
    }
    if (migration.changed) rewritten.add(key);
    return entity;
  }
}

/// Prunes decoded rows written under [from] down to what [to] can read.
final class _Migration {
  _Migration(this.from, this.to);

  final SchemaFields from;
  final SchemaFields to;

  /// Set when a field was removed since it was last reset.
  bool changed = false;

  /// `field_<fnv1a64 of the arguments>`: 64 bits as two base-36 halves.
  static final _argsHash = RegExp(r'^[0-9a-z]{8,14}$');

  /// The field a cache [alias] stands for among [fields]: the alias itself
  /// (no arguments) or the part before the arguments' hash.
  static String? _field(String alias, Map<String, String> fields) {
    if (fields.containsKey(alias)) return alias;
    final underscore = alias.lastIndexOf('_');
    if (underscore <= 0) return null;
    final field = alias.substring(0, underscore);
    return fields.containsKey(field) &&
            _argsHash.hasMatch(alias.substring(underscore + 1))
        ? field
        : null;
  }

  /// The signature of [alias]'s field on [typename] when it is the same in
  /// both schemas, else null.
  String? _signature(String typename, String alias) {
    final before = from[typename], after = to[typename];
    if (before == null || after == null) return null;
    final field = _field(alias, after);
    if (field == null || field != _field(alias, before)) return null;
    final signature = after[field];
    return signature == before[field] ? signature : null;
  }

  /// True when the named type of [signature] (`'(id: ID!) [Launch!]!'` →
  /// `Launch`) is an object, interface or union: its values hold objects.
  bool _holdsObjects(String signature) {
    final start = signature.startsWith('(')
        ? signature.lastIndexOf(') ') + 2
        : 0;
    var end = signature.length;
    while (end > start && '[]!'.contains(signature[end - 1])) {
      end--;
    }
    var begin = start;
    while (begin < end && signature[begin] == '[') {
      begin++;
    }
    return to.containsKey(signature.substring(begin, end));
  }

  /// Keeps `ROOT_QUERY.<alias>` holding [value]? Prunes [value] in place.
  bool rootField(String alias, Object? value) {
    final signature = _signature(queryRoot, alias);
    if (signature == null) return false;
    return !_holdsObjects(signature) || _value(value);
  }

  /// Prunes the fields of [object] (of type [typename]) the new schema
  /// cannot read as cached. False when [typename] is gone.
  bool object(Map<String, Object?> object, String typename) {
    if (!from.containsKey(typename) || !to.containsKey(typename)) return false;
    object.removeWhere((alias, value) {
      if (alias == '__typename') return false;
      final signature = _signature(typename, alias);
      if (signature != null && (!_holdsObjects(signature) || _value(value))) {
        return false;
      }
      changed = true;
      return true;
    });
    return true;
  }

  /// False when [value] (a field's value holding objects) holds an inline
  /// object of a gone type; references are kept (their entity is migrated
  /// on its own).
  bool _value(Object? value) {
    if (value is List) return value.every(_value);
    if (value is! Map<String, Object?>) return true; // null
    if (Ref.tryParse(value) != null) return true;
    final typename = value['__typename'];
    return typename is String && object(value, typename);
  }
}
