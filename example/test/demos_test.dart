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

  testWidgets('prepare: a second request without it, none with it', (
    tester,
  ) async {
    await open(tester, 'prepare');
    expect(find.text('1 request'), findsOneWidget);
    await tester.tap(find.text('Show payloads'));
    await tester.pump();
    await settle(tester);
    expect(find.text('2 requests'), findsOneWidget);
    expect(find.textContaining('Crew Dragon Payload 1'), findsOneWidget);

    await tester.tap(find.text('With prepare'));
    await tester.pump();
    await settle(tester);
    expect(find.text('1 request'), findsOneWidget);
    await tester.tap(find.text('Show payloads'));
    await tester.pump();
    await settle(tester);
    expect(find.text('1 request'), findsOneWidget);
    expect(find.textContaining('Crew Dragon Payload 1'), findsOneWidget);
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

  testWidgets('errors: sticky until Retry', (tester) async {
    await open(tester, 'errors');
    expect(find.text('Crew-5'), findsOneWidget);

    // The server starts failing; run the screen again.
    await tester.tap(find.text('Server fails'));
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.refresh));
    await tester.pump();
    await settle(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('1 request'), findsOneWidget);

    // Rebuilding the widget does not send the failing request again.
    await tester.tap(find.text('Rebuild the widget'));
    await tester.pump();
    await settle(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('1 request'), findsOneWidget);

    // The server is back; Retry is state.refetch.
    await tester.tap(find.text('Server OK'));
    await tester.pump();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await settle(tester);
    expect(find.text('Crew-5'), findsOneWidget);
    expect(find.text('2 requests'), findsOneWidget);
  });

  testWidgets('pagination: load more fetches one page, refresh starts over', (
    tester,
  ) async {
    await open(tester, 'pagination');
    expect(find.text('1 request'), findsOneWidget);
    expect(find.textContaining('Load more (5 /'), findsOneWidget);

    await tester.tap(find.textContaining('Load more'));
    await tester.pump();
    await settle(tester);
    expect(find.text('2 requests'), findsOneWidget);
    expect(find.textContaining('Load more (10 /'), findsOneWidget);
    final second = harness(tester).requests.first.document;
    expect(RegExp(r'launches\(').allMatches(second), hasLength(1));
    expect(second, contains('after'), reason: 'only the next page');

    await tester.tap(find.text('Refresh'));
    await tester.pump();
    await settle(tester);
    expect(find.text('3 requests'), findsOneWidget);
    final refresh = harness(tester).requests.first.document;
    expect(
      RegExp(r'launches\(').allMatches(refresh),
      hasLength(1),
      reason: 'the first page only',
    );
    expect(refresh, isNot(contains('after')));
    expect(find.textContaining('Load more (5 /'), findsOneWidget);
  });

  testWidgets(
    'caching: one entity; SlingRow rebuilds one row, plain rows all',
    (tester) async {
      await open(tester, 'caching');
      expect(find.text('1 request'), findsOneWidget);
      expect(find.text('built 1×'), findsNWidgets(5));

      // The detail is served from the entity the list stored.
      await tester.tap(find.text('Open the first launch'));
      await tester.pump();
      await settle(tester);
      expect(find.text('Detail: Crew-5'), findsOneWidget);
      expect(find.text('1 request'), findsOneWidget);

      // A cache write updates both, and rebuilds that row only.
      await tester.tap(find.text('Rename it'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Detail: Crew-5 ✨'), findsOneWidget);
      expect(find.text('Crew-5 ✨'), findsOneWidget);
      expect(find.text('built 2×'), findsOneWidget);
      expect(find.text('built 1×'), findsNWidgets(4));
      expect(find.text('1 request'), findsOneWidget);

      // Plain rows: the same write rebuilds the whole list.
      await tester.tap(find.text('Plain rows'));
      await tester.pump();
      await settle(tester);
      expect(find.text('built 1×'), findsNWidgets(5));
      await tester.tap(find.text('Rename it'));
      await tester.pump();
      await tester.pump();
      expect(find.text('built 2×'), findsNWidgets(5));
    },
  );

  testWidgets('subscriptions: an event updates banner and row, no request', (
    tester,
  ) async {
    await open(tester, 'subscriptions');
    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(finder, findsOneWidget);
    }

    Future<void> setOnServer(String status) => tester.runAsync(
      () => harness(tester).changeOnServer(
        'mutation { updateLaunchStatus(id: "launch-181", status: $status)'
        ' { id } }',
      ),
    );

    await waitFor(find.text('Live: waiting for a status change…'));
    expect(find.text('1 subscription open'), findsOneWidget);

    await setOnServer('SUCCESS');
    await waitFor(find.text('Live: Crew-5 → Success'));
    expect(find.text('1 request'), findsOneWidget, reason: 'the event did it');
    expect(find.text('Success'), findsWidgets);

    await setOnServer('SCHEDULED');
    await waitFor(find.text('Live: Crew-5 → Scheduled'));
  });
}
