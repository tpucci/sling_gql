import 'package:gql/ast.dart';
import 'package:gql/language.dart';

import 'schema.dart';
import 'type_ref.dart';

const _builtInScalars = ['Int', 'Float', 'String', 'Boolean', 'ID'];

/// Builds the [IntrospectionSchema] a server would return for [sdl], a
/// GraphQL schema in SDL (`type Query { ... }`), so a schema file kept in a
/// repository can be generated from without a running server.
///
/// Type extensions (`extend type ...`) are merged into their type. Directive
/// definitions and usages are ignored, except `@deprecated`.
IntrospectionSchema introspectionFromSdl(String sdl) {
  final document = parseString(sdl);

  // Definitions and extensions, merged per type name, in SDL order.
  final definitions = <String, TypeDefinitionNode>{};
  final extraFields = <String, List<FieldDefinitionNode>>{};
  final extraInterfaces = <String, List<NamedTypeNode>>{};
  final extraInputFields = <String, List<InputValueDefinitionNode>>{};
  final extraValues = <String, List<EnumValueDefinitionNode>>{};
  final extraMembers = <String, List<NamedTypeNode>>{};
  final roots = <OperationType, String>{};

  for (final node in document.definitions) {
    switch (node) {
      case SchemaDefinitionNode():
        for (final op in node.operationTypes) {
          roots[op.operation] = op.type.name.value;
        }
      case TypeDefinitionNode():
        definitions[node.name.value] = node;
      case ObjectTypeExtensionNode():
        (extraFields[node.name.value] ??= []).addAll(node.fields);
        (extraInterfaces[node.name.value] ??= []).addAll(node.interfaces);
      case InterfaceTypeExtensionNode():
        (extraFields[node.name.value] ??= []).addAll(node.fields);
        (extraInterfaces[node.name.value] ??= []).addAll(node.interfaces);
      case InputObjectTypeExtensionNode():
        (extraInputFields[node.name.value] ??= []).addAll(node.fields);
      case EnumTypeExtensionNode():
        (extraValues[node.name.value] ??= []).addAll(node.values);
      case UnionTypeExtensionNode():
        (extraMembers[node.name.value] ??= []).addAll(node.types);
      default:
        break; // directive definitions, scalar extensions, operations
    }
  }

  String kindOf(String name) => switch (definitions[name]) {
    ObjectTypeDefinitionNode() => 'OBJECT',
    InterfaceTypeDefinitionNode() => 'INTERFACE',
    UnionTypeDefinitionNode() => 'UNION',
    EnumTypeDefinitionNode() => 'ENUM',
    InputObjectTypeDefinitionNode() => 'INPUT_OBJECT',
    ScalarTypeDefinitionNode() => 'SCALAR',
    _ when _builtInScalars.contains(name) => 'SCALAR',
    _ => throw FormatException('Unknown type "$name" in SDL'),
  };

  TypeRef typeRef(TypeNode node) {
    final TypeRef inner = switch (node) {
      NamedTypeNode() => TypeRef(
        kind: kindOf(node.name.value),
        name: node.name.value,
      ),
      ListTypeNode() => TypeRef(kind: 'LIST', ofType: typeRef(node.type)),
      _ => throw FormatException('Unsupported type node $node'),
    };
    return node.isNonNull ? TypeRef(kind: 'NON_NULL', ofType: inner) : inner;
  }

  GqlInputValue inputValue(InputValueDefinitionNode node) => GqlInputValue(
    name: node.name.value,
    description: node.description?.value,
    type: typeRef(node.type),
    defaultValue: node.defaultValue == null
        ? null
        : printNode(node.defaultValue!),
  );

  GqlField field(FieldDefinitionNode node) {
    final reason = _deprecationReason(node.directives);
    return GqlField(
      name: node.name.value,
      description: node.description?.value,
      type: typeRef(node.type),
      args: node.args.map(inputValue).toList(),
      isDeprecated: reason != null,
      deprecationReason: reason,
    );
  }

  GqlEnumValue enumValue(EnumValueDefinitionNode node) {
    final reason = _deprecationReason(node.directives);
    return GqlEnumValue(
      name: node.name.value,
      description: node.description?.value,
      isDeprecated: reason != null,
      deprecationReason: reason,
    );
  }

  List<String> implementing(String interface) => [
    for (final d in definitions.values)
      if (d is ObjectTypeDefinitionNode &&
          [
            ...d.interfaces,
            ...?extraInterfaces[d.name.value],
          ].any((i) => i.name.value == interface))
        d.name.value,
  ];

  final types = [
    for (final name in _builtInScalars)
      if (!definitions.containsKey(name)) GqlType(kind: 'SCALAR', name: name),
    for (final d in definitions.values)
      GqlType(
        kind: kindOf(d.name.value),
        name: d.name.value,
        description: d.description?.value,
        fields: switch (d) {
          ObjectTypeDefinitionNode(:final fields) ||
          InterfaceTypeDefinitionNode(
            :final fields,
          ) => [...fields, ...?extraFields[d.name.value]].map(field).toList(),
          _ => const [],
        },
        inputFields: d is InputObjectTypeDefinitionNode
            ? [
                ...d.fields,
                ...?extraInputFields[d.name.value],
              ].map(inputValue).toList()
            : const [],
        enumValues: d is EnumTypeDefinitionNode
            ? [
                ...d.values,
                ...?extraValues[d.name.value],
              ].map(enumValue).toList()
            : const [],
        possibleTypes: switch (d) {
          UnionTypeDefinitionNode(:final types) => [
            ...types,
            ...?extraMembers[d.name.value],
          ].map((t) => t.name.value).toList(),
          InterfaceTypeDefinitionNode() => implementing(d.name.value),
          _ => const [],
        },
      ),
  ];

  // Without a `schema { ... }` block, the roots are the types named
  // Query / Mutation / Subscription, as in graphql-js.
  String? root(OperationType op, String conventional) =>
      roots[op] ??
      (definitions.containsKey(conventional) ? conventional : null);

  final query = root(OperationType.query, 'Query');
  if (query == null) {
    throw const FormatException('SDL defines no Query root type');
  }
  return IntrospectionSchema(
    queryTypeName: query,
    mutationTypeName: root(OperationType.mutation, 'Mutation'),
    subscriptionTypeName: root(OperationType.subscription, 'Subscription'),
    types: types,
  );
}

/// The `@deprecated` reason (graphql-js's default when none is given), or
/// null when the element isn't deprecated.
String? _deprecationReason(List<DirectiveNode> directives) {
  for (final d in directives) {
    if (d.name.value != 'deprecated') continue;
    for (final arg in d.arguments) {
      if (arg.name.value == 'reason' && arg.value is StringValueNode) {
        return (arg.value as StringValueNode).value;
      }
    }
    return 'No longer supported';
  }
  return null;
}
