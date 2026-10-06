import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_sqflite/src/load.dart';

/// The cache alias of [field] called with [args] (as the runtime prints it).
String alias(String field, Map<String, Object?> args) => Selection.root('query')
    .child(field, {for (final e in args.entries) e.key: Arg('ID!', e.value)})
    .alias;

Map<String, Object?> ref(String key) => {'__ref': key};

void main() {
  // `loadCache` migrating rows written under [before] to [after]: a pure
  // function, so the rules are tested on hand-made rows.
  const before = <String, Map<String, String>>{
    'ROOT_QUERY': {
      'me': 'User',
      'node': '(id: ID!) Node',
      'search': '(text: String!) [SearchResult!]!',
      'viewer': 'Viewer',
      'settings': 'JSON',
      'old': 'String',
    },
    'User': {
      'id': 'ID!',
      'name': 'String',
      'nickname': 'String',
      'friend': 'Node',
      'profile': 'Profile',
      'first_name': 'String',
    },
    'Pet': {'id': 'ID!', 'name': 'String'},
    'Profile': {'bio': 'String', 'theme': 'Theme'},
    'OldTheme': {'color': 'String'},
    'Viewer': {'name': 'String', 'karma': 'Int'},
    'Node': {},
    'SearchResult': {},
    'Theme': {},
  };
  // `nickname`, `Pet`, `OldTheme`, `Viewer.karma` and `old` are gone.
  const after = <String, Map<String, String>>{
    'ROOT_QUERY': {
      'me': 'User',
      'node': '(id: ID!) Node',
      'search': '(text: String!) [SearchResult!]!',
      'viewer': 'Viewer',
      'settings': 'JSON',
    },
    'User': {
      'id': 'ID!',
      'name': 'String',
      'friend': 'Node',
      'profile': 'Profile',
      'first_name': 'String',
    },
    'Profile': {'bio': 'String', 'theme': 'Theme'},
    'Viewer': {'name': 'String'},
    'Node': {},
    'SearchResult': {},
    'Theme': {},
  };

  final nodeAlias = alias('node', {'id': 'p1'});
  final searchAlias = alias('search', {'text': 'a'});

  LoadedCache load({
    SchemaFields? from = before,
    SchemaFields? to = after,
    Map<String, Object?> extraRoots = const {},
  }) {
    final entities = <String, Object?>{
      'User:1': {
        '__typename': 'User',
        'id': '1',
        'name': 'Ada',
        'nickname': 'A',
        'first_name': 'Ada',
        'friend': ref('Pet:1'),
        'profile': {
          '__typename': 'Profile',
          'bio': 'hi',
          'theme': {'__typename': 'OldTheme', 'color': 'red'},
        },
      },
      'Pet:1': {'__typename': 'Pet', 'id': '1', 'name': 'Rex'},
    };
    final roots = <String, Object?>{
      'me': ref('User:1'),
      nodeAlias: ref('Pet:1'),
      searchAlias: [
        ref('User:1'),
        {'__typename': 'Pet', 'name': 'Rex'},
      ],
      'viewer': {'__typename': 'Viewer', 'name': 'Ada', 'karma': 3},
      'settings': {'color': 'blue', 'karma': 1},
      'old': 'x',
      ...extraRoots,
    };
    return loadCache((
      StoredRows(
        entityKeys: entities.keys.toList(),
        entityData: [for (final e in entities.values) jsonEncode(e)],
        rootFields: roots.keys.toList(),
        rootData: [for (final v in roots.values) jsonEncode(v)],
        rootUpdatedAt: List.filled(roots.length, 0),
      ),
      LoadOptions(
        keyField: 'id',
        nowMs: 0,
        maxAgeMs: null,
        maxEntities: null,
        migrateFrom: from,
        migrateTo: to,
      ),
    ));
  }

  test('fields gone or changed are pruned, inline objects by their own '
      'type; references and scalars are kept as they are', () {
    final loaded = load();
    final user = {
      '__typename': 'User',
      'id': '1',
      'name': 'Ada',
      // A field whose name ends like an argument hash still resolves.
      'first_name': 'Ada',
      'friend': ref('Pet:1'),
      // `theme` held an object of a gone type: the field reads as missing.
      'profile': {'__typename': 'Profile', 'bio': 'hi'},
    };
    expect(jsonDecode(jsonEncode(loaded.cache.entity('User:1'))), user);
    expect(decodeRow(loaded.rewrittenEntities['User:1'], null), user);

    final root = jsonDecode(jsonEncode(loaded.cache.entity('ROOT_QUERY')));
    expect(root, {
      'me': ref('User:1'),
      // The reference stays; the entity is gone, so it reads as missing.
      nodeAlias: ref('Pet:1'),
      'viewer': {'__typename': 'Viewer', 'name': 'Ada'},
      // A custom scalar is opaque: not pruned.
      'settings': {'color': 'blue', 'karma': 1},
    });
    expect(loaded.rewrittenRootFields.keys, ['viewer']);
    // `search` held an inline object of a gone type; `old` is gone.
    expect(
      loaded.incompatibleRootFields,
      unorderedEquals([searchAlias, 'old']),
    );
    expect(loaded.incompatibleEntities, ['Pet:1']);
    expect(loaded.unreachableEntities, isEmpty);
    expect(loaded.cache.entity('Pet:1'), isNull);
  });

  test('only an argument hash after `_` stands for a field with arguments', () {
    expect(nodeAlias, matches(RegExp(r'^node_[0-9a-z]{8,14}$')));
    // A `node_label` row neither schema has a field for (`node` does
    // not stand for it: `label` is not an argument hash).
    final loaded = load(extraRoots: {'node_label': 1});
    expect(loaded.incompatibleRootFields, contains('node_label'));
    expect(loaded.cache.entity('ROOT_QUERY'), contains(nodeAlias));
  });

  test('without fields to migrate along, rows load as they are', () {
    final loaded = load(from: null, to: null);
    expect(loaded.incompatibleRootFields, isEmpty);
    expect(loaded.cache.entity('Pet:1'), isNotNull);
    expect(loaded.cache.entity('User:1')?['nickname'], 'A');
  });
}
