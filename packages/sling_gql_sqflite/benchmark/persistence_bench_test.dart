// Open/hydrate and delta-save timings of SqflitePersistence at 1k and 10k
// entities (~600 B of JSON each), on the host through sqflite_common_ffi.
// Not a CI test: run explicitly with
//   flutter test benchmark/persistence_bench_test.dart
// Numbers are JIT (test VM) on the host's SQLite, not a device: use them for
// orders of magnitude.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_sqflite/sling_gql_sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _schema = SlingSchema<Accessor, Accessor>(
  query: _Root.new,
  hash: 'bench',
);

class _Root extends Accessor {
  _Root(Recorder r) : super(r, r.root, const []);
}

Map<String, Object?> _launch(int i, {String name = 'Mission'}) => {
  '__typename': 'Launch',
  'id': 'launch-$i',
  'name': '$name $i',
  'date': '2026-01-${(i % 28 + 1).toString().padLeft(2, '0')}T00:00:00.000Z',
  'status': i % 3 == 0 ? 'SUCCESS' : 'FAILURE',
  'favorite': i % 7 == 0,
  'details':
      'Launch $i carried a payload to a low orbit and returned the booster '
      'to the landing pad; the second stage performed a deorbit burn after '
      'deploying every satellite of the batch. Weather was nominal.',
  'rocket': {
    '__typename': 'Rocket',
    'id': 'rocket-${i % 5}',
    'name': 'Rocket ${i % 5}',
  },
  'links': [
    {'__typename': 'Link', 'kind': 'webcast', 'url': 'https://x.test/$i/w'},
    {'__typename': 'Link', 'kind': 'article', 'url': 'https://x.test/$i/a'},
  ],
};

/// [entities] launches in pages of 50, one root field per page.
Map<String, Object?> _pages(int entities, {String name = 'Mission'}) => {
  for (var page = 0; page * 50 < entities; page++)
    'launches_$page': {
      '__typename': 'LaunchConnection',
      'nodes': [
        for (var i = page * 50; i < (page + 1) * 50 && i < entities; i++)
          _launch(i, name: name),
      ],
      'totalCount': entities,
    },
};

Duration _median(List<Duration> times) =>
    (List.of(times)..sort())[times.length ~/ 2];

String _ms(Duration d) => (d.inMicroseconds / 1000).toStringAsFixed(2);

void main() {
  for (final n in [1000, 10000]) {
    test('$n entities', () async {
      final dir = Directory.systemTemp.createTempSync('sling_bench_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/bench.db';

      Future<SqflitePersistence> open({bool isolate = false}) =>
          SqflitePersistence.open(
            path,
            schema: _schema,
            databaseFactory: databaseFactoryFfi,
            maxEntities: null,
            flushOnLifecycle: false,
            debounce: const Duration(hours: 1),
            hydrateInIsolate: isolate,
          );

      var p = await open();
      // ignore: invalid_use_of_internal_member
      p.cache.writeResponse('query', _pages(n));
      final json = jsonEncode(p.cache.snapshot).length;
      var watch = Stopwatch()..start();
      await p.flush();
      final firstSave = watch.elapsed;
      await p.close();

      // Warm-up open (JIT), then measured ones.
      await (await open()).close();
      p = await open();
      final main = p.loaded;
      await p.close();
      p = await open(isolate: true);
      final isolate = p.loaded;
      expect(p.loaded.entities, n + 5); // + 5 rockets

      // A response changing 20 launches, five times (median reported).
      final changesSinceTimes = <Duration>[];
      final saveTimes = <Duration>[];
      var changed = 0;
      for (var round = 0; round < 5; round++) {
        // ignore: invalid_use_of_internal_member
        p.cache.writeResponse('query', {
          'launches_0': {
            '__typename': 'LaunchConnection',
            'nodes': [
              for (var i = 0; i < 20; i++) _launch(i, name: 'Changed $round'),
            ],
            'totalCount': n,
          },
        });
        watch = Stopwatch()..start();
        changed = p.cache.changesSince(p.savedVersion).changed.length;
        changesSinceTimes.add(watch.elapsed);
        watch = Stopwatch()..start();
        await p.flush();
        saveTimes.add(watch.elapsed);
      }
      final changesSince = _median(changesSinceTimes);
      final deltaSave = _median(saveTimes);
      await p.close();

      // ignore: avoid_print
      print(
        '$n entities, ${(json / 1024 / 1024).toStringAsFixed(1)} MB JSON: '
        'first save ${_ms(firstSave)} ms; open main isolate: read '
        '${_ms(main.readTime)} + hydrate ${_ms(main.hydrateTime)} ms; '
        'open hydrateInIsolate: read ${_ms(isolate.readTime)} + hydrate '
        '${_ms(isolate.hydrateTime)} ms; delta of $changed '
        'entities: changesSince ${_ms(changesSince)} ms, save '
        '${_ms(deltaSave)} ms',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
