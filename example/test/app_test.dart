import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_example/generated/schema.dart';
import 'package:sling_gql_example/network_log.dart';
import 'package:sling_gql_example/screens/launches_screen.dart';

/// Runs against the real mock API: `cd mock-api && npm start` first.
/// (`flutter test` blocks HTTP by default; we opt out with HttpOverrides.)
void main() {
  setUpAll(() => HttpOverrides.global = null);

  late NetworkLog log;
  late SlingClient<Query> client;

  setUp(() {
    log = NetworkLog();
    client = SlingClient<Query>(
      endpoint: Uri.parse('http://localhost:4000/graphql'),
      rootFactory: Query.root,
      onOperation: log.add,
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(SlingScope<Query>(
      client: client,
      child: NetworkLogScope(
        log: log,
        child: const CupertinoApp(home: LaunchesScreen()),
      ),
    ));
  }

  Future<void> settle(WidgetTester tester) async {
    // Real network: poll until no scope is loading anymore. Pumping with a
    // duration also advances the fake clock so page transitions complete.
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
      if (i > 0 && find.byType(CupertinoActivityIndicator).evaluate().isEmpty) break;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('first frame → one request; load more → one more; detail → one more',
      (tester) async {
    await pumpApp(tester);
    await settle(tester);

    expect(log.entries, hasLength(1), reason: 'header + list + rows batched');
    expect(find.text('Sling Space'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('Load more'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Load more (20 / 181)'), findsOneWidget);
    await tester.tap(find.textContaining('Load more'));
    await settle(tester);

    expect(log.entries, hasLength(2), reason: 'only the second page is fetched');
    expect(log.entries.first.variables, containsPair('v1', isA<String>()),
        reason: 'the `after` cursor is sent as a variable');
    await tester.scrollUntilVisible(
      find.textContaining('Load more'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Load more (40 / 181)'), findsOneWidget);

    final tappedRow = find.byType(CupertinoListTile).hitTestable().first;
    final tappedName = tester
        .widget<Text>(find.descendant(of: tappedRow, matching: find.byType(Text)).first)
        .data!;
    await tester.tap(tappedRow);
    await settle(tester);

    expect(log.entries, hasLength(3), reason: 'detail screen: exactly one request');
    final detail = log.entries.first.document;
    expect(detail, contains('launch('));
    expect(detail, contains('payloads {'), reason: 'prepare selected the collapsed section');
    expect(detail, isNot(contains('nodes')), reason: 'list data was served from cache');
    expect(detail, isNot(contains('date')),
        reason: 'name/date/status come from the Launch entity the list wrote');
    expect(detail, isNot(contains('status')));
    expect(detail, contains('details'), reason: 'only fields the list did not fetch');
    expect(find.text('Rocket'), findsOneWidget);

    await tester.tap(find.textContaining('Show payloads'));
    await tester.pump();
    expect(log.entries, hasLength(3), reason: 'no request when expanding: prepare paid for it');

    // --- Mutation: toggle favourite from the detail screen -------------------
    // The mock server keeps favourites in memory across runs, so assert on the
    // transition rather than on an absolute state.
    final wasFavorite = find.byIcon(CupertinoIcons.heart_fill).evaluate().isNotEmpty;
    await tester.tap(
      find.byIcon(wasFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart),
    );
    await tester.pump();
    expect(
      find.byIcon(wasFavorite ? CupertinoIcons.heart : CupertinoIcons.heart_fill),
      findsOneWidget,
      reason: 'optimistic write shows before the response',
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pump();

    expect(log.entries, hasLength(4), reason: 'one mutation request');
    final mutation = log.entries.first.document;
    expect(mutation, startsWith('mutation'));
    expect(mutation, contains('toggleFavorite(launchId: \$v0) {\n    __typename\n    id\n    favorite\n  }'));
    expect(
      find.byIcon(wasFavorite ? CupertinoIcons.heart : CupertinoIcons.heart_fill),
      findsOneWidget,
      reason: 'confirmed by the response',
    );

    // Back to the list: the row reads the same Launch entity → star updated,
    // and no request was needed for it.
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pump(const Duration(milliseconds: 600)); // page transition
    final row = find.ancestor(of: find.text(tappedName), matching: find.byType(CupertinoListTile));
    expect(
      find.descendant(of: row, matching: find.byIcon(CupertinoIcons.heart_fill)),
      wasFavorite ? findsNothing : findsOneWidget,
    );
    expect(log.entries, hasLength(4));

    // Close keep-alive connections: their 15 s idle timer would otherwise be
    // reported as pending by the test binding.
    client.dispose();
  });
}
