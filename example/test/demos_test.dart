import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql_example/demos/demo_harness.dart';
import 'package:sling_gql_example/demos/demos.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

/// The concept demos the guides embed, against the real mock API (like
/// `app_test.dart`). What each guide tells the reader to try is asserted
/// here. Tests that change server data put it back, so the other tests'
/// counts hold on the same server.
void main() {
  useRealNetwork();

  DemoHarnessState harness(WidgetTester tester) =>
      tester.state<DemoHarnessState>(find.byType(DemoHarness));

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpUntilSettled(harness(tester).client);
    await tester.pump();
  }

  Future<void> open(WidgetTester tester, String name) async {
    await tester.pumpWidget(DemoApp(demo: demoFor(name)!));
    await settle(tester);
  }

  testWidgets('batching: one request read at the top, two inside a condition', (
    tester,
  ) async {
    await open(tester, 'batching');
    expect(find.text('1 request'), findsOneWidget);
    expect(find.textContaining('CEO Alex Corren'), findsOneWidget);
    expect(find.textContaining('Crew-5'), findsOneWidget);

    await tester.tap(find.text('Read inside a condition'));
    await tester.pump();
    await settle(tester);
    expect(find.text('2 requests'), findsOneWidget);
    expect(find.textContaining('CEO Alex Corren'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('fetch policies: cacheFirst keeps the old status, '
      'cacheAndNetwork refreshes it', (tester) async {
    await open(tester, 'fetch-policies');
    expect(find.text('1 request'), findsOneWidget);
    expect(find.textContaining('SCHEDULED'), findsOneWidget);

    Future<void> setOnServer(String status) => tester.runAsync(
      () => harness(tester).changeOnServer(
        'mutation { updateLaunchStatus(id: "launch-181", status: $status)'
        ' { id } }',
      ),
    );
    Future<void> reopen() async {
      await tester.tap(find.text('Close'));
      await tester.pump();
      await setOnServer('FAILURE');
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(); // the run that knows a refresh started
    }

    // cacheFirst: the cache has an answer, nothing is asked.
    await reopen();
    await settle(tester);
    expect(find.textContaining('SCHEDULED'), findsOneWidget);
    expect(find.text('1 request'), findsOneWidget);
    await setOnServer('SCHEDULED');

    // cacheAndNetwork: the old status at once, refreshed by a request.
    await tester.tap(find.text('cacheAndNetwork'));
    await tester.pump();
    await settle(tester);
    await reopen();
    expect(find.textContaining('SCHEDULED'), findsOneWidget);
    expect(find.text('refreshing…'), findsOneWidget);
    await settle(tester);
    expect(find.textContaining('FAILURE'), findsOneWidget);
    expect(find.text('refreshing…'), findsNothing);
    expect(find.text('2 requests'), findsOneWidget);

    await setOnServer('SCHEDULED');
  });

  testWidgets('optimistic: confirmed on success, rolled back on failure', (
    tester,
  ) async {
    await open(tester, 'optimistic');
    expect(find.text('Elsewhere in the app: not a favourite'), findsOneWidget);

    // Server succeeds: the other widget follows at once, then it is confirmed.
    await tester.tap(find.byIcon(CupertinoIcons.heart));
    await tester.pump();
    expect(find.text('sending…'), findsOneWidget);
    expect(
      find.text('Elsewhere in the app: in your favourites'),
      findsOneWidget,
    );
    await settle(tester);
    expect(find.text('confirmed'), findsOneWidget);
    expect(
      find.text('Elsewhere in the app: in your favourites'),
      findsOneWidget,
    );

    // Put it back on the server.
    await tester.tap(find.byIcon(CupertinoIcons.heart_fill));
    await tester.pump();
    await settle(tester);
    expect(find.text('Elsewhere in the app: not a favourite'), findsOneWidget);

    // Server fails: flipped, then rolled back.
    await tester.tap(find.text('Server fails'));
    await tester.pump();
    await settle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.heart));
    await tester.pump();
    expect(
      find.text('Elsewhere in the app: in your favourites'),
      findsOneWidget,
    );
    await settle(tester);
    expect(find.text('failed: rolled back'), findsOneWidget);
    expect(find.text('Elsewhere in the app: not a favourite'), findsOneWidget);
  });
}
