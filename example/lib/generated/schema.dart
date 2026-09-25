// GENERATED CODE - DO NOT MODIFY BY HAND
//
// This file is generated from the GraphQL schema; do not edit it directly --
// change the schema and regenerate instead (see the package README).
//
// Identifier scheme (GraphQL name -> Dart name), and why:
//   - A leading `_` becomes `$`, so the identifier stays public in Dart (a
//     leading underscore would make it library-private): Hasura-style
//     `_eq` -> `$eq`, `_and` -> `$and`.
//   - A Dart keyword, or a name `Accessor` already declares (`selection`,
//     `write`, `isSkeleton`, ...), gets a trailing `$` so the generated
//     getter/method doesn't fail to parse or shadow the base class:
//     `type` -> `type$`, `class` -> `class$`.
//   - A GraphQL type name that collides with `dart:core` or a sling_gql
//     runtime type (`Object`, `String`, `List`, `Map`, `Cache`, `Accessor`,
//     `Selection`, `Arg`, `Recorder`) gets a trailing `$`:
//     `Object` -> `Object$`.
//   - A field whose Dart name is spelled exactly like its own return type
//     (common with lowercase table types, e.g. a `users` field returning
//     type `users`) is disambiguated at the member, not the type, so it
//     doesn't shadow the class inside its own body: `users` -> `users$`.
//   - Enum constants are lowerCamelCased (`PARTIAL_FAILURE` ->
//     `partialFailure`) and get the same trailing `$` on a clash with a
//     keyword or an enum member (`unknown`, `values`, `index`, `name`, ...),
//     or when two wire names camel-case to the same identifier.
//   - `Accessor.$typename` (declared once, in the runtime, not per
//     generated type) reads the cached `__typename`; it is named with a
//     leading `$` for the same public-identifier reason as `_eq` above.
//
// The original GraphQL name is never lost: it is always kept as the string
// literal used for cache keys, `Arg` map keys and `toJson` keys, so renaming
// here is purely cosmetic on the Dart side.
//
// See packages/sling_gql_gen/lib/src/naming.dart for the implementation.
//
// ignore_for_file: non_constant_identifier_names, camel_case_types, camel_case_extensions

import 'package:sling_gql/sling_gql.dart';

class Query extends Accessor {
  Query(super.recorder, super.selection, super.path);
  Query.root(Recorder r) : super(r, r.root, const []);

  Company? get company => object('company', Company.new, keyed: true);

  /// Relay-style cursor pagination.
  LaunchConnection? launches({
    int? first,
    String? after,
    LaunchFilter? filter,
    LaunchOrder? orderBy,
  }) => object(
    'launches',
    LaunchConnection.new,
    args: {
      'first': Arg('Int', first),
      'after': Arg('String', after),
      'filter': Arg('LaunchFilter', filter?.toJson()),
      'orderBy': Arg('LaunchOrder', orderBy?.toGraphQL()),
    },
  );

  /// Classic offset pagination over the same data.
  List<Launch>? launchesPage({
    int? limit,
    int? offset,
    LaunchFilter? filter,
    LaunchOrder? orderBy,
  }) => list(
    'launchesPage',
    Launch.new,
    args: {
      'limit': Arg('Int', limit),
      'offset': Arg('Int', offset),
      'filter': Arg('LaunchFilter', filter?.toJson()),
      'orderBy': Arg('LaunchOrder', orderBy?.toGraphQL()),
    },
    keyed: true,
  );

  /// The signed-in user (static in the mock).
  Viewer? get me => object('me', Viewer.new, keyed: true);
  Launch? launch({required String id}) => object(
    'launch',
    Launch.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Launch',
  );
  Launch? get nextLaunch => object('nextLaunch', Launch.new, keyed: true);
  Launch? get latestLaunch => object('latestLaunch', Launch.new, keyed: true);
  List<Rocket>? get rockets => list('rockets', Rocket.new, keyed: true);
  Rocket? rocket({required String id}) => object(
    'rocket',
    Rocket.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Rocket',
  );
  List<Launchpad>? get launchpads =>
      list('launchpads', Launchpad.new, keyed: true);
  AstronautConnection? astronauts({int? first, String? after}) => object(
    'astronauts',
    AstronautConnection.new,
    args: {'first': Arg('Int', first), 'after': Arg('String', after)},
  );
  Astronaut? astronaut({required String id}) => object(
    'astronaut',
    Astronaut.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Astronaut',
  );
  Stats? get stats => object('stats', Stats.new);
}

