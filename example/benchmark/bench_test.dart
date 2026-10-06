// Micro-benchmarks of the runtime hot paths using the example's generated
// schema. Not part of `flutter test`'s default run: run explicitly with
//   flutter test benchmark/bench_test.dart
// Numbers are JIT (test VM), not AOT — use them for ratios, not absolutes.
//
// With SLING_BENCH_OUT=<dir> it also writes <dir>/read_path.json: each cost
// as a ratio to jsonDecode of the same response measured in the same run,
// so the numbers compare across machines. `node scripts/bench.mjs` (CI's bench job) checks them against
// scripts/bench-baseline.json.
//
// Measures the runtime's internals (printer, writeResponse) directly.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_example/generated/schema.dart';

const rows = 181;

Map<String, Object?> launchJson(int i) => {
  '__typename': 'Launch',
  'id': 'launch-$i',
  'name': 'Mission $i',
  'date': '2026-01-${(i % 28 + 1).toString().padLeft(2, '0')}T00:00:00.000Z',
  'status': i % 3 == 0 ? 'SUCCESS' : 'FAILURE',
  'favorite': i % 7 == 0,
  'rocket': {
    '__typename': 'Rocket',
    'id': 'rocket-${i % 5}',
    'name': 'Rocket ${i % 5}',
  },
};

Map<String, Object?> pageJson(String alias) => {
  alias: {
    '__typename': 'LaunchConnection',
    'nodes': [for (var i = 0; i < rows; i++) launchJson(i)],
    'pageInfo': {
      '__typename': 'PageInfo',
      'hasNextPage': false,
      'endCursor': 'c',
    },
    'totalCount': rows,
  },
};

/// What every list row reads (mirrors LaunchRow + the list builder).
int readList(Query q) {
  final page = q.launches(first: rows);
  var n = 0;
  for (final l in page?.nodes ?? const <Launch>[]) {
    l.isSkeleton;
    l.id;
    l.name;
    l.date;
    l.status;
    l.favorite;
    l.rocket?.name;
    n++;
  }
  page?.pageInfo?.hasNextPage;
  page?.totalCount;
  return n;
}

/// Fastest of 5 rounds of [iterations] calls, after one warm-up round (the
/// JIT and GC make single rounds swing by 2× on a laptop).
Duration timeIt(int iterations, void Function() body) {
  Duration? best;
  for (var round = 0; round < 6; round++) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      body();
    }
    sw.stop();
    if (round > 0 && (best == null || sw.elapsed < best)) best = sw.elapsed;
  }
  return best!;
}

String us(Duration d, int n) =>
    '${(d.inMicroseconds / n).toStringAsFixed(1)} µs';

