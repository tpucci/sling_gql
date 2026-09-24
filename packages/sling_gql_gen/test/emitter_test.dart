import 'package:sling_gql_gen/sling_gql_gen.dart';
import 'package:test/test.dart';

Map<String, Object?> _type(String kind, [String? name]) => {
      'kind': kind,
      'name': name,
      'ofType': null,
    };

Map<String, Object?> _nonNull(Map<String, Object?> inner) =>
    {'kind': 'NON_NULL', 'name': null, 'ofType': inner};

Map<String, Object?> _list(Map<String, Object?> inner) =>
    {'kind': 'LIST', 'name': null, 'ofType': inner};

Map<String, Object?> _field(
  String name,
  Map<String, Object?> type, {
  List<Map<String, Object?>> args = const [],
  bool isDeprecated = false,
  String? deprecationReason,
  String? description,
}) =>
    {
      'name': name,
      'description': description,
      'args': args,
      'type': type,
      'isDeprecated': isDeprecated,
      'deprecationReason': deprecationReason,
    };

Map<String, Object?> _arg(String name, Map<String, Object?> type, {Object? defaultValue}) => {
      'name': name,
      'description': null,
      'type': type,
      'defaultValue': defaultValue,
    };

/// A small inline introspection document mirroring
/// `packages/sling_gql/test/core_test.dart`'s hand-written example, plus a
/// list-with-args field, an enum, an input object with a Hasura-style `_eq`
/// field, and a Mutation root that must be skipped.
final Map<String, Object?> _schemaJson = {
  '__schema': {
    'queryType': {'name': 'Query'},
    'mutationType': {'name': 'Mutation'},
    'subscriptionType': null,
    'types': [
      {
        'kind': 'OBJECT',
        'name': 'Query',
        'description': 'The query root.',
        'fields': [
          _field('me', _nonNull(_type('OBJECT', 'User'))),
          _field(
            'user',
            _type('OBJECT', 'User'),
            args: [_arg('id', _nonNull(_type('SCALAR', 'ID')))],
          ),
          _field(
            'users',
            _list(_nonNull(_type('OBJECT', 'User'))),
            args: [_arg('where', _type('INPUT_OBJECT', 'UserFilter'))],
          ),
        ],
        'inputFields': null,
        'enumValues': null,
      },
      {
        'kind': 'OBJECT',
        'name': 'Mutation',
        'fields': [_field('noop', _type('SCALAR', 'Boolean'))],
        'description': null,
        'inputFields': null,
        'enumValues': null,
      },
      {
        'kind': 'OBJECT',
        'name': 'User',
        'description': 'A user.',
        'fields': [
          _field('id', _nonNull(_type('SCALAR', 'ID'))),
          _field('name', _nonNull(_type('SCALAR', 'String'))),
          _field('age', _type('SCALAR', 'Int')),
          _field('status', _type('ENUM', 'UserStatus')),
          _field(
            'friends',
            _nonNull(_list(_nonNull(_type('OBJECT', 'User')))),
            args: [_arg('limit', _type('SCALAR', 'Int'))],
          ),
          _field(
            'legacyName',
            _type('SCALAR', 'String'),
            isDeprecated: true,
            deprecationReason: 'Use name instead.',
          ),
          _field('createdAt', _type('SCALAR', 'Date')),
          _field('externalId', _type('SCALAR', 'ObjectID')),
        ],
        'inputFields': null,
        'enumValues': null,
      },
      {
        'kind': 'ENUM',
        'name': 'UserStatus',
        'description': null,
        'fields': null,
        'inputFields': null,
        'enumValues': [
          {'name': 'ACTIVE', 'description': null, 'isDeprecated': false, 'deprecationReason': null},
          {'name': 'INACTIVE', 'description': null, 'isDeprecated': false, 'deprecationReason': null},
        ],
      },
      {
        'kind': 'INPUT_OBJECT',
        'name': 'UserFilter',
        'description': 'Filters users.',
        'fields': null,
        'inputFields': [
          _arg('_eq', _type('SCALAR', 'String')),
          _arg('_and', _list(_type('INPUT_OBJECT', 'UserFilter'))),
        ],
        'enumValues': null,
      },
    ],
  },
};

