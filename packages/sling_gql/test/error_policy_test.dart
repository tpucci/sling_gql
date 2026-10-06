import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/internal.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// Answers `me { name age }` with `age: null` and an error at `me.age`,
/// `user(id:) { name }` with `name: null` and an error at its path, and
/// `rename` with `name: null` and an error. [ok] answers everything.
class _Server {
  int calls = 0;
  bool ok = false;

  late final http.Client httpClient = MockClient((request) async {
    calls++;
    final query = (jsonDecode(request.body) as Map)['query'] as String;
    final data = <String, Object?>{};
    final errors = <Map<String, Object?>>[];
    if (query.startsWith('mutation')) {
      final alias = RegExp(r'(rename_\w+): rename').firstMatch(query)![1]!;
      data[alias] = {'__typename': 'User', 'id': '1', 'name': null};
      errors.add({
        'message': 'name refused',
        'path': [alias, 'name'],
      });
    }
    if (query.contains('me {')) {
      data['me'] = {
        '__typename': 'User',
        'id': '1',
        'name': 'Ada',
        'age': ok ? 36 : null,
      };
      if (!ok) {
        errors.add({
          'message': 'age unavailable',
          'path': ['me', 'age'],
        });
      }
    }
    final user = RegExp(r'(user_\w+): user').firstMatch(query)?[1];
    if (user != null) {
      data[user] = {'__typename': 'User', 'id': 'a', 'name': ok ? 'Bob' : null};
      if (!ok) {
        errors.add({
          'message': 'name unavailable',
          'path': [user, 'name'],
        });
      }
    }
    return http.Response(
      jsonEncode({'data': data, if (errors.isNotEmpty) 'errors': errors}),
      200,
    );
  });

  SlingClient<Query> client({ErrorPolicy errorPolicy = ErrorPolicy.none}) =>
      SlingClient<Query>(
        endpoint: testEndpoint,
        schema: slingSchema,
        httpClient: httpClient,
        errorPolicy: errorPolicy,
      );
}