class Mutation extends Accessor {
  Mutation(super.recorder, super.selection, super.path);
  Mutation.root(Recorder r) : super(r, r.root, const []);

  Launch? toggleFavorite({required String launchId}) => object(
    'toggleFavorite',
    Launch.new,
    args: {'launchId': Arg('ID!', launchId)},
    keyed: true,
  );
  Launch? scheduleLaunch({required ScheduleLaunchInput input}) => object(
    'scheduleLaunch',
    Launch.new,
    args: {'input': Arg('ScheduleLaunchInput!', input.toJson())},
    keyed: true,
  );
  Launch? updateLaunchStatus({
    required String id,
    required LaunchStatus status,
  }) => object(
    'updateLaunchStatus',
    Launch.new,
    args: {
      'id': Arg('ID!', id),
      'status': Arg('LaunchStatus!', status.toGraphQL()),
    },
    keyed: true,
  );
}

/// Typed mutations for this schema. See `SlingClient.mutateWith`.
extension SlingMutations on SlingClient<Query> {
  Future<T> mutate<T>(
    T Function(Mutation mutation) body, {
    void Function()? optimistic,
  }) => mutateWith(Mutation.root, body, optimistic: optimistic);
}

class PageInfo extends Accessor {
  PageInfo(super.recorder, super.selection, super.path);

  bool? get hasNextPage => scalar<bool>('hasNextPage');
  bool? get hasPreviousPage => scalar<bool>('hasPreviousPage');
  String? get startCursor => scalar<String>('startCursor');
  String? get endCursor => scalar<String>('endCursor');
}

class Address extends Accessor {
  Address(super.recorder, super.selection, super.path);

  String? get street => scalar<String>('street');
  set street(String? v) => write('street', v);
  String? get city => scalar<String>('city');
  set city(String? v) => write('city', v);
  String? get state => scalar<String>('state');
  set state(String? v) => write('state', v);
  String? get country => scalar<String>('country');
  set country(String? v) => write('country', v);
}

class Company extends Accessor {
  Company(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  String? get founder => scalar<String>('founder');
  set founder(String? v) => write('founder', v);
  int? get founded => scalar<int>('founded');
  set founded(int? v) => write('founded', v);
  int? get employees => scalar<int>('employees');
  set employees(int? v) => write('employees', v);
  String? get ceo => scalar<String>('ceo');
  set ceo(String? v) => write('ceo', v);
  double? get valuation => scalar<double>('valuation');
  set valuation(double? v) => write('valuation', v);
  String? get summary => scalar<String>('summary');
  set summary(String? v) => write('summary', v);
  Address? get headquarters => object('headquarters', Address.new);
}

class Dimension extends Accessor {
  Dimension(super.recorder, super.selection, super.path);

  double? get meters => scalar<double>('meters');
  set meters(double? v) => write('meters', v);
  double? get feet => scalar<double>('feet');
  set feet(double? v) => write('feet', v);
}

class Mass extends Accessor {
  Mass(super.recorder, super.selection, super.path);

  int? get kg => scalar<int>('kg');
  set kg(int? v) => write('kg', v);
  int? get lb => scalar<int>('lb');
  set lb(int? v) => write('lb', v);
}

class Engine extends Accessor {
  Engine(super.recorder, super.selection, super.path);

