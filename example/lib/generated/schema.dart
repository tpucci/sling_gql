// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: non_constant_identifier_names, camel_case_types, constant_identifier_names, camel_case_extensions

import 'package:sling_gql/sling_gql.dart';

class Query extends Accessor {
  Query(super.recorder, super.selection, super.path);
  Query.root(Recorder r) : super(r, r.root, const []);

  Company? get company => object('company', Company.new);

  /// Relay-style cursor pagination.
  LaunchConnection? launches({
    int? first,
    String? after,
    LaunchFilter? filter,
    String? orderBy,
  }) => object(
    'launches',
    LaunchConnection.new,
    args: {
      'first': Arg('Int', first),
      'after': Arg('String', after),
      'filter': Arg('LaunchFilter', filter?.toJson()),
      'orderBy': Arg('LaunchOrder', orderBy),
    },
  );

  /// Classic offset pagination over the same data.
  List<Launch>? launchesPage({
    int? limit,
    int? offset,
    LaunchFilter? filter,
    String? orderBy,
  }) => list(
    'launchesPage',
    Launch.new,
    args: {
      'limit': Arg('Int', limit),
      'offset': Arg('Int', offset),
      'filter': Arg('LaunchFilter', filter?.toJson()),
      'orderBy': Arg('LaunchOrder', orderBy),
    },
  );
  Launch? launch({required String id}) =>
      object('launch', Launch.new, args: {'id': Arg('ID!', id)});
  Launch? get nextLaunch => object('nextLaunch', Launch.new);
  Launch? get latestLaunch => object('latestLaunch', Launch.new);
  List<Rocket>? get rockets => list('rockets', Rocket.new);
  Rocket? rocket({required String id}) =>
      object('rocket', Rocket.new, args: {'id': Arg('ID!', id)});
  List<Launchpad>? get launchpads => list('launchpads', Launchpad.new);
  AstronautConnection? astronauts({int? first, String? after}) => object(
    'astronauts',
    AstronautConnection.new,
    args: {'first': Arg('Int', first), 'after': Arg('String', after)},
  );
  Astronaut? astronaut({required String id}) =>
      object('astronaut', Astronaut.new, args: {'id': Arg('ID!', id)});
  Stats? get stats => object('stats', Stats.new);
}

class PageInfo extends Accessor {
  PageInfo(super.recorder, super.selection, super.path);

  bool? get hasNextPage => scalar<bool>('hasNextPage');
  set hasNextPage(bool? v) => write('hasNextPage', v);
  bool? get hasPreviousPage => scalar<bool>('hasPreviousPage');
  set hasPreviousPage(bool? v) => write('hasPreviousPage', v);
  String? get startCursor => scalar<String>('startCursor');
  set startCursor(String? v) => write('startCursor', v);
  String? get endCursor => scalar<String>('endCursor');
  set endCursor(String? v) => write('endCursor', v);
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
  set id(String? v) => write('id', v);
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
  set id(String? v) => write('id', v);
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  String? get family => scalar<String>('family');
  set family(String? v) => write('family', v);
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
  String? get firstFlight => scalar<String>('firstFlight');
  set firstFlight(String? v) => write('firstFlight', v);
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
  set id(String? v) => write('id', v);
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
  set id(String? v) => write('id', v);
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
  List<Launch>? get missions => list('missions', Launch.new);
}

class Payload extends Accessor {
  Payload(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  set id(String? v) => write('id', v);
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
  set id(String? v) => write('id', v);
  int? get flightNumber => scalar<int>('flightNumber');
  set flightNumber(int? v) => write('flightNumber', v);
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  String? get details => scalar<String>('details');
  set details(String? v) => write('details', v);
  String? get date => scalar<String>('date');
  set date(String? v) => write('date', v);
  String? get status => scalar<String>('status');
  set status(String? v) => write('status', v);
  bool? get upcoming => scalar<bool>('upcoming');
  set upcoming(bool? v) => write('upcoming', v);
  Rocket? get rocket => object('rocket', Rocket.new);
  Launchpad? get launchpad => object('launchpad', Launchpad.new);
  List<Payload>? get payloads => list('payloads', Payload.new);
  List<Astronaut>? get crew => list('crew', Astronaut.new);
  Links? get links => object('links', Links.new);

  /// Client-side favourite flag, toggled via Mutation.toggleFavorite.
  bool? get favorite => scalar<bool>('favorite');
  set favorite(bool? v) => write('favorite', v);
}

class LaunchEdge extends Accessor {
  LaunchEdge(super.recorder, super.selection, super.path);

  String? get cursor => scalar<String>('cursor');
  set cursor(String? v) => write('cursor', v);
  Launch? get node => object('node', Launch.new);
}

class LaunchConnection extends Accessor {
  LaunchConnection(super.recorder, super.selection, super.path);

  List<LaunchEdge>? get edges => list('edges', LaunchEdge.new);
  List<Launch>? get nodes => list('nodes', Launch.new);
  PageInfo? get pageInfo => object('pageInfo', PageInfo.new);
  int? get totalCount => scalar<int>('totalCount');
  set totalCount(int? v) => write('totalCount', v);
}

class AstronautEdge extends Accessor {
  AstronautEdge(super.recorder, super.selection, super.path);

  String? get cursor => scalar<String>('cursor');
  set cursor(String? v) => write('cursor', v);
  Astronaut? get node => object('node', Astronaut.new);
}

class AstronautConnection extends Accessor {
  AstronautConnection(super.recorder, super.selection, super.path);

  List<AstronautEdge>? get edges => list('edges', AstronautEdge.new);
  List<Astronaut>? get nodes => list('nodes', Astronaut.new);
  PageInfo? get pageInfo => object('pageInfo', PageInfo.new);
  int? get totalCount => scalar<int>('totalCount');
  set totalCount(int? v) => write('totalCount', v);
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

abstract final class LaunchStatus {
  static const SCHEDULED = 'SCHEDULED';
  static const SUCCESS = 'SUCCESS';
  static const FAILURE = 'FAILURE';
  static const PARTIAL_FAILURE = 'PARTIAL_FAILURE';
  static const SCRUBBED = 'SCRUBBED';
}

abstract final class LaunchOrder {
  static const DATE_ASC = 'DATE_ASC';
  static const DATE_DESC = 'DATE_DESC';
  static const NAME_ASC = 'NAME_ASC';
}

abstract final class RocketFamily {
  static const FALCON = 'FALCON';
  static const STARSHIP = 'STARSHIP';
  static const ATLAS = 'ATLAS';
  static const ARIANE = 'ARIANE';
  static const VULCAN = 'VULCAN';
}

class LaunchFilter {
  const LaunchFilter({
    this.status,
    this.rocketId,
    this.year,
    this.upcoming,
    this.search,
  });

  final String? status;
  final String? rocketId;
  final int? year;
  final bool? upcoming;

  /// Case-insensitive substring match on name and details.
  final String? search;

  Map<String, Object?> toJson() => {
    if (status != null) 'status': status,
    if (rocketId != null) 'rocketId': rocketId,
    if (year != null) 'year': year,
    if (upcoming != null) 'upcoming': upcoming,
    if (search != null) 'search': search,
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
  final String? date;
  final String? details;
  final List<String>? payloadNames;

  Map<String, Object?> toJson() => {
    if (name != null) 'name': name,
    if (rocketId != null) 'rocketId': rocketId,
    if (launchpadId != null) 'launchpadId': launchpadId,
    if (date != null) 'date': date,
    if (details != null) 'details': details,
    if (payloadNames != null) 'payloadNames': payloadNames,
  };
}
