/// Maps a GraphQL scalar name to the Dart type used to read/write it.
///
/// The built-in scalars map to their obvious Dart equivalents. A few known
/// custom scalars that are ISO date strings on this API map to `String`.
/// Every other (truly unknown) custom scalar maps to `Object`, since we
/// cannot know its JSON shape from the schema alone — see [isKnownScalar].
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
