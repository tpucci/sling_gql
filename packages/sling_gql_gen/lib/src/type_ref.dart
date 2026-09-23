/// A GraphQL introspection `__Type` reference, i.e. the recursive
/// `{kind, name, ofType}` shape used for field/arg/input-field types.
///
/// `kind` is one of `SCALAR`, `OBJECT`, `INTERFACE`, `UNION`, `ENUM`,
/// `INPUT_OBJECT`, `LIST`, `NON_NULL`. Only `LIST` and `NON_NULL` wrap
/// another [TypeRef] via [ofType]; all other kinds are "named" types.
class TypeRef {
  const TypeRef({required this.kind, this.name, this.ofType});

  factory TypeRef.fromJson(Map<String, Object?> json) => TypeRef(
        kind: json['kind']! as String,
        name: json['name'] as String?,
        ofType: json['ofType'] == null
            ? null
            : TypeRef.fromJson(json['ofType']! as Map<String, Object?>),
      );

  final String kind;
  final String? name;
  final TypeRef? ofType;

  bool get isNonNull => kind == 'NON_NULL';
  bool get isList => kind == 'LIST';

  /// Unwraps a single leading `NON_NULL` wrapper, if any.
  TypeRef get withoutTopNonNull => isNonNull ? ofType! : this;

  /// True when this type (after stripping a leading `NON_NULL`) is a list.
  bool get isListType => withoutTopNonNull.kind == 'LIST';

  /// The list element type ref. Only valid when [isListType] is true.
  TypeRef get listElement => withoutTopNonNull.ofType!;

  /// Strips every `LIST`/`NON_NULL` wrapper down to the named type
  /// (`SCALAR`, `OBJECT`, `ENUM`, `INPUT_OBJECT`, `INTERFACE`, `UNION`).
  TypeRef get named {
    var t = this;
    while (t.kind == 'NON_NULL' || t.kind == 'LIST') {
      t = t.ofType!;
    }
    return t;
  }

  /// The exact GraphQL type literal, e.g. `Int`, `String!`, `[String!]!`.
  String toGraphQLLiteral() {
    switch (kind) {
      case 'NON_NULL':
        return '${ofType!.toGraphQLLiteral()}!';
      case 'LIST':
        return '[${ofType!.toGraphQLLiteral()}]';
      default:
        return name!;
    }
  }

  @override
  String toString() => toGraphQLLiteral();
}

/// The result of recursively resolving a [TypeRef] to a Dart type
/// expression, tracking whether the *outermost* wrapper was `NON_NULL` so
/// callers can decide between `required T` and `T?`.
class ResolvedDartType {
  const ResolvedDartType(this.dartType, this.nonNull);

  /// The bare Dart type, without a trailing `?`.
  final String dartType;

  /// True when the outermost GraphQL wrapper was `NON_NULL`.
  final bool nonNull;
}
