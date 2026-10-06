import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// [MutationBuilder]'s root resolution: an explicit `root:` always wins;
/// otherwise it comes from the nearest [SlingScope]'s `schema:`, or from the
/// schema its client was built with. Missing both is a clear assertion, not
/// a silent null.
void main() {
  // `rename` is aliased by the printer (see `selection.dart`); echo it back
  // under whatever alias the operation used, like a real server would.
  SlingClient<Query> client({SlingSchema<Query, Mutation>? schema}) =>
      SlingClient<Query>(
        endpoint: testEndpoint,
        rootFactory: schema == null ? Query.root : null,
        schema: schema,
        httpClient: mockGraphQL((query, vars) {
          final alias = RegExp(r'(rename_\w+):').firstMatch(query)!.group(1)!;
          return {
            alias: {
              '__typename': 'User',
              'id': vars['id'],
              'name': vars['name'],
            },
          };
        }),
      );

  Widget harness({
    required SlingClient<Query> client,
    SlingSchema<Query, Mutation>? schema,
    RootFactory<Mutation>? explicitRoot,
    required void Function(Mutate<Mutation> mutate) onBuild,
  }) => SlingScope<Query>(
    client: client,
    schema: schema,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: MutationBuilder<Mutation>(
        root: explicitRoot,
        builder: (context, mutate, state) {
          onBuild(mutate);
          return const SizedBox.shrink();
        },
      ),
    ),
  );

  testWidgets('resolves the root from SlingScope(schema:)', (tester) async {
    Mutate<Mutation>? mutate;
    await tester.pumpWidget(
      harness(
        client: client(),
        schema: slingSchema,
        onBuild: (m) => mutate = m,
      ),
    );
    await tester.pump();

    final result = await mutate!((m) => m.rename(id: '1', name: 'Ada')?.name);
    await tester.pumpAndSettle();

    expect(result, 'Ada');
  });

  testWidgets("resolves the root from the client's schema", (tester) async {
    Mutate<Mutation>? mutate;
    await tester.pumpWidget(
      harness(
        client: client(schema: slingSchema),
        onBuild: (m) => mutate = m,
      ),
    );
    await tester.pump();

    final result = await mutate!((m) => m.rename(id: '1', name: 'Ada')?.name);
    await tester.pumpAndSettle();

    expect(result, 'Ada');
  });

  testWidgets("an explicit root: wins over the scope's schema", (tester) async {
    // The scope offers no schema at all: if MutationBuilder
    // fell back to the scope instead of using its own `root:`, this would
    // throw the "no root" assertion. It succeeding proves `root:` wins.
    Mutate<Mutation>? mutate;
    await tester.pumpWidget(
      harness(
        client: client(),
        explicitRoot: Mutation.root,
        onBuild: (m) => mutate = m,
      ),
    );
    await tester.pump();

    final result = await mutate!((m) => m.rename(id: '1', name: 'Ada')?.name);
    await tester.pumpAndSettle();

    expect(result, 'Ada');
  });

  testWidgets(
    'missing root: and no schema on the SlingScope or its client throws a '
    'helpful '
    'assertion',
    (tester) async {
      await tester.pumpWidget(harness(client: client(), onBuild: (_) {}));

      final error = tester.takeException();
      expect(error, isAssertionError);
      expect(
        error.toString(),
        contains('has no schema: (nor a client built with one)'),
      );
    },
  );
}
