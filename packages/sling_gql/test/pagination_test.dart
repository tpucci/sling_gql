import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/printed_document.dart';

// --- Hand-written "generated" code for a connection schema -------------------
//
// type Query          { users(after: String): UserConnection! }
// type UserConnection { nodes: [User!]!  pageInfo: PageInfo!  totalCount: Int! }
// type PageInfo       { hasNextPage: Boolean!  endCursor: String }
// type User           { id: ID!  name: String! }

class Query extends Accessor {
  Query(super.recorder, super.selection, super.path);
  Query.root(Recorder r) : super(r, r.root, const []);

  UserConnection? users({String? after}) => object(
    'users',
    UserConnection.new,
    args: {'after': Arg('String', after)},
  );
}

class UserConnection extends Accessor {
  UserConnection(super.recorder, super.selection, super.path);

  List<User>? get nodes => list('nodes', User.new, keyed: true);
  PageInfo? get pageInfo => object('pageInfo', PageInfo.new);
  int? get totalCount => scalar<int>('totalCount');
}

class PageInfo extends Accessor {
  PageInfo(super.recorder, super.selection, super.path);

  bool? get hasNextPage => scalar<bool>('hasNextPage');
  String? get endCursor => scalar<String>('endCursor');
}

class User extends Accessor {
  User(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
}

// --- Mock server: two pages of two users ---------------------------------------

Map<String, Object?> _page(Object? after) {
  final (names, endCursor, hasNext) = switch (after) {
    null => (['Ada', 'Bob'], 'c2', true),
    'c2' => (['Cy', 'Dee'], 'c4', false),
    _ => throw StateError('unknown cursor $after'),
  };
  return {
    '__typename': 'UserConnection',
    'nodes': [
      for (final n in names)
        {'__typename': 'User', 'id': n.toLowerCase(), 'name': n},
    ],
    'pageInfo': {
      '__typename': 'PageInfo',
      'hasNextPage': hasNext,
      'endCursor': endCursor,
    },
    'totalCount': 4,
  };
}

class Harness {
  Harness({
    bool merged = true,
    this.renderSkeletons = true,
    DateTime Function() now = DateTime.now,
  }) {
    client = SlingClient<Query>(
      endpoint: Uri.parse('http://test/graphql'),
      rootFactory: Query.root,
      now: now,
      onOperation: sent.add,
      typePolicies: merged
          ? const {
              Query: TypePolicy(fields: {'users': RelayStylePagination()}),
            }
          : const {},
      // Answers what the document selects, nothing more.
      httpClient: printedDocumentServer(
        () => {'users': (Map<String, Object?> args) => _page(args['after'])},
        gate: () async => gate?.future,
      ),
    );
  }

  late final SlingClient<Query> client;
  final sent = <PrintedOperation>[];

  /// When set, responses wait for it.
  Completer<void>? gate;

  /// Rows for the skeleton of a page being loaded are built (and read their
  /// fields) too.
  final bool renderSkeletons;

  /// The last state handed to the builder.
  late PaginatedState<User> state;

  /// `state.isSkeleton` as each build saw it.
  final skeletonSeen = <bool>[];

  Widget app({
    PaginationController? controller,
    String? debugLabel,
    FetchPolicy? fetchPolicy,
    Duration? maxAge,
  }) => SlingScope<Query>(
    client: client,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: PaginatedQueryBuilder<Query, User>(
        controller: controller,
        debugLabel: debugLabel,
        fetchPolicy: fetchPolicy,
        maxAge: maxAge,
        page: (query, after) {
          final page = query.users(after: after);
          return ConnectionPage(
            nodes: page?.nodes,
            hasNextPage: page?.pageInfo?.hasNextPage,
            endCursor: page?.pageInfo?.endCursor,
            totalCount: page?.totalCount,
          );
        },
        builder: (context, state) {
          this.state = state;
          skeletonSeen.add(state.isSkeleton);
          return Column(
            children: [
              for (final u in state.items)
                if (renderSkeletons || !u.isSkeleton) Text(u.name ?? '…'),
            ],
          );
        },
      ),
    ),
  );

  List<String?> get names => [for (final u in state.items) u.name];

  /// The `users` entries in the cache, by key.
  Map<String, Object?> get entries => {
    for (final e in client.cache.entity('ROOT_QUERY')!.entries)
      if (e.key.startsWith('users')) e.key: e.value,
  };
}

