import 'package:sling_gql_gen/sling_gql_gen.dart';
import 'package:test/test.dart';

void main() {
  group('scalarDartType', () {
    test('maps built-in scalars', () {
      expect(scalarDartType('String'), 'String');
      expect(scalarDartType('ID'), 'String');
      expect(scalarDartType('Int'), 'int');
      expect(scalarDartType('Float'), 'double');
      expect(scalarDartType('Boolean'), 'bool');
    });

    test('maps known string-like custom scalars', () {
      expect(scalarDartType('Date'), 'String');
      expect(scalarDartType('timestamptz'), 'String');
    });

    test('maps unknown custom scalars to Object', () {
      expect(scalarDartType('ObjectID'), 'Object');
      expect(scalarDartType('uuid'), 'Object');
      expect(scalarDartType('_Any'), 'Object');
      expect(scalarDartType('federation__FieldSet'), 'Object');
      expect(scalarDartType('link__Import'), 'Object');
    });

    test('isKnownScalar', () {
      expect(isKnownScalar('String'), isTrue);
      expect(isKnownScalar('Date'), isTrue);
      expect(isKnownScalar('uuid'), isFalse);
    });
  });

  group('TypeRef.toGraphQLLiteral', () {
    TypeRef named(String kind, String name) => TypeRef(kind: kind, name: name);

    test('bare scalar', () {
      expect(named('SCALAR', 'Int').toGraphQLLiteral(), 'Int');
    });

    test('non-null scalar', () {
      final ref = TypeRef(kind: 'NON_NULL', ofType: named('SCALAR', 'String'));
      expect(ref.toGraphQLLiteral(), 'String!');
    });

    test('list of non-null scalar, non-null list', () {
      final ref = TypeRef(
        kind: 'NON_NULL',
        ofType: TypeRef(
          kind: 'LIST',
          ofType: TypeRef(kind: 'NON_NULL', ofType: named('SCALAR', 'String')),
        ),
      );
      expect(ref.toGraphQLLiteral(), '[String!]!');
    });

    test('object/input type names pass through', () {
      expect(named('INPUT_OBJECT', 'LaunchFind').toGraphQLLiteral(), 'LaunchFind');
      expect(named('ENUM', 'order_by').toGraphQLLiteral(), 'order_by');
    });
  });

  group('resolveArgDartType', () {
    TypeRef named(String kind, String name) => TypeRef(kind: kind, name: name);

    test('non-null scalar reports nonNull=true, bare dart type', () {
      final ref = TypeRef(kind: 'NON_NULL', ofType: named('SCALAR', 'ID'));
      final resolved = resolveArgDartType(ref);
      expect(resolved.dartType, 'String');
      expect(resolved.nonNull, isTrue);
    });

    test('nullable scalar reports nonNull=false', () {
      final resolved = resolveArgDartType(named('SCALAR', 'Int'));
      expect(resolved.dartType, 'int');
      expect(resolved.nonNull, isFalse);
    });

    test('list of non-null enum -> List<String> with non-null elements, nullable list', () {
      final ref = TypeRef(
        kind: 'LIST',
        ofType: TypeRef(kind: 'NON_NULL', ofType: named('ENUM', 'users_select_column')),
      );
      final resolved = resolveArgDartType(ref);
      expect(resolved.dartType, 'List<String>');
      expect(resolved.nonNull, isFalse);
    });

    test('list of nullable input object -> List<T?>', () {
      final ref = TypeRef(kind: 'LIST', ofType: named('INPUT_OBJECT', 'LaunchFind'));
      final resolved = resolveArgDartType(ref);
      expect(resolved.dartType, 'List<LaunchFind?>');
    });

    test('input object type name is sanitized', () {
      final resolved = resolveArgDartType(named('INPUT_OBJECT', 'Object'));
      expect(resolved.dartType, 'Object\$');
    });
  });

  group('argValueExpression', () {
    TypeRef named(String kind, String name) => TypeRef(kind: kind, name: name);

    test('scalar passes through unchanged', () {
      expect(argValueExpression('limit', named('SCALAR', 'Int'), nonNull: false), 'limit');
    });

    test('nullable input object calls ?.toJson()', () {
      expect(
        argValueExpression('find', named('INPUT_OBJECT', 'LaunchFind'), nonNull: false),
        'find?.toJson()',
      );
    });

    test('required input object calls .toJson()', () {
      expect(
        argValueExpression('find', named('INPUT_OBJECT', 'LaunchFind'), nonNull: true),
        'find.toJson()',
      );
    });

    test('list of nullable-element input objects maps toJson with ?.', () {
      final ref = TypeRef(kind: 'LIST', ofType: named('INPUT_OBJECT', 'OrderBy'));
      expect(
        argValueExpression('order', ref, nonNull: false),
        'order?.map((e) => e?.toJson()).toList()',
      );
    });

    test('list of non-null-element input objects maps toJson without ?.', () {
      final ref = TypeRef(
        kind: 'LIST',
        ofType: TypeRef(kind: 'NON_NULL', ofType: named('INPUT_OBJECT', 'OrderBy')),
      );
      expect(
        argValueExpression('order', ref, nonNull: false),
        'order?.map((e) => e.toJson()).toList()',
      );
    });
  });

  group('sanitizeIdentifier', () {
    test('leaves ordinary names untouched', () {
      expect(sanitizeIdentifier('mission_name'), 'mission_name');
      expect(sanitizeIdentifier('id'), 'id');
    });

    test('Hasura-style leading underscore becomes a leading \$', () {
      expect(sanitizeIdentifier('_eq'), r'$eq');
      expect(sanitizeIdentifier('_and'), r'$and');
      expect(sanitizeIdentifier('_service'), r'$service');
    });

    test('Dart keywords get a trailing \$', () {
      expect(sanitizeIdentifier('class'), 'class\$');
      expect(sanitizeIdentifier('type'), 'type\$');
      expect(sanitizeIdentifier('in'), 'in\$');
      expect(sanitizeIdentifier('default'), 'default\$');
    });

    test('Accessor member names get a trailing \$', () {
      expect(sanitizeIdentifier('write'), 'write\$');
      expect(sanitizeIdentifier('selection'), 'selection\$');
      expect(sanitizeIdentifier('toJson'), 'toJson\$');
    });
  });

  group('sanitizeTypeName', () {
    test('leaves ordinary type names untouched', () {
      expect(sanitizeTypeName('Launch'), 'Launch');
      expect(sanitizeTypeName('users'), 'users');
    });

    test('suffixes collisions with dart:core / runtime types', () {
      expect(sanitizeTypeName('Object'), 'Object\$');
      expect(sanitizeTypeName('String'), 'String\$');
      expect(sanitizeTypeName('Accessor'), 'Accessor\$');
      expect(sanitizeTypeName('Recorder'), 'Recorder\$');
    });
  });
}
