import 'package:flutter/widgets.dart';

import 'accessor.dart';
import 'cache/cache.dart';
import 'errors.dart';
import 'widgets.dart';

/// The next page a [PaginatedQueryBuilder] is loading, if any.
///
/// The pages themselves live in the cache: with [RelayStylePagination] on
/// the connection field, every page is merged into one growing list, so
/// the builder reads the first page (which *is* that list) and, while one
/// is on its way, the page after [pendingCursor]. Keep the controller in a
/// `State` when the list must survive rebuilds of the surrounding widget or
/// when a filter change has to [reset] it.
class PaginationController extends ChangeNotifier {
  String? _pending;

  /// The cursor the page being loaded starts after (`after: pendingCursor`);
  /// `null` when no page is loading. Cleared once the page is merged.
  String? get pendingCursor => _pending;

  /// Loads the page starting after [endCursor]. Ignored when [endCursor] is
  /// `null` (the last page has not been fetched yet, the request would
  /// re-read the first page) or already loading (double tap).
  void loadMore(String? endCursor) {
    if (endCursor == null || endCursor == _pending) return;
    _pending = endCursor;
    notifyListeners();
  }

  /// Forgets the page being loaded. Call when the arguments that select the
  /// list change (filter, sort): each argument set is its own merged list,
  /// kept in the cache with the pages it had, so coming back to it shows
  /// them again without a request.
  void reset() {
    if (_pending == null) return;
    _pending = null;
    notifyListeners();
  }

  /// The builder saw the page after [cursor] merged: nothing to load. Not
  /// notified, it runs during a build that already shows the page.
  void _loaded(String cursor) {
    if (_pending == cursor) _pending = null;
  }
}

/// What [PaginatedQueryBuilder] needs from one page of a connection, read
/// from the generated connection accessor by the `page` callback.
///
/// Read every field you pass here unconditionally — the callback runs for
/// the merged list and for the page being loaded during a single build,
/// which is what keeps one request per user action.
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

  /// `connection.pageInfo.hasNextPage`. `null` tells the builder the page
  /// is not cached yet (`hasNextPage` is non-null in every Relay
  /// connection).
  final bool? hasNextPage;

  /// `connection.pageInfo.endCursor`; fed to [PaginationController.loadMore].
  final String? endCursor;

  /// `connection.totalCount`, if the schema has one.
  final int? totalCount;
}

/// Reads the page of the connection that starts after [after] (`null` for the
/// first page) from the query root. With [RelayStylePagination] on the
/// field, the first page is the merged list of every page loaded so far.
typedef PageSelector<Q extends Accessor, Node> = ConnectionPage<Node> Function(
  Q query,
  String? after,
);

typedef PaginatedWidgetBuilder<Node> = Widget Function(
  BuildContext context,
  PaginatedState<Node> state,
);

/// The merged list, plus the query status and the actions a list screen
/// needs.
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

  /// `endCursor` of the merged list, captured during build so [loadMore]
  /// never reads (and fetches) it from a callback.
  final String? _endCursor;

  /// Nodes of all loaded pages, in order (the merged list), followed by the
  /// skeleton of the page being loaded. While the first page is loading
  /// this holds one skeleton element (the skeleton-list rule), so check
  /// [isLoading] or [hasMissingData] before rendering counts or empty states.
  final List<Node> items;

  /// The last loaded page reports a next page. `false` while a page is
  /// loading.
  final bool hasMore;

  /// `totalCount` of the connection, when the schema provides one.
  final int? totalCount;

  /// A fetch containing this list's selections is in flight.
  bool get isLoading => _query.isLoading;

  /// The last build read data that is not (yet) cached.
  bool get hasMissingData => _query.hasMissingData;

  /// Sticky until [refetch], like [QueryState.error].
  SlingException? get error => _query.error;

  /// Appends the next page. No-op when [hasMore] is `false`; only the new page
  /// is fetched and merged into the list, the loaded ones stay on screen.
  void loadMore() {
    if (!hasMore) return;
    _controller.loadMore(_endCursor);
  }

  /// Starts the list over: refetches its **first page only**, which
  /// replaces the merged list (the pages loaded after it are dropped, see
  /// [RelayStylePagination]), and forgets a page being loaded. Clears
  /// [error] like [QueryState.refetch].
  Future<void> refetch() {
    _controller.reset();
    return _query.refetch();
  }
}

/// A [QueryBuilder] over a cursor-paginated connection whose pages the
/// cache merges into one list: register [RelayStylePagination] for the
/// field (`SlingClient(typePolicies:)`).
///
/// The [page] callback runs during every build for the first page — the
/// merged list of every page loaded so far — and, while one is on its way,
/// for the page the [controller] is loading. The first frame fetches page
/// one, [PaginatedState.loadMore] fetches only the next page (the loaded
/// ones stay on screen, its skeleton follows them), and
/// [PaginatedState.refetch] starts the list over from page one.
///
/// ```dart
/// SlingClient<Query>(
///   typePolicies: {
///     Query: TypePolicy(fields: {'launches': RelayStylePagination()}),
///   },
///   // …
/// );
///
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

  /// Holds the page being loaded. When omitted the widget keeps a private
  /// one that lives as long as the widget does.
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
        // The merged list: every page loaded so far.
        final first = widget.page(query, null);
        final items = <Node>[...?first.nodes];
        var hasMore = first.hasNextPage ?? false;
        final pending = controller.pendingCursor;
        if (pending != null) {
          final next = widget.page(query, pending);
          if (next.hasNextPage == null) {
            // Not merged yet: a miss, fetched now; its skeleton follows.
            items.addAll(next.nodes ?? const []);
            hasMore = false;
          } else {
            assert(
              first.endCursor != pending || first.hasNextPage != true,
              'PaginatedQueryBuilder: the page after "$pending" is cached but '
              'the first page did not grow. Register RelayStylePagination '
              'for the connection field in SlingClient(typePolicies:).',
            );
            controller._loaded(pending);
          }
        }
        return widget.builder(
          context,
          PaginatedState<Node>._(
            items: items,
            hasMore: hasMore,
            totalCount: first.totalCount,
            endCursor: first.endCursor,
            query: queryState,
            controller: controller,
          ),
        );
      },
    );
  }
}