void main() {
  testWidgets('first page: one request; skeleton while loading', (
    tester,
  ) async {
    final h = Harness();
    await tester.pumpWidget(h.app());

    // The MockClient answers within the same fake-async turn, so only the
    // build-time facts of the first run are observable here.
    expect(
      h.state.items,
      hasLength(1),
      reason: 'skeleton list has one element',
    );
    expect(h.state.hasMissingData, isTrue);
    expect(h.state.hasMore, isFalse, reason: 'unknown until fetched');
    await tester.pump();

    expect(h.sent, hasLength(1));
    expect(h.names, ['Ada', 'Bob']);
    expect(h.state.hasMore, isTrue);
    expect(h.state.totalCount, 4);
    expect(h.state.isLoading, isFalse);
    expect(h.state.hasMissingData, isFalse);
  });

  testWidgets('forwards debugLabel and fetchPolicy to its QueryBuilder; '
      'isSkeleton on the first page', (tester) async {
    final h = Harness();
    final scopes = <List<String>>[];
    h.client.requests.listen((r) {
      if (!r.isDone) scopes.add(r.scopes);
    });
    await tester.pumpWidget(h.app(debugLabel: 'Users'));
    await tester.pump();

    expect(h.skeletonSeen.first, isTrue);
    expect(h.skeletonSeen.last, isFalse);
    expect(scopes, [
      ['Users'],
    ]);

    // Cached now: a cache-first list would send nothing; network-only does.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(h.app(fetchPolicy: FetchPolicy.networkOnly));
    await tester.pump();
    expect(h.sent, hasLength(2));
    expect(h.names, ['Ada', 'Bob']);
  });

  testWidgets('maxAge: isStale and revalidate()', (tester) async {
    var now = DateTime(2026, 10, 1);
    final h = Harness(now: () => now);
    await tester.pumpWidget(h.app(maxAge: const Duration(minutes: 1)));
    await tester.pump();
    expect(h.sent, hasLength(1));
    expect(h.state.isStale, isFalse);

    await h.state.revalidate();
    expect(h.sent, hasLength(1), reason: 'fresh: nothing sent');

    now = now.add(const Duration(minutes: 2));
    final done = h.state.revalidate();
    await tester.pump();
    await done;
    expect(h.sent, hasLength(2));
    expect(h.names, ['Ada', 'Bob']);
  });

  testWidgets('loadMore fetches only the next page, merged into one list', (
    tester,
  ) async {
    final h = Harness();
    final controller = PaginationController();
    await tester.pumpWidget(h.app(controller: controller));
    await tester.pump();

    h.state.loadMore();
    expect(controller.pendingCursor, 'c2');
    await tester.pump();
    await tester.pump();

    expect(h.sent, hasLength(2));
    final doc = h.sent.last.document;
    expect(doc, contains('users(after: \$after)'));
    expect(h.sent.last.variables, {'after': 'c2'});
    expect(
      doc,
      isNot(contains('  users {')),
      reason: 'page one comes from cache',
    );
    expect(h.names, ['Ada', 'Bob', 'Cy', 'Dee']);
    expect(h.state.hasMore, isFalse);
    expect(controller.pendingCursor, isNull, reason: 'merged');
    expect(h.entries.keys, [
      'users',
    ], reason: 'one cache entry, not one per page');
    expect((h.entries['users']! as Map)['nodes'], hasLength(4));

    h.state.loadMore();
    await tester.pump();
    expect(h.sent, hasLength(2), reason: 'no next page: loadMore is a no-op');
  });

  testWidgets('while the next page loads, the loaded items stay and its '
      'skeleton follows them', (tester) async {
    final h = Harness();
    await tester.pumpWidget(h.app());
    await tester.pump();

    h.gate = Completer<void>();
    h.state.loadMore();
    await tester.pump();
    await tester.pump();
    expect(h.sent, hasLength(2));
    expect(h.state.items, hasLength(3));
    expect(h.names.take(2), ['Ada', 'Bob']);
    expect(h.state.items.last.isSkeleton, isTrue);
    expect(h.state.hasMore, isFalse);
    expect(h.state.isLoading, isTrue);

    h.gate!.complete();
    await tester.pump();
    await tester.pump();
    expect(h.names, ['Ada', 'Bob', 'Cy', 'Dee']);
    expect(h.state.isLoading, isFalse);
  });

  testWidgets('the next page selects what the rows read, even when its '
      'skeleton row is not built', (tester) async {
    final h = Harness(renderSkeletons: false);
    await tester.pumpWidget(h.app());
    await tester.pump();
    await tester.pump();
    await tester.pump();
    // No skeleton row in the first frame, so `name` was not read before
    // the first page landed: one more (fill) request for it.
    expect(h.sent, hasLength(2));
    expect(h.sent.last.document, contains('name'));

    h.state.loadMore();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(h.sent, hasLength(3), reason: 'no extra round trip for `name`');
    final next = h.sent.last.document;
    expect(next, contains(r'users(after: $after)'));
    expect(next, contains('name'), reason: 'read through the first page');
    expect(h.names, ['Ada', 'Bob', 'Cy', 'Dee']);
  });

  testWidgets('refetch starts the list over from the first page', (
    tester,
  ) async {
    final h = Harness();
    await tester.pumpWidget(h.app());
    await tester.pump();
    h.state.loadMore();
    await tester.pump();
    await tester.pump();
    expect(h.names, hasLength(4));

    final refetched = h.state.refetch();
    await tester.pump();
    await tester.pump();
    await refetched;
    await tester.pump();

    expect(h.sent, hasLength(3));
    final doc = h.sent.last.document;
    expect(doc, contains('  users {'));
    expect(doc, isNot(contains('after')), reason: 'the first page only');
    expect(h.names, ['Ada', 'Bob']);
    expect(h.state.hasMore, isTrue);
  });

  testWidgets('without RelayStylePagination the builder says so', (
    tester,
  ) async {
    final h = Harness(merged: false);
    await tester.pumpWidget(h.app());
    await tester.pump();
    h.state.loadMore();
    await tester.pump();
    await tester.pump();
    expect(
      tester.takeException(),
      isA<AssertionError>().having(
        (e) => e.message,
        'message',
        contains('RelayStylePagination'),
      ),
    );
  });

  test('PaginationController ignores null and duplicate cursors', () {
    final controller = PaginationController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.loadMore(null);
    expect(controller.pendingCursor, isNull);
    controller.loadMore('c2');
    controller.loadMore('c2');
    expect(controller.pendingCursor, 'c2');
    expect(notifications, 1);

    controller.reset();
    controller.reset();
    expect(controller.pendingCursor, isNull);
    expect(notifications, 2);
  });
}
