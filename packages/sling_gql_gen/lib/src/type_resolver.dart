import 'naming.dart';
import 'scalars.dart';
import 'type_ref.dart';

/// Recursively resolves a [TypeRef] (as used for arguments and input-object
/// fields) to a Dart type expression, honoring `NON_NULL` at every nesting
/// level: `[users_select_column!]` -> `List<String>` (non-null elements),
/// `LaunchFind` -> `LaunchFind`, `LaunchStatus` (enum) -> `LaunchStatus`.
///
/// The outermost `NON_NULL` wrapper is reported via [ResolvedDartType.nonNull]
/// rather than baked into the type string, so callers can choose between
/// `required T name` and `T? name`.
///
/// [scalars] resolves a `SCALAR` leaf's Dart type; defaults to
/// [ScalarRegistry.empty] (every scalar uses [scalarDartType]).
ResolvedDartType resolveArgDartType(TypeRef ref, {ScalarRegistry? scalars}) {
  final registry = scalars ?? ScalarRegistry.empty;
  if (ref.kind == 'NON_NULL') {
    final inner = resolveArgDartType(ref.ofType!, scalars: registry);
    return ResolvedDartType(inner.dartType, true);
  }
  if (ref.kind == 'LIST') {
    final inner = resolveArgDartType(ref.ofType!, scalars: registry);
    final elementType = inner.nonNull ? inner.dartType : '${inner.dartType}?';
    return ResolvedDartType('List<$elementType>', false);
  }
  switch (ref.kind) {
    case 'SCALAR':
      return ResolvedDartType(registry.dartType(ref.name!), false);
    case 'ENUM':
    case 'INPUT_OBJECT':
    case 'OBJECT':
    case 'INTERFACE':
    case 'UNION':
      return ResolvedDartType(sanitizeTypeName(ref.name!), false);
    default:
      return const ResolvedDartType('Object', false);
  }
}

/// Builds the Dart expression that serializes [dartExpr] (a value of the
/// resolved Dart type for [ref]) for use as an `Arg` value / `toJson` entry:
/// input objects call `.toJson()`, enums call `.toGraphQL()`, a `--scalar`
/// mapped scalar goes through its converter (both recursively for lists),
/// everything else passes through unchanged.
///
/// [nonNull] must match the `nonNull` used to decide whether [dartExpr]
/// itself can be null (i.e. whether `?.` is needed to reach the serializer).
String argValueExpression(
  String dartExpr,
  TypeRef ref, {
  required bool nonNull,
  ScalarRegistry? scalars,
}) {
  final registry = scalars ?? ScalarRegistry.empty;
  final unwrapped = ref.withoutTopNonNull;
  if (unwrapped.kind == 'LIST') {
    final elementRef = unwrapped.ofType!;
    final wire = _wireExpression('e', elementRef.named, nonNull: elementRef.isNonNull, registry: registry);
    if (wire == null) return dartExpr;
    final listAccessor = nonNull ? '.' : '?.';
    return '$dartExpr${listAccessor}map((e) => $wire).toList()';
  }
  final wire = _wireExpression(dartExpr, unwrapped.named, nonNull: nonNull, registry: registry);
  return wire ?? dartExpr;
}

/// The wire-form expression for a single value [expr] of the named type
/// [namedRef], or `null` when it passes through unchanged (built-in
/// scalars, unmapped custom scalars, objects/interfaces/unions).
String? _wireExpression(
  String expr,
  TypeRef namedRef, {
  required bool nonNull,
  required ScalarRegistry registry,
}) {
  switch (namedRef.kind) {
    case 'INPUT_OBJECT':
      return nonNull ? '$expr.toJson()' : '$expr?.toJson()';
    case 'ENUM':
      return nonNull ? '$expr.toGraphQL()' : '$expr?.toGraphQL()';
    case 'SCALAR':
      final mapping = registry[namedRef.name!];
      if (mapping == null) return null;
      return mapping.serializeCall(expr, nonNull: nonNull);
    default:
      return null;
  }
}
