import 'naming.dart';
import 'scalars.dart';
import 'schema.dart';
import 'type_resolver.dart';

/// Generates the full contents of the `sling_gql`-style accessor file for
/// [schema]. [importPath] is the import used to bring in `Accessor`/`Arg`/
/// `Recorder` (defaults to `package:sling_gql/sling_gql.dart`).
///
/// Object types that have a scalar [keyField] are *keyed*: fields returning
/// them are emitted with `keyed: true` so the runtime always selects the key
/// and normalizes the object (`__typename:id`). A field whose only argument is
/// the key field and which returns a keyed object (`launch(id: ID!): Launch`)
/// is emitted with `lookup: 'Launch'` so it can be served from the entity
/// cache without a request.
String generate(
  IntrospectionSchema schema, {
  String importPath = 'package:sling_gql/sling_gql.dart',
  String keyField = 'id',
}) {
  final typesByName = schema.typesByName;
  final ctx = _EmitContext(typesByName, keyField);
  final skipRootNames = {
    if (schema.mutationTypeName != null) schema.mutationTypeName!,
    if (schema.subscriptionTypeName != null) schema.subscriptionTypeName!,
  };

  final objectTypes = schema.types
      .where((t) => t.kind == 'OBJECT')
      .where((t) => !t.name.startsWith('__'))
      .where((t) => !skipRootNames.contains(t.name))
      .toList();
  final enumTypes = schema.types
      .where((t) => t.kind == 'ENUM')
      .where((t) => !t.name.startsWith('__'))
      .toList();
  final inputTypes = schema.types
      .where((t) => t.kind == 'INPUT_OBJECT')
      .where((t) => !t.name.startsWith('__'))
      .toList();

  final queryType = objectTypes.firstWhere(
    (t) => t.name == schema.queryTypeName,
    orElse: () => throw StateError(
      'Query root type "${schema.queryTypeName}" not found among OBJECT types.',
    ),
  );

  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
    ..writeln(
      '// ignore_for_file: non_constant_identifier_names, camel_case_types, '
      'constant_identifier_names, camel_case_extensions',
    )
    ..writeln()
    ..writeln("import '$importPath';")
    ..writeln();

  _emitQueryClass(out, queryType, ctx);

  for (final t in objectTypes) {
    if (t.name == schema.queryTypeName) continue;
    out.writeln();
    _emitObjectClass(out, t, ctx, className: sanitizeTypeName(t.name));
  }

  for (final t in enumTypes) {
    out.writeln();
    _emitEnumHolder(out, t);
  }

  for (final t in inputTypes) {
    out.writeln();
    _emitInputClass(out, t);
  }

  return out.toString();
}

void _emitDocAndDeprecation(
  StringBuffer out, {
  required String indent,
  String? description,
  bool isDeprecated = false,
  String? deprecationReason,
}) {
  if (description != null && description.trim().isNotEmpty) {
    for (final line in docCommentLines(description)) {
      out.writeln('$indent$line');
    }
  }
  if (isDeprecated) {
    out.writeln('$indent@Deprecated(${dartStringLiteral(deprecationReason ?? 'deprecated')})');
  }
}

/// Schema-wide facts the field emitter needs.
class _EmitContext {
  _EmitContext(this.typesByName, this.keyField);

  final Map<String, GqlType> typesByName;
  final String keyField;

  /// True when [typeName] is an object type with a scalar [keyField].
  bool isKeyed(String typeName) {
    final type = typesByName[typeName];
    if (type == null || type.kind != 'OBJECT') return false;
    return type.fields.any(
      (f) => f.name == keyField && f.args.isEmpty && f.type.named.kind == 'SCALAR',
    );
  }

  /// True when [field] is a by-key lookup of a keyed object:
  /// `launch(id: ID!): Launch`.
  bool isLookup(GqlField field) {
    if (field.type.isListType) return false;
    final leaf = field.type.named;
    if (leaf.kind != 'OBJECT' || !isKeyed(leaf.name!)) return false;
    return field.args.length == 1 && field.args.single.name == keyField;
  }
}

void _emitQueryClass(StringBuffer out, GqlType queryType, _EmitContext ctx) {
  _emitDocAndDeprecation(out, indent: '', description: queryType.description);
  out.writeln('class Query extends Accessor {');
  out.writeln('  Query(super.recorder, super.selection, super.path);');
  out.writeln('  Query.root(Recorder r) : super(r, r.root, const []);');
  out.writeln();
  for (final field in queryType.fields) {
    _emitField(out, field, ctx);
  }
  out.writeln('}');
}

void _emitObjectClass(
  StringBuffer out,
  GqlType type,
  _EmitContext ctx, {
  required String className,
}) {
  _emitDocAndDeprecation(out, indent: '', description: type.description);
  out.writeln('class $className extends Accessor {');
  out.writeln('  $className(super.recorder, super.selection, super.path);');
  out.writeln();
  for (final field in type.fields) {
    _emitField(out, field, ctx);
  }
  out.writeln('}');
}

