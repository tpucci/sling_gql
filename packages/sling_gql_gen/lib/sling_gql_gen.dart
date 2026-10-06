/// Code generator: turns a GraphQL introspection JSON document into
/// `sling_gql`-compatible typed `Accessor` classes.
library;

export 'src/emitter.dart' show generate, generatedCodeHash;
export 'src/introspection_query.dart' show introspectionQuery;
export 'src/scalars.dart' show ScalarMapping;
export 'src/schema.dart'
    show IntrospectionSchema, GqlType, GqlField, GqlInputValue, GqlEnumValue;
export 'src/type_ref.dart' show TypeRef;