void main() {
  test('bench', () async {
    final client = SlingClient<Query>(
      endpoint: Uri.parse('http://bench/graphql'),
      rootFactory: Query.root,
      httpClient: MockClient((req) async {
        final q = (jsonDecode(req.body) as Map)['query'] as String;
        if (q.startsWith('mutation')) {
          final alias = RegExp(r'(toggleFavorite_\w+):')
              .firstMatch(q)!
              .group(1)!;
          return http.Response(
            jsonEncode({
              'data': {
                alias: {
                  '__typename': 'Launch',
                  'id': 'launch-1',
                  'favorite': true,
                },
              },
            }),
            200,
          );
        }
        final alias = RegExp(r'(launches_\w+):').firstMatch(q)!.group(1)!;
        return http.Response(jsonEncode({'data': pageJson(alias)}), 200);
      }),
    );

    // 1. First build: everything misses (skeleton), records the selection.
    final scope = client.createScope(onChanged: () {});
    final skeletonBuild = timeIt(200, () => scope.run(readList));
    final printed = PrintedOperation.from(scope.root);
    final printCost = timeIt(1000, () => PrintedOperation.from(scope.root));

    // 2. Response write (normalized): 181 Launch entities + 5 Rocket entities.
    await scope.whenSettled;
    final body = jsonEncode({'data': pageJson(scope.root.childAliases.first)});
    final decode = timeIt(50, () => jsonDecode(body));
    final write = timeIt(50, () {
      final data =
          (jsonDecode(body) as Map<String, Object?>)['data']
              as Map<String, Object?>;
      client.cache.writeResponse('query', data);
    });

    // 3. Warm build: every read hits the cache. This is the per-frame cost.
    final warmBuild = timeIt(500, () => scope.run(readList));
    final depsCount = scope.deps.length;

    // Baseline: same reads against the decoded JSON map.
    final json =
        (jsonDecode(body) as Map<String, Object?>)['data']
            as Map<String, Object?>;
    final page = json.values.first as Map<String, Object?>;
    final rawBuild = timeIt(500, () {
      for (final n in page['nodes'] as List) {
        final m = n as Map;
        m['id'];
        m['name'];
        m['date'];
        m['status'];
        m['favorite'];
        (m['rocket'] as Map)['name'];
      }
    });

    // 4. Notification fan-out: 50 live scopes, one entity field written.
    final scopes = [
      for (var i = 0; i < 50; i++) client.createScope(onChanged: () {}),
    ];
    for (final s in scopes) {
      s.run(readList);
    }
    final notify = timeIt(200, () {
      scope.run((q) => q.launches(first: rows)!.nodes![3].name = 'x');
    });

    // 5. Persistence hooks: the full snapshot (deep copy of every entity).
    final snapshot = timeIt(200, () => client.cache.snapshot);
    // …versus the delta since the last persisted version, one field written.
    final persisted = client.cache.version;
    scope.run((q) => q.launches(first: rows)!.nodes![3].name = 'y');
    final delta = timeIt(200, () => client.cache.changesSince(persisted));
    final deltaSize = client.cache.changesSince(persisted).changed.length;

    // 6. Mutation round trip (mock transport, no latency).
    final mutation = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      await client.mutateWith(
        Mutation.root,
        (m) => m.toggleFavorite(launchId: 'launch-1')?.favorite,
      );
    }
    mutation.stop();

    final report =
        '''
sling_gql bench — $rows rows × 7 reads/row (${rows * 7} accessor reads per build)
  skeleton build (all misses, records selection) : ${us(skeletonBuild, 200)} / build
  print document from selection tree             : ${us(printCost, 1000)}  (${printed.document.length} chars)
  jsonDecode of the ${body.length}-byte response           : ${us(decode, 50)}
  writeResponse (decode + normalize + merge)     : ${us(write, 50)}  → ${client.cache.entityKeys.length} entities
  warm build (all cache hits)                    : ${us(warmBuild, 500)} / build  → ${(warmBuild.inMicroseconds * 1000 / 500 / (rows * 7)).toStringAsFixed(0)} ns / read, $depsCount dep keys
  raw Map reads, same fields (baseline)          : ${us(rawBuild, 500)} / build
  overhead vs raw maps                           : ${(warmBuild.inMicroseconds / rawBuild.inMicroseconds).toStringAsFixed(1)}×
  optimistic write + notify 50 scopes            : ${us(notify, 200)}
  cache.snapshot (deep copy of every entity)     : ${us(snapshot, 200)}
  cache.changesSince after one write             : ${us(delta, 200)}  ($deltaSize entity)
  mutation round trip (mock http)                : ${us(mutation.elapsed, 20)}
''';
    // ignore: avoid_print
    print(report);

    final out = Platform.environment['SLING_BENCH_OUT'];
    if (out != null) {
      double per(Duration d, int n) => d.inMicroseconds / n;
      // jsonDecode of the response: native-heavy and stable from run to
      // run, unlike the 15 µs raw-map loop (JIT-sensitive, ±30%).
      final decoded = per(decode, 50);
      File('$out/read_path.json').writeAsStringSync(
        jsonEncode({
          'read.warm_build_vs_json_decode': per(warmBuild, 500) / decoded,
          'read.skeleton_build_vs_json_decode':
              per(skeletonBuild, 200) / decoded,
          'read.print_document_vs_json_decode': per(printCost, 1000) / decoded,
          'read.notify_50_scopes_vs_json_decode': per(notify, 200) / decoded,
          'read.write_response_vs_json_decode': per(write, 50) / decoded,
          'read.snapshot_vs_json_decode': per(snapshot, 200) / decoded,
        }),
      );
    }
  });
}
