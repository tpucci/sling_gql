import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_example/app.dart';
import 'package:sling_gql_example/generated/schema.dart';
import 'package:sling_gql_example/list_rules.dart';
import 'package:sling_gql_example/mock_latency.dart';
import 'package:sling_gql_example/network_log.dart';
import 'package:sling_gql_example/screens/launch_screen.dart';
import 'package:sling_gql_example/widgets/launch_row.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

/// Runs against the real mock API: `cd mock-api && npm start` first
/// (`melos run test:example` starts it for you). `useRealNetwork()` lifts
/// the HTTP block `flutter test` installs.
void main() {
  useRealNetwork();

  late NetworkLog log;
  late MockLatencyController latency;
  late SlingClient<Query> client;

  setUp(() {
    log = NetworkLog();
    latency = MockLatencyController(); // no header until a test picks one
    final httpClient = http.Client();
    // Disposed after each test: keep-alive connections would otherwise be
    // reported as pending timers by the test binding.
    client = disposeAfterTest(
      SlingClient<Query>(
        endpoint: Uri.parse('http://localhost:4000/graphql'),
        schema: slingSchema,
        httpClient: httpClient,
        transport: log.transport(latency.transport(httpClient)),
        listRules: listRules,
        subscriptionRetryAfter: const Duration(seconds: 3),
      ),
    );
    log.attach(client);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      SlingScope<Query>(
        client: client,
        child: MockLatencyScope(
          latency: latency,
          child: NetworkLogScope(log: log, child: const SlingApp()),
        ),
      ),
    );
    // CupertinoTabView wraps each tab in its own Navigator; that Navigator
    // needs one extra pump to push its initial route before content builds.
    await tester.pump();
  }

  /// Waits for every request to land and the UI to rebuild with it, then
  /// finishes any page transition.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpUntilSettled(client);
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'first frame → one request; load more → one more; detail → one more',
    (tester) async {
      await pumpApp(tester);
      await settle(tester);

      expect(log.entries, hasLength(1), reason: 'header + list + rows batched');
      // Attributed to the widgets that recorded it (the request overlay).
      expect(log.entries.single.request.scopes, contains('_Header'));
      expect(find.text('Sling Space'), findsOneWidget);

      // The launches list uses a ValueKey so we can scroll it unambiguously even
      // if other Scrollables exist in the tab scaffold.
      final launchesScrollable = find.descendant(
        of: find.byKey(const ValueKey('launches-scroll')),
        matching: find.byType(Scrollable),
      );

      await tester.scrollUntilVisible(
        find.textContaining('Load more'),
        300,
        scrollable: launchesScrollable,
      );
      expect(find.textContaining('Load more (20 / 181)'), findsOneWidget);
      await tester.tap(find.textContaining('Load more'));
      await settle(tester);

      expect(
        log.entries,
        hasLength(2),
        reason: 'only the second page is fetched',
      );
      expect(
        log.entries.first.variables,
        containsPair('after', isA<String>()),
        reason: 'the `after` cursor is sent as a variable',
      );
      await tester.scrollUntilVisible(
        find.textContaining('Load more'),
        300,
        scrollable: launchesScrollable,
      );
      expect(find.textContaining('Load more (40 / 181)'), findsOneWidget);

      final tappedRow = find.byType(CupertinoListTile).hitTestable().first;
      final tappedName = tester
          .widget<Text>(
            find.descendant(of: tappedRow, matching: find.byType(Text)).first,
          )
          .data!;
      await tester.tap(tappedRow);
      expect(
        log.entries,
        hasLength(3),
        reason: 'LaunchScreen.open prefetched with client.resolve on tap',
      );
      expect(
        find.byType(LaunchScreen),
        findsNothing,
        reason: 'the request left before the route was built',
      );
      await settle(tester);

      expect(
        log.entries,
        hasLength(3),
        reason:
            'detail screen: exactly one request (its QueryBuilder joined the '
            'in-flight prefetch)',
      );
      expect(find.byType(LaunchScreen), findsOneWidget);
      final detail = log.entries.first.document;
      expect(detail, contains('launch('));
      expect(
        detail,
        contains('payloads {'),
        reason: 'the whole screen in one request, payloads included',
      );
      expect(
        detail,
        isNot(contains('nodes')),
        reason: 'list data was served from cache',
      );
      expect(
        detail,
        isNot(contains('date')),
        reason: 'name/date/status come from the Launch entity the list wrote',
      );
      expect(detail, isNot(contains('status')));
      expect(
        detail,
        contains('details'),
        reason: 'only fields the list did not fetch',
      );
      expect(find.text('Rocket'), findsOneWidget);
      // Further down, built once scrolled to (and it costs no request).
      await tester.scrollUntilVisible(
        find.text('Payloads'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Payloads'), findsOneWidget);
      expect(log.entries, hasLength(3));

      // --- Mutation: toggle favourite from the detail screen -------------------
      // The mock server keeps favourites in memory across runs, so assert on the
      // transition rather than on an absolute state.
      // Scroll back to the top of the detail screen where the heart lives.
      final anyHeart = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == CupertinoIcons.heart ||
                w.icon == CupertinoIcons.heart_fill),
      );
      await tester.scrollUntilVisible(
        anyHeart,
        -200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump(const Duration(milliseconds: 300));
      final wasFavorite = find
          .byIcon(CupertinoIcons.heart_fill)
          .evaluate()
          .isNotEmpty;
      await tester.tap(
        find.byIcon(
          wasFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
        ),
      );
      await tester.pump();
      expect(
        find.byIcon(
          wasFavorite ? CupertinoIcons.heart : CupertinoIcons.heart_fill,
        ),
        findsOneWidget,
        reason: 'optimistic write shows before the response',
      );
      await tester.pumpUntilSettled(client);

      expect(log.entries, hasLength(4), reason: 'one mutation request');
      final mutation = log.entries.first.document;
      expect(mutation, startsWith('mutation'));
      expect(
        mutation,
        contains(
          'toggleFavorite(launchId: \$launchId) {\n    __typename\n    id\n    favorite\n  }',
        ),
      );
      expect(
        find.byIcon(
          wasFavorite ? CupertinoIcons.heart : CupertinoIcons.heart_fill,
        ),
        findsOneWidget,
        reason: 'confirmed by the response',
      );

      // Back to the list: the row reads the same Launch entity → star updated,
      // and no request was needed for it.
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pump(const Duration(milliseconds: 600)); // page transition
      final row = find.ancestor(
        of: find.text(tappedName),
        matching: find.byType(CupertinoListTile),
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(CupertinoIcons.heart_fill),
        ),
        wasFavorite ? findsNothing : findsOneWidget,
      );
      expect(log.entries, hasLength(4));
    },
  );

  testWidgets(
    'toggleFavorite → Me tab gains/loses the launch with no refetch',
    (tester) async {
      await pumpApp(tester);
      await settle(tester);

      // Load the Me tab first so `me.favorites` is cached.
      await tester.tap(find.byIcon(CupertinoIcons.person_crop_circle));
      await tester.pump();
      await settle(tester);
      expect(log.entries, hasLength(2), reason: 'Launches tab + Me tab');
      final favoritesBefore = find.byType(LaunchRow).evaluate().length;

      int shownCount() {
        final text = find
            .textContaining('favourite')
            .evaluate()
            .map((e) => (e.widget as Text).data!)
            .firstWhere((s) => RegExp(r'^\d+').hasMatch(s));
        return int.parse(RegExp(r'^\d+').firstMatch(text)!.group(0)!);
      }

      expect(shownCount(), favoritesBefore);

      // Open the first launch of the list.
      await tester.tap(find.byIcon(CupertinoIcons.rocket));
      await tester.pump();
      await settle(tester);
      final tappedRow = find.byType(CupertinoListTile).hitTestable().first;
      final tappedName = tester
          .widget<Text>(
            find.descendant(of: tappedRow, matching: find.byType(Text)).first,
          )
          .data!;
      await tester.tap(tappedRow);
      await settle(tester);
      expect(log.entries, hasLength(3), reason: 'detail screen: one request');

      // Taps the detail screen's heart and waits for the mutation to land: the
      // button is disabled while it is in flight.
      Future<bool> toggle() async {
        final wasFavorite = find
            .byIcon(CupertinoIcons.heart_fill)
            .evaluate()
            .isNotEmpty;
        final heart = find.byIcon(
          wasFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
        );
        await tester.tap(heart);
        await tester.pumpUntilSettled(client);
        return wasFavorite;
      }

      Future<void> showMeTab() async {
        await tester.tap(find.byIcon(CupertinoIcons.person_crop_circle));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      final meRowNamed = find.descendant(
        of: find.byType(LaunchRow),
        matching: find.text(tappedName),
      );

      // Toggle once: the Me tab's list and count follow, no request.
      final wasFavorite = await toggle();
      expect(log.entries, hasLength(4), reason: 'the mutation only');
      expect(log.entries.first.document, startsWith('mutation'));
      await showMeTab();
      final delta = wasFavorite ? -1 : 1;
      expect(find.byType(LaunchRow).evaluate().length, favoritesBefore + delta);
      expect(shownCount(), favoritesBefore + delta);
      expect(meRowNamed, wasFavorite ? findsNothing : findsOneWidget);
      expect(log.entries, hasLength(4), reason: 'no refetch of me.favorites');

      // Toggle back (restores the shared mock server's state).
      await tester.tap(find.byIcon(CupertinoIcons.rocket));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await toggle();
      expect(log.entries, hasLength(5), reason: 'the second mutation only');
      await showMeTab();
      expect(find.byType(LaunchRow).evaluate().length, favoritesBefore);
      expect(shownCount(), favoritesBefore);
      expect(meRowNamed, wasFavorite ? findsOneWidget : findsNothing);
      expect(log.entries, hasLength(5));
    },
  );

  testWidgets(
    'Me tab → one request with me+favorites; Success segment → one more request; All → no request',
    (tester) async {
      await pumpApp(tester);
      await settle(tester);

      // Switch to the Me tab (index 1).
      // Extra pump needed so CupertinoTabView's Navigator can build MeScreen.
      await tester.tap(find.byIcon(CupertinoIcons.person_crop_circle));
      await tester.pump(); // Navigator initialises and MeScreen builds
      await settle(tester);

      // Exactly one request on switching to Me; it must contain me { and favorites {.
      expect(
        log.entries,
        hasLength(2),
        reason: 'Launches tab (1 request) + Me tab (1 request)',
      );
      final meDoc = log.entries.first.document;
      expect(meDoc, contains('me {'), reason: 'me field selected');
      expect(
        meDoc,
        contains('favorites {'),
        reason: 'favorites nested field selected',
      );

      // Viewer name visible.
      expect(find.text('Mira Vance'), findsOneWidget);

      // Number of LaunchRow widgets must equal the favouriteCount shown.
      final launchRows = find.byType(LaunchRow).evaluate().length;
      // Find the favouriteCount text — it shows "N favourite(s)".
      final countWidget = find
          .textContaining('favourite')
          .evaluate()
          .map((e) => (e.widget as Text).data!)
          .firstWhere((s) => RegExp(r'^\d+').hasMatch(s));
      final countInText = int.parse(
        RegExp(r'^\d+').firstMatch(countWidget)!.group(0)!,
      );
      expect(launchRows, equals(countInText));

      // Switch back to Launches tab.
      await tester.tap(find.byIcon(CupertinoIcons.rocket));
      await tester.pump(); // tab switch frame
      await settle(tester);

      // Tap the "Success" status segment.
      await tester.tap(find.text('Success'));
      await settle(tester);

      // Exactly one more request compared to before.
      expect(
        log.entries,
        hasLength(3),
        reason: 'a status filter is a new argument set → new cache entry → one request',
      );
      final statusDoc = log.entries.first;
      expect(statusDoc.document, contains('filter: \$filter'));
      expect(
        statusDoc.variables.values.any(
          (v) => v is Map && v['status'] == 'SUCCESS',
        ),
        isTrue,
        reason: 'LaunchFilter(status: SUCCESS) sent as a variable',
      );

      // Every visible row is a successful launch (the row's leading icon).
      final visibleRows = find.byType(LaunchRow).evaluate().length;
      expect(visibleRows, greaterThan(0));
      expect(
        find.byIcon(CupertinoIcons.checkmark_circle_fill).evaluate().length,
        equals(visibleRows),
        reason:
            'every visible row in the Success segment shows the success icon',
      );

      // Switch back to All — no new request.
      final requestsBeforeAll = log.entries.length;
      await tester.tap(find.text('All'));
      await settle(tester);

      expect(
        log.entries,
        hasLength(requestsBeforeAll),
        reason: 'switching back to All is served from cache, no request',
      );
    },
  );

  testWidgets(
    'launchStatusChanged over SSE: a status change made elsewhere updates the row',
    (tester) async {
      await pumpApp(tester);
      await settle(tester);

      expect(
        log.entries,
        hasLength(1),
        reason: 'subscriptions are not requests',
      );
      expect(log.subscriptions, hasLength(2), reason: 'scheduled + status');
      expect(
        log.subscriptions.map((op) => op.document),
        everyElement(startsWith('subscription')),
      );
      expect(
        log.subscriptions.map((op) => op.document).join(),
        allOf(contains('launchStatusChanged'), contains('launchScheduled')),
      );
      expect(find.text('Live: waiting for a status change…'), findsOneWidget);
      expect(client.activeSubscriptions, 2);

      // The first row's launch, as the list has it.
      final row = tester.widget<LaunchRow>(find.byType(LaunchRow).first);
      final id = row.launch.id!;
      final name = row.launch.name!;
      final before = row.launch.status!;
      final after = before == LaunchStatus.scrubbed
          ? LaunchStatus.scheduled
          : LaunchStatus.scrubbed;

      // Change it *outside* this client (a plain POST, so the response is
      // not written to our cache); only the subscription can tell the list.
      Future<void> setStatus(LaunchStatus status) => tester.runAsync(() async {
        final response = await http.post(
          Uri.parse('http://localhost:4000/graphql'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'query':
                'mutation(\$id: ID!, \$status: LaunchStatus!) { '
                'updateLaunchStatus(id: \$id, status: \$status) { id status } }',
            'variables': {'id': id, 'status': status.graphqlName},
          }),
        );
        expect(response.statusCode, 200);
      });
      // Put it back whatever happens, other tests assume the seed data.
      addTearDown(
        () => http.post(
          Uri.parse('http://localhost:4000/graphql'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'query':
                'mutation(\$id: ID!, \$status: LaunchStatus!) { '
                'updateLaunchStatus(id: \$id, status: \$status) { id } }',
            'variables': {'id': id, 'status': before.graphqlName},
          }),
        ),
      );

      await setStatus(after);
      // Let the event travel: real time for the socket, then a frame.
      final banner = find.text('Live: $name → ${after.graphqlName}');
      for (var i = 0; i < 40 && banner.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(banner, findsOneWidget, reason: 'the event reached the widget');
      expect(
        tester.widget<LaunchRow>(find.byType(LaunchRow).first).launch.status,
        after,
        reason: 'the row reads the same Launch:<id> entity',
      );
      expect(log.entries, hasLength(1), reason: 'no request was needed');
      expect(client.cache.entity('Launch:$id')!['status'], after.graphqlName);
    },
  );

  testWidgets(
    'mission control: schedule → detail page, then the sequence flies the '
    'launch live through the list rules (segments follow the status)',
    (tester) async {
      await pumpApp(tester);
      await settle(tester);
      // Cache the "Scheduled" and "Success" segments up front, so what
      // they show after the flight comes from the list rules, not a fetch.
      await tester.tap(find.text('Scheduled'));
      await settle(tester);
      await tester.tap(find.text('Success'));
      await settle(tester);
      await tester.tap(find.text('All'));
      await settle(tester);
      final before = log.entries.length; // 3

      await tester.tap(find.byKey(const ValueKey('schedule-launch')));
      await settle(tester);
      expect(
        log.entries,
        hasLength(before + 1),
        reason: 'rockets + launchpads for the pickers: one request',
      );
      await tester.enterText(
        find.byKey(const ValueKey('schedule-name')),
        'Test Pigeon',
      );
      await tester.tap(find.byKey(const ValueKey('schedule-submit')));
      await settle(tester);
      // Redirected to the detail screen: the mutation, then the detail's
      // own request for what the response did not carry.
      expect(
        log.entries,
        hasLength(before + 3),
        reason: 'the mutation + the detail screen',
      );
      expect(log.entries[1].document, contains('scheduleLaunch'));
      expect(log.entries.first.document, contains('launch('));
      expect(find.text('Test Pigeon'), findsOneWidget);
      expect(find.text('Launch'), findsOneWidget);
      final detailRequests = log.entries.length;

      // The server flies it: IN_FLIGHT, then SUCCESS (name has no "fail").
      // SEQUENCE_MS=700 in the test server; give it real time.
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }
        expect(finder, findsOneWidget);
      }

      await waitFor(find.text('IN_FLIGHT'));
      await waitFor(find.text('SUCCESS'));
      expect(
        log.entries,
        hasLength(detailRequests),
        reason: 'the sequence arrived over the subscription: no request',
      );

      // Back on the list: the launch is on top of "All" (prepended by the
      // launches rule on the launchScheduled event) with its final status…
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await settle(tester);
      final firstRow = tester.widget<LaunchRow>(find.byType(LaunchRow).first);
      expect(firstRow.launch.name, 'Test Pigeon');
      expect(firstRow.launch.status, LaunchStatus.success);
      expect(find.textContaining('Test Pigeon → SUCCESS'), findsOneWidget);

      // …and the cached segments followed the status without a request:
      // "Success" gained it (prepended by the rule on the SUCCESS event),
      // "Scheduled" lost it (removed on the IN_FLIGHT event).
      await tester.tap(find.text('Success'));
      await settle(tester);
      expect(
        tester.widget<LaunchRow>(find.byType(LaunchRow).first).launch.name,
        'Test Pigeon',
      );
      await tester.tap(find.text('Scheduled'));
      await settle(tester);
      expect(find.text('Test Pigeon'), findsNothing);
      expect(
        log.entries,
        hasLength(detailRequests),
        reason: 'both segments were cached: the rules did the work',
      );
    },
  );

  testWidgets(
    'Search tab: a union list is one request covering every member type; '
    'a hit opens the launch from the cache',
    (tester) async {
      await pumpApp(tester);
      await settle(tester);
      await tester.tap(find.byIcon(CupertinoIcons.search));
      await tester.pump();
      await settle(tester);
      expect(log.entries, hasLength(1), reason: 'empty query: no request');

      // "al": 3 launches, Falcon 9, 2 astronauts in the mock data.
      await tester.enterText(find.byType(CupertinoSearchTextField), 'al');
      await tester.pump(const Duration(milliseconds: 350)); // debounce
      await settle(tester);

      expect(
        log.entries,
        hasLength(2),
        reason: 'skeleton recorded all branches',
      );
      final document = log.entries.first.document;
      expect(document, contains('... on Launch {'));
      expect(document, contains('... on Rocket {'));
      expect(document, contains('... on Astronaut {'));
      expect(find.textContaining('Launch · '), findsNWidgets(3));
      expect(find.textContaining('Rocket · '), findsOneWidget);
      expect(find.textContaining('Astronaut · '), findsNWidgets(2));
      expect(find.text('Falcon 9'), findsOneWidget);

      // The launch hit is the `Launch:<id>` entity: the detail screen finds
      // name and date in cache and only asks for what the hit did not carry.
      await tester.tap(find.textContaining('Launch · ').first);
      await settle(tester);
      expect(log.entries, hasLength(3));
      final detail = log.entries.first.document;
      expect(detail, contains('launch('));
      expect(detail, isNot(contains('date')), reason: 'came with the hit');
      expect(
        detail,
        isNot(contains(RegExp(r'^    name$', multiLine: true))),
        reason: "the launch's name came with the hit",
      );
    },
  );
  testWidgets(
    'network log screen: the latency picker sets x-mock-latency-ms per '
    'request; cache stats follow Cache.onChange live',
    (tester) async {
      await pumpApp(tester);
      await settle(tester);

      await tester.tap(find.byType(NetworkLogButton).hitTestable().first);
      await settle(tester);
      expect(log.entries, hasLength(1), reason: 'opening the log is free');

      // One collapsed line per request: number, type, root fields by name,
      // and what the transport saw.
      final first = log.entries.single;
      expect(first.rootFields, ['company', 'stats', 'launches']);
      expect(first.statusCode, 200);
      expect(first.duration, isNotNull);
      expect(find.text('company · stats · launches'), findsOneWidget);
      expect(find.text('Requests (1)'), findsOneWidget);
      // Expanded, the document reads like what the widgets asked for.
      await tester.tap(find.text('company · stats · launches'));
      await tester.pump();
      expect(find.textContaining(r'launches(first: $first'), findsOneWidget);
      final readable = readableDocument(first.document);
      expect(readable, isNot(contains('__typename')));
      expect(find.text(readable), findsOneWidget);

      await tester.tap(find.text('Dev tools'));
      await tester.pump();

      String stats() =>
          tester.widget<Text>(find.byKey(const ValueKey('cache-stats'))).data!;
      int typeCount(String type) =>
          client.cache.entityKeys.where((k) => k.startsWith('$type:')).length;
      final entitiesBefore = client.cache.entityKeys
          .where((k) => k.contains(':'))
          .length;
      expect(stats(), startsWith('$entitiesBefore objects · '));
      expect(typeCount('Launchpad'), 0, reason: 'the list never selects one');

      expect(latency.value, MockLatency.serverDefault);
      await tester.tap(find.text(MockLatency.twoSeconds.label));
      await tester.pump();
      expect(latency.value, MockLatency.twoSeconds);

      // A request made now carries the header: the server waits 2 s instead
      // of its LATENCY_MS.
      final elapsed = await tester.runAsync(() async {
        final stopwatch = Stopwatch()..start();
        await client.resolve(
          (q) => [for (final p in q.launchpads ?? const <Launchpad>[]) p.name],
        );
        return stopwatch.elapsed;
      });
      expect(
        elapsed,
        // A little slack for timer granularity; LATENCY_MS is 400.
        greaterThanOrEqualTo(const Duration(milliseconds: 1900)),
        reason: 'x-mock-latency-ms: 2000 was honoured',
      );
      expect(log.entries, hasLength(2));

      // The open screen was told by onChange, no navigation needed.
      await tester.pump();
      final launchpads = typeCount('Launchpad');
      expect(launchpads, greaterThan(0));
      expect(stats(), startsWith('${entitiesBefore + launchpads} objects · '));
      expect(find.textContaining('$launchpads launchpad'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'\d+ updates? since you opened this')),
        findsOneWidget,
      );
    },
  );
}
