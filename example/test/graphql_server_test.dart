import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_example/generated/schema.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

/// What the runtime puts on the wire, checked against a real GraphQL server
/// rather than `MockGraphQLServer`: batching, aliases, fragments, mutations,
/// partial errors and SSE subscriptions. Runs against yoga (`melos run
/// test:example`) and, with `--dart-define=SLING_API=…`, against the same
/// schema and resolvers behind graphql-http + graphql-sse (`melos run
/// test:example:graphql-http`).
void main() {
  useRealNetwork();
  final endpoint = Uri.parse(
    const String.fromEnvironment(
      'SLING_API',
      defaultValue: 'http://localhost:4000/graphql',
    ),
  );
  // No artificial latency: these tests count requests, not wait for them.
  const headers = {'x-mock-latency-ms': '0'};

  late List<String> documents;
  late SlingClient<Query> client;
  setUp(() {
    documents = [];
    final httpClient = http.Client();
    client = SlingClient<Query>(
      endpoint: endpoint,
      schema: slingSchema,
      headers: headers,
      httpClient: httpClient,
      transport: (request) async {
        documents.add(jsonDecode(request.body)['query'] as String);
        return http.Response.fromStream(await httpClient.send(request));
      },
    );
    addTearDown(client.dispose);
  });

  /// Sends [document] outside [client] (its cache never sees the answer).
  Future<Map<String, Object?>> post(
    String document, [
    Map<String, Object?> variables = const {},
  ]) async {
    final response = await http.post(
      endpoint,
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode({'query': document, 'variables': variables}),
    );
    expect(response.statusCode, 200, reason: response.body);
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  test('two scopes in one microtask: one request, both answered', () async {
    final company = client.createScope(onChanged: () {});
    final rockets = client.createScope(onChanged: () {});
    addTearDown(company.dispose);
    addTearDown(rockets.dispose);
    company.run((q) => q.company?.name);
    rockets.run((q) => [for (final r in q.rockets ?? const <Rocket>[]) r.name]);
    await Future.wait([company.whenSettled, rockets.whenSettled]);

    expect(documents, hasLength(1));
    expect(company.run((q) => q.company?.name), 'Sling Space');
    expect(rockets.run((q) => q.rockets?.map((r) => r.name)), [
      'Falcon 9',
      'Starship',
      'Atlas V',
      'Ariane 6',
      'Vulcan Centaur',
    ]);
  });

  test('one field with two argument sets: two aliases, one request', () async {
    final (first, filtered) = await client.resolve(
      (q) => (
        q.launches(first: 2)?.nodes?.map((l) => l.name).toList(),
        q
            .launches(
              first: 3,
              filter: LaunchFilter(status: LaunchStatus.success),
            )
            ?.nodes
            ?.map((l) => l.status)
            .toList(),
      ),
    );
    expect(documents, hasLength(1));
    expect(
      RegExp(r'launches_\w+: launches\(').allMatches(documents.single),
      hasLength(2),
    );
    // Other test files schedule launches on the same server, so compare
    // with what it lists now rather than with fixed names.
    final listed = await post('{ launches(first: 2) { nodes { name } } }');
    final nodes =
        ((listed['data']! as Map)['launches']! as Map)['nodes']! as List;
    expect(first, [for (final n in nodes) (n as Map)['name']]);
    expect(first, hasLength(2));
    expect(filtered, List.filled(3, LaunchStatus.success));
  });

  test('a union and an interface: inline fragments, one request; a field in '
      'two fragments gets one response name per type', () async {
    final (hits, node) = await client.resolve(
      (q) => (
        [
          for (final hit in q.search(text: 'al') ?? const <SearchResult>[])
            hit.when(
              launch: (l) => 'Launch ${l.name}',
              rocket: (r) => 'Rocket ${r.name}',
              astronaut: (a) => 'Astronaut ${a.name}',
            ),
        ],
        q
            .node(id: 'rocket-falcon')
            ?.when(rocket: (r) => r.name, launch: (l) => l.name),
      ),
    );
    expect(documents, hasLength(1));
    expect(documents.single, contains('... on Launch {'));
    expect(documents.single, contains('... on Rocket {'));
    expect(documents.single, contains('... on Astronaut {'));
    expect(documents.single, contains('name__Rocket: name'));
    expect(documents.single, contains('name__Launch: name'));
    expect(hits.where((h) => h!.startsWith('Launch ')), hasLength(3));
    expect(hits, contains('Rocket Falcon 9'));
    expect(hits.where((h) => h!.startsWith('Astronaut ')), hasLength(2));
    expect(node, 'Falcon 9');
    // The search hit and the node are the same Rocket:rocket-falcon entity.
    expect(client.cache.entity('Rocket:rocket-falcon')?['name'], 'Falcon 9');
  });

  test(
    'a mutation: sent alone, its answer updates the cached entity',
    () async {
      final before = await client.resolve(
        (q) => q.launch(id: 'launch-2')?.favorite,
      );
      Future<bool?> toggle() => client.mutate(
        (m) => m.toggleFavorite(launchId: 'launch-2')?.favorite,
      );
      expect(await toggle(), !before!);
      expect(documents.last, startsWith('mutation'));
      expect(client.cache.entity('Launch:launch-2')?['favorite'], !before);
      expect(await toggle(), before, reason: 'back to the seed data');
      expect(documents, hasLength(3));
    },
  );

  test('a partial error: the failing branch is pruned and surfaced, the '
      'rest of the response is cached', () async {
    final scope = client.createScope(onChanged: () {});
    addTearDown(scope.dispose);
    scope.run(
      (q) => (
        q.company?.name,
        // A bad nested cursor: Rocket.launches is non-null, so the error
        // nulls the whole (nullable) rocket.
        q.rocket(id: 'rocket-falcon')?.launches(after: 'nope')?.totalCount,
      ),
    );
    await scope.whenSettled;

    expect(documents, hasLength(1));
    final error = scope.error;
    expect(error, isA<SlingGraphQLException>());
    expect((error! as SlingGraphQLException).isPartial, isTrue);
    final graphqlError = error.errors.single;
    expect(graphqlError.message, 'Invalid cursor: nope');
    expect(graphqlError.path!.first, startsWith('rocket'));
    expect(
      await client.resolve((q) => q.company?.name),
      'Sling Space',
      reason: 'served from the cache',
    );
    expect(documents, hasLength(1));
  });

  test('a subscription over SSE: a change made elsewhere arrives as an '
      'event and lands in the cache', () async {
    const id = 'launch-1';
    final before = await client.resolve((q) => q.launch(id: id)?.status);
    final after = before == LaunchStatus.scrubbed
        ? LaunchStatus.failure
        : LaunchStatus.scrubbed;
    const setStatus =
        r'mutation($id: ID!, $status: LaunchStatus!) { '
        r'updateLaunchStatus(id: $id, status: $status) { id } }';
    addTearDown(
      () => post(setStatus, {'id': id, 'status': before!.graphqlName}),
    );

    final subscription = client.subscribe(
      (s) => (s.launchStatusChanged?.id, s.launchStatusChanged?.status),
    );
    addTearDown(subscription.cancel);
    final events = <(String?, LaunchStatus?)>[];
    final listener = subscription.stream.listen(events.add);
    addTearDown(listener.cancel);
    // The server registers the subscription some time after the request
    // went out: change the status until an event comes back.
    for (var attempt = 0; attempt < 20 && events.isEmpty; attempt++) {
      await post(setStatus, {'id': id, 'status': after.graphqlName});
      for (var i = 0; i < 10 && events.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }
    final event = events.isEmpty ? null : events.first;
    expect(event, (id, after));
    expect(client.cache.entity('Launch:$id')?['status'], after.graphqlName);
    expect(documents, hasLength(1), reason: 'subscriptions are not requests');
    await subscription.cancel();
    expect(client.activeSubscriptions, 0);
  });
}
