// The long soak: `test/soak_test.dart`'s workload (see
// `test/soak/soak_workload.dart`) over 2 000 iterations with bigger pages,
// printing cache size, store size and RSS every 100 iterations. Every
// per-iteration check of the short run still applies; on top, the resident
// set must stop growing once every page is cached. Not a CI test: run
// explicitly with
//   flutter test benchmark/soak_bench_test.dart
// RSS is the test VM's (JIT, host SQLite): read it as a trend, not a size.
import 'package:flutter_test/flutter_test.dart';

import '../test/soak/soak_workload.dart';

void main() {
  test('2000 screen visits', timeout: Timeout.none, () async {
    final watch = Stopwatch()..start();
    final report = await runSoak(
      iterations: 2000,
      pageSize: 25,
      pages: 4,
      flushEvery: 20,
      onSample: (sample) {
        if (sample.iteration % 100 == 99) {
          // ignore: avoid_print
          print('${watch.elapsed.inSeconds}s $sample');
        }
      },
    );
    // ignore: avoid_print
    print('requests: ${report.requests}, reloaded ${report.reloadedEntities}');
    int medianRss(Iterable<SoakSample> samples) =>
        (samples.map((s) => s.rss).toList()..sort())[samples.length ~/ 2];
    final warm = medianRss(report.samples.skip(200).take(100));
    final end = medianRss(report.samples.skip(1900));
    const mb = 1 << 20;
    // ignore: avoid_print
    print('rss: ${warm ~/ mb} MB at #200-300, ${end ~/ mb} MB at #1900-2000');
    expect(end - warm, lessThan(64 * mb), reason: 'RSS keeps growing');
  });
}
