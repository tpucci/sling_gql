// Micro-benchmarks of the runtime hot paths using the example's generated
// schema. Not a CI test: run explicitly with
//   flutter test benchmark/bench_test.dart
// Numbers are JIT (test VM), not AOT — use them for ratios, not absolutes.
import 'dart:convert';

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
      'rocket': {'__typename': 'Rocket', 'id': 'rocket-${i % 5}', 'name': 'Rocket ${i % 5}'},
    };

Map<String, Object?> pageJson(String alias) => {
      alias: {
        '__typename': 'LaunchConnection',
        'nodes': [for (var i = 0; i < rows; i++) launchJson(i)],
        'pageInfo': {'__typename': 'PageInfo', 'hasNextPage': false, 'endCursor': 'c'},
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

Duration timeIt(int iterations, void Function() body) {
  body(); // warm-up
  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    body();
  }
  return sw.elapsed;
}

String us(Duration d, int n) => '${(d.inMicroseconds / n).toStringAsFixed(1)} µs';

void main() {
  test('bench', () async {
    final client = SlingClient<Query>(
      endpoint: Uri.parse('http://bench/graphql'),
      rootFactory: Query.root,
      httpClient: MockClient((req) async {
        final q = (jsonDecode(req.body) as Map)['query'] as String;
        if (q.startsWith('mutation')) {
          final alias = RegExp(r'(toggleFavorite_\w+):').firstMatch(q)!.group(1)!;
          return http.Response(
            jsonEncode({'data': {alias: {'__typename': 'Launch', 'id': 'launch-1', 'favorite': true}}}),
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
      final data = (jsonDecode(body) as Map<String, Object?>)['data'] as Map<String, Object?>;
      client.cache.writeResponse('query', scope.root, data);
    });

    // 3. Warm build: every read hits the cache. This is the per-frame cost.
    final warmBuild = timeIt(500, () => scope.run(readList));
    final depsCount = scope.deps.length;

    // Baseline: same reads against the decoded JSON map.
    final json = (jsonDecode(body) as Map<String, Object?>)['data'] as Map<String, Object?>;
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
    final scopes = [for (var i = 0; i < 50; i++) client.createScope(onChanged: () {})];
    for (final s in scopes) {
      s.run(readList);
    }
    final notify = timeIt(200, () {
      scope.run((q) => q.launches(first: rows)!.nodes![3].name = 'x');
    });

    // 5. Mutation round trip (mock transport, no latency).
    final mutation = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      await client.mutateWith(Mutation.root, (m) => m.toggleFavorite(launchId: 'launch-1')?.favorite);
    }
    mutation.stop();

    final report = '''
sling_gql bench — $rows rows × 7 reads/row (${rows * 7} accessor reads per build)
  skeleton build (all misses, records selection) : ${us(skeletonBuild, 200)} / build
  print document from selection tree             : ${us(printCost, 1000)}  (${printed.document.length} chars)
  jsonDecode of the ${body.length}-byte response           : ${us(decode, 50)}
  writeResponse (decode + normalize + merge)     : ${us(write, 50)}  → ${client.cache.entityKeys.length} entities
  warm build (all cache hits)                    : ${us(warmBuild, 500)} / build  → ${(warmBuild.inMicroseconds * 1000 / 500 / (rows * 7)).toStringAsFixed(0)} ns / read, $depsCount dep keys
  raw Map reads, same fields (baseline)          : ${us(rawBuild, 500)} / build
  overhead vs raw maps                           : ${(warmBuild.inMicroseconds / rawBuild.inMicroseconds).toStringAsFixed(1)}×
  optimistic write + notify 50 scopes            : ${us(notify, 200)}
  mutation round trip (mock http)                : ${us(mutation.elapsed, 20)}
''';
    // ignore: avoid_print
    print(report);
  });
}
