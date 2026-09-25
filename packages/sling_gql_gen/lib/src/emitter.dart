import 'naming.dart';
import 'scalars.dart';
import 'schema.dart';
import 'type_resolver.dart';

/// The identifier-renaming scheme explained once, in the file every reader
/// of the generated output actually opens (see `naming.dart` for the
/// implementation and `tooling/code-generation.mdx`'s "Name sanitization"
/// section for the full write-up — keep all three in sync by hand). A raw
/// string: no `$` in it is Dart interpolation, all of it is literal text.
const String _headerComment = r'''
//
// This file is generated from the GraphQL schema; do not edit it directly --
// change the schema and regenerate instead (see the package README).
//
// Identifier scheme (GraphQL name -> Dart name), and why:
//   - A leading `_` becomes `$`, so the identifier stays public in Dart (a
//     leading underscore would make it library-private): Hasura-style
//     `_eq` -> `$eq`, `_and` -> `$and`.
//   - A Dart keyword, or a name `Accessor` already declares (`selection`,
//     `write`, `isSkeleton`, ...), gets a trailing `$` so the generated
//     getter/method doesn't fail to parse or shadow the base class:
//     `type` -> `type$`, `class` -> `class$`.
//   - A GraphQL type name that collides with `dart:core` or a sling_gql
//     runtime type (`Object`, `String`, `List`, `Map`, `Cache`, `Accessor`,
//     `Selection`, `Arg`, `Recorder`) gets a trailing `$`:
//     `Object` -> `Object$`.
//   - A field whose Dart name is spelled exactly like its own return type
//     (common with lowercase table types, e.g. a `users` field returning
//     type `users`) is disambiguated at the member, not the type, so it
//     doesn't shadow the class inside its own body: `users` -> `users$`.
//   - Enum constants are lowerCamelCased (`PARTIAL_FAILURE` ->
//     `partialFailure`) and get the same trailing `$` on a clash with a
//     keyword or an enum member (`unknown`, `values`, `index`, `name`, ...),
//     or when two wire names camel-case to the same identifier.
//   - `Accessor.$typename` (declared once, in the runtime, not per
//     generated type) reads the cached `__typename`; it is named with a
//     leading `$` for the same public-identifier reason as `_eq` above.
//
// The original GraphQL name is never lost: it is always kept as the string
// literal used for cache keys, `Arg` map keys and `toJson` keys, so renaming
// here is purely cosmetic on the Dart side.
//
// See packages/sling_gql_gen/lib/src/naming.dart for the implementation.
//''';

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
///
/// [scalars] overrides how specific custom scalars are read/written (see
/// `--scalar` / [ScalarMapping]); every other scalar keeps the
/// [scalarDartType] default.
String generate(
  IntrospectionSchema schema, {
  String importPath = 'package:sling_gql/sling_gql.dart',
  String keyField = 'id',
  Iterable<ScalarMapping> scalars = const [],
}) {
  final typesByName = schema.typesByName;
  final ctx = _EmitContext(typesByName, keyField, ScalarRegistry(scalars));
  // Subscriptions are not supported yet; the Mutation root is emitted like
  // Query, with a `.root` constructor and a `client.mutate` extension.
  final skipRootNames = {
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
    ..writeln(_headerComment)
    ..writeln(
      '// ignore_for_file: non_constant_identifier_names, camel_case_types, '
      'camel_case_extensions',
    )
    ..writeln()
    ..writeln("import '$importPath';")
    ..writeln();

  _emitRootClass(out, queryType, ctx, className: 'Query');

  final mutationType = schema.mutationTypeName == null
      ? null
      : typesByName[schema.mutationTypeName!];
  if (mutationType != null && mutationType.fields.isNotEmpty) {
    out.writeln();
    _emitRootClass(out, mutationType, ctx, className: 'Mutation');
    out.writeln();
    _emitMutateExtension(out);
    out.writeln();
    _emitSlingSchema(out);
  }

  for (final t in objectTypes) {
    if (t.name == schema.queryTypeName || t.name == schema.mutationTypeName) continue;
    out.writeln();
    _emitObjectClass(out, t, ctx, className: sanitizeTypeName(t.name));
  }

  for (final t in enumTypes) {
    out.writeln();
    _emitEnum(out, t);
  }

  for (final t in inputTypes) {
    out.writeln();
    _emitInputClass(out, t, ctx.registry);
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
  _EmitContext(this.typesByName, this.keyField, this.registry);

  final Map<String, GqlType> typesByName;
  final String keyField;
  final ScalarRegistry registry;

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

  /// True when a setter must not be emitted for [field] on [owner]:
  /// the key field of a keyed type (writing it would corrupt the entity key)
  /// and connection metadata (`PageInfo` fields, `totalCount`/`pageInfo` on
  /// a connection-shaped type), which only the server can know.
  bool isReadOnly(GqlType owner, GqlField field) {
    if (field.name == keyField && isKeyed(owner.name)) return true;
    if (owner.name == 'PageInfo') return true;
    return isConnection(owner) && const {'totalCount', 'pageInfo'}.contains(field.name);
  }

  /// Relay-style connection: has `pageInfo` plus `nodes` or `edges`.
  bool isConnection(GqlType type) {
    final names = type.fields.map((f) => f.name).toSet();
    return names.contains('pageInfo') && (names.contains('nodes') || names.contains('edges'));
  }
}

/// Operation root types (`Query`, `Mutation`) get a `.root` constructor that
/// binds them to a [Recorder]'s selection root.
void _emitRootClass(
  StringBuffer out,
  GqlType type,
  _EmitContext ctx, {
  required String className,
}) {
  _emitDocAndDeprecation(out, indent: '', description: type.description);
  out.writeln('class $className extends Accessor {');
  out.writeln('  $className(super.recorder, super.selection, super.path);');
  out.writeln('  $className.root(Recorder r) : super(r, r.root, const []);');
  out.writeln();
  for (final field in type.fields) {
    _emitField(out, type, field, ctx);
  }
  out.writeln('}');
}

/// A schema-wide convenience so apps never name roots by hand: pass to
/// `SlingScope(schema: slingSchema, ...)` and `MutationBuilder` resolves its
/// root without a `root:` argument.
void _emitSlingSchema(StringBuffer out) {
  out.writeln(
    'const slingSchema = SlingSchema<Query, Mutation>(query: Query.root, mutation: Mutation.root);',
  );
}

/// `client.mutate((m) => m.toggleFavorite(launchId: id)?.favorite)` without
/// the caller having to pass `Mutation.root`.
void _emitMutateExtension(StringBuffer out) {
  out
    ..writeln('/// Typed mutations for this schema. See `SlingClient.mutateWith`.')
    ..writeln('extension SlingMutations on SlingClient<Query> {')
    ..writeln('  Future<T> mutate<T>(')
    ..writeln('    T Function(Mutation mutation) body, {')
    ..writeln('    void Function()? optimistic,')
    ..writeln('    Iterable<String>? refetchQueries,')
    ..writeln('  }) =>')
    ..writeln('      mutateWith(')
    ..writeln('        Mutation.root,')
    ..writeln('        body,')
    ..writeln('        optimistic: optimistic,')
    ..writeln('        refetchQueries: refetchQueries,')
    ..writeln('      );')
    ..writeln('}');
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
    _emitField(out, type, field, ctx);
  }
  out.writeln('}');
}

void _emitField(StringBuffer out, GqlType owner, GqlField field, _EmitContext ctx) {
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

  final scalarMapping = leaf.kind == 'SCALAR' ? ctx.registry[leaf.name!] : null;
  final elementDartType =
      leaf.kind == 'SCALAR' ? ctx.registry.dartType(leaf.name!) : sanitizeTypeName(leaf.name!);

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
  if (leaf.kind == 'SCALAR' && !ctx.registry.isKnown(leaf.name!)) {
    out.writeln('  /// Unknown custom scalar `${leaf.name}`; read as `Object?`.');
  }

  final hasArgs = field.args.isNotEmpty;
  final key = dartStringLiteral(field.name);

  // Enums are cached as their wire `String` and mapped on read; a `--scalar`
  // mapped scalar (e.g. `DateTime`) goes through the same conversion path
  // (`Accessor.scalarAs`/`scalarListAs`) with its own parse/serialize; the
  // setter writes the wire value back either way.
  final isEnum = leaf.kind == 'ENUM';
  final scalarRead = isEnum
      ? 'enumValue($key, $elementDartType.fromGraphQL'
      : scalarMapping != null
          ? 'scalarAs<$elementDartType, String>($key, ${scalarMapping.parseExpr}'
          : 'scalar<$elementDartType>($key';
  final scalarListRead = isEnum
      ? 'enumList($key, $elementDartType.fromGraphQL'
      : scalarMapping != null
          ? 'scalarListAs<$elementDartType, String>($key, ${scalarMapping.parseExpr}'
          : 'scalarList<$elementDartType>($key';
  final writeValue = isEnum
      ? 'v?.graphqlName'
      : scalarMapping != null
          ? scalarMapping.serializeCall('v', nonNull: false)
          : 'v';

  if (!hasArgs) {
    if (!isList && isScalarLeaf) {
      out.writeln("  $elementDartType? get $effectiveFieldName => $scalarRead);");
      if (!ctx.isReadOnly(owner, field)) {
        out.writeln("  set $effectiveFieldName($elementDartType? v) => write($key, $writeValue);");
      }
    } else if (isList && isScalarLeaf) {
      out.writeln("  List<$elementDartType?>? get $effectiveFieldName => $scalarListRead);");
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

  final params = _buildParamList(field.args, ctx.registry);
  final argsMap = _buildArgsMap(field.args, ctx.registry);
  if (!isList && isScalarLeaf) {
    out.writeln(
      "  $elementDartType? $effectiveFieldName($params) => $scalarRead, args: $argsMap);",
    );
  } else if (isList && isScalarLeaf) {
    out.writeln(
      "  List<$elementDartType?>? $effectiveFieldName($params) => $scalarListRead, args: $argsMap);",
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
String _buildParamList(List<GqlInputValue> args, ScalarRegistry registry) {
  final parts = <String>[];
  for (final a in args) {
    final resolved = resolveArgDartType(a.type, scalars: registry);
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
String _buildArgsMap(List<GqlInputValue> args, ScalarRegistry registry) {
  final entries = <String>[];
  for (final a in args) {
    final resolved = resolveArgDartType(a.type, scalars: registry);
    final required = resolved.nonNull && a.defaultValue == null;
    final dartName = sanitizeIdentifier(a.name);
    final valueExpr = argValueExpression(dartName, a.type, nonNull: required, scalars: registry);
    entries.add("'${a.name}': Arg('${a.type.toGraphQLLiteral()}', $valueExpr)");
  }
  return '{${entries.join(', ')}}';
}

/// A real Dart `enum` per GraphQL enum: one lowerCamelCase constant per
/// value carrying its wire name, plus `unknown` so a value added to the
/// schema after generation still decodes (forward compatibility).
void _emitEnum(StringBuffer out, GqlType type) {
  final enumName = sanitizeTypeName(type.name);
  _emitDocAndDeprecation(out, indent: '', description: type.description);
  out.writeln('enum $enumName {');
  final usedNames = <String>{};
  for (final v in type.enumValues) {
    _emitDocAndDeprecation(
      out,
      indent: '  ',
      description: v.description,
      isDeprecated: v.isDeprecated,
      deprecationReason: v.deprecationReason,
    );
    // Two wire names can camel-case to the same identifier (`FOO_BAR` and
    // `fooBar`); the later one gets the usual `$` suffix.
    var dartName = sanitizeEnumConstantName(v.name);
    while (!usedNames.add(dartName)) {
      dartName = '$dartName\$';
    }
    out.writeln('  $dartName(${dartStringLiteral(v.name)}),');
  }
  out
    ..writeln('  /// A wire value this client does not know (forward compatibility).')
    ..writeln("  unknown('');")
    ..writeln()
    ..writeln('  const $enumName(this.graphqlName);')
    ..writeln()
    ..writeln('  /// The value as spelled in the GraphQL schema.')
    ..writeln('  final String graphqlName;')
    ..writeln()
    ..writeln('  /// Maps a wire value to its constant, [unknown] when unmatched.')
    ..writeln('  static $enumName fromGraphQL(String value) =>')
    ..writeln('      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);')
    ..writeln()
    ..writeln('  /// The wire value to send as an argument; [unknown] has none.')
    ..writeln('  String toGraphQL() {')
    ..writeln('    if (this == unknown) {')
    ..writeln(
      '      throw ArgumentError.value(this, ${dartStringLiteral(enumName)}, '
      "'unknown cannot be sent as an argument');",
    )
    ..writeln('    }')
    ..writeln('    return graphqlName;')
    ..writeln('  }')
    ..writeln('}');
}

void _emitInputClass(StringBuffer out, GqlType type, ScalarRegistry registry) {
  final className = sanitizeTypeName(type.name);
  _emitDocAndDeprecation(out, indent: '', description: type.description);
  out.writeln('class $className {');

  final ctorParams = type.inputFields.map((f) => 'this.${sanitizeIdentifier(f.name)}').join(', ');
  out.writeln('  const $className({$ctorParams});');
  out.writeln();

  for (final f in type.inputFields) {
    final resolved = resolveArgDartType(f.type, scalars: registry);
    _emitDocAndDeprecation(out, indent: '  ', description: f.description);
    out.writeln('  final ${resolved.dartType}? ${sanitizeIdentifier(f.name)};');
  }

  out.writeln();
  out.writeln('  Map<String, Object?> toJson() => {');
  for (final f in type.inputFields) {
    final dartName = sanitizeIdentifier(f.name);
    final valueExpr = argValueExpression(dartName, f.type, nonNull: false, scalars: registry);
    out.writeln("    if ($dartName != null) '${f.name}': $valueExpr,");
  }
  out.writeln('  };');
  out.writeln('}');
}
