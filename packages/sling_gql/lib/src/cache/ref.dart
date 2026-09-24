/// Sentinel returned by `Cache.read` when a path does not exist.
///
/// Distinguishes "the server said null" (a real `null` stored in the cache)
/// from "we never fetched this" (a cache miss → skeleton state).
const missing = _Missing();

class _Missing {
  const _Missing();
  @override
  String toString() => '<missing>';
}

/// A reference to a normalized entity, stored in place of the object itself.
///
/// Entity keys look like `Launch:launch-181` (`__typename:id`, see
/// `Normalization.identify`). A [Ref] may also be used as the first element
/// of a read/write path to address an entity directly instead of walking
/// from the operation root.
///
/// Serialized as `{"__ref": "<key>"}` in `Cache.snapshot`.
final class Ref {
  const Ref(this.key);

  final String key;

  static const jsonKey = '__ref';

  Map<String, Object?> toJson() => {jsonKey: key};

  static Ref? tryParse(Object? json) {
    if (json is Map && json.length == 1 && json[jsonKey] is String) {
      return Ref(json[jsonKey] as String);
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is Ref && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'Ref($key)';
}
