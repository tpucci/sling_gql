import 'naming.dart';
import 'scalars.dart';
import 'type_ref.dart';

/// Recursively resolves a [TypeRef] (as used for arguments and input-object
/// fields) to a Dart type expression, honoring `NON_NULL` at every nesting
/// level: `[users_select_column!]` -> `List<String>` (non-null elements),
/// `LaunchFind` -> `LaunchFind`.
///
/// The outermost `NON_NULL` wrapper is reported via [ResolvedDartType.nonNull]
/// rather than baked into the type string, so callers can choose between
/// `required T name` and `T? name`.
ResolvedDartType resolveArgDartType(TypeRef ref) {
  if (ref.kind == 'NON_NULL') {
    final inner = resolveArgDartType(ref.ofType!);
    return ResolvedDartType(inner.dartType, true);
  }
  if (ref.kind == 'LIST') {
    final inner = resolveArgDartType(ref.ofType!);
    final elementType = inner.nonNull ? inner.dartType : '${inner.dartType}?';
    return ResolvedDartType('List<$elementType>', false);
  }
  switch (ref.kind) {
    case 'SCALAR':
      return ResolvedDartType(scalarDartType(ref.name!), false);
    case 'ENUM':
      // PoC simplification: enums are read/written as their string value.
      return ResolvedDartType('String', false);
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
/// input objects call `.toJson()` (recursively for lists), everything else
/// passes through unchanged.
///
/// [nonNull] must match the `nonNull` used to decide whether [dartExpr]
/// itself can be null (i.e. whether `?.` is needed to reach `.toJson()`).
String argValueExpression(String dartExpr, TypeRef ref, {required bool nonNull}) {
  final unwrapped = ref.withoutTopNonNull;
  if (unwrapped.kind == 'LIST') {
    final elementRef = unwrapped.ofType!;
    final elementNamed = elementRef.named;
    if (elementNamed.kind == 'INPUT_OBJECT') {
      final listAccessor = nonNull ? '.' : '?.';
      final elementAccessor = elementRef.isNonNull ? '.' : '?.';
      return '$dartExpr$listAccessor'
          'map((e) => e${elementAccessor}toJson()).toList()';
    }
    return dartExpr;
  }
  final named = unwrapped.named;
  if (named.kind == 'INPUT_OBJECT') {
    final accessor = nonNull ? '.' : '?.';
    return '$dartExpr${accessor}toJson()';
  }
  return dartExpr;
}
