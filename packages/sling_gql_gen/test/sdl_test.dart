import 'dart:convert';
import 'dart:io';

import 'package:sling_gql_gen/sling_gql_gen.dart';
import 'package:test/test.dart';

void main() {
  test('the mock API SDL generates the same code as its introspection', () {
    final fromJson = IntrospectionSchema.fromJson(
      jsonDecode(File('../../example/graphql/schema.json').readAsStringSync())
          as Map<String, Object?>,
    );
    final fromSdl = introspectionFromSdl(
      File('../../mock-api/schema.graphql').readAsStringSync(),
    );
    final scalars = [ScalarMapping.parseFlag('DateTime=DateTime')];

    expect(
      generate(fromSdl, scalars: scalars),
      generate(fromJson, scalars: scalars),
    );
  });

  test('merges extensions, honours schema roots, deprecations, defaults', () {
    final schema = introspectionFromSdl('''
      schema { query: Root subscription: Events }
      interface Node { id: ID! }
      type Root { node(id: ID!): Node, items(first: Int = 10, tag: Tag = A): [Item!]! }
      type Item implements Node { id: ID! }
      extend type Item { old: String @deprecated(reason: "use id") }
      type Events { tick: Int @deprecated }
      enum Tag { A }
      extend enum Tag { B }
      directive @auth(role: String) on FIELD_DEFINITION
    ''');
    final types = schema.typesByName;

    expect(schema.queryTypeName, 'Root');
    expect(schema.mutationTypeName, isNull);
    expect(schema.subscriptionTypeName, 'Events');
    expect(types['Node']!.possibleTypes, ['Item']);
    expect(types['Tag']!.enumValues.map((v) => v.name), ['A', 'B']);

    final old = types['Item']!.fields.last;
    expect(old.name, 'old');
    expect(old.deprecationReason, 'use id');
    expect(types['Events']!.fields.single.deprecationReason, isNotNull);

    final items = types['Root']!.fields.last;
    expect(items.type.toGraphQLLiteral(), '[Item!]!');
    expect(items.args.map((a) => a.defaultValue), ['10', 'A']);
  });

  test('rejects a reference to an undefined type', () {
    expect(
      () => introspectionFromSdl('type Query { a: Missing }'),
      throwsFormatException,
    );
  });
}