void main() {
  late String code;

  setUpAll(() {
    final schema = IntrospectionSchema.fromJson(_schemaJson);
    code = generate(schema);
  });

  test('emits header, ignore_for_file and import', () {
    expect(code, contains('// GENERATED CODE - DO NOT MODIFY BY HAND'));
    expect(code, contains('// ignore_for_file:'));
    expect(code, contains("import 'package:sling_gql/sling_gql.dart';"));
  });

  test('emits Query with root constructors, skips Mutation', () {
    expect(code, contains('class Query extends Accessor {'));
    expect(code, contains('Query(super.recorder, super.selection, super.path);'));
    expect(code, contains('Query.root(Recorder r) : super(r, r.root, const []);'));
    expect(code, isNot(contains('class Mutation')));
  });

  test('non-null required arg without default -> required T', () {
    expect(code, contains("User? user({required String id}) => object('user', User.new"));
  });

  test('keyed types: object/list fields carry keyed: true', () {
    expect(code, contains("User? get me => object('me', User.new, keyed: true);"));
    expect(
      code,
      contains("List<User>? friends({int? limit}) => list('friends', User.new, args: {'limit': Arg('Int', limit)}, keyed: true);"),
    );
  });

  test('by-id root field carries lookup: <Type>', () {
    expect(
      code,
      contains("User? user({required String id}) => object('user', User.new, args: {'id': Arg('ID!', id)}, lookup: 'User');"),
    );
    // `users(where:)` is a list → no lookup, but keyed.
    expect(code, contains("list('users', User.new, args: {'where': Arg('UserFilter', where?.toJson())}, keyed: true);"));
  });

  test('a type without the key field is neither keyed nor a lookup target', () {
    final schema = IntrospectionSchema.fromJson(_schemaJson);
    final unkeyed = generate(schema, keyField: 'uuid');
    expect(unkeyed, isNot(contains('keyed:')));
    expect(unkeyed, isNot(contains('lookup:')));
  });

  test('getters never null-assert (no bare `!` Dart operator outside string literals)', () {
    for (final line in code.split('\n')) {
      if (!line.contains('=>')) continue;
      final rhs = line.split('=>').last;
      // Strip string literals (which legitimately contain GraphQL `!`, e.g. 'ID!').
      final withoutStrings = rhs.replaceAll(RegExp("'[^']*'"), "''");
      expect(withoutStrings, isNot(contains('!')), reason: 'null-assert found in: $line');
    }
  });

  test('emits object type with getters/setters', () {
    expect(code, contains('class User extends Accessor {'));
    expect(code, contains("String? get id => scalar<String>('id');"));
    expect(code, contains("String? get name => scalar<String>('name');"));
    expect(code, contains("set name(String? v) => write('name', v);"));
    expect(code, contains("int? get age => scalar<int>('age');"));
  });

  test('list-of-object field with args', () {
    expect(
      code,
      contains("List<User>? friends({int? limit}) => list('friends', User.new, args:"),
    );
    expect(code, contains("keyed: true);"));
  });

  test('enum field is read as nullable String', () {
    expect(code, contains("String? get status => scalar<String>('status');"));
  });

  test('emits enum value holder class', () {
    expect(code, contains('abstract final class UserStatus {'));
    expect(code, contains("static const ACTIVE = 'ACTIVE';"));
    expect(code, contains("static const INACTIVE = 'INACTIVE';"));
  });

  test('deprecated field gets @Deprecated annotation', () {
    expect(code, contains("@Deprecated('Use name instead.')"));
    expect(code, contains('String? get legacyName'));
  });

  test('known string-like custom scalar Date maps to String', () {
    expect(code, contains("String? get createdAt => scalar<String>('createdAt');"));
  });

  test('unknown custom scalar ObjectID maps to Object with a doc note', () {
    expect(code, contains('Unknown custom scalar `ObjectID`'));
    expect(code, contains("Object? get externalId => scalar<Object>('externalId');"));
  });

  test('input object emits class with toJson, Hasura _eq becomes \$eq', () {
    expect(code, contains('class UserFilter {'));
    expect(code, contains('const UserFilter({this.\$eq, this.\$and});'));
    expect(code, contains('final String? \$eq;'));
    expect(code, contains("if (\$eq != null) '_eq': \$eq,"));
    expect(code, contains("if (\$and != null) '_and': \$and?.map((e) => e?.toJson()).toList(),"));
  });

  test('users field passes input toJson() through Arg', () {
    expect(
      code,
      contains(
        "List<User>? users({UserFilter? where}) => list('users', User.new, args: {'where': Arg('UserFilter', where?.toJson())}, keyed: true);",
      ),
    );
  });
}
