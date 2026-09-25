/// Name sanitization for generated identifiers.
///
/// GraphQL names are much more permissive than Dart identifiers: they can be
/// Dart keywords (`type`, `class`), can collide with [Accessor] members
/// (`selection`, `write`), or can start with `_` (which makes them library
/// -private in Dart, e.g. Hasura's `_eq`/`_and` comparison operators). This
/// module maps GraphQL names to safe Dart identifiers while the original
/// GraphQL name is always kept as the string literal used for cache keys,
/// `Arg` map keys and `toJson` keys.
library;

/// Dart keywords (reserved, built-in, and contextual enough to be unsafe)
/// that would either fail to parse or shadow language constructs if used as
/// an identifier.
const Set<String> dartKeywords = {
  'is', 'in', 'default', 'new', 'switch', 'case', 'do', 'if', 'else', 'for',
  'while', 'return', 'void', 'var', 'final', 'const', 'this', 'super', 'null',
  'true', 'false', 'with', 'enum', 'extends', 'implements', 'import', 'export',
  'library', 'part', 'static', 'assert', 'break', 'continue', 'catch', 'try',
  'finally', 'throw', 'rethrow', 'abstract', 'as', 'async', 'await', 'yield',
  'get', 'set', 'operator', 'factory', 'external', 'typedef', 'dynamic',
  'covariant', 'deferred', 'late', 'required', 'mixin', 'on', 'show', 'hide',
  'sync', 'interface', 'extension', 'base', 'sealed', 'when', 'of', 'class',
  'type',
};

/// [dartKeywords] plus `Accessor` instance members (and dart:core `Object`
/// members it inherits) that a generated getter/method must not clash with.
const Set<String> dartReservedAndAccessorMembers = {
  ...dartKeywords,
  'recorder', 'selection', 'path', 'isSkeleton', 'scalar', 'scalarList',
  'enumValue', 'enumList', 'object', 'list', 'write', 'hashCode',
  'runtimeType', 'toString', 'noSuchMethod', 'toJson',
};

/// [dartKeywords] plus the members every generated `enum` already has
/// (`Enum`/`Object` members, the generated `unknown` constant, `graphqlName`,
/// `fromGraphQL`, `toGraphQL`) that an enum constant must not clash with.
const Set<String> dartReservedAndEnumMembers = {
  ...dartKeywords,
  'unknown', 'values', 'index', 'name', 'graphqlName', 'fromGraphQL',
  'toGraphQL', 'byName', 'compareTo', 'hashCode', 'runtimeType', 'toString',
  'noSuchMethod',
};

/// Type names that would collide with dart:core or sling_gql runtime types
/// if used verbatim as a generated class name.
const Set<String> dartCoreOrRuntimeTypeNames = {
  'Object', 'String', 'List', 'Map', 'Cache', 'Accessor', 'Selection', 'Arg',
  'Recorder',
};

/// Sanitizes a GraphQL field/argument/enum-value name into a safe Dart
/// identifier suitable for a getter, setter, method, parameter or constant.
///
/// - A leading `_` (Hasura-style `_eq`, `_and`, `_service`) is replaced with
///   `$` so the name stays public: `_eq` -> `$eq`.
/// - Dart keywords and `Accessor` member names get a trailing `$`:
///   `type` -> `type$`, `class` -> `class$`.
String sanitizeIdentifier(String name) {
  var out = name;
  if (out.startsWith('_')) {
    out = '\$${out.replaceFirst(RegExp('^_+'), '')}';
  }
  if (dartReservedAndAccessorMembers.contains(out)) {
    out = '$out\$';
  }
  return out;
}

/// Sanitizes a GraphQL enum value name into a lowerCamelCase Dart enum
/// constant name.
///
/// - `SCHEDULED` -> `scheduled`, `PARTIAL_FAILURE` -> `partialFailure`,
///   `created_at` -> `createdAt`, `dateAsc` -> `dateAsc`.
/// - A leading `_` is replaced with `$` (as in [sanitizeIdentifier]) so the
///   constant stays public: `_internal` -> `$internal`.
/// - Dart keywords and names an enum already has (`unknown`, `values`,
///   `index`, `name`, …) get a trailing `$`: `default` -> `default$`,
///   `UNKNOWN` -> `unknown$`.
String sanitizeEnumConstantName(String name) {
  final leadingUnderscore = name.startsWith('_');
  final trimmed = name.replaceFirst(RegExp('^_+'), '');
  // All-caps wire names (`PARTIAL_FAILURE`) are lowercased before splitting;
  // mixed-case ones (`dateAsc`) keep their inner capitals.
  final normalized = trimmed.toUpperCase() == trimmed ? trimmed.toLowerCase() : trimmed;
  final words = normalized.split('_').where((w) => w.isNotEmpty).toList();
  final buffer = StringBuffer();
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    buffer.write(i == 0
        ? word[0].toLowerCase() + word.substring(1)
        : word[0].toUpperCase() + word.substring(1));
  }
  var out = buffer.toString();
  if (leadingUnderscore || out.isEmpty || RegExp('^[0-9]').hasMatch(out)) {
    out = '\$$out';
  }
  if (dartReservedAndEnumMembers.contains(out)) {
    out = '$out\$';
  }
  return out;
}

/// Sanitizes a GraphQL type name (object/input/enum) into a safe, public
/// Dart class name. GraphQL casing (including snake_case) is otherwise
/// preserved.
String sanitizeTypeName(String name) {
  var out = name;
  if (out.startsWith('_')) {
    // A leading `_` makes a Dart top-level declaration library-private
    // (e.g. federation's `_Service` type); replace it so the class stays
    // usable from the generated file's public API.
    out = '\$${out.replaceFirst(RegExp('^_+'), '')}';
  }
  if (dartCoreOrRuntimeTypeNames.contains(out)) {
    out = '$out\$';
  }
  return out;
}

/// Escapes a string for embedding in a single-quoted Dart string literal.
String dartStringLiteral(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}

/// Formats a GraphQL description as one or more `///` doc-comment lines.
List<String> docCommentLines(String description) {
  return description.split('\n').map((line) => '/// $line'.trimRight()).toList();
}