/// A scope that re-runs [body] whenever the client asks, like a widget.
QueryScope<Query> _live(
  SlingClient<Query> client,
  void Function(Query q) body, {
  ErrorPolicy? errorPolicy,
}) {
  late QueryScope<Query> scope;
  scope = client.createScope(
    onChanged: () => scope.run(body),
    errorPolicy: errorPolicy,
  );
  scope.run(body);
  return scope;
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void _meNameAge(Query q) => (q.me.name, q.me.age);

void main() {
  test('none (default): the errored path is pruned and the error is the '
      "scope's", () async {
    final server = _Server();
    final client = server.client();
    final scope = _live(client, _meNameAge);
    await _settle();
    expect(scope.errorPolicy, ErrorPolicy.none);
    expect(client.cache.read('query', ['me', 'age']), missing);
    expect(scope.hasMissingData, isTrue);
    expect(scope.error, isA<SlingGraphQLException>());
    expect(server.calls, 1);
  });

  test(
    'all: the null is cached as sent and the error stays until refetch',
    () async {
      final server = _Server();
      final client = server.client();
      final scope = _live(client, _meNameAge, errorPolicy: ErrorPolicy.all);
      await _settle();
      expect(client.cache.read('query', ['me', 'age']), isNull);
      expect(scope.hasMissingData, isFalse);
      final error = scope.error as SlingGraphQLException;
      expect(error.isPartial, isTrue);
      expect(error.errors.single.path, ['me', 'age']);

      // Rebuilds served from the cache keep the error (data is complete).
      scope.run(_meNameAge);
      await _settle();
      expect(scope.error, same(error));
      expect(server.calls, 1);

      server.ok = true;
      await scope.refetch();
      expect(scope.error, isNull);
      expect(client.cache.read('query', ['me', 'age']), 36);
    },
  );

  test('ignore: the null is cached, no error, no refetch loop', () async {
    final server = _Server();
    final client = server.client();
    final scope = _live(client, _meNameAge, errorPolicy: ErrorPolicy.ignore);
    await _settle();
    expect(client.cache.read('query', ['me', 'age']), isNull);
    expect(scope.error, isNull);
    expect(scope.hasMissingData, isFalse);
    scope.run(_meNameAge);
    await _settle();
    expect(server.calls, 1);
  });

  test('client-wide default applies to scopes that set none', () async {
    final server = _Server();
    final client = server.client(errorPolicy: ErrorPolicy.ignore);
    final scope = _live(client, _meNameAge);
    expect(scope.errorPolicy, ErrorPolicy.ignore);
    await _settle();
    expect(scope.error, isNull);
    expect(client.cache.read('query', ['me', 'age']), isNull);
  });

  test('a batch: a field selected by a none scope is pruned, even for an '
      'ignore scope, which neither reports it nor loops', () async {
    final server = _Server();
    final client = server.client();
    final strict = _live(client, _meNameAge);
    final lax = _live(client, _meNameAge, errorPolicy: ErrorPolicy.ignore);
    await _settle();
    expect(server.calls, 1, reason: 'one batch');
    expect(client.cache.read('query', ['me', 'age']), missing);
    expect(strict.error, isA<SlingGraphQLException>());
    expect(lax.error, isNull);
    expect(lax.hasMissingData, isTrue);
    for (var i = 0; i < 3; i++) {
      lax.run(_meNameAge);
      await _settle();
    }
    expect(server.calls, 1, reason: 'the hidden error still blocks refetching');
  });

  test('a batch: errored paths are decided per root field', () async {
    final server = _Server();
    final client = server.client();
    _live(client, _meNameAge);
    final lax = _live(
      client,
      (q) => q.user(id: 'a')?.name,
      errorPolicy: ErrorPolicy.ignore,
    );
    await _settle();
    expect(server.calls, 1);
    expect(client.cache.read('query', ['me', 'age']), missing);
    expect(client.cache.entity('User:a'), containsPair('name', null));
    expect(lax.hasMissingData, isFalse);
  });

  test('a response without data is an error under every policy', () async {
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
      errorPolicy: ErrorPolicy.ignore,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': null,
            'errors': [
              {'message': 'nope'},
            ],
          }),
          200,
        ),
      ),
    );
    final scope = _live(client, _meNameAge);
    await _settle();
    expect(
      scope.error,
      isA<SlingGraphQLException>().having((e) => e.isPartial, 'partial', false),
    );
  });

  group('resolve', () {
    test('none throws the partial error', () async {
      final client = _Server().client();
      await expectLater(
        client.resolve(_meNameAge),
        throwsA(isA<SlingGraphQLException>()),
      );
    });

    test('all throws it with the value computed from the cache', () async {
      final client = _Server().client();
      await expectLater(
        client.resolve(
          (q) => (q.me.name, q.me.age),
          errorPolicy: ErrorPolicy.all,
        ),
        throwsA(
          isA<SlingGraphQLException>()
              .having((e) => e.isPartial, 'partial', true)
              .having((e) => e.data, 'data', ('Ada', null)),
        ),
      );
    });

    test('ignore returns the value', () async {
      final client = _Server().client();
      final value = await client.resolve(
        (q) => (q.me.name, q.me.age),
        errorPolicy: ErrorPolicy.ignore,
      );
      expect(value, ('Ada', null));
    });
  });

  group('mutateWith', () {
    test('ignore: lands like a success — no rollback, refetchQueries run, '
        'the value is returned', () async {
      final server = _Server()..ok = true;
      final client = server.client();
      final bob = await client.resolve((q) => q.user(id: 'a')!);
      final me = _live(client, (q) => q.me.name);
      await _settle();
      server.calls = 0;

      final value = await client.mutateWith(
        Mutation.root,
        (m) {
          final u = m.rename(id: '1', name: 'Zed');
          return (u?.id, u?.name);
        },
        optimistic: () => bob.age = 30,
        refetchQueries: ['me'],
        errorPolicy: ErrorPolicy.ignore,
      );
      expect(value, ('1', null));
      expect(client.cache.entity('User:a'), containsPair('age', 30));
      expect(client.cache.entity('User:1'), containsPair('name', null));
      await _settle();
      expect(server.calls, 2, reason: 'the mutation, then the me refetch');
      expect(me.error, isNull);
    });

    test('all: throws with the value in data', () async {
      final client = _Server().client();
      await expectLater(
        client.mutateWith(Mutation.root, (m) {
          final u = m.rename(id: '1', name: 'Zed');
          return (u?.id, u?.name);
        }, errorPolicy: ErrorPolicy.all),
        throwsA(
          isA<SlingGraphQLException>().having((e) => e.data, 'data', (
            '1',
            null,
          )),
        ),
      );
    });

    testWidgets('MutationBuilder with all: both state.data and state.error', (
      tester,
    ) async {
      final client = _Server().client();
      late Mutate<Mutation> mutate;
      late MutationState state;
      await tester.pumpWidget(
        SlingScope<Query>(
          client: client,
          child: MutationBuilder<Mutation>(
            builder: (context, m, s) {
              mutate = m;
              state = s;
              return const SizedBox();
            },
          ),
        ),
      );
      final result = await tester.runAsync(
        () => mutate(
          (m) => m.rename(id: '1', name: 'Zed')?.id,
          errorPolicy: ErrorPolicy.all,
        ),
      );
      await tester.pump();
      expect(result, '1');
      expect(state.data, '1');
      expect(state.error, isA<SlingGraphQLException>());
    });
  });

  testWidgets('QueryBuilder(errorPolicy:) reaches its scope', (tester) async {
    final client = _Server().client();
    late QueryState state;
    int? age = -1;
    await tester.pumpWidget(
      SlingScope<Query>(
        client: client,
        child: QueryBuilder<Query>(
          errorPolicy: ErrorPolicy.all,
          builder: (context, q, s) {
            state = s;
            age = q.me.age;
            q.me.name;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(age, isNull);
    expect(state.hasMissingData, isFalse);
    expect(state.error, isA<SlingGraphQLException>());
  });
}
