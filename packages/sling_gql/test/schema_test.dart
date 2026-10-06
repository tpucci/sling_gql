import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

// #25: the key field the generator ran with travels in `slingSchema`, and
// `SlingClient(schema:)` builds its cache from it.

const _uuidSchema = SlingSchema<Query, Mutation>(
  query: Query.root,
  mutation: Mutation.root,
  keyField: 'uuid',
);

void main() {
  test('SlingClient(schema:) takes the root factory and key field', () async {
    final documents = <String>[];
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: _uuidSchema,
      httpClient: MockClient((req) async {
        documents.add(
          (jsonDecode(req.body) as Map<String, Object?>)['query'] as String,
        );
        return http.Response(
          jsonEncode({
            'data': {
              'me': {'__typename': 'User', 'uuid': 'u1', 'name': 'Ada'},
            },
          }),
          200,
        );
      }),
    );
    addTearDown(client.dispose);

    expect(client.rootFactory, same(_uuidSchema.query));
    expect(client.schema, same(_uuidSchema));
    expect(client.cache.normalization.keyField, 'uuid');

    final name = await client.resolve((q) => q.me.name);
    expect(name, 'Ada');
    // Keyed selections fetch the schema's key field, and the response is
    // normalized on it.
    expect(documents.single, contains('uuid'));
    expect(documents.single, isNot(contains(RegExp(r'\bid\b'))));
    expect(client.cacheScope.entity('User', 'u1', User.new)?.name, 'Ada');
  });

  test('the default schema key field is id', () {
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
    );
    addTearDown(client.dispose);
    expect(client.cache.normalization.keyField, 'id');
    expect(slingSchema.normalization.keyField, 'id');
  });

  test(
    'SlingSchema.hash is the generated code fingerprint, null by default',
    () {
      expect(
        const SlingSchema<Query, Mutation>(query: Query.root, hash: 'abc').hash,
        'abc',
      );
      expect(_uuidSchema.hash, isNull);
    },
  );

  test('SlingSchema.fields carries the generated field signatures, null by '
      'default', () {
    const schema = SlingSchema<Query, Mutation>(
      query: Query.root,
      fields: {
        'ROOT_QUERY': {'me': 'User'},
        'User': {'id': 'ID!', 'name': 'String'},
      },
    );
    expect(schema.fields?['User'], {'id': 'ID!', 'name': 'String'});
    expect(_uuidSchema.fields, isNull);
  });

  test('a cache normalizing on another key field fails an assert', () {
    expect(
      () => SlingClient<Query>(
        endpoint: testEndpoint,
        schema: _uuidSchema,
        cache: Cache(),
      ),
      throwsA(
        isA<AssertionError>().having(
          (e) => e.message,
          'message',
          contains('--key-field uuid'),
        ),
      ),
    );
    // Matching, and explicitly unnormalized, caches are accepted.
    SlingClient<Query>(
      endpoint: testEndpoint,
      schema: _uuidSchema,
      cache: Cache(normalization: _uuidSchema.normalization),
    ).dispose();
    SlingClient<Query>(
      endpoint: testEndpoint,
      schema: _uuidSchema,
      cache: Cache(normalization: Normalization.none),
    ).dispose();
  });

  test('either schema: or rootFactory: is required', () {
    expect(
      () => SlingClient<Query>(endpoint: testEndpoint),
      throwsA(isA<AssertionError>()),
    );
  });

  testWidgets('SlingScope falls back to the client schema for its roots', (
    tester,
  ) async {
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      schema: slingSchema,
    );
    addTearDown(client.dispose);

    late RootFactory<Mutation> mutationRoot;
    late RootFactory<Subscription> subscriptionRoot;
    await tester.pumpWidget(
      SlingScope<Query>(
        client: client,
        child: Builder(
          builder: (context) {
            mutationRoot = SlingScope.mutationRootOf<Mutation>(context);
            subscriptionRoot = SlingScope.subscriptionRootOf<Subscription>(
              context,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(mutationRoot, same(slingSchema.mutation));
    expect(subscriptionRoot, same(slingSchema.subscription));
  });
}
