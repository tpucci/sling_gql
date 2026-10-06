/// The soak workload shared by `test/soak_test.dart` (a short run, in CI)
/// and `benchmark/soak_bench_test.dart` (a long one, by hand): a client on
/// the large generated schema in `soak_schema.dart` (150 keyed types, see
/// `packages/sling_gql_gen/test/soak/soak_introspection.dart`), persisted
/// to SQLite, through many "screen visits".
///
/// One iteration opens a screen per [_screens] entry plus a union and an
/// interface read, all in one microtask, with rows on the first list; waits
/// for the one batched request; reads an entity through a lookup (no
/// request); renames one row's entity with a mutation (only that row
/// rebuilds); receives one subscription event; disposes everything; runs
/// `client.gc()`. Every page refetch answers new ids (a new server
/// generation), so whatever a disposed scope still pinned would pile up.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_sqflite/sling_gql_sqflite.dart';
import 'package:sling_gql_test/sling_gql_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'soak_schema.dart';

/// One sample, taken after an iteration's `gc`.
class SoakSample {
  SoakSample({
    required this.iteration,
    required this.entities,
    required this.rootFields,
    required this.storedEntities,
    required this.storedRootFields,
    required this.rss,
  });

  final int iteration;

  /// Entities in the cache (operation roots excluded).
  final int entities;

  /// `ROOT_QUERY` fields in the cache.
  final int rootFields;

  /// Rows in SQLite after the last flush (`null` between flushes).
  final int? storedEntities;
  final int? storedRootFields;

  /// Resident set size of the test process, bytes.
  final int rss;

  @override
  String toString() =>
      '#$iteration: $entities entities, $rootFields root fields, '
      'stored ${storedEntities ?? '-'}/${storedRootFields ?? '-'}, '
      'rss ${(rss / (1 << 20)).toStringAsFixed(1)} MB';
}

class SoakReport {
  SoakReport(this.samples, this.requests, this.reloadedEntities);

  final List<SoakSample> samples;

  /// Requests the server answered, by type (`query`, `mutation`,
  /// `subscription`).
  final Map<String, int> requests;

  /// Entities the store held when reopened at the end.
  final int reloadedEntities;
}

/// The data behind the soak schema. Pages answer ids of the current
/// [generation]; `next` and `related` are resolved lazily per selection.
class SoakServer {
  SoakServer({required this.pageSize});

  final int pageSize;
  int generation = 0;
  final Map<String, String> _names = {};
  final StreamController<Object?> nodeChanged = StreamController.broadcast();

  static String _two(int k) => k.toString().padLeft(2, '0');
  static String thingName(int k) => 'Thing${k.toString().padLeft(3, '0')}';

  Map<String, Object?> thing(int k, String id) => {
    '__typename': thingName(k),
    'id': id,
    'name': _names[id] ?? 'name $id',
    'rank': id.length,
    'score': id.length / 2,
    'active': id.length.isEven,
    'state': 'ACTIVE',
    'tags': ['soak', 'gen'],
    'detail': {'__typename': 'Detail${_two(k % 15)}', 'label': 'label $id'},
    'next': (Map<String, Object?> _) => thing((k + 1) % 150, '$id.n'),
    'related': (Map<String, Object?> args) => [
      for (var r = 0; r < (args['first'] as int? ?? 3); r++)
        thing((k + 7) % 150, '$id.r$r'),
    ],
  };

  List<Map<String, Object?>> page(int k, int page) => [
    for (var i = 0; i < pageSize; i++) thing(k, 't$k-p$page-g$generation-$i'),
  ];

