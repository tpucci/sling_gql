import 'package:sling_gql/sling_gql.dart';

import 'generated/schema.dart';

/// How the cache stores particular fields (`SlingClient(typePolicies:)`),
/// keyed by the generated class a field is read through.
///
/// `launches(first:, after:, filter:, orderBy:)` is a Relay connection: with
/// [RelayStylePagination], every page of one `filter`/`orderBy` is merged
/// into a single growing list in the cache, instead of one entry per
/// cursor. `PaginatedQueryBuilder` (the Launches tab, the pagination demo)
/// reads that list; a refresh starts it over from page one.
const Map<Type, TypePolicy> typePolicies = {
  Query: TypePolicy(fields: {'launches': RelayStylePagination()}),
};
