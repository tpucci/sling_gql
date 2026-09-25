/// Maps a GraphQL scalar name to the Dart type used to read/write it.
///
/// The built-in scalars map to their obvious Dart equivalents. A few known
/// custom scalars that are ISO date strings on this API map to `String`.
/// Every other (truly unknown) custom scalar maps to `Object`, since we
/// cannot know its JSON shape from the schema alone — see [isKnownScalar].
///
/// This is the *default*; a `--scalar` CLI flag overrides it per scalar name
/// via [ScalarMapping]/[ScalarRegistry].
String scalarDartType(String graphqlScalarName) {
  switch (graphqlScalarName) {
    case 'String':
    case 'ID':
      return 'String';
    case 'Int':
      return 'int';
    case 'Float':
      return 'double';
    case 'Boolean':
      return 'bool';
  }
  if (_stringlikeCustomScalars.contains(graphqlScalarName)) return 'String';
  return 'Object';
}

/// True when [graphqlScalarName] is a built-in scalar or one of the custom
/// scalars this generator knows to be a plain string. False for unknown
/// custom scalars (mapped to `Object` by [scalarDartType]).
bool isKnownScalar(String graphqlScalarName) {
  const builtIns = {'String', 'ID', 'Int', 'Float', 'Boolean'};
  return builtIns.contains(graphqlScalarName) ||
      _stringlikeCustomScalars.contains(graphqlScalarName);
}

/// Custom scalars known to be serialized as ISO strings on this API.
const Set<String> _stringlikeCustomScalars = {'Date', 'DateTime', 'timestamptz'};

/// A `--scalar Name=DartType[:converterExpr]` mapping: reads/writes the
/// GraphQL scalar [graphqlName] as [dartType] instead of the [scalarDartType]
/// default, going through [Accessor.scalarAs]/[Accessor.scalarListAs] so
/// misses, skeletons and dependency tracking are unaffected — only the
/// getter's return type and the read/write conversion change.
///
/// The wire form is always assumed to be a JSON string (true of every scalar
/// this generator has seen: ISO date-times, big decimals, opaque ids, ...).
///
/// Two forms:
/// - **Built-in**: `dartType == 'DateTime'` and no [converter] — uses
///   `DateTime.parse` to read and `.toIso8601String()` to write.
/// - **Generic**: [converter] names a class with static `T parse(String)`
///   and `String serialize(T)` methods, e.g. `MoneyConverter` for
///   `--scalar Money=Decimal:MoneyConverter`.
class ScalarMapping {
  const ScalarMapping(this.graphqlName, this.dartType, {this.converter});

  final String graphqlName;
  final String dartType;
  final String? converter;

  /// Parses `Name=DartType[:converterExpr]`. Throws [FormatException] on a
  /// malformed flag, or when [dartType] isn't `DateTime` and no [converter]
  /// is given (the generator has no way to guess how to (de)serialize an
  /// arbitrary Dart type without one).
  factory ScalarMapping.parseFlag(String raw) {
    final eq = raw.indexOf('=');
    if (eq <= 0 || eq == raw.length - 1) {
      throw FormatException(
        '--scalar must look like Name=DartType[:converterExpr], got "$raw"',
      );
    }
    final name = raw.substring(0, eq);
    final rest = raw.substring(eq + 1);
    final colon = rest.indexOf(':');
    final dartType = colon == -1 ? rest : rest.substring(0, colon);
    final converter = colon == -1 ? null : rest.substring(colon + 1);
    if (dartType.isEmpty) {
      throw FormatException('--scalar $raw: DartType must not be empty');
    }
    if (converter != null && converter.isEmpty) {
      throw FormatException('--scalar $raw: converterExpr must not be empty if given');
    }
    if (converter == null && dartType != 'DateTime') {
      throw FormatException(
        '--scalar $raw: a converter is required unless DartType is DateTime '
        '(the built-in DateTime.parse/toIso8601String converter)',
      );
    }
    return ScalarMapping(name, dartType, converter: converter);
  }

  /// A `T Function(String)` tear-off expression for the generated getter.
  String get parseExpr => converter != null ? '$converter.parse' : 'DateTime.parse';

  /// The wire-form (String) expression for a value of [dartType] held in
  /// [dartExpr], or `null` if the emitted code already established
  /// [dartExpr] cannot be null (`nonNull: true`).
  String serializeCall(String dartExpr, {required bool nonNull}) {
    if (converter == null) {
      return nonNull ? '$dartExpr.toIso8601String()' : '$dartExpr?.toIso8601String()';
    }
    final call = '$converter.serialize($dartExpr)';
    return nonNull ? call : '($dartExpr == null ? null : $call)';
  }
}

/// The full set of `--scalar` mappings for one generator run, keyed by
/// GraphQL scalar name. Falls back to [scalarDartType]/[isKnownScalar] for
/// any scalar without an explicit mapping.
class ScalarRegistry {
  ScalarRegistry(Iterable<ScalarMapping> mappings)
      : _byName = {for (final m in mappings) m.graphqlName: m};

  /// No `--scalar` flags: every scalar uses the [scalarDartType] default.
  static final ScalarRegistry empty = ScalarRegistry(const []);

  final Map<String, ScalarMapping> _byName;

  /// The mapping for [graphqlName], or `null` if it uses the default.
  ScalarMapping? operator [](String graphqlName) => _byName[graphqlName];

  /// The Dart type [graphqlName] is read/written as.
  String dartType(String graphqlName) => _byName[graphqlName]?.dartType ?? scalarDartType(graphqlName);

  /// True when [graphqlName] has an explicit `--scalar` mapping or is one of
  /// the built-in/known-string scalars (see [isKnownScalar]).
  bool isKnown(String graphqlName) => _byName.containsKey(graphqlName) || isKnownScalar(graphqlName);
}
