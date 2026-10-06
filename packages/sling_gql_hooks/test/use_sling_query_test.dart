import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_hooks/sling_gql_hooks.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

import 'support/test_schema.dart';

/// [useSlingQuery] behaves like a [QueryBuilder]: end-of-frame batching,
/// rebuilds on notify, sticky errors, fetch policies, disposal.
void main() {
  Widget app(SlingClient<Query> client, Widget child) => SlingScope<Query>(
    client: client,
    schema: slingSchema,
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );

  testWidgets('fetches what select read, then rebuilds with the data', (
    tester,
  ) async {
    final server = MockGraphQLServer(
      query: {'me': user('1', 'Ada', age: 36)},
      latency: const Duration(milliseconds: 10),
    );
    final client = server.client(Query.root);
    final states = <QueryState>[];
    await tester.pumpWidget(
      app(
        client,
        HookBuilder(
          builder: (context) {
            final ((name, age), state) = useSlingQuery(
              (Query q) => (q.me.name, q.me.age),
            );
            states.add(state);
            return Text('${name ?? '…'} ${age ?? ''}');
          },
        ),
      ),
    );
    expect(find.text('… '), findsOneWidget);
    await tester.pump();
    expect(states.last.isSkeleton, isTrue);

    await tester.pumpUntilSettled(client);
    expect(find.text('Ada 36'), findsOneWidget);
    expect(states.last.hasMissingData, isFalse);
    expect(states.last.isLoading, isFalse);
    expect(server.requests, hasLength(1));
    expect(server.lastRequest.selects('me.name'), isTrue);
    expect(server.lastRequest.selects('me.age'), isTrue);
  });

  testWidgets('hooks and QueryBuilders building in one frame share a request', (
    tester,
  ) async {
    final server = MockGraphQLServer(
      query: {
        'me': user('1', 'Ada', age: 36),
        'user': (Map<String, Object?> args) => user('2', 'Bob'),
      },
    );
    final client = server.client(Query.root);
    await tester.pumpWidget(
      app(
        client,
        Column(
          children: [
            HookBuilder(
              builder: (context) {
                final (name, _) = useSlingQuery((Query q) => q.me.name);
                return Text(name ?? '…');
              },
            ),
            HookBuilder(
              builder: (context) {
                final (age, _) = useSlingQuery((Query q) => q.me.age);
                return Text('${age ?? '…'}');
              },
            ),
            QueryBuilder<Query>(
              builder: (context, q, state) =>
                  Text(q.user(id: '2')?.name ?? '…'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpUntilSettled(client);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('36'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(server.requests, hasLength(1));
    expect(server.lastRequest.rootFields, {'me', 'user'});
  });

  testWidgets('rebuilds when a write touches what it read, and only then', (
    tester,
  ) async {
    final server = MockGraphQLServer(
      query: {
        'me': user('1', 'Ada', age: 36),
        'user': (Map<String, Object?> args) => user('2', 'Bob'),
      },
    );
    final client = server.client(Query.root);
    await tester.runAsync(() => client.resolve((q) => q.user(id: '2')?.name));
    var builds = 0;
    late User me;
    await tester.pumpWidget(
      app(
        client,
        HookBuilder(
          builder: (context) {
            builds++;
            final (user, _) = useSlingQuery((Query q) => q.me..name);
            me = user;
            return Text(user.name ?? '…');
          },
        ),
      ),
    );
    await tester.pumpUntilSettled(client);
    expect(find.text('Ada'), findsOneWidget);
    final settled = builds;

    // An optimistic-style write through the accessor: `User:1.name`.
    me.name = 'Ada L.';
    await tester.pump();
    expect(find.text('Ada L.'), findsOneWidget);
    expect(builds, settled + 1);

    // An entity this widget never read does not rebuild it.
    client.cacheScope.entity('User', '2', User.new)!.name = 'Bobby';
    await tester.pump();
    expect(builds, settled + 1);
  });

  testWidgets('disposes its scope with the widget', (tester) async {
    final ada = user('1', 'Ada');
    final server = MockGraphQLServer(
      query: {'me': ada},
      mutation: {
        'rename': (Map<String, Object?> args) => ada..['name'] = args['name'],
      },
    );
    final client = server.client(Query.root);
    var builds = 0;
    late User me;
    await tester.pumpWidget(
      app(
        client,
        HookBuilder(
          builder: (context) {
            builds++;
            me = useSlingQuery((Query q) => q.me..name).$1;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpUntilSettled(client);
    await tester.pumpWidget(app(client, const SizedBox()));
    final before = builds;

    // The scope no longer listens: no setState on a defunct element...
    me.name = 'Gone';
    await tester.pump();
    expect(builds, before);
    // ...and it is no longer a live query `refetchQueries` would refetch.
    await tester.runAsync(
      () => client.mutateWith(
        Mutation.root,
        (m) => m.rename(id: '1', name: 'Ada L.')?.name,
        refetchQueries: ['me'],
      ),
    );
    await tester.pumpUntilSettled(client);
    expect(server.requests.map((r) => r.type), ['query', 'mutation']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('errors are sticky until refetch, like QueryBuilder', (
    tester,
  ) async {
    var fail = true;
    final server = MockGraphQLServer(
      query: {'me': () => fail ? throw GraphQLError('down') : user('1', 'Ada')},
    );
    final client = server.client(Query.root);
    late QueryState state;
    await tester.pumpWidget(
      app(
        client,
        HookBuilder(
          builder: (context) {
            final (name, s) = useSlingQuery((Query q) => q.me.name);
            state = s;
            return Text(name ?? '…');
          },
        ),
      ),
    );
    await tester.pumpUntilSettled(client);
    expect(state.error, isNotNull);
    // Rebuilds re-read the missing field without re-sending the query.
    await tester.pump();
    await tester.pump();
    expect(server.requests, hasLength(1));

    fail = false;
    unawaited(state.refetch());
    await tester.pumpUntilSettled(client);
    expect(state.error, isNull);
    expect(find.text('Ada'), findsOneWidget);
    expect(server.requests, hasLength(2));
  });

  testWidgets('fetchPolicy and maxAge are passed to the scope', (tester) async {
    final server = MockGraphQLServer(query: {'me': user('1', 'Ada')});
    var now = DateTime(2026);
    final client = SlingClient<Query>(
      endpoint: Uri.parse('http://mock/graphql'),
      schema: slingSchema,
      httpClient: server.httpClient,
      now: () => now,
    );
    addTearDown(client.dispose);
    await tester.runAsync(() => client.resolve((q) => q.me.name));
    expect(server.requests, hasLength(1));

    // cacheAndNetwork: cached data at once, one background refresh.
    await tester.pumpWidget(
      app(
        client,
        HookBuilder(
          builder: (context) {
            final (name, _) = useSlingQuery(
              (Query q) => q.me.name,
              fetchPolicy: FetchPolicy.cacheAndNetwork,
            );
            return Text(name ?? '…');
          },
        ),
      ),
    );
    expect(find.text('Ada'), findsOneWidget);
    await tester.pumpUntilSettled(client);
    expect(server.requests, hasLength(2));

    // maxAge: stale data is shown and revalidated in the background.
    now = now.add(const Duration(minutes: 10));
    late QueryState state;
    await tester.pumpWidget(
      app(
        client,
        HookBuilder(
          key: const ValueKey('maxAge'),
          builder: (context) {
            final (name, s) = useSlingQuery(
              (Query q) => q.me.name,
              maxAge: const Duration(minutes: 5),
            );
            state = s;
            return Text(name ?? '…');
          },
        ),
      ),
    );
    expect(find.text('Ada'), findsOneWidget);
    expect(state.isStale, isTrue);
    await tester.pumpUntilSettled(client);
    expect(server.requests, hasLength(3));
    expect(state.isStale, isFalse);
  });

  testWidgets('errorPolicy and timeout are passed to the scope', (
    tester,
  ) async {
    final server = MockGraphQLServer(
      query: {
        'me': {
          ...user('1', 'Ada'),
          'age': (Map<String, Object?> _) => throw GraphQLError('hidden'),
        },
      },
    );
    final client = server.client(Query.root);
    late QueryState state;
    await tester.pumpWidget(
      app(
        client,
        HookBuilder(
          builder: (context) {
            final (name, s) = useSlingQuery(
              (Query q) => (q.me.name, q.me.age),
              errorPolicy: ErrorPolicy.ignore,
            );
            state = s;
            return Text(name.$1 ?? '…');
          },
        ),
      ),
    );
    await tester.pumpUntilSettled(client);
    expect(find.text('Ada'), findsOneWidget);
    expect(state.error, isNull);
    expect(state.hasMissingData, isFalse);
    expect(server.requests, hasLength(1));

    final slow = MockGraphQLServer(
      query: {'me': user('1', 'Ada')},
      latency: const Duration(seconds: 2),
    );
    final slowClient = slow.client(Query.root, retry: RetryPolicy.none);
    await tester.pumpWidget(
      app(
        slowClient,
        HookBuilder(
          key: const ValueKey('timeout'),
          builder: (context) {
            final (name, s) = useSlingQuery(
              (Query q) => q.me.name,
              timeout: const Duration(milliseconds: 100),
            );
            state = s;
            return Text(name ?? '…');
          },
        ),
      ),
    );
    await tester.pumpUntilSettled(slowClient);
    expect(state.error, isA<SlingTimeoutException>());
    await tester.pump(const Duration(seconds: 2)); // the latency timer
  });

  testWidgets('scheduler decides when the misses are flushed', (tester) async {
    final server = MockGraphQLServer(query: {'me': user('1', 'Ada')});
    final client = server.client(Query.root);
    final pending = <void Function()>[];
    await tester.pumpWidget(
      app(
        client,
        HookBuilder(
          builder: (context) {
            final (name, _) = useSlingQuery(
              (Query q) => q.me.name,
              scheduler: pending.add,
            );
            return Text(name ?? '…');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(pending, hasLength(1));
    expect(server.requests, isEmpty);

    pending.single();
    await tester.pumpUntilSettled(client);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('debugLabel: explicit, then the widget key, then its type '
      '(the enclosing widget inside a HookBuilder)', (tester) async {
    final server = MockGraphQLServer(
      query: {
        'me': user('1', 'Ada'),
        'user': (Map<String, Object?> args) => user('${args['id']}', 'Bob'),
      },
    );
    final client = server.client(Query.root);
    final requests = <SlingRequest>{};
    final sub = client.requests.listen(requests.add);
    addTearDown(sub.cancel);
    await tester.pumpWidget(
      app(
        client,
        const Column(
          children: [
            _NameOf(id: '2', debugLabel: 'explicit'),
            _NameOf(id: '3', key: ValueKey('keyed')),
            _NameOf(id: '4'),
            _Screen(),
          ],
        ),
      ),
    );
    await tester.pumpUntilSettled(client);
    expect(requests, hasLength(1));
    expect(
      requests.single.scopes,
      unorderedEquals(['explicit', "[<'keyed'>]", '_NameOf', '_Screen']),
    );
  });

  testWidgets('a new client from SlingScope gets a new scope', (tester) async {
    final first = MockGraphQLServer(query: {'me': user('1', 'Ada')});
    final second = MockGraphQLServer(query: {'me': user('1', 'Bea')});
    final a = first.client(Query.root);
    final b = second.client(Query.root);
    Widget tree(SlingClient<Query> client) => app(
      client,
      HookBuilder(
        builder: (context) {
          final (name, _) = useSlingQuery((Query q) => q.me.name);
          return Text(name ?? '…');
        },
      ),
    );
    await tester.pumpWidget(tree(a));
    await tester.pumpUntilSettled(a);
    expect(find.text('Ada'), findsOneWidget);

    await tester.pumpWidget(tree(b));
    await tester.pumpUntilSettled(b);
    expect(find.text('Bea'), findsOneWidget);
    expect(second.requests, hasLength(1));
  });
}

class _NameOf extends HookWidget {
  const _NameOf({super.key, required this.id, this.debugLabel});

  final String id;
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    final (name, _) = useSlingQuery(
      (Query q) => q.user(id: id)?.name,
      debugLabel: debugLabel,
    );
    return Text(name ?? '…');
  }
}

/// A plain widget hosting the hook in a [HookBuilder]: the label is
/// `_Screen`, not `HookBuilder`.
class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) => HookBuilder(
    builder: (context) {
      final (name, _) = useSlingQuery((Query q) => q.user(id: '5')?.name);
      return Text(name ?? '…');
    },
  );
}
