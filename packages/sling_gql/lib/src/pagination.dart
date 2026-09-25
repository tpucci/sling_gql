import 'package:flutter/widgets.dart';

import 'accessor.dart';
import 'widgets.dart';

/// Owns the cursors of a cursor-paginated list: one entry per loaded page,
/// `null` being the first page.
///
/// Pagination in sling_gql is plain state — every `connection(after: cursor)`
/// call is its own cache entry — so this controller only decides *which*
/// pages a [PaginatedQueryBuilder] reads. Keep it in a `State` when the list
/// must survive rebuilds of the surrounding widget or when a filter change
/// has to [reset] it.
class PaginationController extends ChangeNotifier {
  List<String?> _cursors = const [null];

  /// Cursors of the loaded pages, first page first.
  List<String?> get cursors => _cursors;

  int get pageCount => _cursors.length;

  /// Appends the page starting after [endCursor]. Ignored when [endCursor] is
  /// `null` (the last page has not been fetched yet, appending would re-read
  /// the first page) or already loaded (double tap).
  void loadMore(String? endCursor) {
    if (endCursor == null || _cursors.contains(endCursor)) return;
    _cursors = [..._cursors, endCursor];
    notifyListeners();
  }

  /// Back to the first page only. Call when the arguments that select the
  /// list change (filter, sort): the old pages stay cached, the new first
  /// page is read from cache or fetched.
  void reset() {
    if (_cursors.length == 1) return;
    _cursors = const [null];
    notifyListeners();
  }
}

/// What [PaginatedQueryBuilder] needs from one page of a connection, read
/// from the generated connection accessor by the `page` callback.
///
/// Read every field you pass here unconditionally — the callback runs for
/// every loaded page during a single build, which is what keeps all pages in
/// one request per user action.
class ConnectionPage<Node> {
  const ConnectionPage({
    required this.nodes,
    required this.hasNextPage,
    required this.endCursor,
    this.totalCount,
  });

  /// `connection.nodes`. A skeleton page (not cached yet) yields a list with
  /// exactly one skeleton element, see [Accessor].
  final List<Node>? nodes;

  /// `connection.pageInfo.hasNextPage`.
  final bool? hasNextPage;

  /// `connection.pageInfo.endCursor`; fed to [PaginationController.loadMore].
  final String? endCursor;

  /// `connection.totalCount`, if the schema has one.
  final int? totalCount;
}

/// Reads the page of the connection that starts after [after] (`null` for the
/// first page) from the query root.
typedef PageSelector<Q extends Accessor, Node> = ConnectionPage<Node> Function(
  Q query,
  String? after,
);

typedef PaginatedWidgetBuilder<Node> = Widget Function(
  BuildContext context,
  PaginatedState<Node> state,
);

/// Every loaded page flattened, plus the query status and the actions a list
/// screen needs.
class PaginatedState<Node> {
  const PaginatedState._({
    required this.items,
    required this.hasMore,
    required this.totalCount,
    required this._query,
    required this._controller,
    required this._endCursor,
  });

  final QueryState _query;
  final PaginationController _controller;

  /// `endCursor` of the last page, captured during build so [loadMore] never
  /// reads (and fetches) it from a callback.
  final String? _endCursor;

  /// Nodes of all loaded pages, in order. While the first page is loading
  /// this holds one skeleton element (the skeleton-list rule), so check
  /// [isLoading] or [hasMissingData] before rendering counts or empty states.
  final List<Node> items;

  /// The last loaded page reports a next page. `false` while that page is
  /// still loading.
  final bool hasMore;

  /// `totalCount` of the last loaded page, when the schema provides one.
  final int? totalCount;

  /// A fetch containing this list's selections is in flight.
  bool get isLoading => _query.isLoading;

  /// The last build read data that is not (yet) cached.
  bool get hasMissingData => _query.hasMissingData;

  /// Sticky until [refetch], like [QueryState.error].
  Object? get error => _query.error;

  /// Appends the next page. No-op when [hasMore] is `false`; only the new page
  /// is fetched, the others are served from cache.
  void loadMore() {
    if (!hasMore) return;
    _controller.loadMore(_endCursor);
  }

  /// Re-fetches every loaded page in one request, keeping the cursors.
  Future<void> refetch() => _query.refetch();
}

/// A [QueryBuilder] over a cursor-paginated connection.
///
/// The [page] callback is run once per cursor held by the [controller] during
/// every build, so all loaded pages are part of the same selection: the first
/// frame fetches page one, [PaginatedState.loadMore] fetches only the new
/// page, and [PaginatedState.refetch] replays every page in one request.
///
/// ```dart
/// PaginatedQueryBuilder<Query, Launch>(
///   controller: _pagination, // optional; reset() it when the filter changes
///   page: (query, after) {
///     final page = query.launches(first: 20, after: after, filter: filter);
///     return ConnectionPage(
///       nodes: page?.nodes,
///       hasNextPage: page?.pageInfo?.hasNextPage,
///       endCursor: page?.pageInfo?.endCursor,
///       totalCount: page?.totalCount,
///     );
///   },
///   builder: (context, state) => ListView.builder(
///     itemCount: state.items.length,
///     itemBuilder: (_, i) => LaunchRow(state.items[i]),
///   ),
/// )
/// ```
class PaginatedQueryBuilder<Q extends Accessor, Node> extends StatefulWidget {
  const PaginatedQueryBuilder({
    super.key,
    this.controller,
    required this.page,
    required this.builder,
  });

  /// Owns the cursors. When omitted the widget keeps a private one that lives
  /// as long as the widget does.
  final PaginationController? controller;

  final PageSelector<Q, Node> page;

  final PaginatedWidgetBuilder<Node> builder;

  @override
  State<PaginatedQueryBuilder<Q, Node>> createState() =>
      _PaginatedQueryBuilderState<Q, Node>();
}

class _PaginatedQueryBuilderState<Q extends Accessor, Node>
    extends State<PaginatedQueryBuilder<Q, Node>> {
  PaginationController? _ownController;
  late PaginationController _controller;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant PaginatedQueryBuilder<Q, Node> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_onCursorsChanged);
      _attach();
    }
  }

  void _attach() {
    final external = widget.controller;
    if (external != null) {
      _ownController?.dispose();
      _ownController = null;
      _controller = external;
    } else {
      _controller = _ownController ??= PaginationController();
    }
    _controller.addListener(_onCursorsChanged);
  }

  void _onCursorsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onCursorsChanged);
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<Q>(
      builder: (context, query, queryState) {
        final controller = _controller;
        final pages = [
          for (final cursor in controller.cursors) widget.page(query, cursor),
        ];
        final last = pages.last;
        return widget.builder(
          context,
          PaginatedState<Node>._(
            items: [for (final page in pages) ...?page.nodes],
            hasMore: last.hasNextPage ?? false,
            totalCount: last.totalCount,
            endCursor: last.endCursor,
            query: queryState,
            controller: controller,
          ),
        );
      },
    );
  }
}
