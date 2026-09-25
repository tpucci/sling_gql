/// `2024-01-02` from a [DateTime] — the launch list/detail screens only ever
/// show the calendar date, never the time.
///
/// No `intl` dependency: the runtime stays `http`-only and this is the only
/// place the example formats a date, so a couple of `padLeft` calls are
/// simpler than a new dependency.
String formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
