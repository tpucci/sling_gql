import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

import 'support/test_schema.dart';

Widget app(SlingClient<Query> client, Widget child) => SlingScope<Query>(
  client: client,
  schema: slingSchema,
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

/// Shows `me.name`; when [showFriends] is set, also the friends — read
/// *conditionally* on fetched data, which is the classic waterfall.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key, this.showFriends = false});
  final bool showFriends;

  @override
  Widget build(BuildContext context) => QueryBuilder<Query>(
    builder: (context, query, state) {
      final name = query.me.name;
      final friends = showFriends && name != null
          ? query.me.friends().map((f) => f.name ?? '…').join(',')
          : '';
      return Text('${name ?? 'loading'}|$friends');
    },
  );
}

void main() {
  testWidgets('pumpUntilSettled: skeleton → data in one call', (tester) async {
    final server = MockGraphQLServer(query: {'me': user('1', 'Ada')});
    final client = server.client(Query.root);
    await tester.pumpWidget(app(client, const MeScreen()));
    expect(find.text('loading|'), findsOneWidget);

    await tester.pumpUntilSettled(client);
    expect(find.text('Ada|'), findsOneWidget);
    expect(server.requests, hasLength(1));
    expect(client.isIdle, isTrue);
  });

  testWidgets('pumpUntilSettled waits through server latency', (tester) async {
    final server = MockGraphQLServer(
      query: {'me': user('1', 'Ada')},
      latency: const Duration(milliseconds: 300),
    );
    final client = server.client(Query.root);
    await tester.pumpWidget(app(client, const MeScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('loading|'), findsOneWidget, reason: 'still in flight');

    await pumpUntilSettled(tester, client);
    expect(find.text('Ada|'), findsOneWidget);
  });

  testWidgets('pumpUntilSettled follows a waterfall to the end', (
    tester,
  ) async {
    final server = MockGraphQLServer(query: {'me': user('1', 'Ada')});
    final client = server.client(Query.root, warnOnWaterfall: false);
    await tester.pumpWidget(app(client, const MeScreen(showFriends: true)));

    await tester.pumpUntilSettled(client);
    expect(find.text('Ada|Bob,Cy'), findsOneWidget);
    expect(server.requests, hasLength(2), reason: 'name, then friends');
  });

  testWidgets('pumpUntilSettled covers mutations', (tester) async {
    final store = {'1': user('1', 'Ada')};
    final server = MockGraphQLServer(
      query: {'me': () => store['1']},
      mutation: {
        'rename': (Map<String, Object?> args) =>
            store['1']!..['name'] = args['name'],
      },
      latency: const Duration(milliseconds: 200),
    );
    final client = server.client(Query.root);
    await tester.pumpWidget(app(client, const MeScreen()));
    await tester.pumpUntilSettled(client);
    expect(find.text('Ada|'), findsOneWidget);

    final done = client.mutateWith(
      Mutation.root,
      (m) => m.rename(id: '1', name: 'Grace')?.name,
    );
    expect(client.isIdle, isFalse);
    await tester.pumpUntilSettled(client);
    expect(await done, 'Grace');
    expect(find.text('Grace|'), findsOneWidget, reason: 'entity notified');
  });

  testWidgets('pumpUntilSettled fails after the timeout', (tester) async {
    final server = MockGraphQLServer(
      query: {'me': user('1', 'Ada')},
      latency: const Duration(seconds: 5),
    );
    final client = server.client(Query.root);
    await tester.pumpWidget(app(client, const MeScreen()));
    await expectLater(
      () => tester.pumpUntilSettled(
        client,
        timeout: const Duration(milliseconds: 200),
      ),
      throwsA(isA<TestFailure>()),
    );
    // Drain the pending latency timer so the test binding is happy.
    await tester.pump(const Duration(seconds: 5));
  });

  test('disposeAfterTest returns the client it registers', () {
    final client = disposeAfterTest(
      SlingClient<Query>(
        endpoint: Uri.parse('http://x/graphql'),
        rootFactory: Query.root,
      ),
    );
    expect(client, isA<SlingClient<Query>>());
  });
}
