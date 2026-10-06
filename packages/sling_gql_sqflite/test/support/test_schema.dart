import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_sqflite/sling_gql_sqflite.dart';
import 'package:sling_gql_test/sling_gql_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Hand-written "generated" code for the tiny schema of these tests:
//
// type Query    { me: User  user(id: ID!): User  users(first: Int!): [User!]!
//                 greeting(name: String!): String  tags: [Tag!]!
//                 friends(first: Int, after: String): UserConnection! }
// type UserConnection { nodes: [User!]!  pageInfo: PageInfo! }
// type PageInfo { hasNextPage: Boolean!  endCursor: String }
// type User     { id: ID!  name: String  age: Int  best: User }
// type Tag      { label: String }  # no id: inline
// type Mutation { rename(id: ID!, name: String!): User }

class Query extends Accessor {
  Query(super.recorder, super.selection, super.path);
  Query.root(Recorder r) : super(r, r.root, const []);

  User? get me => object('me', User.new, keyed: true);
  User? user({required String id}) =>
      object('user', User.new, args: {'id': Arg('ID!', id)}, lookup: 'User');
  List<User>? users({required int first}) =>
      list('users', User.new, args: {'first': Arg('Int!', first)}, keyed: true);
  String? greeting({required String name}) =>
      scalar<String>('greeting', args: {'name': Arg('String!', name)});
  List<Tag>? get tags => list('tags', Tag.new);
  UserConnection? friends({int? first, String? after}) => object(
    'friends',
    UserConnection.new,
    args: {'first': Arg('Int', first), 'after': Arg('String', after)},
  );
}

class UserConnection extends Accessor {
  UserConnection(super.recorder, super.selection, super.path);

  List<User>? get nodes => list('nodes', User.new, keyed: true);
  PageInfo? get pageInfo => object('pageInfo', PageInfo.new);
}

class PageInfo extends Accessor {
  PageInfo(super.recorder, super.selection, super.path);

  bool? get hasNextPage => scalar<bool>('hasNextPage');
  String? get endCursor => scalar<String>('endCursor');
}

class User extends Accessor {
  User(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get age => scalar<int>('age');
  User? get best => object('best', User.new, keyed: true);
}

class Tag extends Accessor {
  Tag(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
}

class Mutation extends Accessor {
  Mutation(super.recorder, super.selection, super.path);
  Mutation.root(Recorder r) : super(r, r.root, const []);

  User? rename({required String id, required String name}) => object(
    'rename',
    User.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
}

/// What `sling_gql_gen` would emit as `slingSchema.fields` for the schema
/// above.
const testFields = <String, Map<String, String>>{
  'ROOT_QUERY': {
    'me': 'User',
    'user': '(id: ID!) User',
    'users': '(first: Int!) [User!]!',
    'greeting': '(name: String!) String',
    'tags': '[Tag!]!',
  },
  'User': {'id': 'ID!', 'name': 'String', 'age': 'Int', 'best': 'User'},
  'Tag': {'label': 'String'},
};

const slingSchema = SlingSchema<Query, Mutation>(
  query: Query.root,
  mutation: Mutation.root,
  hash: 'test-schema-1',
  fields: testFields,
);

Map<String, Object?> user(String id, {String? name, int? age, Object? best}) =>
    {
      '__typename': 'User',
      'id': id,
      'name': name ?? 'User $id',
      'age': age ?? 30,
      'best': ?best,
    };

/// A [MockGraphQLServer] over a few users.
MockGraphQLServer testServer() {
  final users = {for (var i = 1; i <= 5; i++) '$i': user('$i')};
  return MockGraphQLServer(
    query: {
      'me': users['1'],
      'user': (args) => users[args['id']],
      'users': (args) => users.values.take(args['first']! as int).toList(),
      'greeting': (args) => 'Hello ${args['name']}',
      'tags': [
        {'__typename': 'Tag', 'label': 'a'},
        {'__typename': 'Tag', 'label': 'b'},
      ],
      // Pages of two over the five users; the cursor is the last id.
      'friends': (args) {
        final after = int.parse((args['after'] as String?) ?? '0');
        final first = (args['first'] as int?) ?? 2;
        final page = [
          for (var i = after + 1; i <= 5 && i <= after + first; i++)
            users['$i'],
        ];
        return {
          '__typename': 'UserConnection',
          'nodes': page,
          'pageInfo': {
            '__typename': 'PageInfo',
            'hasNextPage': after + page.length < 5,
            'endCursor': page.isEmpty ? null : page.last!['id'],
          },
        };
      },
    },
    mutation: {
      'rename': (args) {
        final u = users[args['id']]!..['name'] = args['name'];
        return u;
      },
    },
  );
}

/// A fresh database path per test, in a temp directory deleted afterwards.
String tempDatabasePath() {
  final dir = Directory.systemTemp.createTempSync('sling_gql_sqflite_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return '${dir.path}/cache.db';
}

/// Opens [path] with the ffi factory; saves only on [SqflitePersistence.flush]
/// unless the debounce is given.
Future<SqflitePersistence> openStore(
  String path, {
  SlingSchema<Accessor, Accessor> schema = slingSchema,
  Duration? maxAge = const Duration(days: 7),
  int? maxEntities = 10000,
  Duration debounce = const Duration(hours: 1),
  Duration maxWait = const Duration(hours: 1),
  bool hydrateInIsolate = false,
  bool flushOnLifecycle = false,
  bool compact = true,
  SqfliteCodec? codec,
  void Function(Object error, StackTrace stack)? onError,
  DateTime Function()? now,
}) => SqflitePersistence.open(
  path,
  schema: schema,
  databaseFactory: databaseFactoryFfi,
  maxAge: maxAge,
  maxEntities: maxEntities,
  debounce: debounce,
  maxWait: maxWait,
  hydrateInIsolate: hydrateInIsolate,
  flushOnLifecycle: flushOnLifecycle,
  compact: compact,
  codec: codec,
  onError: onError,
  now: now ?? DateTime.now,
);

/// `sling_entities` as `{key: entity json}`.
Future<Map<String, Object?>> entityRows(SqflitePersistence p) async => {
  for (final row in await p.database.query('sling_entities'))
    row['key']! as String: jsonDecode(row['data']! as String),
};

/// `sling_root_fields` as `{field: (value, updated_at)}`.
Future<Map<String, (Object?, int)>> rootRows(SqflitePersistence p) async => {
  for (final row in await p.database.query('sling_root_fields'))
    row['field']! as String: (
      jsonDecode(row['data']! as String),
      row['updated_at']! as int,
    ),
};

/// The store as a snapshot: entities plus `ROOT_QUERY` rebuilt from its rows.
Future<Map<String, Object?>> storedSnapshot(SqflitePersistence p) async {
  final roots = await rootRows(p);
  return {
    ...await entityRows(p),
    if (roots.isNotEmpty)
      'ROOT_QUERY': {for (final e in roots.entries) e.key: e.value.$1},
  };
}

/// A stand-in cipher: XORs every byte with [key].
final class XorCodec implements SqfliteCodec {
  const XorCodec({this.key = 42, this.id = 'xor:42'});

  final int key;

  @override
  final String id;

  @override
  Uint8List encode(Uint8List bytes) =>
      Uint8List.fromList([for (final b in bytes) b ^ key]);

  @override
  Uint8List decode(Uint8List bytes) => encode(bytes);
}
