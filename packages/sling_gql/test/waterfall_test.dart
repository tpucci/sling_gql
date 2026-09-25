import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// A client whose mock endpoint answers `me` with two friends, collecting the
/// documents sent and the waterfall warnings raised.
///
/// Unlike [meWithFriends] alone, the answer only carries `age` when the
/// document asked for it — a real server never returns unselected fields,
/// and a waterfall only exists when the first response did *not* bring the
/// field along. `friends(limit:)` is answered under whatever alias the
/// document used.
class WaterfallHarness {
  WaterfallHarness({bool? warnOnWaterfall}) {
    client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      onOperation: sent.add,
      warnOnWaterfall: warnOnWaterfall,
      onWaterfall: warnings.add,
      httpClient: mockGraphQL((q, v) => _answer(q)),
    );
  }

  static Map<String, Object?> _answer(String query) {
    final withAge = query.contains('age');
    final me = Map<String, Object?>.of(meWithFriends()['me'] as Map<String, Object?>);
    final friends = [
      for (final f in me.remove('friends') as List)
        {...f as Map<String, Object?>, if (withAge) 'age': 30},
    ];
    for (final m in RegExp(r'(friends(?:_\w+)?): friends').allMatches(query)) {
      me[m.group(1)!] = friends;
    }
    if (query.contains(RegExp(r'\bfriends {'))) me['friends'] = friends;
    if (!withAge) me.remove('age');
    return {'me': me};
  }

  late final SlingClient<Query> client;
  final sent = <PrintedOperation>[];
  final warnings = <WaterfallWarning>[];

  /// A scope that re-runs [body] whenever the client asks, like a widget.
  QueryScope<Query> widgetScope(void Function(Query q) body, {String? debugLabel}) {
    late QueryScope<Query> scope;
    scope = client.createScope(
      debugLabel: debugLabel,
      onChanged: () => scope.run(body),
    );
    scope.run(body);
    return scope;
  }
}

Future<void> settle(QueryScope<Query> scope) async {
  await scope.whenSettled;
  await Future<void>.delayed(Duration.zero); // let the rebuild's flush run
}

void main() {
  test('a field read inside an `if` on fetched data is reported as a waterfall',
      () async {
    final h = WaterfallHarness();
    final scope = h.widgetScope(
      (q) {
        final me = q.me;
        // ❌ age is only read once name has arrived.
        if (me.name != null) me.age;
      },
      debugLabel: 'Header',
    );
    await settle(scope);
    await settle(scope);

    expect(h.sent, hasLength(2));
    expect(h.warnings, hasLength(1));
    final w = h.warnings.single;
    expect(w.scope, 'Header');
    expect(w.fields, ['me.age']);
    expect(w.toString(), contains('waterfall in Header'));
    expect(w.toString(), contains('me.age'));
    expect(w.toString(), contains(WaterfallWarning.hint));
  });

  test('the first request is never a waterfall, even with many misses', () async {
    final h = WaterfallHarness();
    final scope = h.widgetScope((q) {
      q.me.name;
      q.me.friends().map((f) => f.age).toList();
    });
    await settle(scope);

    expect(h.sent, hasLength(1));
    expect(h.warnings, isEmpty);
  });

  test('refetch() is not a waterfall', () async {
    final h = WaterfallHarness();
    final scope = h.widgetScope((q) => q.me.name);
    await settle(scope);
    await scope.refetch();
    await settle(scope);

    expect(h.sent, hasLength(2));
    expect(h.warnings, isEmpty);
  });

  test('a rebuild the app triggered itself (pagination) is not a waterfall',
      () async {
    final h = WaterfallHarness();
    var limit = 2;
    void body(Query q) => q.me.friends(limit: limit).map((f) => f.name).toList();
    final scope = h.widgetScope(body);
    await settle(scope);
    expect(h.sent, hasLength(1));

    // User taps "load more": setState → rebuild reads a new page.
    limit = 4;
    scope.run(body);
    await settle(scope);

    expect(h.sent, hasLength(2));
    expect(h.warnings, isEmpty);
  });

  test('a read inside a callback bound to the rebuilt widget is a waterfall',
      () async {
    final h = WaterfallHarness();
    late User me;
    final scope = h.widgetScope((q) {
      me = q.me;
      me.name;
    }, debugLabel: 'Detail');
    await settle(scope);
    expect(h.sent, hasLength(1));

    // ❌ onPressed: () => me.age — first read on tap.
    me.age;
    await settle(scope);

    expect(h.sent, hasLength(2));
    expect(h.warnings.map((w) => w.scope), ['Detail']);
    expect(h.warnings.single.fields, ['me.age']);
  });

  test('paths name the fields, marking arguments; one warning per request',
      () async {
    final h = WaterfallHarness();
    final scope = h.widgetScope((q) {
      final friends = q.me.friends(limit: 2);
      if (friends.first.name != null) {
        friends.map((f) => f.age).toList();
        q.me.age;
      }
    });
    await settle(scope);
    await settle(scope);

    expect(h.warnings, hasLength(1));
    expect(h.warnings.single.fields, ['me.friends(…).age', 'me.age']);
  });

  test('a scope fully served by another scope\'s request never warns', () async {
    final h = WaterfallHarness();
    final list = h.widgetScope((q) => q.me.friends().map((f) => f.name).toList());
    await settle(list);
    // All of this is cached: no request, no rebuild, no warning.
    final detail = h.widgetScope((q) => q.user(id: 'a')?.name);
    await settle(detail);

    expect(h.sent, hasLength(1));
    expect(h.warnings, isEmpty);
  });

  test('warnOnWaterfall: false silences the sink', () async {
    final h = WaterfallHarness(warnOnWaterfall: false);
    final scope = h.widgetScope((q) {
      if (q.me.name != null) q.me.age;
    });
    await settle(scope);
    await settle(scope);

    expect(h.sent, hasLength(2));
    expect(h.warnings, isEmpty);
  });

  test('warnOnWaterfall defaults to true when asserts are enabled', () {
    final client = SlingClient<Query>(endpoint: testEndpoint, rootFactory: Query.root);
    expect(client.warnOnWaterfall, isTrue);
  });

  testWidgets('QueryBuilder: debugLabel, key or generated id name the scope',
      (tester) async {
    final h = WaterfallHarness();
    Widget conditional(BuildContext _, Query q, QueryState _) {
      final me = q.me;
      return Text('${me.name} ${me.name == null ? '' : me.age}');
    }

    await tester.pumpWidget(SlingScope<Query>(
      client: h.client,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [
          QueryBuilder<Query>(debugLabel: 'Header', builder: conditional),
          QueryBuilder<Query>(key: const ValueKey('list'), builder: conditional),
          QueryBuilder<Query>(builder: conditional),
        ]),
      ),
    ));
    await tester.pump(); // first response lands, widgets rebuild
    await tester.pump(); // post-frame flush of the conditional reads

    expect(h.sent, hasLength(2));
    expect(find.text('Ada 36'), findsNWidgets(3));
    expect(
      h.warnings.map((w) => w.scope),
      containsAll(['Header', "[<'list'>]"]),
    );
    expect(h.warnings.map((w) => w.scope).where((s) => s.startsWith('QueryScope#')),
        hasLength(1));
    expect(h.warnings.map((w) => w.fields), everyElement(['me.age']));
  });
}
