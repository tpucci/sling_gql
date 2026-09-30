/// `5,000,000` from `5000000` (and `14,750` from `14750.2`): whole numbers
/// with thousands separators, for masses and the like.
///
/// No `intl` dependency, for the same reason as `formatDate`.
String formatWhole(num value) {
  final digits = value.round().abs().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return value < 0 ? '-$grouped' : '$grouped';
}
