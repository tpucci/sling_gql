import 'type_ref.dart';

/// An `input value` in introspection: used for both field/directive
/// arguments and input-object fields (they share the same JSON shape).
class GqlInputValue {
  const GqlInputValue({
    required this.name,
    required this.type,
    this.description,
    this.defaultValue,
  });

  factory GqlInputValue.fromJson(Map<String, Object?> json) => GqlInputValue(
        name: json['name']! as String,
        description: json['description'] as String?,
        type: TypeRef.fromJson(json['type']! as Map<String, Object?>),
        defaultValue: json['defaultValue'],
      );

  final String name;
  final String? description;
  final TypeRef type;

  /// Raw introspection default value (a GraphQL literal string), or null.
  final Object? defaultValue;
}

class GqlField {
  const GqlField({
    required this.name,
    required this.type,
    required this.args,
    required this.isDeprecated,
    this.description,
    this.deprecationReason,
  });

  factory GqlField.fromJson(Map<String, Object?> json) => GqlField(
        name: json['name']! as String,
        description: json['description'] as String?,
        type: TypeRef.fromJson(json['type']! as Map<String, Object?>),
        args: (json['args']! as List)
            .map((a) => GqlInputValue.fromJson(a as Map<String, Object?>))
            .toList(),
        isDeprecated: json['isDeprecated'] as bool? ?? false,
        deprecationReason: json['deprecationReason'] as String?,
      );

  final String name;
  final String? description;
  final TypeRef type;
  final List<GqlInputValue> args;
  final bool isDeprecated;
  final String? deprecationReason;
}

class GqlEnumValue {
  const GqlEnumValue({
    required this.name,
    required this.isDeprecated,
    this.description,
    this.deprecationReason,
  });

  factory GqlEnumValue.fromJson(Map<String, Object?> json) => GqlEnumValue(
        name: json['name']! as String,
        description: json['description'] as String?,
        isDeprecated: json['isDeprecated'] as bool? ?? false,
        deprecationReason: json['deprecationReason'] as String?,
      );

  final String name;
  final String? description;
  final bool isDeprecated;
  final String? deprecationReason;
}

/// A named type from `__schema.types`: `OBJECT`, `INPUT_OBJECT`, `ENUM`,
/// `SCALAR`, `INTERFACE` or `UNION`.
class GqlType {
  const GqlType({
    required this.kind,
    required this.name,
    this.description,
    this.fields = const [],
    this.inputFields = const [],
    this.enumValues = const [],
  });

  factory GqlType.fromJson(Map<String, Object?> json) {
    final fields = json['fields'] as List?;
    final inputFields = json['inputFields'] as List?;
    final enumValues = json['enumValues'] as List?;
    return GqlType(
      kind: json['kind']! as String,
      name: json['name']! as String,
      description: json['description'] as String?,
      fields: fields == null
          ? const []
          : fields.map((f) => GqlField.fromJson(f as Map<String, Object?>)).toList(),
      inputFields: inputFields == null
          ? const []
          : inputFields
              .map((f) => GqlInputValue.fromJson(f as Map<String, Object?>))
              .toList(),
      enumValues: enumValues == null
          ? const []
          : enumValues
              .map((v) => GqlEnumValue.fromJson(v as Map<String, Object?>))
              .toList(),
    );
  }

  final String kind;
  final String name;
  final String? description;
  final List<GqlField> fields;
  final List<GqlInputValue> inputFields;
  final List<GqlEnumValue> enumValues;
}

/// A parsed GraphQL introspection result (`{"__schema": {...}}`).
class IntrospectionSchema {
  const IntrospectionSchema({
    required this.queryTypeName,
    required this.types,
    this.mutationTypeName,
    this.subscriptionTypeName,
  });

  /// Accepts either the full `{"__schema": {...}}` document (the standard
  /// introspection response) or an already-unwrapped `__schema` object.
  factory IntrospectionSchema.fromJson(Map<String, Object?> json) {
    final schema = (json['__schema'] as Map<String, Object?>?) ?? json;
    final queryType = schema['queryType'] as Map<String, Object?>?;
    final mutationType = schema['mutationType'] as Map<String, Object?>?;
    final subscriptionType = schema['subscriptionType'] as Map<String, Object?>?;
    final types = (schema['types']! as List)
        .map((t) => GqlType.fromJson(t as Map<String, Object?>))
        .toList();
    return IntrospectionSchema(
      queryTypeName: queryType!['name']! as String,
      mutationTypeName: mutationType?['name'] as String?,
      subscriptionTypeName: subscriptionType?['name'] as String?,
      types: types,
    );
  }

  final String queryTypeName;
  final String? mutationTypeName;
  final String? subscriptionTypeName;
  final List<GqlType> types;

  Map<String, GqlType> get typesByName => {for (final t in types) t.name: t};
}
