import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// #29 — a mutation response with both `data` and `errors` is a failure:
/// the fields that resolved are written, the errored paths are pruned, the
/// optimistic writes are undone *before* the resolved fields land (so the
/// server's values win), `refetchQueries` does not run, and the call rejects
/// (`MutationBuilder`: `mutate` resolves `null`, `state.error` is set).
void main() {
  late SlingClient<Query> client;
  late List<String> sent;

  // `me` as a query; `rename` answers `name` and errors on `age`.
  http.Client server() => MockClient((req) async {
    final body = jsonDecode(req.body) as Map<String, Object?>;
    final query = body['query'] as String;
    sent.add(query);
    if (!query.startsWith('mutation')) {
      return http.Response(
        jsonEncode({
          'data': {
            'me': {'__typename': 'User', 'id': '1', 'name': 'Ada', 'age': 36},
          },
        }),
        200,
      );
    }
    final alias = RegExp(r'(rename_\w+):').firstMatch(query)!.group(1)!;
    return http.Response(
      jsonEncode({
        'data': {
          alias: {
            '__typename': 'User',
            'id': '1',
            'name': 'Grace Hopper',
            'age': null,
          },
        },
        'errors': [
          {
            'message': 'age is unavailable',
            'path': [alias, 'age'],
          },
        ],
      }),
      200,
    );
  });

  (String?, int?) renameBody(Mutation m) {
    final user = m.rename(id: '1', name: 'Grace Hopper');
    return (user?.name, user?.age);
  }

  void optimistic() {
    client.cacheScope.user('1')!
      ..name = 'Grace'
      ..age = 99;
  }

  User me() => client.cacheScope.user('1')!;

  setUp(() async {
    sent = [];
    client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      httpClient: server(),
    );
    addTearDown(client.dispose);
    final scope = client.createScope(onChanged: () {});
    scope.run((q) => (q.me.name, q.me.age));
    await scope.whenSettled;
    scope.dispose();
    sent.clear();
  });

  test('the resolved fields are written, the errored path is not, and the '
      'call rejects with the GraphQL errors', () async {
    await expectLater(
      client.mutateWith(Mutation.root, renameBody),
      throwsA(
        isA<SlingException>()
            .having((e) => e.message, 'message', 'age is unavailable')
            .having((e) => e.graphqlErrors, 'graphqlErrors', hasLength(1)),
      ),
    );

    expect(me().name, 'Grace Hopper');
    expect(
      me().age,
      36,
      reason: 'the server null at an errored path is pruned',
    );
  });

  test('the optimistic writes are undone before the resolved fields land: '
      'the server value wins, the errored field is restored', () async {
    final result = client.mutateWith(
      Mutation.root,
      renameBody,
      optimistic: optimistic,
    );
    expect((me().name, me().age), ('Grace', 99));
    await expectLater(result, throwsA(isA<SlingException>()));

    expect(
      me().name,
      'Grace Hopper',
      reason: 'the rollback must not clobber a field the server resolved',
    );
    expect(me().age, 36, reason: 'the optimistic write to the errored field');
  });

  test('every scope reading a changed field is notified once', () async {
    var changes = 0;
    client
        .createScope(onChanged: () => changes++)
        .run((q) => (q.me.name, q.me.age));
    final result = client.mutateWith(
      Mutation.root,
      renameBody,
      optimistic: optimistic,
    );
    expect(changes, 2, reason: 'one per optimistic setter');
    await expectLater(result, throwsA(isA<SlingException>()));
    expect(changes, 3, reason: 'rollback and resolved fields notify together');
  });

  test('refetchQueries does not run', () async {
    final scope = client.createScope(onChanged: () {});
    scope.run((q) => q.me.name);
    await expectLater(
      client.mutateWith(Mutation.root, renameBody, refetchQueries: ['me']),
      throwsA(isA<SlingException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(sent, hasLength(1), reason: 'the mutation only');
    scope.dispose();
  });

  test('the mutation root fields do not stay in the cache', () async {
    await expectLater(
      client.mutateWith(Mutation.root, renameBody),
      throwsA(isA<SlingException>()),
    );

    expect(client.cache.entity('ROOT_MUTATION') ?? const {}, isEmpty);
  });

  testWidgets('MutationBuilder: mutate resolves null, state.error is set, '
      'state.data is null', (tester) async {
    late MutationState state;
    late Mutate<Mutation> mutate;
    await tester.pumpWidget(
      SlingScope<Query>(
        client: client,
        child: MutationBuilder<Mutation>(
          builder: (context, m, s) {
            mutate = m;
            state = s;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final result = await tester.runAsync(() => mutate(renameBody));
    await tester.pump();

    expect(result, isNull);
    expect(state.error, isA<SlingException>());
    expect(state.data, isNull);
    expect(me().name, 'Grace Hopper', reason: 'resolved fields are cached');
  });
}
