import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_sqflite/sling_gql_sqflite.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

import 'support/test_schema.dart';

/// The screen of these tests: one `QueryBuilder` reading `me`.
Widget meScreen(SlingClient<Query> client, List<QueryState> states) =>
    SlingScope<Query>(
      client: client,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: QueryBuilder<Query>(
          builder: (context, q, state) {
            states.add(state);
            return Text(q.me?.name ?? '…');
          },
        ),
      ),
    );

SlingClient<Query> clientFor(
  MockGraphQLServer server,
  SqflitePersistence persistence, {
  Duration? maxAge,
}) {
  final client = SlingClient<Query>(
    endpoint: Uri.parse('http://mock/graphql'),
    schema: slingSchema,
    cache: persistence.cache,
    httpClient: server.httpClient,
    maxAge: maxAge,
  );
  addTearDown(client.dispose);
  return client;
}

void main() {
  /// A store holding `me` (Ada), as a previous run of the app left it.
  Future<String> previousRun(WidgetTester tester) async {
    final path = tempDatabasePath();
    await tester.runAsync(() async {
      final p = await openStore(path);
      final server = testServer();
      await clientFor(server, p).resolve((q) => q.me?.name);
      expect(server.requests, hasLength(1));
      await p.close();
    });
    return path;
  }

  Future<SqflitePersistence> reopen(WidgetTester tester, String path) async {
    final p = (await tester.runAsync(() => openStore(path)))!;
    addTearDown(() => tester.runAsync(p.close));
    return p;
  }

  testWidgets('a reopened cache serves the first frame; cacheFirst never '
      'revalidates it', (tester) async {
    final path = await previousRun(tester);
    final persistence = await reopen(tester, path);
    final server = testServer()..query['me'] = user('1', name: 'Ada L.');
    final client = clientFor(server, persistence);
    final states = <QueryState>[];

    await tester.pumpWidget(meScreen(client, states));
    expect(find.text('User 1'), findsOneWidget, reason: 'no skeleton');
    expect(states.first.hasMissingData, isFalse);
    await tester.pumpUntilSettled(client);
    expect(server.requests, isEmpty, reason: 'served from the store');
    expect(find.text('User 1'), findsOneWidget);
  });

  testWidgets('under maxAge, restored data is shown, then revalidated (no '
      'fetchedAt stamp: stale)', (tester) async {
    final path = await previousRun(tester);
    final persistence = await reopen(tester, path);
    final server = testServer()..query['me'] = user('1', name: 'Ada L.');
    final client = clientFor(
      server,
      persistence,
      maxAge: const Duration(minutes: 5),
    );
    final states = <QueryState>[];

    await tester.pumpWidget(meScreen(client, states));
    expect(find.text('User 1'), findsOneWidget, reason: 'stale, on screen');
    await tester.pumpUntilSettled(client);
    expect(server.requests, hasLength(1));
    expect(find.text('Ada L.'), findsOneWidget);
    expect(states.last.isStale, isFalse);

    // The revalidated value is what the next run starts from.
    await tester.runAsync(persistence.flush);
    final stored = (await tester.runAsync(() => entityRows(persistence)))!;
    expect((stored['User:1']! as Map)['name'], 'Ada L.');
  });
}