void _emitField(StringBuffer out, GqlField field, _EmitContext ctx) {
  final dartFieldName = sanitizeIdentifier(field.name);
  final leaf = field.type.named;
  final isList = field.type.isListType;
  final isScalarLeaf = leaf.kind == 'SCALAR' || leaf.kind == 'ENUM';

  // Normalization hints for object fields (see `generate`).
  final keyed = !isScalarLeaf && ctx.isKeyed(leaf.name!);
  final lookup = !isScalarLeaf && ctx.isLookup(field) ? sanitizeTypeName(leaf.name!) : null;
  final objectOpts = lookup != null
      ? ", lookup: '$lookup'" // implies keyed
      : keyed
          ? ', keyed: true'
          : '';

  final String elementDartType;
  if (leaf.kind == 'SCALAR') {
    elementDartType = scalarDartType(leaf.name!);
  } else if (leaf.kind == 'ENUM') {
    elementDartType = 'String';
  } else {
    elementDartType = sanitizeTypeName(leaf.name!);
  }

  // A field whose sanitized Dart name is spelled exactly like the Dart
  // class it returns (common with Hasura's lowercase table types, e.g. a
  // `users` field returning type `users`) would shadow that top-level type
  // name within this class body, breaking `elementDartType.new` and the
  // return-type annotation. Disambiguate the member, not the type.
  final effectiveFieldName =
      dartFieldName == elementDartType ? '$dartFieldName\$' : dartFieldName;

  _emitDocAndDeprecation(
    out,
    indent: '  ',
    description: field.description,
    isDeprecated: field.isDeprecated,
    deprecationReason: field.deprecationReason,
  );
  if (leaf.kind == 'SCALAR' && !isKnownScalar(leaf.name!)) {
    out.writeln('  /// Unknown custom scalar `${leaf.name}`; read as `Object?`.');
  }

  final hasArgs = field.args.isNotEmpty;
  final key = dartStringLiteral(field.name);

  if (!hasArgs) {
    if (!isList && isScalarLeaf) {
      out.writeln(
        "  $elementDartType? get $effectiveFieldName => scalar<$elementDartType>($key);",
      );
      out.writeln("  set $effectiveFieldName($elementDartType? v) => write($key, v);");
    } else if (isList && isScalarLeaf) {
      out.writeln(
        "  List<$elementDartType?>? get $effectiveFieldName => scalarList<$elementDartType>($key);",
      );
    } else if (!isList) {
      out.writeln(
        "  $elementDartType? get $effectiveFieldName => object($key, $elementDartType.new$objectOpts);",
      );
    } else {
      out.writeln(
        "  List<$elementDartType>? get $effectiveFieldName => list($key, $elementDartType.new$objectOpts);",
      );
    }
    return;
  }

  final params = _buildParamList(field.args);
  final argsMap = _buildArgsMap(field.args);
  if (!isList && isScalarLeaf) {
    out.writeln(
      "  $elementDartType? $effectiveFieldName($params) => scalar<$elementDartType>($key, args: $argsMap);",
    );
  } else if (isList && isScalarLeaf) {
    out.writeln(
      "  List<$elementDartType?>? $effectiveFieldName($params) => scalarList<$elementDartType>($key, args: $argsMap);",
    );
  } else if (!isList) {
    out.writeln(
      "  $elementDartType? $effectiveFieldName($params) => object($key, $elementDartType.new, args: $argsMap$objectOpts);",
    );
  } else {
    out.writeln(
      "  List<$elementDartType>? $effectiveFieldName($params) => list($key, $elementDartType.new, args: $argsMap$objectOpts);",
    );
  }
}

/// `{required String id, LaunchFind? find, int? limit}`
String _buildParamList(List<GqlInputValue> args) {
  final parts = <String>[];
  for (final a in args) {
    final resolved = resolveArgDartType(a.type);
    final dartName = sanitizeIdentifier(a.name);
    final required = resolved.nonNull && a.defaultValue == null;
    if (required) {
      parts.add('required ${resolved.dartType} $dartName');
    } else {
      parts.add('${resolved.dartType}? $dartName');
    }
  }
  return '{${parts.join(', ')}}';
}

/// `{'id': Arg('ID!', id), 'find': Arg('LaunchFind', find?.toJson())}`
String _buildArgsMap(List<GqlInputValue> args) {
  final entries = <String>[];
  for (final a in args) {
    final resolved = resolveArgDartType(a.type);
    final required = resolved.nonNull && a.defaultValue == null;
    final dartName = sanitizeIdentifier(a.name);
    final valueExpr = argValueExpression(dartName, a.type, nonNull: required);
    entries.add("'${a.name}': Arg('${a.type.toGraphQLLiteral()}', $valueExpr)");
  }
  return '{${entries.join(', ')}}';
}

void _emitEnumHolder(StringBuffer out, GqlType type) {
  final className = sanitizeTypeName(type.name);
  _emitDocAndDeprecation(out, indent: '', description: type.description);
  out.writeln('abstract final class $className {');
  for (final v in type.enumValues) {
    _emitDocAndDeprecation(
      out,
      indent: '  ',
      description: v.description,
      isDeprecated: v.isDeprecated,
      deprecationReason: v.deprecationReason,
    );
    final dartName = sanitizeIdentifier(v.name);
    out.writeln('  static const $dartName = ${dartStringLiteral(v.name)};');
  }
  out.writeln('}');
}

void _emitInputClass(StringBuffer out, GqlType type) {
  final className = sanitizeTypeName(type.name);
  _emitDocAndDeprecation(out, indent: '', description: type.description);
  out.writeln('class $className {');

  final ctorParams = type.inputFields.map((f) => 'this.${sanitizeIdentifier(f.name)}').join(', ');
  out.writeln('  const $className({$ctorParams});');
  out.writeln();

  for (final f in type.inputFields) {
    final resolved = resolveArgDartType(f.type);
    _emitDocAndDeprecation(out, indent: '  ', description: f.description);
    out.writeln('  final ${resolved.dartType}? ${sanitizeIdentifier(f.name)};');
  }

  out.writeln();
  out.writeln('  Map<String, Object?> toJson() => {');
  for (final f in type.inputFields) {
    final dartName = sanitizeIdentifier(f.name);
    final valueExpr = argValueExpression(dartName, f.type, nonNull: false);
    out.writeln("    if ($dartName != null) '${f.name}': $valueExpr,");
  }
  out.writeln('  };');
  out.writeln('}');
}
