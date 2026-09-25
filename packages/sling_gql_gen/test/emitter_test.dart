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
        'fields': [
          _field('noop', _type('SCALAR', 'Boolean')),
          _field(
            'rename',
            _nonNull(_type('OBJECT', 'User')),
            args: [
              _arg('id', _nonNull(_type('SCALAR', 'ID'))),
              _arg('name', _nonNull(_type('SCALAR', 'String'))),
            ],
          ),
        ],
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
          _field('pastStatuses', _list(_type('ENUM', 'UserStatus'))),
          _field(
            'statusAt',
            _type('ENUM', 'UserStatus'),
            args: [_arg('date', _nonNull(_type('SCALAR', 'Date')))],
          ),
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
        'kind': 'OBJECT',
        'name': 'PageInfo',
        'description': null,
        'fields': [
          _field('hasNextPage', _nonNull(_type('SCALAR', 'Boolean'))),
          _field('endCursor', _type('SCALAR', 'String')),
        ],
        'inputFields': null,
        'enumValues': null,
      },
      {
        'kind': 'OBJECT',
        'name': 'UserConnection',
        'description': null,
        'fields': [
          _field('nodes', _nonNull(_list(_nonNull(_type('OBJECT', 'User'))))),
          _field('pageInfo', _nonNull(_type('OBJECT', 'PageInfo'))),
          _field('totalCount', _nonNull(_type('SCALAR', 'Int'))),
          _field('label', _type('SCALAR', 'String')),
        ],
        'inputFields': null,
        'enumValues': null,
      },
      {
        'kind': 'OBJECT',
        'name': 'Tally',
        'description': 'Not a connection: no pageInfo.',
        'fields': [
          _field('totalCount', _nonNull(_type('SCALAR', 'Int'))),
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
          {'name': 'ACTIVE', 'description': 'Signed in recently.', 'isDeprecated': false, 'deprecationReason': null},
          {'name': 'INACTIVE', 'description': null, 'isDeprecated': false, 'deprecationReason': null},
          {'name': 'ON_HOLD', 'description': null, 'isDeprecated': true, 'deprecationReason': 'Use INACTIVE.'},
          {'name': 'UNKNOWN', 'description': null, 'isDeprecated': false, 'deprecationReason': null},
          {'name': 'default', 'description': null, 'isDeprecated': false, 'deprecationReason': null},
          {'name': 'on_hold', 'description': null, 'isDeprecated': false, 'deprecationReason': null},
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
          _arg('status', _type('ENUM', 'UserStatus')),
          _arg('statusIn', _list(_nonNull(_type('ENUM', 'UserStatus')))),
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

  test('emits Query with root constructors', () {
    expect(code, contains('class Query extends Accessor {'));
    expect(code, contains('Query(super.recorder, super.selection, super.path);'));
    expect(code, contains('Query.root(Recorder r) : super(r, r.root, const []);'));
  });

  test('emits Mutation root and the typed mutate extension', () {
    expect(code, contains('class Mutation extends Accessor {'));
    expect(code, contains('Mutation.root(Recorder r) : super(r, r.root, const []);'));
    expect(code, contains("bool? get noop => scalar<bool>('noop');"));
    expect(
      code,
      contains(
        "User? rename({required String id, required String name}) => object('rename', User.new, args: {'id': Arg('ID!', id), 'name': Arg('String!', name)}, keyed: true);",
      ),
    );
    expect(code, contains('extension SlingMutations on SlingClient<Query> {'));
    expect(code, contains('mutateWith(Mutation.root, body, optimistic: optimistic);'));
    // Mutation is not emitted twice (once as root, once as plain object).
    expect(RegExp('class Mutation extends Accessor').allMatches(code), hasLength(1));
  });

  test('no Mutation class when the schema has no mutation type', () {
    final json = Map<String, Object?>.from(_schemaJson);
    final schema = Map<String, Object?>.from(json['__schema'] as Map<String, Object?>)
      ..['mutationType'] = null;
    final code = generate(IntrospectionSchema.fromJson({'__schema': schema}));
    expect(code, isNot(contains('extension SlingMutations')));
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
    expect(code, contains("set age(int? v) => write('age', v);"));
  });

  test('no setter on the key field of a keyed type', () {
    expect(code, isNot(contains("set id(String? v) => write('id', v);")));
    // With another key field, `id` is an ordinary scalar again.
    final unkeyed = generate(IntrospectionSchema.fromJson(_schemaJson), keyField: 'uuid');
    expect(unkeyed, contains("set id(String? v) => write('id', v);"));
  });

  test('no setters on PageInfo fields', () {
    expect(code, contains("bool? get hasNextPage => scalar<bool>('hasNextPage');"));
    expect(code, contains("String? get endCursor => scalar<String>('endCursor');"));
    expect(code, isNot(contains('set hasNextPage(')));
    expect(code, isNot(contains('set endCursor(')));
  });

  test('no setter on totalCount of a connection-shaped type; other scalars keep theirs', () {
    expect(code, contains("int? get totalCount => scalar<int>('totalCount');"));
    expect(code, contains("set label(String? v) => write('label', v);"));
    // `Tally.totalCount` is not connection metadata (no pageInfo/nodes/edges).
    expect(code, contains("set totalCount(int? v) => write('totalCount', v);"));
    expect(RegExp(r'set totalCount\(').allMatches(code), hasLength(1));
  });

  test('list-of-object field with args', () {
    expect(
      code,
      contains("List<User>? friends({int? limit}) => list('friends', User.new, args:"),
    );
    expect(code, contains("keyed: true);"));
  });

  test('enum field is read through enumValue and written as its wire name', () {
    expect(code, contains("UserStatus? get status => enumValue('status', UserStatus.fromGraphQL);"));
    expect(code, contains("set status(UserStatus? v) => write('status', v?.graphqlName);"));
    expect(
      code,
      contains("List<UserStatus?>? get pastStatuses => enumList('pastStatuses', UserStatus.fromGraphQL);"),
    );
    expect(
      code,
      contains(
        "UserStatus? statusAt({required String date}) => enumValue('statusAt', UserStatus.fromGraphQL, args: {'date': Arg('Date!', date)});",
      ),
    );
  });

  test('emits a real enum with lowerCamelCase constants and graphqlName', () {
    expect(code, contains('enum UserStatus {'));
    expect(code, contains("  /// Signed in recently.\n  active('ACTIVE'),"));
    expect(code, contains("  inactive('INACTIVE'),"));
    expect(code, contains("  @Deprecated('Use INACTIVE.')\n  onHold('ON_HOLD'),"));
    expect(code, contains('  const UserStatus(this.graphqlName);'));
    expect(code, contains('  final String graphqlName;'));
    expect(code, contains('  static UserStatus fromGraphQL(String value) =>'));
    expect(code, contains('  String toGraphQL() {'));
    expect(code, isNot(contains('abstract final class UserStatus')));
  });

  test('enum gets a trailing unknown constant for forward compatibility', () {
    expect(code, contains("  unknown('');\n\n  const UserStatus(this.graphqlName);"));
    expect(code, contains('orElse: () => unknown'));
    expect(code, contains("throw ArgumentError.value(this, 'UserStatus', 'unknown cannot be sent as an argument');"));
  });

  test('enum constants clashing with enum members, keywords or each other get a \$', () {
    expect(code, contains("  unknown\$('UNKNOWN'),"));
    expect(code, contains("  default\$('default'),"));
    // `on_hold` camel-cases to `onHold`, already taken by `ON_HOLD`.
    expect(code, contains("  onHold\$('on_hold'),"));
  });

  test('enum-typed input fields and args serialize through toGraphQL()', () {
    expect(code, contains('final UserStatus? status;'));
    expect(code, contains('final List<UserStatus>? statusIn;'));
    expect(code, contains("if (status != null) 'status': status?.toGraphQL(),"));
    expect(code, contains("if (statusIn != null) 'statusIn': statusIn?.map((e) => e.toGraphQL()).toList(),"));
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
    expect(code, contains('const UserFilter({this.\$eq, this.\$and, this.status, this.statusIn});'));
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
