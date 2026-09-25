import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

void main() {
  test('refetchQueries: re-requests exactly the scopes that read the named '
      'root field, matching by field name regardless of arguments', () async {
    var meCalls = 0;
    var userCalls = 0;
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, Object?>;
        final query = body['query'] as String;
        if (query.startsWith('mutation')) {
          return http.Response(
            jsonEncode({
              'data': {
                'rename_x': {'__typename': 'User', 'id': '1', 'name': 'Grace'},
              },
            }),
            200,
          );
        }
        final data = <String, Object?>{};
        if (query.contains('me {')) {
          meCalls++;
          data['me'] = {'__typename': 'User', 'id': '1', 'name': 'Ada'};
        }
        if (RegExp(r'user(_\w+)?: user').hasMatch(query)) {
          userCalls++;
          final alias = RegExp(r'(user(?:_\w+)?): user').firstMatch(query)!.group(1)!;
          data[alias] = {'__typename': 'User', 'id': 'a', 'name': 'Bob'};
        }
        return http.Response(jsonEncode({'data': data}), 200);
      }),
    );

    // Scope A reads `me` (a query field named `me`).
    final meScope = client.createScope(onChanged: () {});
    meScope.run((q) => q.me.name);
    await meScope.whenSettled;

    // Scope B reads `user(id:)` only \u2014 a different root field name.
    final userScope = client.createScope(onChanged: () {});
    userScope.run((q) => q.user(id: 'a')?.name);
    await userScope.whenSettled;

    expect(meCalls, 1);
    expect(userCalls, 1);

    await client.mutateWith(
      Mutation.root,
      (m) => m.rename(id: '1', name: 'Grace')?.name,
      refetchQueries: ['me'],
    );
    await meScope.whenSettled;

    expect(meCalls, 2, reason: 'the scope reading `me` is refetched');
    expect(userCalls, 1, reason: 'the scope reading only `user(id:)` is not');
  });

  test('refetchQueries: matches a root field regardless of its arguments',
      () async {
    var userCalls = 0;
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, Object?>;
        final query = body['query'] as String;
        if (query.startsWith('mutation')) {
          return http.Response(
            jsonEncode({
              'data': {
                'rename_x': {'__typename': 'User', 'id': '1', 'name': 'Grace'},
              },
            }),
            200,
          );
        }
        userCalls++;
        final alias = RegExp(r'(user(?:_\w+)?): user').firstMatch(query)!.group(1)!;
        return http.Response(
          jsonEncode({
            'data': {
              alias: {'__typename': 'User', 'id': 'a', 'name': 'Bob'},
            },
          }),
          200,
        );
      }),
    );

    final scope = client.createScope(onChanged: () {});
    scope.run((q) => q.user(id: 'a')?.name);
    await scope.whenSettled;
    expect(userCalls, 1);

    await client.mutateWith(
      Mutation.root,
      (m) => m.rename(id: '1', name: 'Grace')?.name,
      refetchQueries: ['user'],
    );
    await scope.whenSettled;

    expect(userCalls, 2,
        reason: 'matched on Selection.field (`user`), not the aliased/hashed key');
  });

  test('refetchQueries: no refetch when the mutation fails', () async {
    var meCalls = 0;
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, Object?>;
        final query = body['query'] as String;
        if (query.startsWith('mutation')) {
          return http.Response(
            jsonEncode({
              'errors': [
                {'message': 'boom'},
              ],
            }),
            200,
          );
        }
        meCalls++;
        return http.Response(
          jsonEncode({
            'data': {
              'me': {'__typename': 'User', 'id': '1', 'name': 'Ada'},
            },
          }),
          200,
        );
      }),
    );

    final scope = client.createScope(onChanged: () {});
    scope.run((q) => q.me.name);
    await scope.whenSettled;
    expect(meCalls, 1);

    await expectLater(
      client.mutateWith(
        Mutation.root,
        (m) => m.rename(id: '1', name: 'Grace')?.name,
        refetchQueries: ['me'],
      ),
      throwsA(isA<SlingException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(meCalls, 1, reason: 'a failed mutation must not trigger refetchQueries');
  });
}