  late final MockGraphQLServer server = MockGraphQLServer(
    query: {
      for (var k = 0; k < _screens.length; k++)
        'things${k.toString().padLeft(3, '0')}': (Map<String, Object?> args) =>
            page(k, args['page']! as int),
      'thing003': (Map<String, Object?> args) =>
          thing(3, args['id']! as String),
      'node': (Map<String, Object?> args) => thing(0, args['id']! as String),
      'group0': (Map<String, Object?> _) => [
        thing(0, 'g0-a-g$generation'),
        thing(10, 'g0-b-g$generation'),
      ],
    },
    mutation: {
      'rename000': (Map<String, Object?> args) {
        final id = args['id']! as String;
        _names[id] = args['name']! as String;
        return thing(0, id);
      },
    },
    subscription: {
      'nodeChanged': (Map<String, Object?> _) => nodeChanged.stream,
    },
  );
}

String _row(
  String? id,
  String? name,
  int? rank,
  Object? state,
  String? label,
  String? next,
  Iterable<String?>? related,
) => '$id $name $rank $state $label $next ${related?.join(',')}';

/// One list screen per keyed type it reads; each reads most fields of the
/// type, an inline object, a keyed reference and a keyed list with args.
final List<List<String> Function(Query q, int page)> _screens = [
  (q, p) => [
    for (final t in q.things000(page: p) ?? const <Thing000>[])
      _row(t.id, t.name, t.rank, t.state, t.detail?.label, t.next?.name, [
        for (final r in t.related(first: 2) ?? const <Thing007>[]) r.name,
      ]),
  ],
  (q, p) => [
    for (final t in q.things001(page: p) ?? const <Thing001>[])
      _row(t.id, t.name, t.rank, t.state, t.detail?.label, t.next?.name, [
        for (final r in t.related(first: 2) ?? const <Thing008>[]) r.name,
      ]),
  ],
  (q, p) => [
    for (final t in q.things002(page: p) ?? const <Thing002>[])
      _row(t.id, t.name, t.rank, t.state, t.detail?.label, t.next?.name, [
        for (final r in t.related(first: 2) ?? const <Thing009>[]) r.name,
      ]),
  ],
  (q, p) => [
    for (final t in q.things003(page: p) ?? const <Thing003>[])
      _row(t.id, t.name, t.rank, t.state, t.detail?.label, t.next?.name, [
        for (final r in t.related(first: 2) ?? const <Thing010>[]) r.name,
      ]),
  ],
  (q, p) => [
    for (final t in q.things004(page: p) ?? const <Thing004>[])
      _row(t.id, t.name, t.rank, t.state, t.detail?.label, t.next?.name, [
        for (final r in t.related(first: 2) ?? const <Thing011>[]) r.name,
      ]),
  ],
  (q, p) => [
    for (final t in q.things005(page: p) ?? const <Thing005>[])
      _row(t.id, t.name, t.rank, t.state, t.detail?.label, t.next?.name, [
        for (final r in t.related(first: 2) ?? const <Thing012>[]) r.name,
      ]),
  ],
];

/// Entities one cached list item brings: itself, `next`, two `related`.
const _entitiesPerItem = 4;

