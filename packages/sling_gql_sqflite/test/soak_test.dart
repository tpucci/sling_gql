import 'package:flutter_test/flutter_test.dart';

import 'soak/soak_workload.dart';

/// A short soak on the large generated schema (`soak/soak_schema.dart`):
/// many scopes and rows, batching, mutations, subscriptions, `gc` and
/// SQLite persistence over many iterations, with the cache, the store and
/// the client's scopes checked after each one (see `runSoak`). The long run
/// is `benchmark/soak_bench_test.dart`.
void main() {
  test('40 screen visits: bounded cache and store, nothing leaked', () async {
    final report = await runSoak(iterations: 40);
    expect(report.requests, {'query': 40, 'mutation': 40, 'subscription': 40});
    final first = report.samples[2]; // every page cached once
    final last = report.samples.last;
    expect(last.entities, first.entities, reason: 'steady state');
    expect(last.rootFields, first.rootFields);
    expect(report.reloadedEntities, last.entities);
  });
}
