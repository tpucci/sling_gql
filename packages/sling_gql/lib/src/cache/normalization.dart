import '../selection.dart';

/// How objects are identified for normalization.
///
/// The generator marks fields returning a type that has a [keyField] as
/// `keyed`, which makes the selection always fetch that field. On write, any
/// object for which [identify] returns a key is stored once in the entity map
/// and referenced from wherever it appeared. Objects without a key (`PageInfo`,
/// `Stats`, …) are stored inline in their parent, as before.
class Normalization {
  const Normalization({
    this.keyField = 'id',
    String? Function(Map<String, Object?> object)? identify,
  }) : _identify = identify; // ignore: prefer_initializing_formals

  /// Disables normalization: everything is stored inline, path-addressed.
  static const none = Normalization(keyField: '', identify: _never);

  /// Field automatically added to every keyed object selection and used by the
  /// default identity (`__typename:<keyField>`).
  final String keyField;

  final String? Function(Map<String, Object?> object)? _identify;

  bool get enabled => keyField.isNotEmpty || _identify != null;

  /// The field to add to keyed selections, or `null` when nothing is needed.
  String? get selectedKeyField => keyField.isEmpty ? null : keyField;

  /// Returns the entity key for a response object, or `null` to keep it
  /// inline.
  String? identify(Map<String, Object?> object) {
    if (_identify != null) return _identify(object);
    final typename = object['__typename'];
    final id = object[keyField];
    if (typename is! String || id == null) return null;
    return '$typename:$id';
  }

  /// Entity key a `lookup` field points at, e.g. `launch(id: "x")` →
  /// `Launch:x`. Returns `null` when the arguments do not carry the key.
  String? lookup(String typename, Map<String, Arg> args) {
    if (!enabled) return null;
    final id = args[keyField]?.value;
    if (id == null) return null;
    return '$typename:$id';
  }

  static String? _never(Map<String, Object?> _) => null;
}
