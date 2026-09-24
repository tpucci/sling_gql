import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_example/app.dart';
import 'package:sling_gql_example/generated/schema.dart';
import 'package:sling_gql_example/network_log.dart';
import 'package:sling_gql_example/widgets/launch_row.dart';

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
        child: const SlingApp(),
      ),
    ));
    // CupertinoTabView wraps each tab in its own Navigator; that Navigator
    // needs one extra pump to push its initial route before content builds.
    await tester.pump();
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

    expect(log.entries, hasLength(2), reason: 'only the second page is fetched');
    expect(log.entries.first.variables, containsPair('v1', isA<String>()),
        reason: 'the `after` cursor is sent as a variable');
    await tester.scrollUntilVisible(
      find.textContaining('Load more'),
      300,
      scrollable: launchesScrollable,
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

    // The tab bar stays visible over the detail screen (per-tab navigators);
    // bring the button above it before tapping or the tap hits the "Me" tab.
    await tester.ensureVisible(find.textContaining('Show payloads'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.textContaining('Show payloads'));
    await tester.pump();
    expect(log.entries, hasLength(3), reason: 'no request when expanding: prepare paid for it');
    expect(find.textContaining('Hide payloads'), findsOneWidget, reason: 'the tap landed');

    // --- Mutation: toggle favourite from the detail screen -------------------
    // The mock server keeps favourites in memory across runs, so assert on the
    // transition rather than on an absolute state.
    // Scroll back to the top of the detail screen where the heart lives.
    final anyHeart = find.byWidgetPredicate(
      (w) => w is Icon && (w.icon == CupertinoIcons.heart || w.icon == CupertinoIcons.heart_fill),
    );
    await tester.scrollUntilVisible(anyHeart, -200, scrollable: find.byType(Scrollable).last);
    await tester.pump(const Duration(milliseconds: 300));
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

  testWidgets('Me tab → one request with me+favorites; Favourites segment → one more request; All → no request',
      (tester) async {
    await pumpApp(tester);
    await settle(tester);

    // Switch to the Me tab (index 1).
    // Extra pump needed so CupertinoTabView's Navigator can build MeScreen.
    await tester.tap(find.byIcon(CupertinoIcons.person_crop_circle));
    await tester.pump(); // Navigator initialises and MeScreen builds
    await settle(tester);

    // Exactly one request on switching to Me; it must contain me { and favorites {.
    expect(log.entries, hasLength(2),
        reason: 'Launches tab (1 request) + Me tab (1 request)');
    final meDoc = log.entries.first.document;
    expect(meDoc, contains('me {'), reason: 'me field selected');
    expect(meDoc, contains('favorites {'), reason: 'favorites nested field selected');

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
    final countInText = int.parse(RegExp(r'^\d+').firstMatch(countWidget)!.group(0)!);
    expect(launchRows, equals(countInText));

    // Switch back to Launches tab.
    await tester.tap(find.byIcon(CupertinoIcons.rocket));
    await tester.pump(); // tab switch frame
    await settle(tester);

    // Tap the "Favourites" segment.
    await tester.tap(find.text('Favourites'));
    await settle(tester);

    // Exactly one more request compared to before.
    expect(log.entries, hasLength(3),
        reason: 'Favourites filter is a new cache entry → one request');
    final favDoc = log.entries.first;
    // The variables map should contain a LaunchFilter with favorite: true.
    expect(favDoc.variables.values.any((v) {
      if (v is Map) return v['favorite'] == true;
      return false;
    }), isTrue, reason: 'LaunchFilter(favorite: true) sent as variable');

    // All visible LaunchRows should show heart_fill (they are all favourites).
    final visibleRows = find.byType(LaunchRow).evaluate().length;
    if (visibleRows > 0) {
      expect(
        find.byIcon(CupertinoIcons.heart_fill).evaluate().length,
        equals(visibleRows),
        reason: 'every visible row in Favourites mode shows heart_fill',
      );
    }

    // Switch back to All — no new request.
    final requestsBeforeAll = log.entries.length;
    await tester.tap(find.text('All'));
    await settle(tester);

    expect(log.entries, hasLength(requestsBeforeAll),
        reason: 'switching back to All is served from cache, no request');

    client.dispose();
  });
}