/// Runs [iterations] screen visits over [pages] pages of [pageSize] items
/// and checks, after every one, that the cache and the store hold no more
/// than the pages currently cached, that nothing a disposed scope or row
/// read is retained, and that no disposed scope or row is notified.
/// [onSample] sees every sample (the benchmark prints them).
Future<SoakReport> runSoak({
  required int iterations,
  int pageSize = 10,
  int pages = 3,
  int flushEvery = 5,
  void Function(SoakSample sample)? onSample,
}) async {
  final dir = Directory.systemTemp.createTempSync('sling_soak_');
  final path = '${dir.path}/soak.db';
  Future<SqflitePersistence> open() => SqflitePersistence.open(
    path,
    schema: slingSchema,
    databaseFactory: databaseFactoryFfi,
    maxEntities: null,
    flushOnLifecycle: false,
    debounce: const Duration(hours: 1),
    maxWait: const Duration(hours: 1),
  );
  final persistence = await open();
  final soak = SoakServer(pageSize: pageSize);
  final server = soak.server;
  final client = SlingClient<Query>(
    endpoint: Uri.parse('http://soak/graphql'),
    schema: slingSchema,
    cache: persistence.cache,
    httpClient: server.httpClient,
    subscriptionTransport: server.subscriptionTransport,
    gcAfterWrites: 7,
  );
  final cache = client.cache;

  // Reachable at most: every (screen, page) list, the union's two things
  // and the lookup / mutation / subscription entities of one iteration.
  final maxEntities = _screens.length * pages * pageSize * _entitiesPerItem + 8;
  final maxRootFields = _screens.length * pages + 4;

  var notifiedAfterDispose = 0;
  final samples = <SoakSample>[];
  // The server's request log, tallied and emptied every iteration (it
  // keeps every document: the soak measures the client, not the mock).
  final requestCounts = <String, int>{};
  int requests(String type) =>
      (requestCounts[type] ?? 0) +
      server.requests.where((r) => r.type == type).length;
  int? storedEntities, storedRootFields;

  try {
    for (var i = 0; i < iterations; i++) {
      final page = i % pages;
      soak.generation = i;
      final queriesBefore = requests('query');

      // Open every screen in one microtask: one request for all of them.
      final disposed = <Object>{};
      void Function() onChanged(Object owner) => () {
        if (disposed.contains(owner)) notifiedAfterDispose++;
      };
      final scopes = <QueryScope<Query>>[];
      QueryScope<Query> open(FetchPolicy policy) {
        late final QueryScope<Query> scope;
        scope = client.createScope(
          onChanged: () => onChanged(scope)(),
          fetchPolicy: policy,
        );
        scopes.add(scope);
        return scope;
      }

      final screens = [
        for (final _ in _screens) open(FetchPolicy.cacheAndNetwork),
      ];
      final group = open(FetchPolicy.networkOnly);
      final node = open(FetchPolicy.networkOnly);
      List<String> readScreen(int s) =>
          screens[s].run((q) => _screens[s](q, page));
      List<String?> readGroup() => group.run(
        (q) => [
          for (final g in q.group0(text: 'g') ?? const <Group0>[])
            g.asThing000?.name ?? g.asThing010?.name,
        ],
      );
      // A bounded set of ids: every argument set is a root field kept
      // until evicted, so ever-new ids would grow `ROOT_QUERY` for good.
      final nodeId = 'node-${i % 2}';
      String? readNode() =>
          node.run((q) => q.node(id: nodeId)?.asThing000?.name);
      for (var s = 0; s < _screens.length; s++) {
        readScreen(s);
      }
      readGroup();
      readNode();
      await Future.wait(scopes.map((s) => s.whenSettled));
      expect(requests('query'), queriesBefore + 1, reason: 'one batch, #$i');
      for (final scope in scopes) {
        expect(scope.error, isNull);
      }

      for (var s = 0; s < _screens.length; s++) {
        final rows = readScreen(s);
        expect(rows, hasLength(pageSize));
        expect(rows.first, startsWith('t$s-p$page-g$i-0 '), reason: '#$i');
      }
      expect(readGroup(), ['name g0-a-g$i', 'name g0-b-g$i']);
      expect(readNode(), 'name $nodeId');

      // Rows on the first screen: a rename re-runs that one row only.
      final rowRuns = <int>[];
      final items = screens[0].run((q) => q.things000(page: page)!);
      final rows = [
        for (var r = 0; r < 3; r++)
          screens[0].row(onChanged: () => rowRuns.add(r)),
      ];
      for (var r = 0; r < rows.length; r++) {
        rows[r].run(items[r], Thing000.new, (t) => t.name);
      }
      final renamedId = items[1].id!;

      // A lookup screen: the entity is cached, so no request.
      final lookup = open(FetchPolicy.cacheFirst);
      final lookedUp = lookup.run(
        (q) => q.thing003(id: 't3-p$page-g$i-2')?.name,
      );
      expect(lookedUp, 'name t3-p$page-g$i-2');
      expect(lookup.isLoading, isFalse, reason: 'served by the lookup');

      final renamed = await client.mutate(
        (m) => m.rename000(id: renamedId, name: 'renamed $i')?.name,
      );
      expect(renamed, 'renamed $i');
      await pumpEventQueue();
      expect(rowRuns, [1], reason: 'only the renamed row is notified');
      expect(rows[1].run(items[1], Thing000.new, (t) => t.name), 'renamed $i');

      // One subscription event, then close.
      final subscription = client.subscribe(
        (s) => s.nodeChanged?.asThing001?.name,
      );
      final events = <String?>[];
      final listener = subscription.stream.listen(events.add);
      while (!soak.nodeChanged.hasListener) {
        await pumpEventQueue();
      }
      soak.nodeChanged.add(soak.thing(1, 'event-$i'));
      while (events.isEmpty) {
        await pumpEventQueue();
      }
      expect(events, ['name event-$i']);
      await listener.cancel();
      await subscription.cancel();

      // Leave every screen.
      for (final row in rows) {
        disposed.add(row);
        row.dispose();
      }
      for (final scope in scopes) {
        disposed.add(scope);
        scope.dispose();
      }
      await client.whenIdle;
      client.gc();
      // With no screen open, what the client keeps is exactly what the
      // roots reach: a disposed scope or row still counted by `gc` would
      // have kept something a root-only sweep removes.
      expect(cache.gc(), isEmpty, reason: 'nothing pinned after dispose, #$i');

      if ((i + 1) % flushEvery == 0 || i == iterations - 1) {
        await persistence.flush();
        Future<int> count(String table) async =>
            (await persistence.database.rawQuery(
                  'SELECT COUNT(*) AS n FROM $table',
                )).single['n']!
                as int;
        storedEntities = await count('sling_entities');
        storedRootFields = await count('sling_root_fields');
      } else {
        storedEntities = storedRootFields = null;
      }

      final entities = cache.entityKeys.where((k) => !k.startsWith('ROOT_'));
      final sample = SoakSample(
        iteration: i,
        entities: entities.length,
        rootFields: cache.entity('ROOT_QUERY')?.length ?? 0,
        storedEntities: storedEntities,
        storedRootFields: storedRootFields,
        rss: ProcessInfo.currentRss,
      );
      samples.add(sample);
      onSample?.call(sample);
      expect(
        sample.entities,
        lessThanOrEqualTo(maxEntities),
        reason: '$sample',
      );
      expect(
        sample.rootFields,
        lessThanOrEqualTo(maxRootFields),
        reason: '$sample',
      );
      if (storedEntities != null) {
        expect(storedEntities, sample.entities, reason: 'store = cache');
        expect(storedRootFields, sample.rootFields, reason: 'store = cache');
      }
      expect(notifiedAfterDispose, 0, reason: 'a disposed scope was notified');
      for (final r in server.requests) {
        requestCounts[r.type] = (requestCounts[r.type] ?? 0) + 1;
      }
      server.requests.clear();
    }

    expect(client.isIdle, isTrue);
    expect(client.activeSubscriptions, 0);
    expect(server.openSubscriptions, 0);
    final requestsByType = {
      for (final type in ['query', 'mutation', 'subscription'])
        type: requests(type),
    };

    // What was saved loads back whole.
    final last = samples.last;
    await persistence.close();
    final reopened = await open();
    final reloaded = reopened.loaded.entities;
    expect(reloaded, last.entities);
    expect(reopened.loaded.rootFields, last.rootFields);
    expect(reopened.loaded.unreachableEntities, 0);
    await reopened.close();
    return SoakReport(samples, requestsByType, reloaded);
  } finally {
    client.dispose();
    await soak.nodeChanged.close();
    if (persistence.database.isOpen) await persistence.close();
    dir.deleteSync(recursive: true);
  }
}
