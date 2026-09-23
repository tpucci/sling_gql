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
    // Real network: poll until no scope is loading anymore.
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      if (find.byType(CupertinoActivityIndicator).evaluate().isEmpty) break;
    }
    await tester.pump();
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

    await tester.tap(find.byType(CupertinoListTile).hitTestable().first);
    await settle(tester);

    expect(log.entries, hasLength(3), reason: 'detail screen: exactly one request');
    final detail = log.entries.first.document;
    expect(detail, contains('launch('));
    expect(detail, contains('payloads {'), reason: 'prepare selected the collapsed section');
    expect(detail, isNot(contains('nodes')), reason: 'list data was served from cache');
    expect(find.text('Rocket'), findsOneWidget);

    await tester.tap(find.textContaining('Show payloads'));
    await tester.pump();
    expect(log.entries, hasLength(3), reason: 'no request when expanding: prepare paid for it');
  });
}
