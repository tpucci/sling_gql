import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

void main() {
  test('isFetched: not fetched vs. server null vs. fetched, and with args',
      () async {
    final requestCount = <int>[0];
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      onOperation: (_) => requestCount[0]++,
      httpClient: mockGraphQL((q, v) => {
            'me': {
              '__typename': 'User',
              'id': '1',
              'name': 'Ada',
              'age': null, // explicit server null
              _limitAlias(2): [
                {'__typename': 'User', 'id': 'a', 'name': 'Bob'},
              ],
            },
          }),
    );

    // Warm the cache: `name`, `age` (server null) and `friends(limit: 2)`.
    await client.resolve(
      (q) => (q.me.name, q.me.age, q.me.friends(limit: 2).map((f) => f.name).toList()),
    );
    final requestsAfterWarmup = requestCount[0];

    final scope = client.createScope(onChanged: () {});
    late bool nameFetched, ageFetched, friendsSameArgs, friendsOtherArgs;
    scope.run((q) {
      final me = q.me;
      nameFetched = me.isFetched('name');
      ageFetched = me.isFetched('age');
      friendsSameArgs = me.isFetched('friends', args: {'limit': Arg('Int', 2)});
      friendsOtherArgs = me.isFetched('friends', args: {'limit': Arg('Int', 5)});
    });

    expect(nameFetched, isTrue);
    expect(ageFetched, isTrue, reason: 'a server null still counts as fetched');
    expect(friendsSameArgs, isTrue, reason: 'same args as the fetch: same alias');
    expect(friendsOtherArgs, isFalse, reason: 'different args: a different, unfetched alias');

    expect(scope.hasMissingData, isFalse,
        reason: 'isFetched must not record a miss, even for the missing case');
    expect(scope.deps, {'ROOT_QUERY.me'},
        reason: 'reading `me` records its own dep as usual, but none of the '
            'four isFetched calls add a dependency on the field they check');
    expect(requestCount[0], requestsAfterWarmup,
        reason: 'isFetched alone must never cause a fetch');
  });

  test('isFetched is false for a field on an object that was never fetched at all',
      () async {
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: mockGraphQL((q, v) => meWithFriends()),
    );

    final scope = client.createScope(onChanged: () {});
    late bool fetched;
    scope.run((q) {
      // `user(id:)` itself is a legitimate miss (nothing cached for id
      // "nope" yet); isFetched on one of its fields must read through that
      // skeleton as "not fetched" without adding another miss on top.
      final missesBefore = scope.hasMissingData;
      final user = q.user(id: 'nope');
      expect(missesBefore, isFalse);
      fetched = user?.isFetched('name') ?? false;
    });

    expect(fetched, isFalse);
  });
}

/// Mirrors the alias `friends(limit:)` gets in `test_schema.dart`'s printer.
String _limitAlias(int limit) {
  final sel = Selection.root('query').child('friends', {'limit': Arg('Int', limit)});
  return sel.alias;
}
