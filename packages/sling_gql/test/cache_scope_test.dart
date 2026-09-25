import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// `SlingClient.cacheScope` / `CacheScope` (TODO #12): typed, non-fetching
/// access to cached entities and root fields.
void main() {
  late List<PrintedOperation> sent;
  late SlingClient<Query> client;

  setUp(() async {
    sent = [];
    client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      onOperation: sent.add,
      httpClient: mockGraphQL((q, v) => meWithFriends()),
    );
    await client.resolve((q) => q.me.friends().map((f) => f.name).toList());
    sent.clear();
  });

  test('entity by id: generated typed accessor over Launch:<id>-style keys', () async {
    final bob = client.cacheScope.user('a');

    expect(bob, isNotNull);
    expect(bob!.path, [const Ref('User:a')]);
    expect(bob.name, 'Bob');
    expect(bob.isSkeleton, isFalse);
    expect(client.cacheScope.user('1')?.name, 'Ada');
    await pumpEventQueue();
    expect(sent, isEmpty);
  });

  test('unknown id → null (not a skeleton), and no request', () async {
    expect(client.cacheScope.user('nope'), isNull);
    await pumpEventQueue();
    expect(sent, isEmpty);
  });

  test('uncached field reads as null and never fetches', () async {
    final bob = client.cacheScope.user('a')!;

    expect(bob.age, isNull, reason: 'friends were fetched without age');
    expect(client.cacheScope.query.user(id: 'zzz')?.isSkeleton, isTrue);
    await pumpEventQueue();
    expect(sent, isEmpty);
  });

  test('query root: typed reads of root fields, served from the cache', () {
    final me = client.cacheScope.query.me;

    expect(me.name, 'Ada');
    expect(me.friends().map((f) => f.name), ['Bob', 'Cy']);
  });

  test('writing a scalar notifies dependent scopes once', () async {
    var changes = 0;
    final scope = client.createScope(onChanged: () => changes++);
    expect(scope.run((q) => q.me.friends().first.name), 'Bob');

    client.cacheScope.user('a')!.name = 'Bo';

    expect(changes, 1);
    expect(scope.run((q) => q.me.friends().first.name), 'Bo');
    await pumpEventQueue();
    expect(sent, isEmpty);
  });

  test('an unrelated write does not notify', () {
    var changes = 0;
    final scope = client.createScope(onChanged: () => changes++);
    scope.run((q) => q.me.name);

    client.cacheScope.user('b')!.name = 'Cyd';

    expect(changes, 0);
  });

  test('writes in an optimistic callback are journaled and rolled back', () async {
    final failing = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      cache: client.cache,
      httpClient: MockClient((_) async => http.Response('boom', 500)),
    );

    final result = failing.mutateWith(
      Mutation.root,
      (m) => m.rename(id: 'a', name: 'Bo')?.name,
      optimistic: () => failing.cacheScope.user('a')!.name = 'Bo',
    );
    expect(failing.cacheScope.user('a')!.name, 'Bo', reason: 'optimistic');
    await expectLater(result, throwsA(isA<SlingException>()));

    expect(failing.cacheScope.user('a')!.name, 'Bob', reason: 'rolled back');
  });

  test('with Normalization.none there are no entities to address', () async {
    final plain = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      cache: Cache(normalization: Normalization.none),
      httpClient: mockGraphQL((q, v) => meWithFriends()),
    );
    await plain.resolve((q) => q.me.name);

    expect(plain.cacheScope.user('1'), isNull);
    expect(plain.cacheScope.query.me.name, 'Ada');
  });
}
