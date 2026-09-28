import 'package:sling_gql/sling_gql.dart';

import 'generated/schema.dart';

/// What keeps the cached lists honest when an entity changes — whichever
/// way it changed: a response, an optimistic setter, a subscription event.
///
/// Without these, a launch that just flew (`launchStatusChanged` →
/// `SUCCESS`) would still sit in the cached "Scheduled" segment and never
/// show up in "Success", and a favourite toggled on the detail screen would
/// not reach `me.favorites`. The client re-evaluates `belongs` for every
/// cached instance of the field (each argument set it ever sent) whenever a
/// `Launch` is written, and adds or removes the reference.
final List<ListRule<Accessor>> listRules = [
  // `launches(filter: {status})` holds a launch iff the status matches (no
  // filter: every launch). New launches go on top, like DATE_DESC would.
  ListRule<Launch>(
    field: 'launches',
    items: 'nodes',
    typename: 'Launch',
    ctor: Launch.new,
    // Only fields every row reads (`status`) may decide membership: a field
    // that is not cached reads `null` and would evict the launch.
    belongs: (args, launch) {
      final status = (args['filter'] as Map<String, Object?>?)?['status'];
      return status == null || launch.status?.graphqlName == status;
    },
    position: ListPosition.prepend,
  ),
  // `me.favorites` holds a launch iff `launch.favorite`.
  ListRule<Launch>(
    field: 'favorites',
    typename: 'Launch',
    ctor: Launch.new,
    belongs: (_, launch) => launch.favorite == true,
    position: ListPosition.prepend,
  ),
];
