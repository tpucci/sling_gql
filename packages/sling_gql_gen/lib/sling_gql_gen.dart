/// Code generator: turns a GraphQL introspection JSON document into
/// `sling_gql`-compatible typed `Accessor` classes.
library;

export 'src/emitter.dart' show generate;
export 'src/naming.dart';
export 'src/scalars.dart';
export 'src/schema.dart';
export 'src/type_ref.dart';
export 'src/type_resolver.dart';
export 'src/introspection_query.dart';
