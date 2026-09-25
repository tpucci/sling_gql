import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

// --- Hand-written "generated" code for a connection schema -------------------
//
// type Query          { users(after: String): UserConnection! }
// type UserConnection { nodes: [User!]!  pageInfo: PageInfo!  totalCount: Int! }
// type PageInfo       { hasNextPage: Boolean!  endCursor: String }
// type User           { id: ID!  name: String! }

class Query extends Accessor {
  Query(super.recorder, super.selection, super.path);
  Query.root(Recorder r) : super(r, r.root, const []);

  UserConnection? users({String? after}) =>
      object('users', UserConnection.new, args: {'after': Arg('String', after)});
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

Map<String, Object?> _page(String? after) {
  final (names, endCursor, hasNext) = switch (after) {
    null => (['Ada', 'Bob'], 'c2', true),
    'c2' => (['Cy', 'Dee'], 'c4', false),
    _ => throw StateError('unknown cursor $after'),
  };
  return {
    '__typename': 'UserConnection',
    'nodes': [
      for (final n in names) {'__typename': 'User', 'id': n.toLowerCase(), 'name': n},
    ],
    'pageInfo': {'__typename': 'PageInfo', 'hasNextPage': hasNext, 'endCursor': endCursor},
    'totalCount': 4,
  };
}

/// Answers each `users` selection of the document under its alias.
Map<String, Object?> _handler(String document, Map vars) {
  final data = <String, Object?>{};
  if (RegExp(r'^  users \{', multiLine: true).hasMatch(document)) {
    data['users'] = _page(null);
  }
  for (final m in RegExp(r'(users_\w+): users\(after: \$(v\d+)\)').allMatches(document)) {
    data[m.group(1)!] = _page(vars[m.group(2)!] as String);
  }
  return data;
}

class Harness {
  Harness() {
    client = SlingClient<Query>(
      endpoint: Uri.parse('http://test/graphql'),
      rootFactory: Query.root,
      onOperation: sent.add,
      httpClient: MockClient((req) async {
        final body = jsonDecode(req.body) as Map;
        final data = _handler(body['query'] as String, body['variables'] as Map);
        return http.Response(jsonEncode({'data': data}), 200);
      }),
    );
  }

  late final SlingClient<Query> client;
  final sent = <PrintedOperation>[];

  /// The last state handed to the builder.
  late PaginatedState<User> state;

  Widget app({PaginationController? controller}) => SlingScope<Query>(
        client: client,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: PaginatedQueryBuilder<Query, User>(
            controller: controller,
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
              return Column(
                children: [for (final u in state.items) Text(u.name ?? '…')],
              );
            },
          ),
        ),
      );

  List<String?> get names => [for (final u in state.items) u.name];
}

void main() {
  testWidgets('first page: one request; skeleton while loading', (tester) async {
    final h = Harness();
    await tester.pumpWidget(h.app());

    // The MockClient answers within the same fake-async turn, so only the
    // build-time facts of the first run are observable here.
    expect(h.state.items, hasLength(1), reason: 'skeleton list has one element');
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

  testWidgets('loadMore fetches only the new page', (tester) async {
    final h = Harness();
    await tester.pumpWidget(h.app());
    await tester.pump();

    h.state.loadMore();
    await tester.pump();
    await tester.pump();

    expect(h.sent, hasLength(2));
    final doc = h.sent.last.document;
    expect(doc, contains('users(after: \$v0)'));
    expect(h.sent.last.variables, {'v0': 'c2'});
    expect(doc, isNot(contains('  users {')), reason: 'page one comes from cache');
    expect(h.names, ['Ada', 'Bob', 'Cy', 'Dee']);
    expect(h.state.hasMore, isFalse);

    h.state.loadMore();
    await tester.pump();
    expect(h.sent, hasLength(2), reason: 'no next page: loadMore is a no-op');
  });

  testWidgets('reset goes back to the first page without a request', (tester) async {
    final h = Harness();
    final controller = PaginationController();
    await tester.pumpWidget(h.app(controller: controller));
    await tester.pump();
    h.state.loadMore();
    await tester.pump();
    await tester.pump();
    expect(controller.pageCount, 2);

    controller.reset();
    await tester.pump();

    expect(controller.pageCount, 1);
    expect(h.names, ['Ada', 'Bob']);
    expect(h.sent, hasLength(2), reason: 'page one is cached');
    expect(h.state.hasMore, isTrue);
  });

  testWidgets('refetch replays every loaded page in one request', (tester) async {
    final h = Harness();
    await tester.pumpWidget(h.app());
    await tester.pump();
    h.state.loadMore();
    await tester.pump();
    await tester.pump();

    final refetched = h.state.refetch();
    await tester.pump();
    await tester.pump();
    await refetched;

    expect(h.sent, hasLength(3));
    final doc = h.sent.last.document;
    expect(doc, contains('  users {'));
    expect(doc, contains('users(after: \$v0)'));
    expect(h.names, ['Ada', 'Bob', 'Cy', 'Dee']);
  });

  test('PaginationController ignores null and duplicate cursors', () {
    final controller = PaginationController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.loadMore(null);
    expect(controller.cursors, [null]);
    controller.loadMore('c2');
    controller.loadMore('c2');
    expect(controller.cursors, [null, 'c2']);
    expect(notifications, 1);

    controller.reset();
    controller.reset();
    expect(controller.cursors, [null]);
    expect(notifications, 2);
  });
}
