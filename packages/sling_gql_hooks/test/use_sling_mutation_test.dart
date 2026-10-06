import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_hooks/sling_gql_hooks.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

import 'support/test_schema.dart';

/// [useSlingMutation] behaves like a [MutationBuilder]: `mutate` resolves to
/// the body's value or `null`, the state follows the latest call, the
/// response reaches every widget showing the entity.
void main() {
  late Map<String, Object?> ada;
  late Completer<void> gate;
  late bool fail;
  late MockGraphQLServer server;
  late SlingClient<Query> client;
  late Mutate<Mutation> mutate;
  late MutationState state;
  late int mutationBuilds;

  setUp(() {
    ada = user('1', 'Ada');
    gate = Completer<void>()..complete();
    fail = false;
    mutationBuilds = 0;
    server = MockGraphQLServer(
      query: {'me': ada},
      mutation: {
        'rename': (Map<String, Object?> args) async {
          await gate.future;
          if (fail) throw GraphQLError('nope');
          return ada..['name'] = args['name'];
        },
      },
    );
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    RootFactory<Mutation>? root,
  }) async {
    client = server.client(Query.root);
    await tester.pumpWidget(
      SlingScope<Query>(
        client: client,
        schema: root == null ? slingSchema : null,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              HookBuilder(
                builder: (context) {
                  final (name, _) = useSlingQuery((Query q) => q.me.name);
                  return Text('query:${name ?? '…'}');
                },
              ),
              HookBuilder(
                builder: (context) {
                  mutationBuilds++;
                  (mutate, state) = useSlingMutation<Mutation>(root: root);
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpUntilSettled(client);
  }

  Future<String?> rename(String name) =>
      mutate<String?>((m) => m.rename(id: '1', name: name)?.name);

  testWidgets('mutate resolves to the body value; the query rebuilds', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('query:Ada'), findsOneWidget);
    expect(state.isLoading, isFalse);
    expect(state.data, isNull);

    gate = Completer<void>();
    final result = rename('Bea');
    await tester.pump();
    expect(state.isLoading, isTrue);
    expect(server.lastRequest.type, 'mutation');

    gate.complete();
    expect(await tester.runAsync(() => result), 'Bea');
    await tester.pumpUntilSettled(client);
    expect(state.isLoading, isFalse);
    expect(state.data, 'Bea');
    expect(state.error, isNull);
    expect(find.text('query:Bea'), findsOneWidget);
    expect(server.requests.map((r) => r.type), ['query', 'mutation']);
  });

  testWidgets('a failure resolves to null, sets error and clears data', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.runAsync(() => rename('Bea'));
    await tester.pump();
    expect(state.data, 'Bea');

    fail = true;
    expect(await tester.runAsync(() => rename('Cy')), isNull);
    await tester.pump();
    expect(state.isLoading, isFalse);
    expect(state.error, isNotNull);
    expect(state.data, isNull);
  });

  testWidgets('errorPolicy all: state has both data and the error', (
    tester,
  ) async {
    await pumpApp(tester);
    fail = true;
    final result = await tester.runAsync(
      () => mutate<String>((m) {
        m.rename(id: '1', name: 'Cy')?.name;
        return 'landed';
      }, errorPolicy: ErrorPolicy.all),
    );
    await tester.pump();
    expect(result, 'landed');
    expect(state.data, 'landed');
    expect(
      state.error,
      isA<SlingGraphQLException>().having((e) => e.isPartial, 'partial', true),
    );
  });

  testWidgets('an older call finishing late does not overwrite a newer one', (
    tester,
  ) async {
    await pumpApp(tester);
    final slow = Completer<void>();
    gate = slow;
    final older = rename('Old');
    await tester.pump();
    gate = Completer<void>()..complete();
    final newer = rename('New');
    await tester.runAsync(() => newer);
    await tester.pump();
    expect(state.data, 'New');

    fail = true;
    slow.complete();
    expect(await tester.runAsync(() => older), isNull);
    await tester.pump();
    expect(state.error, isNull);
    expect(state.data, 'New');
    expect(state.isLoading, isFalse);
  });

  testWidgets('mutate is the same function across builds', (tester) async {
    await pumpApp(tester);
    final first = mutate;
    final builds = mutationBuilds;
    await tester.runAsync(() => rename('Bea'));
    await tester.pump();
    expect(mutationBuilds, greaterThan(builds));
    expect(mutate, first);
  });

  testWidgets('an explicit root works without a schema on SlingScope', (
    tester,
  ) async {
    await pumpApp(tester, root: Mutation.root);
    expect(await tester.runAsync(() => rename('Bea')), 'Bea');
  });

  testWidgets('a call settling after unmount does not touch the widget', (
    tester,
  ) async {
    await pumpApp(tester);
    gate = Completer<void>();
    final result = rename('Bea');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    gate.complete();
    expect(await tester.runAsync(() => result), 'Bea');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline: a call the server cannot be reached for is queued '
      '(isQueued), then resolves when replayed', (tester) async {
    await pumpApp(tester);
    server.failNext(const MockFailure.network());
    final result = mutate<String?>(
      (m) => m.rename(id: '1', name: 'Bea')?.name,
      offline: true,
    );
    await tester.pump();
    expect(state.isQueued, isTrue);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);

    unawaited(client.replayQueue());
    await tester.pumpUntilSettled(client);
    expect(await result, 'Bea');
    expect(state.isQueued, isFalse);
    expect(state.data, 'Bea');
    expect(find.text('query:Bea'), findsOneWidget);
  });
}