  int? get count => scalar<int>('count');
  set count(int? v) => write('count', v);
  String? get type$ => scalar<String>('type');
  set type$(String? v) => write('type', v);
  String? get propellant => scalar<String>('propellant');
  set propellant(String? v) => write('propellant', v);
  double? get thrustSeaLevelKN => scalar<double>('thrustSeaLevelKN');
  set thrustSeaLevelKN(double? v) => write('thrustSeaLevelKN', v);
  double? get thrustVacuumKN => scalar<double>('thrustVacuumKN');
  set thrustVacuumKN(double? v) => write('thrustVacuumKN', v);
}

class Rocket extends Accessor {
  Rocket(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  RocketFamily? get family => enumValue('family', RocketFamily.fromGraphQL);
  set family(RocketFamily? v) => write('family', v?.graphqlName);
  String? get description => scalar<String>('description');
  set description(String? v) => write('description', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  int? get stages => scalar<int>('stages');
  set stages(int? v) => write('stages', v);
  int? get costPerLaunch => scalar<int>('costPerLaunch');
  set costPerLaunch(int? v) => write('costPerLaunch', v);
  int? get successRatePct => scalar<int>('successRatePct');
  set successRatePct(int? v) => write('successRatePct', v);
  DateTime? get firstFlight =>
      scalarAs<DateTime, String>('firstFlight', DateTime.parse);
  set firstFlight(DateTime? v) => write('firstFlight', v?.toIso8601String());
  Dimension? get height => object('height', Dimension.new);
  Dimension? get diameter => object('diameter', Dimension.new);
  Mass? get mass => object('mass', Mass.new);
  Engine? get engines => object('engines', Engine.new);
  String? get wikipedia => scalar<String>('wikipedia');
  set wikipedia(String? v) => write('wikipedia', v);

  /// Launches flown by this rocket, newest first (nested cursor pagination).
  LaunchConnection? launches({int? first, String? after}) => object(
    'launches',
    LaunchConnection.new,
    args: {'first': Arg('Int', first), 'after': Arg('String', after)},
  );
}

class Launchpad extends Accessor {
  Launchpad(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  String? get fullName => scalar<String>('fullName');
  set fullName(String? v) => write('fullName', v);
  String? get locality => scalar<String>('locality');
  set locality(String? v) => write('locality', v);
  String? get region => scalar<String>('region');
  set region(String? v) => write('region', v);
  double? get latitude => scalar<double>('latitude');
  set latitude(double? v) => write('latitude', v);
  double? get longitude => scalar<double>('longitude');
  set longitude(double? v) => write('longitude', v);
  String? get status => scalar<String>('status');
  set status(String? v) => write('status', v);
  int? get launchAttempts => scalar<int>('launchAttempts');
  set launchAttempts(int? v) => write('launchAttempts', v);
  int? get launchSuccesses => scalar<int>('launchSuccesses');
  set launchSuccesses(int? v) => write('launchSuccesses', v);
}

class Astronaut extends Accessor {
  Astronaut(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  String? get nationality => scalar<String>('nationality');
  set nationality(String? v) => write('nationality', v);
  String? get agency => scalar<String>('agency');
  set agency(String? v) => write('agency', v);
  String? get bio => scalar<String>('bio');
  set bio(String? v) => write('bio', v);
  int? get flights => scalar<int>('flights');
  set flights(int? v) => write('flights', v);
  List<Launch>? get missions => list('missions', Launch.new, keyed: true);
}

class Payload extends Accessor {
  Payload(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  String? get type$ => scalar<String>('type');
  set type$(String? v) => write('type', v);
  double? get massKg => scalar<double>('massKg');
  set massKg(double? v) => write('massKg', v);
  String? get orbit => scalar<String>('orbit');
  set orbit(String? v) => write('orbit', v);
  List<String?>? get customers => scalarList<String>('customers');
}

class Links extends Accessor {
  Links(super.recorder, super.selection, super.path);

  String? get article => scalar<String>('article');
  set article(String? v) => write('article', v);
  String? get video => scalar<String>('video');
  set video(String? v) => write('video', v);
  String? get wikipedia => scalar<String>('wikipedia');
  set wikipedia(String? v) => write('wikipedia', v);
  String? get patch => scalar<String>('patch');
  set patch(String? v) => write('patch', v);
  List<String?>? get flickrImages => scalarList<String>('flickrImages');
}

class Launch extends Accessor {
  Launch(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  int? get flightNumber => scalar<int>('flightNumber');
  set flightNumber(int? v) => write('flightNumber', v);
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  String? get details => scalar<String>('details');
  set details(String? v) => write('details', v);
  DateTime? get date => scalarAs<DateTime, String>('date', DateTime.parse);
  set date(DateTime? v) => write('date', v?.toIso8601String());
  LaunchStatus? get status => enumValue('status', LaunchStatus.fromGraphQL);
  set status(LaunchStatus? v) => write('status', v?.graphqlName);
  bool? get upcoming => scalar<bool>('upcoming');
  set upcoming(bool? v) => write('upcoming', v);
  Rocket? get rocket => object('rocket', Rocket.new, keyed: true);
  Launchpad? get launchpad => object('launchpad', Launchpad.new, keyed: true);
  List<Payload>? get payloads => list('payloads', Payload.new, keyed: true);
  List<Astronaut>? get crew => list('crew', Astronaut.new, keyed: true);
  Links? get links => object('links', Links.new);

  /// Client-side favourite flag, toggled via Mutation.toggleFavorite.
  bool? get favorite => scalar<bool>('favorite');
  set favorite(bool? v) => write('favorite', v);
}

class LaunchEdge extends Accessor {
  LaunchEdge(super.recorder, super.selection, super.path);

  String? get cursor => scalar<String>('cursor');
  set cursor(String? v) => write('cursor', v);
  Launch? get node => object('node', Launch.new, keyed: true);
}

class LaunchConnection extends Accessor {
  LaunchConnection(super.recorder, super.selection, super.path);

  List<LaunchEdge>? get edges => list('edges', LaunchEdge.new);
  List<Launch>? get nodes => list('nodes', Launch.new, keyed: true);
  PageInfo? get pageInfo => object('pageInfo', PageInfo.new);
  int? get totalCount => scalar<int>('totalCount');
}

class AstronautEdge extends Accessor {
  AstronautEdge(super.recorder, super.selection, super.path);

  String? get cursor => scalar<String>('cursor');
  set cursor(String? v) => write('cursor', v);
  Astronaut? get node => object('node', Astronaut.new, keyed: true);
}

class AstronautConnection extends Accessor {
  AstronautConnection(super.recorder, super.selection, super.path);

  List<AstronautEdge>? get edges => list('edges', AstronautEdge.new);
  List<Astronaut>? get nodes => list('nodes', Astronaut.new, keyed: true);
  PageInfo? get pageInfo => object('pageInfo', PageInfo.new);
  int? get totalCount => scalar<int>('totalCount');
}

class YearCount extends Accessor {
  YearCount(super.recorder, super.selection, super.path);

  int? get year => scalar<int>('year');
  set year(int? v) => write('year', v);
  int? get count => scalar<int>('count');
  set count(int? v) => write('count', v);
}

class Stats extends Accessor {
  Stats(super.recorder, super.selection, super.path);

  int? get totalLaunches => scalar<int>('totalLaunches');
  set totalLaunches(int? v) => write('totalLaunches', v);
  double? get successRatePct => scalar<double>('successRatePct');
  set successRatePct(double? v) => write('successRatePct', v);
  List<YearCount>? get launchesPerYear =>
      list('launchesPerYear', YearCount.new);
}

class Viewer extends Accessor {
  Viewer(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  String? get agency => scalar<String>('agency');
  set agency(String? v) => write('agency', v);
  String? get avatarInitials => scalar<String>('avatarInitials');
  set avatarInitials(String? v) => write('avatarInitials', v);
  int? get favoriteCount => scalar<int>('favoriteCount');
  set favoriteCount(int? v) => write('favoriteCount', v);

  /// Favourite launches, most recent first.
  List<Launch>? get favorites => list('favorites', Launch.new, keyed: true);
}

enum LaunchStatus {
  scheduled('SCHEDULED'),
  success('SUCCESS'),
  failure('FAILURE'),
  partialFailure('PARTIAL_FAILURE'),
  scrubbed('SCRUBBED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const LaunchStatus(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static LaunchStatus fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'LaunchStatus',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum LaunchOrder {
  dateAsc('DATE_ASC'),
  dateDesc('DATE_DESC'),
  nameAsc('NAME_ASC'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const LaunchOrder(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static LaunchOrder fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'LaunchOrder',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum RocketFamily {
  falcon('FALCON'),
  starship('STARSHIP'),
  atlas('ATLAS'),
  ariane('ARIANE'),
  vulcan('VULCAN'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const RocketFamily(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static RocketFamily fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'RocketFamily',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

class LaunchFilter {
  const LaunchFilter({
    this.status,
    this.rocketId,
    this.year,
    this.upcoming,
    this.search,
    this.favorite,
  });

  final LaunchStatus? status;
  final String? rocketId;
  final int? year;
  final bool? upcoming;

  /// Case-insensitive substring match on name and details.
  final String? search;

  /// Only launches whose favourite flag equals this value.
  final bool? favorite;

  Map<String, Object?> toJson() => {
    if (status != null) 'status': status?.toGraphQL(),
    if (rocketId != null) 'rocketId': rocketId,
    if (year != null) 'year': year,
    if (upcoming != null) 'upcoming': upcoming,
    if (search != null) 'search': search,
    if (favorite != null) 'favorite': favorite,
  };
}

class ScheduleLaunchInput {
  const ScheduleLaunchInput({
    this.name,
    this.rocketId,
    this.launchpadId,
    this.date,
    this.details,
    this.payloadNames,
  });

  final String? name;
  final String? rocketId;
  final String? launchpadId;
  final DateTime? date;
  final String? details;
  final List<String>? payloadNames;

  Map<String, Object?> toJson() => {
    if (name != null) 'name': name,
    if (rocketId != null) 'rocketId': rocketId,
    if (launchpadId != null) 'launchpadId': launchpadId,
    if (date != null) 'date': date?.toIso8601String(),
    if (details != null) 'details': details,
    if (payloadNames != null) 'payloadNames': payloadNames,
  };
}
