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

  Thing000? thing000({required String id}) => object(
    'thing000',
    Thing000.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing000',
  );
  List<Thing000>? things000({required int page, Filter0? filter}) => list(
    'things000',
    Thing000.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing001? thing001({required String id}) => object(
    'thing001',
    Thing001.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing001',
  );
  List<Thing001>? things001({required int page, Filter1? filter}) => list(
    'things001',
    Thing001.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing002? thing002({required String id}) => object(
    'thing002',
    Thing002.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing002',
  );
  List<Thing002>? things002({required int page, Filter2? filter}) => list(
    'things002',
    Thing002.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing003? thing003({required String id}) => object(
    'thing003',
    Thing003.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing003',
  );
  List<Thing003>? things003({required int page, Filter3? filter}) => list(
    'things003',
    Thing003.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing004? thing004({required String id}) => object(
    'thing004',
    Thing004.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing004',
  );
  List<Thing004>? things004({required int page, Filter4? filter}) => list(
    'things004',
    Thing004.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing005? thing005({required String id}) => object(
    'thing005',
    Thing005.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing005',
  );
  List<Thing005>? things005({required int page, Filter0? filter}) => list(
    'things005',
    Thing005.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing006? thing006({required String id}) => object(
    'thing006',
    Thing006.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing006',
  );
  List<Thing006>? things006({required int page, Filter1? filter}) => list(
    'things006',
    Thing006.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing007? thing007({required String id}) => object(
    'thing007',
    Thing007.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing007',
  );
  List<Thing007>? things007({required int page, Filter2? filter}) => list(
    'things007',
    Thing007.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing008? thing008({required String id}) => object(
    'thing008',
    Thing008.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing008',
  );
  List<Thing008>? things008({required int page, Filter3? filter}) => list(
    'things008',
    Thing008.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing009? thing009({required String id}) => object(
    'thing009',
    Thing009.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing009',
  );
  List<Thing009>? things009({required int page, Filter4? filter}) => list(
    'things009',
    Thing009.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing010? thing010({required String id}) => object(
    'thing010',
    Thing010.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing010',
  );
  List<Thing010>? things010({required int page, Filter0? filter}) => list(
    'things010',
    Thing010.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing011? thing011({required String id}) => object(
    'thing011',
    Thing011.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing011',
  );
  List<Thing011>? things011({required int page, Filter1? filter}) => list(
    'things011',
    Thing011.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing012? thing012({required String id}) => object(
    'thing012',
    Thing012.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing012',
  );
  List<Thing012>? things012({required int page, Filter2? filter}) => list(
    'things012',
    Thing012.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing013? thing013({required String id}) => object(
    'thing013',
    Thing013.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing013',
  );
  List<Thing013>? things013({required int page, Filter3? filter}) => list(
    'things013',
    Thing013.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing014? thing014({required String id}) => object(
    'thing014',
    Thing014.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing014',
  );
  List<Thing014>? things014({required int page, Filter4? filter}) => list(
    'things014',
    Thing014.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing015? thing015({required String id}) => object(
    'thing015',
    Thing015.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing015',
  );
  List<Thing015>? things015({required int page, Filter0? filter}) => list(
    'things015',
    Thing015.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing016? thing016({required String id}) => object(
    'thing016',
    Thing016.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing016',
  );
  List<Thing016>? things016({required int page, Filter1? filter}) => list(
    'things016',
    Thing016.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing017? thing017({required String id}) => object(
    'thing017',
    Thing017.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing017',
  );
  List<Thing017>? things017({required int page, Filter2? filter}) => list(
    'things017',
    Thing017.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing018? thing018({required String id}) => object(
    'thing018',
    Thing018.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing018',
  );
  List<Thing018>? things018({required int page, Filter3? filter}) => list(
    'things018',
    Thing018.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing019? thing019({required String id}) => object(
    'thing019',
    Thing019.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing019',
  );
  List<Thing019>? things019({required int page, Filter4? filter}) => list(
    'things019',
    Thing019.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing020? thing020({required String id}) => object(
    'thing020',
    Thing020.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing020',
  );
  List<Thing020>? things020({required int page, Filter0? filter}) => list(
    'things020',
    Thing020.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing021? thing021({required String id}) => object(
    'thing021',
    Thing021.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing021',
  );
  List<Thing021>? things021({required int page, Filter1? filter}) => list(
    'things021',
    Thing021.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing022? thing022({required String id}) => object(
    'thing022',
    Thing022.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing022',
  );
  List<Thing022>? things022({required int page, Filter2? filter}) => list(
    'things022',
    Thing022.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing023? thing023({required String id}) => object(
    'thing023',
    Thing023.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing023',
  );
  List<Thing023>? things023({required int page, Filter3? filter}) => list(
    'things023',
    Thing023.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing024? thing024({required String id}) => object(
    'thing024',
    Thing024.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing024',
  );
  List<Thing024>? things024({required int page, Filter4? filter}) => list(
    'things024',
    Thing024.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing025? thing025({required String id}) => object(
    'thing025',
    Thing025.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing025',
  );
  List<Thing025>? things025({required int page, Filter0? filter}) => list(
    'things025',
    Thing025.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing026? thing026({required String id}) => object(
    'thing026',
    Thing026.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing026',
  );
  List<Thing026>? things026({required int page, Filter1? filter}) => list(
    'things026',
    Thing026.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing027? thing027({required String id}) => object(
    'thing027',
    Thing027.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing027',
  );
  List<Thing027>? things027({required int page, Filter2? filter}) => list(
    'things027',
    Thing027.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing028? thing028({required String id}) => object(
    'thing028',
    Thing028.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing028',
  );
  List<Thing028>? things028({required int page, Filter3? filter}) => list(
    'things028',
    Thing028.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing029? thing029({required String id}) => object(
    'thing029',
    Thing029.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing029',
  );
  List<Thing029>? things029({required int page, Filter4? filter}) => list(
    'things029',
    Thing029.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing030? thing030({required String id}) => object(
    'thing030',
    Thing030.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing030',
  );
  List<Thing030>? things030({required int page, Filter0? filter}) => list(
    'things030',
    Thing030.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing031? thing031({required String id}) => object(
    'thing031',
    Thing031.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing031',
  );
  List<Thing031>? things031({required int page, Filter1? filter}) => list(
    'things031',
    Thing031.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing032? thing032({required String id}) => object(
    'thing032',
    Thing032.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing032',
  );
  List<Thing032>? things032({required int page, Filter2? filter}) => list(
    'things032',
    Thing032.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing033? thing033({required String id}) => object(
    'thing033',
    Thing033.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing033',
  );
  List<Thing033>? things033({required int page, Filter3? filter}) => list(
    'things033',
    Thing033.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing034? thing034({required String id}) => object(
    'thing034',
    Thing034.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing034',
  );
  List<Thing034>? things034({required int page, Filter4? filter}) => list(
    'things034',
    Thing034.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing035? thing035({required String id}) => object(
    'thing035',
    Thing035.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing035',
  );
  List<Thing035>? things035({required int page, Filter0? filter}) => list(
    'things035',
    Thing035.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing036? thing036({required String id}) => object(
    'thing036',
    Thing036.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing036',
  );
  List<Thing036>? things036({required int page, Filter1? filter}) => list(
    'things036',
    Thing036.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing037? thing037({required String id}) => object(
    'thing037',
    Thing037.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing037',
  );
  List<Thing037>? things037({required int page, Filter2? filter}) => list(
    'things037',
    Thing037.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing038? thing038({required String id}) => object(
    'thing038',
    Thing038.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing038',
  );
  List<Thing038>? things038({required int page, Filter3? filter}) => list(
    'things038',
    Thing038.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing039? thing039({required String id}) => object(
    'thing039',
    Thing039.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing039',
  );
  List<Thing039>? things039({required int page, Filter4? filter}) => list(
    'things039',
    Thing039.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing040? thing040({required String id}) => object(
    'thing040',
    Thing040.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing040',
  );
  List<Thing040>? things040({required int page, Filter0? filter}) => list(
    'things040',
    Thing040.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing041? thing041({required String id}) => object(
    'thing041',
    Thing041.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing041',
  );
  List<Thing041>? things041({required int page, Filter1? filter}) => list(
    'things041',
    Thing041.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing042? thing042({required String id}) => object(
    'thing042',
    Thing042.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing042',
  );
  List<Thing042>? things042({required int page, Filter2? filter}) => list(
    'things042',
    Thing042.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing043? thing043({required String id}) => object(
    'thing043',
    Thing043.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing043',
  );
  List<Thing043>? things043({required int page, Filter3? filter}) => list(
    'things043',
    Thing043.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing044? thing044({required String id}) => object(
    'thing044',
    Thing044.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing044',
  );
  List<Thing044>? things044({required int page, Filter4? filter}) => list(
    'things044',
    Thing044.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing045? thing045({required String id}) => object(
    'thing045',
    Thing045.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing045',
  );
  List<Thing045>? things045({required int page, Filter0? filter}) => list(
    'things045',
    Thing045.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing046? thing046({required String id}) => object(
    'thing046',
    Thing046.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing046',
  );
  List<Thing046>? things046({required int page, Filter1? filter}) => list(
    'things046',
    Thing046.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing047? thing047({required String id}) => object(
    'thing047',
    Thing047.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing047',
  );
  List<Thing047>? things047({required int page, Filter2? filter}) => list(
    'things047',
    Thing047.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing048? thing048({required String id}) => object(
    'thing048',
    Thing048.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing048',
  );
  List<Thing048>? things048({required int page, Filter3? filter}) => list(
    'things048',
    Thing048.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing049? thing049({required String id}) => object(
    'thing049',
    Thing049.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing049',
  );
  List<Thing049>? things049({required int page, Filter4? filter}) => list(
    'things049',
    Thing049.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing050? thing050({required String id}) => object(
    'thing050',
    Thing050.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing050',
  );
  List<Thing050>? things050({required int page, Filter0? filter}) => list(
    'things050',
    Thing050.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing051? thing051({required String id}) => object(
    'thing051',
    Thing051.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing051',
  );
  List<Thing051>? things051({required int page, Filter1? filter}) => list(
    'things051',
    Thing051.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing052? thing052({required String id}) => object(
    'thing052',
    Thing052.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing052',
  );
  List<Thing052>? things052({required int page, Filter2? filter}) => list(
    'things052',
    Thing052.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing053? thing053({required String id}) => object(
    'thing053',
    Thing053.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing053',
  );
  List<Thing053>? things053({required int page, Filter3? filter}) => list(
    'things053',
    Thing053.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing054? thing054({required String id}) => object(
    'thing054',
    Thing054.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing054',
  );
  List<Thing054>? things054({required int page, Filter4? filter}) => list(
    'things054',
    Thing054.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing055? thing055({required String id}) => object(
    'thing055',
    Thing055.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing055',
  );
  List<Thing055>? things055({required int page, Filter0? filter}) => list(
    'things055',
    Thing055.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing056? thing056({required String id}) => object(
    'thing056',
    Thing056.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing056',
  );
  List<Thing056>? things056({required int page, Filter1? filter}) => list(
    'things056',
    Thing056.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing057? thing057({required String id}) => object(
    'thing057',
    Thing057.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing057',
  );
  List<Thing057>? things057({required int page, Filter2? filter}) => list(
    'things057',
    Thing057.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing058? thing058({required String id}) => object(
    'thing058',
    Thing058.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing058',
  );
  List<Thing058>? things058({required int page, Filter3? filter}) => list(
    'things058',
    Thing058.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing059? thing059({required String id}) => object(
    'thing059',
    Thing059.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing059',
  );
  List<Thing059>? things059({required int page, Filter4? filter}) => list(
    'things059',
    Thing059.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing060? thing060({required String id}) => object(
    'thing060',
    Thing060.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing060',
  );
  List<Thing060>? things060({required int page, Filter0? filter}) => list(
    'things060',
    Thing060.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing061? thing061({required String id}) => object(
    'thing061',
    Thing061.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing061',
  );
  List<Thing061>? things061({required int page, Filter1? filter}) => list(
    'things061',
    Thing061.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing062? thing062({required String id}) => object(
    'thing062',
    Thing062.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing062',
  );
  List<Thing062>? things062({required int page, Filter2? filter}) => list(
    'things062',
    Thing062.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing063? thing063({required String id}) => object(
    'thing063',
    Thing063.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing063',
  );
  List<Thing063>? things063({required int page, Filter3? filter}) => list(
    'things063',
    Thing063.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing064? thing064({required String id}) => object(
    'thing064',
    Thing064.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing064',
  );
  List<Thing064>? things064({required int page, Filter4? filter}) => list(
    'things064',
    Thing064.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing065? thing065({required String id}) => object(
    'thing065',
    Thing065.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing065',
  );
  List<Thing065>? things065({required int page, Filter0? filter}) => list(
    'things065',
    Thing065.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing066? thing066({required String id}) => object(
    'thing066',
    Thing066.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing066',
  );
  List<Thing066>? things066({required int page, Filter1? filter}) => list(
    'things066',
    Thing066.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing067? thing067({required String id}) => object(
    'thing067',
    Thing067.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing067',
  );
  List<Thing067>? things067({required int page, Filter2? filter}) => list(
    'things067',
    Thing067.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing068? thing068({required String id}) => object(
    'thing068',
    Thing068.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing068',
  );
  List<Thing068>? things068({required int page, Filter3? filter}) => list(
    'things068',
    Thing068.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing069? thing069({required String id}) => object(
    'thing069',
    Thing069.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing069',
  );
  List<Thing069>? things069({required int page, Filter4? filter}) => list(
    'things069',
    Thing069.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing070? thing070({required String id}) => object(
    'thing070',
    Thing070.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing070',
  );
  List<Thing070>? things070({required int page, Filter0? filter}) => list(
    'things070',
    Thing070.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing071? thing071({required String id}) => object(
    'thing071',
    Thing071.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing071',
  );
  List<Thing071>? things071({required int page, Filter1? filter}) => list(
    'things071',
    Thing071.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing072? thing072({required String id}) => object(
    'thing072',
    Thing072.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing072',
  );
  List<Thing072>? things072({required int page, Filter2? filter}) => list(
    'things072',
    Thing072.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing073? thing073({required String id}) => object(
    'thing073',
    Thing073.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing073',
  );
  List<Thing073>? things073({required int page, Filter3? filter}) => list(
    'things073',
    Thing073.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing074? thing074({required String id}) => object(
    'thing074',
    Thing074.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing074',
  );
  List<Thing074>? things074({required int page, Filter4? filter}) => list(
    'things074',
    Thing074.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing075? thing075({required String id}) => object(
    'thing075',
    Thing075.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing075',
  );
  List<Thing075>? things075({required int page, Filter0? filter}) => list(
    'things075',
    Thing075.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing076? thing076({required String id}) => object(
    'thing076',
    Thing076.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing076',
  );
  List<Thing076>? things076({required int page, Filter1? filter}) => list(
    'things076',
    Thing076.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing077? thing077({required String id}) => object(
    'thing077',
    Thing077.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing077',
  );
  List<Thing077>? things077({required int page, Filter2? filter}) => list(
    'things077',
    Thing077.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing078? thing078({required String id}) => object(
    'thing078',
    Thing078.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing078',
  );
  List<Thing078>? things078({required int page, Filter3? filter}) => list(
    'things078',
    Thing078.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing079? thing079({required String id}) => object(
    'thing079',
    Thing079.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing079',
  );
  List<Thing079>? things079({required int page, Filter4? filter}) => list(
    'things079',
    Thing079.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing080? thing080({required String id}) => object(
    'thing080',
    Thing080.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing080',
  );
  List<Thing080>? things080({required int page, Filter0? filter}) => list(
    'things080',
    Thing080.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing081? thing081({required String id}) => object(
    'thing081',
    Thing081.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing081',
  );
  List<Thing081>? things081({required int page, Filter1? filter}) => list(
    'things081',
    Thing081.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing082? thing082({required String id}) => object(
    'thing082',
    Thing082.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing082',
  );
  List<Thing082>? things082({required int page, Filter2? filter}) => list(
    'things082',
    Thing082.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing083? thing083({required String id}) => object(
    'thing083',
    Thing083.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing083',
  );
  List<Thing083>? things083({required int page, Filter3? filter}) => list(
    'things083',
    Thing083.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing084? thing084({required String id}) => object(
    'thing084',
    Thing084.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing084',
  );
  List<Thing084>? things084({required int page, Filter4? filter}) => list(
    'things084',
    Thing084.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing085? thing085({required String id}) => object(
    'thing085',
    Thing085.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing085',
  );
  List<Thing085>? things085({required int page, Filter0? filter}) => list(
    'things085',
    Thing085.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing086? thing086({required String id}) => object(
    'thing086',
    Thing086.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing086',
  );
  List<Thing086>? things086({required int page, Filter1? filter}) => list(
    'things086',
    Thing086.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing087? thing087({required String id}) => object(
    'thing087',
    Thing087.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing087',
  );
  List<Thing087>? things087({required int page, Filter2? filter}) => list(
    'things087',
    Thing087.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing088? thing088({required String id}) => object(
    'thing088',
    Thing088.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing088',
  );
  List<Thing088>? things088({required int page, Filter3? filter}) => list(
    'things088',
    Thing088.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing089? thing089({required String id}) => object(
    'thing089',
    Thing089.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing089',
  );
  List<Thing089>? things089({required int page, Filter4? filter}) => list(
    'things089',
    Thing089.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing090? thing090({required String id}) => object(
    'thing090',
    Thing090.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing090',
  );
  List<Thing090>? things090({required int page, Filter0? filter}) => list(
    'things090',
    Thing090.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing091? thing091({required String id}) => object(
    'thing091',
    Thing091.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing091',
  );
  List<Thing091>? things091({required int page, Filter1? filter}) => list(
    'things091',
    Thing091.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing092? thing092({required String id}) => object(
    'thing092',
    Thing092.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing092',
  );
  List<Thing092>? things092({required int page, Filter2? filter}) => list(
    'things092',
    Thing092.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing093? thing093({required String id}) => object(
    'thing093',
    Thing093.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing093',
  );
  List<Thing093>? things093({required int page, Filter3? filter}) => list(
    'things093',
    Thing093.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing094? thing094({required String id}) => object(
    'thing094',
    Thing094.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing094',
  );
  List<Thing094>? things094({required int page, Filter4? filter}) => list(
    'things094',
    Thing094.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing095? thing095({required String id}) => object(
    'thing095',
    Thing095.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing095',
  );
  List<Thing095>? things095({required int page, Filter0? filter}) => list(
    'things095',
    Thing095.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing096? thing096({required String id}) => object(
    'thing096',
    Thing096.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing096',
  );
  List<Thing096>? things096({required int page, Filter1? filter}) => list(
    'things096',
    Thing096.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing097? thing097({required String id}) => object(
    'thing097',
    Thing097.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing097',
  );
  List<Thing097>? things097({required int page, Filter2? filter}) => list(
    'things097',
    Thing097.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing098? thing098({required String id}) => object(
    'thing098',
    Thing098.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing098',
  );
  List<Thing098>? things098({required int page, Filter3? filter}) => list(
    'things098',
    Thing098.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing099? thing099({required String id}) => object(
    'thing099',
    Thing099.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing099',
  );
  List<Thing099>? things099({required int page, Filter4? filter}) => list(
    'things099',
    Thing099.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing100? thing100({required String id}) => object(
    'thing100',
    Thing100.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing100',
  );
  List<Thing100>? things100({required int page, Filter0? filter}) => list(
    'things100',
    Thing100.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing101? thing101({required String id}) => object(
    'thing101',
    Thing101.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing101',
  );
  List<Thing101>? things101({required int page, Filter1? filter}) => list(
    'things101',
    Thing101.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing102? thing102({required String id}) => object(
    'thing102',
    Thing102.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing102',
  );
  List<Thing102>? things102({required int page, Filter2? filter}) => list(
    'things102',
    Thing102.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing103? thing103({required String id}) => object(
    'thing103',
    Thing103.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing103',
  );
  List<Thing103>? things103({required int page, Filter3? filter}) => list(
    'things103',
    Thing103.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing104? thing104({required String id}) => object(
    'thing104',
    Thing104.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing104',
  );
  List<Thing104>? things104({required int page, Filter4? filter}) => list(
    'things104',
    Thing104.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing105? thing105({required String id}) => object(
    'thing105',
    Thing105.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing105',
  );
  List<Thing105>? things105({required int page, Filter0? filter}) => list(
    'things105',
    Thing105.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing106? thing106({required String id}) => object(
    'thing106',
    Thing106.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing106',
  );
  List<Thing106>? things106({required int page, Filter1? filter}) => list(
    'things106',
    Thing106.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing107? thing107({required String id}) => object(
    'thing107',
    Thing107.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing107',
  );
  List<Thing107>? things107({required int page, Filter2? filter}) => list(
    'things107',
    Thing107.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing108? thing108({required String id}) => object(
    'thing108',
    Thing108.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing108',
  );
  List<Thing108>? things108({required int page, Filter3? filter}) => list(
    'things108',
    Thing108.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing109? thing109({required String id}) => object(
    'thing109',
    Thing109.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing109',
  );
  List<Thing109>? things109({required int page, Filter4? filter}) => list(
    'things109',
    Thing109.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing110? thing110({required String id}) => object(
    'thing110',
    Thing110.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing110',
  );
  List<Thing110>? things110({required int page, Filter0? filter}) => list(
    'things110',
    Thing110.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing111? thing111({required String id}) => object(
    'thing111',
    Thing111.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing111',
  );
  List<Thing111>? things111({required int page, Filter1? filter}) => list(
    'things111',
    Thing111.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing112? thing112({required String id}) => object(
    'thing112',
    Thing112.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing112',
  );
  List<Thing112>? things112({required int page, Filter2? filter}) => list(
    'things112',
    Thing112.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing113? thing113({required String id}) => object(
    'thing113',
    Thing113.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing113',
  );
  List<Thing113>? things113({required int page, Filter3? filter}) => list(
    'things113',
    Thing113.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing114? thing114({required String id}) => object(
    'thing114',
    Thing114.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing114',
  );
  List<Thing114>? things114({required int page, Filter4? filter}) => list(
    'things114',
    Thing114.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing115? thing115({required String id}) => object(
    'thing115',
    Thing115.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing115',
  );
  List<Thing115>? things115({required int page, Filter0? filter}) => list(
    'things115',
    Thing115.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing116? thing116({required String id}) => object(
    'thing116',
    Thing116.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing116',
  );
  List<Thing116>? things116({required int page, Filter1? filter}) => list(
    'things116',
    Thing116.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing117? thing117({required String id}) => object(
    'thing117',
    Thing117.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing117',
  );
  List<Thing117>? things117({required int page, Filter2? filter}) => list(
    'things117',
    Thing117.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing118? thing118({required String id}) => object(
    'thing118',
    Thing118.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing118',
  );
  List<Thing118>? things118({required int page, Filter3? filter}) => list(
    'things118',
    Thing118.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing119? thing119({required String id}) => object(
    'thing119',
    Thing119.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing119',
  );
  List<Thing119>? things119({required int page, Filter4? filter}) => list(
    'things119',
    Thing119.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing120? thing120({required String id}) => object(
    'thing120',
    Thing120.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing120',
  );
  List<Thing120>? things120({required int page, Filter0? filter}) => list(
    'things120',
    Thing120.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing121? thing121({required String id}) => object(
    'thing121',
    Thing121.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing121',
  );
  List<Thing121>? things121({required int page, Filter1? filter}) => list(
    'things121',
    Thing121.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing122? thing122({required String id}) => object(
    'thing122',
    Thing122.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing122',
  );
  List<Thing122>? things122({required int page, Filter2? filter}) => list(
    'things122',
    Thing122.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing123? thing123({required String id}) => object(
    'thing123',
    Thing123.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing123',
  );
  List<Thing123>? things123({required int page, Filter3? filter}) => list(
    'things123',
    Thing123.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing124? thing124({required String id}) => object(
    'thing124',
    Thing124.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing124',
  );
  List<Thing124>? things124({required int page, Filter4? filter}) => list(
    'things124',
    Thing124.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing125? thing125({required String id}) => object(
    'thing125',
    Thing125.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing125',
  );
  List<Thing125>? things125({required int page, Filter0? filter}) => list(
    'things125',
    Thing125.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing126? thing126({required String id}) => object(
    'thing126',
    Thing126.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing126',
  );
  List<Thing126>? things126({required int page, Filter1? filter}) => list(
    'things126',
    Thing126.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing127? thing127({required String id}) => object(
    'thing127',
    Thing127.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing127',
  );
  List<Thing127>? things127({required int page, Filter2? filter}) => list(
    'things127',
    Thing127.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing128? thing128({required String id}) => object(
    'thing128',
    Thing128.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing128',
  );
  List<Thing128>? things128({required int page, Filter3? filter}) => list(
    'things128',
    Thing128.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing129? thing129({required String id}) => object(
    'thing129',
    Thing129.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing129',
  );
  List<Thing129>? things129({required int page, Filter4? filter}) => list(
    'things129',
    Thing129.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing130? thing130({required String id}) => object(
    'thing130',
    Thing130.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing130',
  );
  List<Thing130>? things130({required int page, Filter0? filter}) => list(
    'things130',
    Thing130.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing131? thing131({required String id}) => object(
    'thing131',
    Thing131.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing131',
  );
  List<Thing131>? things131({required int page, Filter1? filter}) => list(
    'things131',
    Thing131.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing132? thing132({required String id}) => object(
    'thing132',
    Thing132.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing132',
  );
  List<Thing132>? things132({required int page, Filter2? filter}) => list(
    'things132',
    Thing132.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing133? thing133({required String id}) => object(
    'thing133',
    Thing133.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing133',
  );
  List<Thing133>? things133({required int page, Filter3? filter}) => list(
    'things133',
    Thing133.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing134? thing134({required String id}) => object(
    'thing134',
    Thing134.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing134',
  );
  List<Thing134>? things134({required int page, Filter4? filter}) => list(
    'things134',
    Thing134.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing135? thing135({required String id}) => object(
    'thing135',
    Thing135.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing135',
  );
  List<Thing135>? things135({required int page, Filter0? filter}) => list(
    'things135',
    Thing135.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing136? thing136({required String id}) => object(
    'thing136',
    Thing136.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing136',
  );
  List<Thing136>? things136({required int page, Filter1? filter}) => list(
    'things136',
    Thing136.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing137? thing137({required String id}) => object(
    'thing137',
    Thing137.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing137',
  );
  List<Thing137>? things137({required int page, Filter2? filter}) => list(
    'things137',
    Thing137.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing138? thing138({required String id}) => object(
    'thing138',
    Thing138.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing138',
  );
  List<Thing138>? things138({required int page, Filter3? filter}) => list(
    'things138',
    Thing138.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing139? thing139({required String id}) => object(
    'thing139',
    Thing139.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing139',
  );
  List<Thing139>? things139({required int page, Filter4? filter}) => list(
    'things139',
    Thing139.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing140? thing140({required String id}) => object(
    'thing140',
    Thing140.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing140',
  );
  List<Thing140>? things140({required int page, Filter0? filter}) => list(
    'things140',
    Thing140.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing141? thing141({required String id}) => object(
    'thing141',
    Thing141.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing141',
  );
  List<Thing141>? things141({required int page, Filter1? filter}) => list(
    'things141',
    Thing141.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing142? thing142({required String id}) => object(
    'thing142',
    Thing142.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing142',
  );
  List<Thing142>? things142({required int page, Filter2? filter}) => list(
    'things142',
    Thing142.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing143? thing143({required String id}) => object(
    'thing143',
    Thing143.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing143',
  );
  List<Thing143>? things143({required int page, Filter3? filter}) => list(
    'things143',
    Thing143.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing144? thing144({required String id}) => object(
    'thing144',
    Thing144.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing144',
  );
  List<Thing144>? things144({required int page, Filter4? filter}) => list(
    'things144',
    Thing144.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Thing145? thing145({required String id}) => object(
    'thing145',
    Thing145.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing145',
  );
  List<Thing145>? things145({required int page, Filter0? filter}) => list(
    'things145',
    Thing145.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter0', filter?.toJson()),
    },
    keyed: true,
  );
  Thing146? thing146({required String id}) => object(
    'thing146',
    Thing146.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing146',
  );
  List<Thing146>? things146({required int page, Filter1? filter}) => list(
    'things146',
    Thing146.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter1', filter?.toJson()),
    },
    keyed: true,
  );
  Thing147? thing147({required String id}) => object(
    'thing147',
    Thing147.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing147',
  );
  List<Thing147>? things147({required int page, Filter2? filter}) => list(
    'things147',
    Thing147.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter2', filter?.toJson()),
    },
    keyed: true,
  );
  Thing148? thing148({required String id}) => object(
    'thing148',
    Thing148.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing148',
  );
  List<Thing148>? things148({required int page, Filter3? filter}) => list(
    'things148',
    Thing148.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter3', filter?.toJson()),
    },
    keyed: true,
  );
  Thing149? thing149({required String id}) => object(
    'thing149',
    Thing149.new,
    args: {'id': Arg('ID!', id)},
    lookup: 'Thing149',
  );
  List<Thing149>? things149({required int page, Filter4? filter}) => list(
    'things149',
    Thing149.new,
    args: {
      'page': Arg('Int!', page),
      'filter': Arg('Filter4', filter?.toJson()),
    },
    keyed: true,
  );
  Node? node({required String id}) =>
      object('node', Node.new, args: {'id': Arg('ID!', id)}, keyed: true);
  List<Group0>? group0({required String text}) =>
      list('group0', Group0.new, args: {'text': Arg('String!', text)});
  List<Group1>? group1({required String text}) =>
      list('group1', Group1.new, args: {'text': Arg('String!', text)});
  List<Group2>? group2({required String text}) =>
      list('group2', Group2.new, args: {'text': Arg('String!', text)});
  List<Group3>? group3({required String text}) =>
      list('group3', Group3.new, args: {'text': Arg('String!', text)});
  List<Group4>? group4({required String text}) =>
      list('group4', Group4.new, args: {'text': Arg('String!', text)});
  List<Group5>? group5({required String text}) =>
      list('group5', Group5.new, args: {'text': Arg('String!', text)});
  List<Group6>? group6({required String text}) =>
      list('group6', Group6.new, args: {'text': Arg('String!', text)});
  List<Group7>? group7({required String text}) =>
      list('group7', Group7.new, args: {'text': Arg('String!', text)});
  List<Group8>? group8({required String text}) =>
      list('group8', Group8.new, args: {'text': Arg('String!', text)});
  List<Group9>? group9({required String text}) =>
      list('group9', Group9.new, args: {'text': Arg('String!', text)});
}

class Mutation extends Accessor {
  Mutation(super.recorder, super.selection, super.path);
  Mutation.root(Recorder r) : super(r, r.root, const []);

  Thing000? rename000({required String id, required String name}) => object(
    'rename000',
    Thing000.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing001? rename001({required String id, required String name}) => object(
    'rename001',
    Thing001.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing002? rename002({required String id, required String name}) => object(
    'rename002',
    Thing002.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing003? rename003({required String id, required String name}) => object(
    'rename003',
    Thing003.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing004? rename004({required String id, required String name}) => object(
    'rename004',
    Thing004.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing005? rename005({required String id, required String name}) => object(
    'rename005',
    Thing005.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing006? rename006({required String id, required String name}) => object(
    'rename006',
    Thing006.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing007? rename007({required String id, required String name}) => object(
    'rename007',
    Thing007.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing008? rename008({required String id, required String name}) => object(
    'rename008',
    Thing008.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing009? rename009({required String id, required String name}) => object(
    'rename009',
    Thing009.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing010? rename010({required String id, required String name}) => object(
    'rename010',
    Thing010.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing011? rename011({required String id, required String name}) => object(
    'rename011',
    Thing011.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing012? rename012({required String id, required String name}) => object(
    'rename012',
    Thing012.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing013? rename013({required String id, required String name}) => object(
    'rename013',
    Thing013.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing014? rename014({required String id, required String name}) => object(
    'rename014',
    Thing014.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing015? rename015({required String id, required String name}) => object(
    'rename015',
    Thing015.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing016? rename016({required String id, required String name}) => object(
    'rename016',
    Thing016.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing017? rename017({required String id, required String name}) => object(
    'rename017',
    Thing017.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing018? rename018({required String id, required String name}) => object(
    'rename018',
    Thing018.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing019? rename019({required String id, required String name}) => object(
    'rename019',
    Thing019.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing020? rename020({required String id, required String name}) => object(
    'rename020',
    Thing020.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing021? rename021({required String id, required String name}) => object(
    'rename021',
    Thing021.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing022? rename022({required String id, required String name}) => object(
    'rename022',
    Thing022.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing023? rename023({required String id, required String name}) => object(
    'rename023',
    Thing023.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing024? rename024({required String id, required String name}) => object(
    'rename024',
    Thing024.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing025? rename025({required String id, required String name}) => object(
    'rename025',
    Thing025.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing026? rename026({required String id, required String name}) => object(
    'rename026',
    Thing026.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing027? rename027({required String id, required String name}) => object(
    'rename027',
    Thing027.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing028? rename028({required String id, required String name}) => object(
    'rename028',
    Thing028.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing029? rename029({required String id, required String name}) => object(
    'rename029',
    Thing029.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing030? rename030({required String id, required String name}) => object(
    'rename030',
    Thing030.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing031? rename031({required String id, required String name}) => object(
    'rename031',
    Thing031.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing032? rename032({required String id, required String name}) => object(
    'rename032',
    Thing032.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing033? rename033({required String id, required String name}) => object(
    'rename033',
    Thing033.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing034? rename034({required String id, required String name}) => object(
    'rename034',
    Thing034.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing035? rename035({required String id, required String name}) => object(
    'rename035',
    Thing035.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing036? rename036({required String id, required String name}) => object(
    'rename036',
    Thing036.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing037? rename037({required String id, required String name}) => object(
    'rename037',
    Thing037.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing038? rename038({required String id, required String name}) => object(
    'rename038',
    Thing038.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing039? rename039({required String id, required String name}) => object(
    'rename039',
    Thing039.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing040? rename040({required String id, required String name}) => object(
    'rename040',
    Thing040.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing041? rename041({required String id, required String name}) => object(
    'rename041',
    Thing041.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing042? rename042({required String id, required String name}) => object(
    'rename042',
    Thing042.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing043? rename043({required String id, required String name}) => object(
    'rename043',
    Thing043.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing044? rename044({required String id, required String name}) => object(
    'rename044',
    Thing044.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing045? rename045({required String id, required String name}) => object(
    'rename045',
    Thing045.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing046? rename046({required String id, required String name}) => object(
    'rename046',
    Thing046.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing047? rename047({required String id, required String name}) => object(
    'rename047',
    Thing047.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing048? rename048({required String id, required String name}) => object(
    'rename048',
    Thing048.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing049? rename049({required String id, required String name}) => object(
    'rename049',
    Thing049.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing050? rename050({required String id, required String name}) => object(
    'rename050',
    Thing050.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing051? rename051({required String id, required String name}) => object(
    'rename051',
    Thing051.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing052? rename052({required String id, required String name}) => object(
    'rename052',
    Thing052.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing053? rename053({required String id, required String name}) => object(
    'rename053',
    Thing053.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing054? rename054({required String id, required String name}) => object(
    'rename054',
    Thing054.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing055? rename055({required String id, required String name}) => object(
    'rename055',
    Thing055.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing056? rename056({required String id, required String name}) => object(
    'rename056',
    Thing056.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing057? rename057({required String id, required String name}) => object(
    'rename057',
    Thing057.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing058? rename058({required String id, required String name}) => object(
    'rename058',
    Thing058.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing059? rename059({required String id, required String name}) => object(
    'rename059',
    Thing059.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing060? rename060({required String id, required String name}) => object(
    'rename060',
    Thing060.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing061? rename061({required String id, required String name}) => object(
    'rename061',
    Thing061.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing062? rename062({required String id, required String name}) => object(
    'rename062',
    Thing062.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing063? rename063({required String id, required String name}) => object(
    'rename063',
    Thing063.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing064? rename064({required String id, required String name}) => object(
    'rename064',
    Thing064.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing065? rename065({required String id, required String name}) => object(
    'rename065',
    Thing065.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing066? rename066({required String id, required String name}) => object(
    'rename066',
    Thing066.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing067? rename067({required String id, required String name}) => object(
    'rename067',
    Thing067.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing068? rename068({required String id, required String name}) => object(
    'rename068',
    Thing068.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing069? rename069({required String id, required String name}) => object(
    'rename069',
    Thing069.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing070? rename070({required String id, required String name}) => object(
    'rename070',
    Thing070.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing071? rename071({required String id, required String name}) => object(
    'rename071',
    Thing071.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing072? rename072({required String id, required String name}) => object(
    'rename072',
    Thing072.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing073? rename073({required String id, required String name}) => object(
    'rename073',
    Thing073.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing074? rename074({required String id, required String name}) => object(
    'rename074',
    Thing074.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing075? rename075({required String id, required String name}) => object(
    'rename075',
    Thing075.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing076? rename076({required String id, required String name}) => object(
    'rename076',
    Thing076.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing077? rename077({required String id, required String name}) => object(
    'rename077',
    Thing077.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing078? rename078({required String id, required String name}) => object(
    'rename078',
    Thing078.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing079? rename079({required String id, required String name}) => object(
    'rename079',
    Thing079.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing080? rename080({required String id, required String name}) => object(
    'rename080',
    Thing080.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing081? rename081({required String id, required String name}) => object(
    'rename081',
    Thing081.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing082? rename082({required String id, required String name}) => object(
    'rename082',
    Thing082.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing083? rename083({required String id, required String name}) => object(
    'rename083',
    Thing083.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing084? rename084({required String id, required String name}) => object(
    'rename084',
    Thing084.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing085? rename085({required String id, required String name}) => object(
    'rename085',
    Thing085.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing086? rename086({required String id, required String name}) => object(
    'rename086',
    Thing086.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing087? rename087({required String id, required String name}) => object(
    'rename087',
    Thing087.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing088? rename088({required String id, required String name}) => object(
    'rename088',
    Thing088.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing089? rename089({required String id, required String name}) => object(
    'rename089',
    Thing089.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing090? rename090({required String id, required String name}) => object(
    'rename090',
    Thing090.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing091? rename091({required String id, required String name}) => object(
    'rename091',
    Thing091.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing092? rename092({required String id, required String name}) => object(
    'rename092',
    Thing092.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing093? rename093({required String id, required String name}) => object(
    'rename093',
    Thing093.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing094? rename094({required String id, required String name}) => object(
    'rename094',
    Thing094.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing095? rename095({required String id, required String name}) => object(
    'rename095',
    Thing095.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing096? rename096({required String id, required String name}) => object(
    'rename096',
    Thing096.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing097? rename097({required String id, required String name}) => object(
    'rename097',
    Thing097.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing098? rename098({required String id, required String name}) => object(
    'rename098',
    Thing098.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing099? rename099({required String id, required String name}) => object(
    'rename099',
    Thing099.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing100? rename100({required String id, required String name}) => object(
    'rename100',
    Thing100.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing101? rename101({required String id, required String name}) => object(
    'rename101',
    Thing101.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing102? rename102({required String id, required String name}) => object(
    'rename102',
    Thing102.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing103? rename103({required String id, required String name}) => object(
    'rename103',
    Thing103.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing104? rename104({required String id, required String name}) => object(
    'rename104',
    Thing104.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing105? rename105({required String id, required String name}) => object(
    'rename105',
    Thing105.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing106? rename106({required String id, required String name}) => object(
    'rename106',
    Thing106.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing107? rename107({required String id, required String name}) => object(
    'rename107',
    Thing107.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing108? rename108({required String id, required String name}) => object(
    'rename108',
    Thing108.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing109? rename109({required String id, required String name}) => object(
    'rename109',
    Thing109.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing110? rename110({required String id, required String name}) => object(
    'rename110',
    Thing110.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing111? rename111({required String id, required String name}) => object(
    'rename111',
    Thing111.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing112? rename112({required String id, required String name}) => object(
    'rename112',
    Thing112.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing113? rename113({required String id, required String name}) => object(
    'rename113',
    Thing113.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing114? rename114({required String id, required String name}) => object(
    'rename114',
    Thing114.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing115? rename115({required String id, required String name}) => object(
    'rename115',
    Thing115.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing116? rename116({required String id, required String name}) => object(
    'rename116',
    Thing116.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing117? rename117({required String id, required String name}) => object(
    'rename117',
    Thing117.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing118? rename118({required String id, required String name}) => object(
    'rename118',
    Thing118.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing119? rename119({required String id, required String name}) => object(
    'rename119',
    Thing119.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing120? rename120({required String id, required String name}) => object(
    'rename120',
    Thing120.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing121? rename121({required String id, required String name}) => object(
    'rename121',
    Thing121.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing122? rename122({required String id, required String name}) => object(
    'rename122',
    Thing122.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing123? rename123({required String id, required String name}) => object(
    'rename123',
    Thing123.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing124? rename124({required String id, required String name}) => object(
    'rename124',
    Thing124.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing125? rename125({required String id, required String name}) => object(
    'rename125',
    Thing125.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing126? rename126({required String id, required String name}) => object(
    'rename126',
    Thing126.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing127? rename127({required String id, required String name}) => object(
    'rename127',
    Thing127.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing128? rename128({required String id, required String name}) => object(
    'rename128',
    Thing128.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing129? rename129({required String id, required String name}) => object(
    'rename129',
    Thing129.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing130? rename130({required String id, required String name}) => object(
    'rename130',
    Thing130.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing131? rename131({required String id, required String name}) => object(
    'rename131',
    Thing131.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing132? rename132({required String id, required String name}) => object(
    'rename132',
    Thing132.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing133? rename133({required String id, required String name}) => object(
    'rename133',
    Thing133.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing134? rename134({required String id, required String name}) => object(
    'rename134',
    Thing134.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing135? rename135({required String id, required String name}) => object(
    'rename135',
    Thing135.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing136? rename136({required String id, required String name}) => object(
    'rename136',
    Thing136.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing137? rename137({required String id, required String name}) => object(
    'rename137',
    Thing137.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing138? rename138({required String id, required String name}) => object(
    'rename138',
    Thing138.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing139? rename139({required String id, required String name}) => object(
    'rename139',
    Thing139.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing140? rename140({required String id, required String name}) => object(
    'rename140',
    Thing140.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing141? rename141({required String id, required String name}) => object(
    'rename141',
    Thing141.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing142? rename142({required String id, required String name}) => object(
    'rename142',
    Thing142.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing143? rename143({required String id, required String name}) => object(
    'rename143',
    Thing143.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing144? rename144({required String id, required String name}) => object(
    'rename144',
    Thing144.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing145? rename145({required String id, required String name}) => object(
    'rename145',
    Thing145.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing146? rename146({required String id, required String name}) => object(
    'rename146',
    Thing146.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing147? rename147({required String id, required String name}) => object(
    'rename147',
    Thing147.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing148? rename148({required String id, required String name}) => object(
    'rename148',
    Thing148.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
  Thing149? rename149({required String id, required String name}) => object(
    'rename149',
    Thing149.new,
    args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
    keyed: true,
  );
}

/// Typed mutations for this schema. See `SlingClient.mutateWith`.
extension SlingMutations on SlingClient<Query> {
  Future<T> mutate<T>(
    T Function(Mutation mutation) body, {
    void Function()? optimistic,
    Iterable<String>? refetchQueries,
  }) => mutateWith(
    Mutation.root,
    body,
    optimistic: optimistic,
    refetchQueries: refetchQueries,
  );
}

class Subscription extends Accessor {
  Subscription(super.recorder, super.selection, super.path);
  Subscription.root(Recorder r) : super(r, r.root, const []);

  Node? get nodeChanged => object('nodeChanged', Node.new, keyed: true);
}

/// Typed subscriptions for this schema. See `SlingClient.subscribeWith`.
extension SlingSubscriptions on SlingClient<Query> {
  SlingSubscription<T> subscribe<T>(
    T Function(Subscription subscription) body, {
    Duration? retryAfter,
  }) => subscribeWith(Subscription.root, body, retryAfter: retryAfter);
}

/// Pass to `SlingClient(schema: slingSchema)`: query/mutation/subscription
/// roots, the key field this file was generated with and its hash.
const slingSchema = SlingSchema<Query, Mutation>(
  query: Query.root,
  mutation: Mutation.root,
  subscription: Subscription.root,
  keyField: 'id',
  hash: 's3h3cl1bk1gs8',
);

/// Typed, non-fetching cache access for this schema's keyed types:
/// `client.cacheScope.launch('launch-181')` returns the cached entity or
/// `null`. See `CacheScope`.
extension SlingCacheAccess on CacheScope<Query> {
  Thing000? thing000(String id) => entity('Thing000', id, Thing000.new);
  Thing001? thing001(String id) => entity('Thing001', id, Thing001.new);
  Thing002? thing002(String id) => entity('Thing002', id, Thing002.new);
  Thing003? thing003(String id) => entity('Thing003', id, Thing003.new);
  Thing004? thing004(String id) => entity('Thing004', id, Thing004.new);
  Thing005? thing005(String id) => entity('Thing005', id, Thing005.new);
  Thing006? thing006(String id) => entity('Thing006', id, Thing006.new);
  Thing007? thing007(String id) => entity('Thing007', id, Thing007.new);
  Thing008? thing008(String id) => entity('Thing008', id, Thing008.new);
  Thing009? thing009(String id) => entity('Thing009', id, Thing009.new);
  Thing010? thing010(String id) => entity('Thing010', id, Thing010.new);
  Thing011? thing011(String id) => entity('Thing011', id, Thing011.new);
  Thing012? thing012(String id) => entity('Thing012', id, Thing012.new);
  Thing013? thing013(String id) => entity('Thing013', id, Thing013.new);
  Thing014? thing014(String id) => entity('Thing014', id, Thing014.new);
  Thing015? thing015(String id) => entity('Thing015', id, Thing015.new);
  Thing016? thing016(String id) => entity('Thing016', id, Thing016.new);
  Thing017? thing017(String id) => entity('Thing017', id, Thing017.new);
  Thing018? thing018(String id) => entity('Thing018', id, Thing018.new);
  Thing019? thing019(String id) => entity('Thing019', id, Thing019.new);
  Thing020? thing020(String id) => entity('Thing020', id, Thing020.new);
  Thing021? thing021(String id) => entity('Thing021', id, Thing021.new);
  Thing022? thing022(String id) => entity('Thing022', id, Thing022.new);
  Thing023? thing023(String id) => entity('Thing023', id, Thing023.new);
  Thing024? thing024(String id) => entity('Thing024', id, Thing024.new);
  Thing025? thing025(String id) => entity('Thing025', id, Thing025.new);
  Thing026? thing026(String id) => entity('Thing026', id, Thing026.new);
  Thing027? thing027(String id) => entity('Thing027', id, Thing027.new);
  Thing028? thing028(String id) => entity('Thing028', id, Thing028.new);
  Thing029? thing029(String id) => entity('Thing029', id, Thing029.new);
  Thing030? thing030(String id) => entity('Thing030', id, Thing030.new);
  Thing031? thing031(String id) => entity('Thing031', id, Thing031.new);
  Thing032? thing032(String id) => entity('Thing032', id, Thing032.new);
  Thing033? thing033(String id) => entity('Thing033', id, Thing033.new);
  Thing034? thing034(String id) => entity('Thing034', id, Thing034.new);
  Thing035? thing035(String id) => entity('Thing035', id, Thing035.new);
  Thing036? thing036(String id) => entity('Thing036', id, Thing036.new);
  Thing037? thing037(String id) => entity('Thing037', id, Thing037.new);
  Thing038? thing038(String id) => entity('Thing038', id, Thing038.new);
  Thing039? thing039(String id) => entity('Thing039', id, Thing039.new);
  Thing040? thing040(String id) => entity('Thing040', id, Thing040.new);
  Thing041? thing041(String id) => entity('Thing041', id, Thing041.new);
  Thing042? thing042(String id) => entity('Thing042', id, Thing042.new);
  Thing043? thing043(String id) => entity('Thing043', id, Thing043.new);
  Thing044? thing044(String id) => entity('Thing044', id, Thing044.new);
  Thing045? thing045(String id) => entity('Thing045', id, Thing045.new);
  Thing046? thing046(String id) => entity('Thing046', id, Thing046.new);
  Thing047? thing047(String id) => entity('Thing047', id, Thing047.new);
  Thing048? thing048(String id) => entity('Thing048', id, Thing048.new);
  Thing049? thing049(String id) => entity('Thing049', id, Thing049.new);
  Thing050? thing050(String id) => entity('Thing050', id, Thing050.new);
  Thing051? thing051(String id) => entity('Thing051', id, Thing051.new);
  Thing052? thing052(String id) => entity('Thing052', id, Thing052.new);
  Thing053? thing053(String id) => entity('Thing053', id, Thing053.new);
  Thing054? thing054(String id) => entity('Thing054', id, Thing054.new);
  Thing055? thing055(String id) => entity('Thing055', id, Thing055.new);
  Thing056? thing056(String id) => entity('Thing056', id, Thing056.new);
  Thing057? thing057(String id) => entity('Thing057', id, Thing057.new);
  Thing058? thing058(String id) => entity('Thing058', id, Thing058.new);
  Thing059? thing059(String id) => entity('Thing059', id, Thing059.new);
  Thing060? thing060(String id) => entity('Thing060', id, Thing060.new);
  Thing061? thing061(String id) => entity('Thing061', id, Thing061.new);
  Thing062? thing062(String id) => entity('Thing062', id, Thing062.new);
  Thing063? thing063(String id) => entity('Thing063', id, Thing063.new);
  Thing064? thing064(String id) => entity('Thing064', id, Thing064.new);
  Thing065? thing065(String id) => entity('Thing065', id, Thing065.new);
  Thing066? thing066(String id) => entity('Thing066', id, Thing066.new);
  Thing067? thing067(String id) => entity('Thing067', id, Thing067.new);
  Thing068? thing068(String id) => entity('Thing068', id, Thing068.new);
  Thing069? thing069(String id) => entity('Thing069', id, Thing069.new);
  Thing070? thing070(String id) => entity('Thing070', id, Thing070.new);
  Thing071? thing071(String id) => entity('Thing071', id, Thing071.new);
  Thing072? thing072(String id) => entity('Thing072', id, Thing072.new);
  Thing073? thing073(String id) => entity('Thing073', id, Thing073.new);
  Thing074? thing074(String id) => entity('Thing074', id, Thing074.new);
  Thing075? thing075(String id) => entity('Thing075', id, Thing075.new);
  Thing076? thing076(String id) => entity('Thing076', id, Thing076.new);
  Thing077? thing077(String id) => entity('Thing077', id, Thing077.new);
  Thing078? thing078(String id) => entity('Thing078', id, Thing078.new);
  Thing079? thing079(String id) => entity('Thing079', id, Thing079.new);
  Thing080? thing080(String id) => entity('Thing080', id, Thing080.new);
  Thing081? thing081(String id) => entity('Thing081', id, Thing081.new);
  Thing082? thing082(String id) => entity('Thing082', id, Thing082.new);
  Thing083? thing083(String id) => entity('Thing083', id, Thing083.new);
  Thing084? thing084(String id) => entity('Thing084', id, Thing084.new);
  Thing085? thing085(String id) => entity('Thing085', id, Thing085.new);
  Thing086? thing086(String id) => entity('Thing086', id, Thing086.new);
  Thing087? thing087(String id) => entity('Thing087', id, Thing087.new);
  Thing088? thing088(String id) => entity('Thing088', id, Thing088.new);
  Thing089? thing089(String id) => entity('Thing089', id, Thing089.new);
  Thing090? thing090(String id) => entity('Thing090', id, Thing090.new);
  Thing091? thing091(String id) => entity('Thing091', id, Thing091.new);
  Thing092? thing092(String id) => entity('Thing092', id, Thing092.new);
  Thing093? thing093(String id) => entity('Thing093', id, Thing093.new);
  Thing094? thing094(String id) => entity('Thing094', id, Thing094.new);
  Thing095? thing095(String id) => entity('Thing095', id, Thing095.new);
  Thing096? thing096(String id) => entity('Thing096', id, Thing096.new);
  Thing097? thing097(String id) => entity('Thing097', id, Thing097.new);
  Thing098? thing098(String id) => entity('Thing098', id, Thing098.new);
  Thing099? thing099(String id) => entity('Thing099', id, Thing099.new);
  Thing100? thing100(String id) => entity('Thing100', id, Thing100.new);
  Thing101? thing101(String id) => entity('Thing101', id, Thing101.new);
  Thing102? thing102(String id) => entity('Thing102', id, Thing102.new);
  Thing103? thing103(String id) => entity('Thing103', id, Thing103.new);
  Thing104? thing104(String id) => entity('Thing104', id, Thing104.new);
  Thing105? thing105(String id) => entity('Thing105', id, Thing105.new);
  Thing106? thing106(String id) => entity('Thing106', id, Thing106.new);
  Thing107? thing107(String id) => entity('Thing107', id, Thing107.new);
  Thing108? thing108(String id) => entity('Thing108', id, Thing108.new);
  Thing109? thing109(String id) => entity('Thing109', id, Thing109.new);
  Thing110? thing110(String id) => entity('Thing110', id, Thing110.new);
  Thing111? thing111(String id) => entity('Thing111', id, Thing111.new);
  Thing112? thing112(String id) => entity('Thing112', id, Thing112.new);
  Thing113? thing113(String id) => entity('Thing113', id, Thing113.new);
  Thing114? thing114(String id) => entity('Thing114', id, Thing114.new);
  Thing115? thing115(String id) => entity('Thing115', id, Thing115.new);
  Thing116? thing116(String id) => entity('Thing116', id, Thing116.new);
  Thing117? thing117(String id) => entity('Thing117', id, Thing117.new);
  Thing118? thing118(String id) => entity('Thing118', id, Thing118.new);
  Thing119? thing119(String id) => entity('Thing119', id, Thing119.new);
  Thing120? thing120(String id) => entity('Thing120', id, Thing120.new);
  Thing121? thing121(String id) => entity('Thing121', id, Thing121.new);
  Thing122? thing122(String id) => entity('Thing122', id, Thing122.new);
  Thing123? thing123(String id) => entity('Thing123', id, Thing123.new);
  Thing124? thing124(String id) => entity('Thing124', id, Thing124.new);
  Thing125? thing125(String id) => entity('Thing125', id, Thing125.new);
  Thing126? thing126(String id) => entity('Thing126', id, Thing126.new);
  Thing127? thing127(String id) => entity('Thing127', id, Thing127.new);
  Thing128? thing128(String id) => entity('Thing128', id, Thing128.new);
  Thing129? thing129(String id) => entity('Thing129', id, Thing129.new);
  Thing130? thing130(String id) => entity('Thing130', id, Thing130.new);
  Thing131? thing131(String id) => entity('Thing131', id, Thing131.new);
  Thing132? thing132(String id) => entity('Thing132', id, Thing132.new);
  Thing133? thing133(String id) => entity('Thing133', id, Thing133.new);
  Thing134? thing134(String id) => entity('Thing134', id, Thing134.new);
  Thing135? thing135(String id) => entity('Thing135', id, Thing135.new);
  Thing136? thing136(String id) => entity('Thing136', id, Thing136.new);
  Thing137? thing137(String id) => entity('Thing137', id, Thing137.new);
  Thing138? thing138(String id) => entity('Thing138', id, Thing138.new);
  Thing139? thing139(String id) => entity('Thing139', id, Thing139.new);
  Thing140? thing140(String id) => entity('Thing140', id, Thing140.new);
  Thing141? thing141(String id) => entity('Thing141', id, Thing141.new);
  Thing142? thing142(String id) => entity('Thing142', id, Thing142.new);
  Thing143? thing143(String id) => entity('Thing143', id, Thing143.new);
  Thing144? thing144(String id) => entity('Thing144', id, Thing144.new);
  Thing145? thing145(String id) => entity('Thing145', id, Thing145.new);
  Thing146? thing146(String id) => entity('Thing146', id, Thing146.new);
  Thing147? thing147(String id) => entity('Thing147', id, Thing147.new);
  Thing148? thing148(String id) => entity('Thing148', id, Thing148.new);
  Thing149? thing149(String id) => entity('Thing149', id, Thing149.new);
}

class Thing000 extends Accessor {
  Thing000(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State00? get state => enumValue('state', State00.fromGraphQL);
  set state(State00? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail00? get detail => object('detail', Detail00.new);
  Thing001? get next => object('next', Thing001.new, keyed: true);
  List<Thing007>? related({int? first}) => list(
    'related',
    Thing007.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing001 extends Accessor {
  Thing001(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State01? get state => enumValue('state', State01.fromGraphQL);
  set state(State01? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail01? get detail => object('detail', Detail01.new);
  Thing002? get next => object('next', Thing002.new, keyed: true);
  List<Thing008>? related({int? first}) => list(
    'related',
    Thing008.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing002 extends Accessor {
  Thing002(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State02? get state => enumValue('state', State02.fromGraphQL);
  set state(State02? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail02? get detail => object('detail', Detail02.new);
  Thing003? get next => object('next', Thing003.new, keyed: true);
  List<Thing009>? related({int? first}) => list(
    'related',
    Thing009.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing003 extends Accessor {
  Thing003(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State03? get state => enumValue('state', State03.fromGraphQL);
  set state(State03? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail03? get detail => object('detail', Detail03.new);
  Thing004? get next => object('next', Thing004.new, keyed: true);
  List<Thing010>? related({int? first}) => list(
    'related',
    Thing010.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing004 extends Accessor {
  Thing004(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State04? get state => enumValue('state', State04.fromGraphQL);
  set state(State04? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail04? get detail => object('detail', Detail04.new);
  Thing005? get next => object('next', Thing005.new, keyed: true);
  List<Thing011>? related({int? first}) => list(
    'related',
    Thing011.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing005 extends Accessor {
  Thing005(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State05? get state => enumValue('state', State05.fromGraphQL);
  set state(State05? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail05? get detail => object('detail', Detail05.new);
  Thing006? get next => object('next', Thing006.new, keyed: true);
  List<Thing012>? related({int? first}) => list(
    'related',
    Thing012.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing006 extends Accessor {
  Thing006(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State06? get state => enumValue('state', State06.fromGraphQL);
  set state(State06? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail06? get detail => object('detail', Detail06.new);
  Thing007? get next => object('next', Thing007.new, keyed: true);
  List<Thing013>? related({int? first}) => list(
    'related',
    Thing013.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing007 extends Accessor {
  Thing007(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State07? get state => enumValue('state', State07.fromGraphQL);
  set state(State07? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail07? get detail => object('detail', Detail07.new);
  Thing008? get next => object('next', Thing008.new, keyed: true);
  List<Thing014>? related({int? first}) => list(
    'related',
    Thing014.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing008 extends Accessor {
  Thing008(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State08? get state => enumValue('state', State08.fromGraphQL);
  set state(State08? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail08? get detail => object('detail', Detail08.new);
  Thing009? get next => object('next', Thing009.new, keyed: true);
  List<Thing015>? related({int? first}) => list(
    'related',
    Thing015.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing009 extends Accessor {
  Thing009(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State09? get state => enumValue('state', State09.fromGraphQL);
  set state(State09? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail09? get detail => object('detail', Detail09.new);
  Thing010? get next => object('next', Thing010.new, keyed: true);
  List<Thing016>? related({int? first}) => list(
    'related',
    Thing016.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing010 extends Accessor {
  Thing010(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State10? get state => enumValue('state', State10.fromGraphQL);
  set state(State10? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail10? get detail => object('detail', Detail10.new);
  Thing011? get next => object('next', Thing011.new, keyed: true);
  List<Thing017>? related({int? first}) => list(
    'related',
    Thing017.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing011 extends Accessor {
  Thing011(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State11? get state => enumValue('state', State11.fromGraphQL);
  set state(State11? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail11? get detail => object('detail', Detail11.new);
  Thing012? get next => object('next', Thing012.new, keyed: true);
  List<Thing018>? related({int? first}) => list(
    'related',
    Thing018.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing012 extends Accessor {
  Thing012(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State12? get state => enumValue('state', State12.fromGraphQL);
  set state(State12? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail12? get detail => object('detail', Detail12.new);
  Thing013? get next => object('next', Thing013.new, keyed: true);
  List<Thing019>? related({int? first}) => list(
    'related',
    Thing019.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing013 extends Accessor {
  Thing013(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State13? get state => enumValue('state', State13.fromGraphQL);
  set state(State13? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail13? get detail => object('detail', Detail13.new);
  Thing014? get next => object('next', Thing014.new, keyed: true);
  List<Thing020>? related({int? first}) => list(
    'related',
    Thing020.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing014 extends Accessor {
  Thing014(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State14? get state => enumValue('state', State14.fromGraphQL);
  set state(State14? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail14? get detail => object('detail', Detail14.new);
  Thing015? get next => object('next', Thing015.new, keyed: true);
  List<Thing021>? related({int? first}) => list(
    'related',
    Thing021.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing015 extends Accessor {
  Thing015(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State00? get state => enumValue('state', State00.fromGraphQL);
  set state(State00? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail00? get detail => object('detail', Detail00.new);
  Thing016? get next => object('next', Thing016.new, keyed: true);
  List<Thing022>? related({int? first}) => list(
    'related',
    Thing022.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing016 extends Accessor {
  Thing016(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State01? get state => enumValue('state', State01.fromGraphQL);
  set state(State01? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail01? get detail => object('detail', Detail01.new);
  Thing017? get next => object('next', Thing017.new, keyed: true);
  List<Thing023>? related({int? first}) => list(
    'related',
    Thing023.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing017 extends Accessor {
  Thing017(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State02? get state => enumValue('state', State02.fromGraphQL);
  set state(State02? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail02? get detail => object('detail', Detail02.new);
  Thing018? get next => object('next', Thing018.new, keyed: true);
  List<Thing024>? related({int? first}) => list(
    'related',
    Thing024.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing018 extends Accessor {
  Thing018(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State03? get state => enumValue('state', State03.fromGraphQL);
  set state(State03? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail03? get detail => object('detail', Detail03.new);
  Thing019? get next => object('next', Thing019.new, keyed: true);
  List<Thing025>? related({int? first}) => list(
    'related',
    Thing025.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing019 extends Accessor {
  Thing019(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State04? get state => enumValue('state', State04.fromGraphQL);
  set state(State04? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail04? get detail => object('detail', Detail04.new);
  Thing020? get next => object('next', Thing020.new, keyed: true);
  List<Thing026>? related({int? first}) => list(
    'related',
    Thing026.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing020 extends Accessor {
  Thing020(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State05? get state => enumValue('state', State05.fromGraphQL);
  set state(State05? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail05? get detail => object('detail', Detail05.new);
  Thing021? get next => object('next', Thing021.new, keyed: true);
  List<Thing027>? related({int? first}) => list(
    'related',
    Thing027.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing021 extends Accessor {
  Thing021(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State06? get state => enumValue('state', State06.fromGraphQL);
  set state(State06? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail06? get detail => object('detail', Detail06.new);
  Thing022? get next => object('next', Thing022.new, keyed: true);
  List<Thing028>? related({int? first}) => list(
    'related',
    Thing028.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing022 extends Accessor {
  Thing022(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State07? get state => enumValue('state', State07.fromGraphQL);
  set state(State07? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail07? get detail => object('detail', Detail07.new);
  Thing023? get next => object('next', Thing023.new, keyed: true);
  List<Thing029>? related({int? first}) => list(
    'related',
    Thing029.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing023 extends Accessor {
  Thing023(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State08? get state => enumValue('state', State08.fromGraphQL);
  set state(State08? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail08? get detail => object('detail', Detail08.new);
  Thing024? get next => object('next', Thing024.new, keyed: true);
  List<Thing030>? related({int? first}) => list(
    'related',
    Thing030.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing024 extends Accessor {
  Thing024(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State09? get state => enumValue('state', State09.fromGraphQL);
  set state(State09? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail09? get detail => object('detail', Detail09.new);
  Thing025? get next => object('next', Thing025.new, keyed: true);
  List<Thing031>? related({int? first}) => list(
    'related',
    Thing031.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing025 extends Accessor {
  Thing025(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State10? get state => enumValue('state', State10.fromGraphQL);
  set state(State10? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail10? get detail => object('detail', Detail10.new);
  Thing026? get next => object('next', Thing026.new, keyed: true);
  List<Thing032>? related({int? first}) => list(
    'related',
    Thing032.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing026 extends Accessor {
  Thing026(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State11? get state => enumValue('state', State11.fromGraphQL);
  set state(State11? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail11? get detail => object('detail', Detail11.new);
  Thing027? get next => object('next', Thing027.new, keyed: true);
  List<Thing033>? related({int? first}) => list(
    'related',
    Thing033.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing027 extends Accessor {
  Thing027(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State12? get state => enumValue('state', State12.fromGraphQL);
  set state(State12? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail12? get detail => object('detail', Detail12.new);
  Thing028? get next => object('next', Thing028.new, keyed: true);
  List<Thing034>? related({int? first}) => list(
    'related',
    Thing034.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing028 extends Accessor {
  Thing028(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State13? get state => enumValue('state', State13.fromGraphQL);
  set state(State13? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail13? get detail => object('detail', Detail13.new);
  Thing029? get next => object('next', Thing029.new, keyed: true);
  List<Thing035>? related({int? first}) => list(
    'related',
    Thing035.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing029 extends Accessor {
  Thing029(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State14? get state => enumValue('state', State14.fromGraphQL);
  set state(State14? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail14? get detail => object('detail', Detail14.new);
  Thing030? get next => object('next', Thing030.new, keyed: true);
  List<Thing036>? related({int? first}) => list(
    'related',
    Thing036.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing030 extends Accessor {
  Thing030(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State00? get state => enumValue('state', State00.fromGraphQL);
  set state(State00? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail00? get detail => object('detail', Detail00.new);
  Thing031? get next => object('next', Thing031.new, keyed: true);
  List<Thing037>? related({int? first}) => list(
    'related',
    Thing037.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing031 extends Accessor {
  Thing031(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State01? get state => enumValue('state', State01.fromGraphQL);
  set state(State01? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail01? get detail => object('detail', Detail01.new);
  Thing032? get next => object('next', Thing032.new, keyed: true);
  List<Thing038>? related({int? first}) => list(
    'related',
    Thing038.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing032 extends Accessor {
  Thing032(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State02? get state => enumValue('state', State02.fromGraphQL);
  set state(State02? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail02? get detail => object('detail', Detail02.new);
  Thing033? get next => object('next', Thing033.new, keyed: true);
  List<Thing039>? related({int? first}) => list(
    'related',
    Thing039.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing033 extends Accessor {
  Thing033(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State03? get state => enumValue('state', State03.fromGraphQL);
  set state(State03? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail03? get detail => object('detail', Detail03.new);
  Thing034? get next => object('next', Thing034.new, keyed: true);
  List<Thing040>? related({int? first}) => list(
    'related',
    Thing040.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing034 extends Accessor {
  Thing034(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State04? get state => enumValue('state', State04.fromGraphQL);
  set state(State04? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail04? get detail => object('detail', Detail04.new);
  Thing035? get next => object('next', Thing035.new, keyed: true);
  List<Thing041>? related({int? first}) => list(
    'related',
    Thing041.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing035 extends Accessor {
  Thing035(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State05? get state => enumValue('state', State05.fromGraphQL);
  set state(State05? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail05? get detail => object('detail', Detail05.new);
  Thing036? get next => object('next', Thing036.new, keyed: true);
  List<Thing042>? related({int? first}) => list(
    'related',
    Thing042.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing036 extends Accessor {
  Thing036(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State06? get state => enumValue('state', State06.fromGraphQL);
  set state(State06? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail06? get detail => object('detail', Detail06.new);
  Thing037? get next => object('next', Thing037.new, keyed: true);
  List<Thing043>? related({int? first}) => list(
    'related',
    Thing043.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing037 extends Accessor {
  Thing037(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State07? get state => enumValue('state', State07.fromGraphQL);
  set state(State07? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail07? get detail => object('detail', Detail07.new);
  Thing038? get next => object('next', Thing038.new, keyed: true);
  List<Thing044>? related({int? first}) => list(
    'related',
    Thing044.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing038 extends Accessor {
  Thing038(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State08? get state => enumValue('state', State08.fromGraphQL);
  set state(State08? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail08? get detail => object('detail', Detail08.new);
  Thing039? get next => object('next', Thing039.new, keyed: true);
  List<Thing045>? related({int? first}) => list(
    'related',
    Thing045.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing039 extends Accessor {
  Thing039(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State09? get state => enumValue('state', State09.fromGraphQL);
  set state(State09? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail09? get detail => object('detail', Detail09.new);
  Thing040? get next => object('next', Thing040.new, keyed: true);
  List<Thing046>? related({int? first}) => list(
    'related',
    Thing046.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing040 extends Accessor {
  Thing040(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State10? get state => enumValue('state', State10.fromGraphQL);
  set state(State10? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail10? get detail => object('detail', Detail10.new);
  Thing041? get next => object('next', Thing041.new, keyed: true);
  List<Thing047>? related({int? first}) => list(
    'related',
    Thing047.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing041 extends Accessor {
  Thing041(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State11? get state => enumValue('state', State11.fromGraphQL);
  set state(State11? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail11? get detail => object('detail', Detail11.new);
  Thing042? get next => object('next', Thing042.new, keyed: true);
  List<Thing048>? related({int? first}) => list(
    'related',
    Thing048.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing042 extends Accessor {
  Thing042(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State12? get state => enumValue('state', State12.fromGraphQL);
  set state(State12? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail12? get detail => object('detail', Detail12.new);
  Thing043? get next => object('next', Thing043.new, keyed: true);
  List<Thing049>? related({int? first}) => list(
    'related',
    Thing049.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing043 extends Accessor {
  Thing043(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State13? get state => enumValue('state', State13.fromGraphQL);
  set state(State13? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail13? get detail => object('detail', Detail13.new);
  Thing044? get next => object('next', Thing044.new, keyed: true);
  List<Thing050>? related({int? first}) => list(
    'related',
    Thing050.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing044 extends Accessor {
  Thing044(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State14? get state => enumValue('state', State14.fromGraphQL);
  set state(State14? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail14? get detail => object('detail', Detail14.new);
  Thing045? get next => object('next', Thing045.new, keyed: true);
  List<Thing051>? related({int? first}) => list(
    'related',
    Thing051.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing045 extends Accessor {
  Thing045(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State00? get state => enumValue('state', State00.fromGraphQL);
  set state(State00? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail00? get detail => object('detail', Detail00.new);
  Thing046? get next => object('next', Thing046.new, keyed: true);
  List<Thing052>? related({int? first}) => list(
    'related',
    Thing052.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing046 extends Accessor {
  Thing046(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State01? get state => enumValue('state', State01.fromGraphQL);
  set state(State01? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail01? get detail => object('detail', Detail01.new);
  Thing047? get next => object('next', Thing047.new, keyed: true);
  List<Thing053>? related({int? first}) => list(
    'related',
    Thing053.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing047 extends Accessor {
  Thing047(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State02? get state => enumValue('state', State02.fromGraphQL);
  set state(State02? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail02? get detail => object('detail', Detail02.new);
  Thing048? get next => object('next', Thing048.new, keyed: true);
  List<Thing054>? related({int? first}) => list(
    'related',
    Thing054.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing048 extends Accessor {
  Thing048(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State03? get state => enumValue('state', State03.fromGraphQL);
  set state(State03? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail03? get detail => object('detail', Detail03.new);
  Thing049? get next => object('next', Thing049.new, keyed: true);
  List<Thing055>? related({int? first}) => list(
    'related',
    Thing055.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing049 extends Accessor {
  Thing049(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State04? get state => enumValue('state', State04.fromGraphQL);
  set state(State04? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail04? get detail => object('detail', Detail04.new);
  Thing050? get next => object('next', Thing050.new, keyed: true);
  List<Thing056>? related({int? first}) => list(
    'related',
    Thing056.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing050 extends Accessor {
  Thing050(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State05? get state => enumValue('state', State05.fromGraphQL);
  set state(State05? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail05? get detail => object('detail', Detail05.new);
  Thing051? get next => object('next', Thing051.new, keyed: true);
  List<Thing057>? related({int? first}) => list(
    'related',
    Thing057.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing051 extends Accessor {
  Thing051(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State06? get state => enumValue('state', State06.fromGraphQL);
  set state(State06? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail06? get detail => object('detail', Detail06.new);
  Thing052? get next => object('next', Thing052.new, keyed: true);
  List<Thing058>? related({int? first}) => list(
    'related',
    Thing058.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing052 extends Accessor {
  Thing052(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State07? get state => enumValue('state', State07.fromGraphQL);
  set state(State07? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail07? get detail => object('detail', Detail07.new);
  Thing053? get next => object('next', Thing053.new, keyed: true);
  List<Thing059>? related({int? first}) => list(
    'related',
    Thing059.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing053 extends Accessor {
  Thing053(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State08? get state => enumValue('state', State08.fromGraphQL);
  set state(State08? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail08? get detail => object('detail', Detail08.new);
  Thing054? get next => object('next', Thing054.new, keyed: true);
  List<Thing060>? related({int? first}) => list(
    'related',
    Thing060.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing054 extends Accessor {
  Thing054(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State09? get state => enumValue('state', State09.fromGraphQL);
  set state(State09? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail09? get detail => object('detail', Detail09.new);
  Thing055? get next => object('next', Thing055.new, keyed: true);
  List<Thing061>? related({int? first}) => list(
    'related',
    Thing061.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing055 extends Accessor {
  Thing055(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State10? get state => enumValue('state', State10.fromGraphQL);
  set state(State10? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail10? get detail => object('detail', Detail10.new);
  Thing056? get next => object('next', Thing056.new, keyed: true);
  List<Thing062>? related({int? first}) => list(
    'related',
    Thing062.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing056 extends Accessor {
  Thing056(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State11? get state => enumValue('state', State11.fromGraphQL);
  set state(State11? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail11? get detail => object('detail', Detail11.new);
  Thing057? get next => object('next', Thing057.new, keyed: true);
  List<Thing063>? related({int? first}) => list(
    'related',
    Thing063.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing057 extends Accessor {
  Thing057(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State12? get state => enumValue('state', State12.fromGraphQL);
  set state(State12? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail12? get detail => object('detail', Detail12.new);
  Thing058? get next => object('next', Thing058.new, keyed: true);
  List<Thing064>? related({int? first}) => list(
    'related',
    Thing064.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing058 extends Accessor {
  Thing058(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State13? get state => enumValue('state', State13.fromGraphQL);
  set state(State13? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail13? get detail => object('detail', Detail13.new);
  Thing059? get next => object('next', Thing059.new, keyed: true);
  List<Thing065>? related({int? first}) => list(
    'related',
    Thing065.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing059 extends Accessor {
  Thing059(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State14? get state => enumValue('state', State14.fromGraphQL);
  set state(State14? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail14? get detail => object('detail', Detail14.new);
  Thing060? get next => object('next', Thing060.new, keyed: true);
  List<Thing066>? related({int? first}) => list(
    'related',
    Thing066.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing060 extends Accessor {
  Thing060(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State00? get state => enumValue('state', State00.fromGraphQL);
  set state(State00? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail00? get detail => object('detail', Detail00.new);
  Thing061? get next => object('next', Thing061.new, keyed: true);
  List<Thing067>? related({int? first}) => list(
    'related',
    Thing067.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing061 extends Accessor {
  Thing061(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State01? get state => enumValue('state', State01.fromGraphQL);
  set state(State01? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail01? get detail => object('detail', Detail01.new);
  Thing062? get next => object('next', Thing062.new, keyed: true);
  List<Thing068>? related({int? first}) => list(
    'related',
    Thing068.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing062 extends Accessor {
  Thing062(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State02? get state => enumValue('state', State02.fromGraphQL);
  set state(State02? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail02? get detail => object('detail', Detail02.new);
  Thing063? get next => object('next', Thing063.new, keyed: true);
  List<Thing069>? related({int? first}) => list(
    'related',
    Thing069.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing063 extends Accessor {
  Thing063(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State03? get state => enumValue('state', State03.fromGraphQL);
  set state(State03? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail03? get detail => object('detail', Detail03.new);
  Thing064? get next => object('next', Thing064.new, keyed: true);
  List<Thing070>? related({int? first}) => list(
    'related',
    Thing070.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing064 extends Accessor {
  Thing064(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State04? get state => enumValue('state', State04.fromGraphQL);
  set state(State04? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail04? get detail => object('detail', Detail04.new);
  Thing065? get next => object('next', Thing065.new, keyed: true);
  List<Thing071>? related({int? first}) => list(
    'related',
    Thing071.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing065 extends Accessor {
  Thing065(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State05? get state => enumValue('state', State05.fromGraphQL);
  set state(State05? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail05? get detail => object('detail', Detail05.new);
  Thing066? get next => object('next', Thing066.new, keyed: true);
  List<Thing072>? related({int? first}) => list(
    'related',
    Thing072.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing066 extends Accessor {
  Thing066(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State06? get state => enumValue('state', State06.fromGraphQL);
  set state(State06? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail06? get detail => object('detail', Detail06.new);
  Thing067? get next => object('next', Thing067.new, keyed: true);
  List<Thing073>? related({int? first}) => list(
    'related',
    Thing073.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing067 extends Accessor {
  Thing067(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State07? get state => enumValue('state', State07.fromGraphQL);
  set state(State07? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail07? get detail => object('detail', Detail07.new);
  Thing068? get next => object('next', Thing068.new, keyed: true);
  List<Thing074>? related({int? first}) => list(
    'related',
    Thing074.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing068 extends Accessor {
  Thing068(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State08? get state => enumValue('state', State08.fromGraphQL);
  set state(State08? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail08? get detail => object('detail', Detail08.new);
  Thing069? get next => object('next', Thing069.new, keyed: true);
  List<Thing075>? related({int? first}) => list(
    'related',
    Thing075.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing069 extends Accessor {
  Thing069(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State09? get state => enumValue('state', State09.fromGraphQL);
  set state(State09? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail09? get detail => object('detail', Detail09.new);
  Thing070? get next => object('next', Thing070.new, keyed: true);
  List<Thing076>? related({int? first}) => list(
    'related',
    Thing076.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing070 extends Accessor {
  Thing070(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State10? get state => enumValue('state', State10.fromGraphQL);
  set state(State10? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail10? get detail => object('detail', Detail10.new);
  Thing071? get next => object('next', Thing071.new, keyed: true);
  List<Thing077>? related({int? first}) => list(
    'related',
    Thing077.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing071 extends Accessor {
  Thing071(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State11? get state => enumValue('state', State11.fromGraphQL);
  set state(State11? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail11? get detail => object('detail', Detail11.new);
  Thing072? get next => object('next', Thing072.new, keyed: true);
  List<Thing078>? related({int? first}) => list(
    'related',
    Thing078.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing072 extends Accessor {
  Thing072(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State12? get state => enumValue('state', State12.fromGraphQL);
  set state(State12? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail12? get detail => object('detail', Detail12.new);
  Thing073? get next => object('next', Thing073.new, keyed: true);
  List<Thing079>? related({int? first}) => list(
    'related',
    Thing079.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing073 extends Accessor {
  Thing073(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State13? get state => enumValue('state', State13.fromGraphQL);
  set state(State13? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail13? get detail => object('detail', Detail13.new);
  Thing074? get next => object('next', Thing074.new, keyed: true);
  List<Thing080>? related({int? first}) => list(
    'related',
    Thing080.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing074 extends Accessor {
  Thing074(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State14? get state => enumValue('state', State14.fromGraphQL);
  set state(State14? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail14? get detail => object('detail', Detail14.new);
  Thing075? get next => object('next', Thing075.new, keyed: true);
  List<Thing081>? related({int? first}) => list(
    'related',
    Thing081.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing075 extends Accessor {
  Thing075(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State00? get state => enumValue('state', State00.fromGraphQL);
  set state(State00? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail00? get detail => object('detail', Detail00.new);
  Thing076? get next => object('next', Thing076.new, keyed: true);
  List<Thing082>? related({int? first}) => list(
    'related',
    Thing082.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing076 extends Accessor {
  Thing076(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State01? get state => enumValue('state', State01.fromGraphQL);
  set state(State01? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail01? get detail => object('detail', Detail01.new);
  Thing077? get next => object('next', Thing077.new, keyed: true);
  List<Thing083>? related({int? first}) => list(
    'related',
    Thing083.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing077 extends Accessor {
  Thing077(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State02? get state => enumValue('state', State02.fromGraphQL);
  set state(State02? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail02? get detail => object('detail', Detail02.new);
  Thing078? get next => object('next', Thing078.new, keyed: true);
  List<Thing084>? related({int? first}) => list(
    'related',
    Thing084.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing078 extends Accessor {
  Thing078(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State03? get state => enumValue('state', State03.fromGraphQL);
  set state(State03? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail03? get detail => object('detail', Detail03.new);
  Thing079? get next => object('next', Thing079.new, keyed: true);
  List<Thing085>? related({int? first}) => list(
    'related',
    Thing085.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing079 extends Accessor {
  Thing079(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State04? get state => enumValue('state', State04.fromGraphQL);
  set state(State04? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail04? get detail => object('detail', Detail04.new);
  Thing080? get next => object('next', Thing080.new, keyed: true);
  List<Thing086>? related({int? first}) => list(
    'related',
    Thing086.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing080 extends Accessor {
  Thing080(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State05? get state => enumValue('state', State05.fromGraphQL);
  set state(State05? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail05? get detail => object('detail', Detail05.new);
  Thing081? get next => object('next', Thing081.new, keyed: true);
  List<Thing087>? related({int? first}) => list(
    'related',
    Thing087.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing081 extends Accessor {
  Thing081(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State06? get state => enumValue('state', State06.fromGraphQL);
  set state(State06? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail06? get detail => object('detail', Detail06.new);
  Thing082? get next => object('next', Thing082.new, keyed: true);
  List<Thing088>? related({int? first}) => list(
    'related',
    Thing088.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing082 extends Accessor {
  Thing082(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State07? get state => enumValue('state', State07.fromGraphQL);
  set state(State07? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail07? get detail => object('detail', Detail07.new);
  Thing083? get next => object('next', Thing083.new, keyed: true);
  List<Thing089>? related({int? first}) => list(
    'related',
    Thing089.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing083 extends Accessor {
  Thing083(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State08? get state => enumValue('state', State08.fromGraphQL);
  set state(State08? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail08? get detail => object('detail', Detail08.new);
  Thing084? get next => object('next', Thing084.new, keyed: true);
  List<Thing090>? related({int? first}) => list(
    'related',
    Thing090.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing084 extends Accessor {
  Thing084(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State09? get state => enumValue('state', State09.fromGraphQL);
  set state(State09? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail09? get detail => object('detail', Detail09.new);
  Thing085? get next => object('next', Thing085.new, keyed: true);
  List<Thing091>? related({int? first}) => list(
    'related',
    Thing091.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing085 extends Accessor {
  Thing085(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State10? get state => enumValue('state', State10.fromGraphQL);
  set state(State10? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail10? get detail => object('detail', Detail10.new);
  Thing086? get next => object('next', Thing086.new, keyed: true);
  List<Thing092>? related({int? first}) => list(
    'related',
    Thing092.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing086 extends Accessor {
  Thing086(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State11? get state => enumValue('state', State11.fromGraphQL);
  set state(State11? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail11? get detail => object('detail', Detail11.new);
  Thing087? get next => object('next', Thing087.new, keyed: true);
  List<Thing093>? related({int? first}) => list(
    'related',
    Thing093.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing087 extends Accessor {
  Thing087(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State12? get state => enumValue('state', State12.fromGraphQL);
  set state(State12? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail12? get detail => object('detail', Detail12.new);
  Thing088? get next => object('next', Thing088.new, keyed: true);
  List<Thing094>? related({int? first}) => list(
    'related',
    Thing094.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing088 extends Accessor {
  Thing088(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State13? get state => enumValue('state', State13.fromGraphQL);
  set state(State13? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail13? get detail => object('detail', Detail13.new);
  Thing089? get next => object('next', Thing089.new, keyed: true);
  List<Thing095>? related({int? first}) => list(
    'related',
    Thing095.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing089 extends Accessor {
  Thing089(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State14? get state => enumValue('state', State14.fromGraphQL);
  set state(State14? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail14? get detail => object('detail', Detail14.new);
  Thing090? get next => object('next', Thing090.new, keyed: true);
  List<Thing096>? related({int? first}) => list(
    'related',
    Thing096.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing090 extends Accessor {
  Thing090(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State00? get state => enumValue('state', State00.fromGraphQL);
  set state(State00? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail00? get detail => object('detail', Detail00.new);
  Thing091? get next => object('next', Thing091.new, keyed: true);
  List<Thing097>? related({int? first}) => list(
    'related',
    Thing097.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing091 extends Accessor {
  Thing091(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State01? get state => enumValue('state', State01.fromGraphQL);
  set state(State01? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail01? get detail => object('detail', Detail01.new);
  Thing092? get next => object('next', Thing092.new, keyed: true);
  List<Thing098>? related({int? first}) => list(
    'related',
    Thing098.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing092 extends Accessor {
  Thing092(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State02? get state => enumValue('state', State02.fromGraphQL);
  set state(State02? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail02? get detail => object('detail', Detail02.new);
  Thing093? get next => object('next', Thing093.new, keyed: true);
  List<Thing099>? related({int? first}) => list(
    'related',
    Thing099.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing093 extends Accessor {
  Thing093(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State03? get state => enumValue('state', State03.fromGraphQL);
  set state(State03? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail03? get detail => object('detail', Detail03.new);
  Thing094? get next => object('next', Thing094.new, keyed: true);
  List<Thing100>? related({int? first}) => list(
    'related',
    Thing100.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing094 extends Accessor {
  Thing094(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State04? get state => enumValue('state', State04.fromGraphQL);
  set state(State04? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail04? get detail => object('detail', Detail04.new);
  Thing095? get next => object('next', Thing095.new, keyed: true);
  List<Thing101>? related({int? first}) => list(
    'related',
    Thing101.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing095 extends Accessor {
  Thing095(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State05? get state => enumValue('state', State05.fromGraphQL);
  set state(State05? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail05? get detail => object('detail', Detail05.new);
  Thing096? get next => object('next', Thing096.new, keyed: true);
  List<Thing102>? related({int? first}) => list(
    'related',
    Thing102.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing096 extends Accessor {
  Thing096(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State06? get state => enumValue('state', State06.fromGraphQL);
  set state(State06? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail06? get detail => object('detail', Detail06.new);
  Thing097? get next => object('next', Thing097.new, keyed: true);
  List<Thing103>? related({int? first}) => list(
    'related',
    Thing103.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing097 extends Accessor {
  Thing097(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State07? get state => enumValue('state', State07.fromGraphQL);
  set state(State07? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail07? get detail => object('detail', Detail07.new);
  Thing098? get next => object('next', Thing098.new, keyed: true);
  List<Thing104>? related({int? first}) => list(
    'related',
    Thing104.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing098 extends Accessor {
  Thing098(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State08? get state => enumValue('state', State08.fromGraphQL);
  set state(State08? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail08? get detail => object('detail', Detail08.new);
  Thing099? get next => object('next', Thing099.new, keyed: true);
  List<Thing105>? related({int? first}) => list(
    'related',
    Thing105.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing099 extends Accessor {
  Thing099(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State09? get state => enumValue('state', State09.fromGraphQL);
  set state(State09? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail09? get detail => object('detail', Detail09.new);
  Thing100? get next => object('next', Thing100.new, keyed: true);
  List<Thing106>? related({int? first}) => list(
    'related',
    Thing106.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing100 extends Accessor {
  Thing100(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State10? get state => enumValue('state', State10.fromGraphQL);
  set state(State10? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail10? get detail => object('detail', Detail10.new);
  Thing101? get next => object('next', Thing101.new, keyed: true);
  List<Thing107>? related({int? first}) => list(
    'related',
    Thing107.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing101 extends Accessor {
  Thing101(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State11? get state => enumValue('state', State11.fromGraphQL);
  set state(State11? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail11? get detail => object('detail', Detail11.new);
  Thing102? get next => object('next', Thing102.new, keyed: true);
  List<Thing108>? related({int? first}) => list(
    'related',
    Thing108.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing102 extends Accessor {
  Thing102(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State12? get state => enumValue('state', State12.fromGraphQL);
  set state(State12? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail12? get detail => object('detail', Detail12.new);
  Thing103? get next => object('next', Thing103.new, keyed: true);
  List<Thing109>? related({int? first}) => list(
    'related',
    Thing109.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing103 extends Accessor {
  Thing103(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State13? get state => enumValue('state', State13.fromGraphQL);
  set state(State13? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail13? get detail => object('detail', Detail13.new);
  Thing104? get next => object('next', Thing104.new, keyed: true);
  List<Thing110>? related({int? first}) => list(
    'related',
    Thing110.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing104 extends Accessor {
  Thing104(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State14? get state => enumValue('state', State14.fromGraphQL);
  set state(State14? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail14? get detail => object('detail', Detail14.new);
  Thing105? get next => object('next', Thing105.new, keyed: true);
  List<Thing111>? related({int? first}) => list(
    'related',
    Thing111.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing105 extends Accessor {
  Thing105(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State00? get state => enumValue('state', State00.fromGraphQL);
  set state(State00? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail00? get detail => object('detail', Detail00.new);
  Thing106? get next => object('next', Thing106.new, keyed: true);
  List<Thing112>? related({int? first}) => list(
    'related',
    Thing112.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing106 extends Accessor {
  Thing106(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State01? get state => enumValue('state', State01.fromGraphQL);
  set state(State01? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail01? get detail => object('detail', Detail01.new);
  Thing107? get next => object('next', Thing107.new, keyed: true);
  List<Thing113>? related({int? first}) => list(
    'related',
    Thing113.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing107 extends Accessor {
  Thing107(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State02? get state => enumValue('state', State02.fromGraphQL);
  set state(State02? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail02? get detail => object('detail', Detail02.new);
  Thing108? get next => object('next', Thing108.new, keyed: true);
  List<Thing114>? related({int? first}) => list(
    'related',
    Thing114.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing108 extends Accessor {
  Thing108(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State03? get state => enumValue('state', State03.fromGraphQL);
  set state(State03? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail03? get detail => object('detail', Detail03.new);
  Thing109? get next => object('next', Thing109.new, keyed: true);
  List<Thing115>? related({int? first}) => list(
    'related',
    Thing115.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing109 extends Accessor {
  Thing109(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State04? get state => enumValue('state', State04.fromGraphQL);
  set state(State04? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail04? get detail => object('detail', Detail04.new);
  Thing110? get next => object('next', Thing110.new, keyed: true);
  List<Thing116>? related({int? first}) => list(
    'related',
    Thing116.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing110 extends Accessor {
  Thing110(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State05? get state => enumValue('state', State05.fromGraphQL);
  set state(State05? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail05? get detail => object('detail', Detail05.new);
  Thing111? get next => object('next', Thing111.new, keyed: true);
  List<Thing117>? related({int? first}) => list(
    'related',
    Thing117.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing111 extends Accessor {
  Thing111(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State06? get state => enumValue('state', State06.fromGraphQL);
  set state(State06? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail06? get detail => object('detail', Detail06.new);
  Thing112? get next => object('next', Thing112.new, keyed: true);
  List<Thing118>? related({int? first}) => list(
    'related',
    Thing118.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing112 extends Accessor {
  Thing112(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State07? get state => enumValue('state', State07.fromGraphQL);
  set state(State07? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail07? get detail => object('detail', Detail07.new);
  Thing113? get next => object('next', Thing113.new, keyed: true);
  List<Thing119>? related({int? first}) => list(
    'related',
    Thing119.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing113 extends Accessor {
  Thing113(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State08? get state => enumValue('state', State08.fromGraphQL);
  set state(State08? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail08? get detail => object('detail', Detail08.new);
  Thing114? get next => object('next', Thing114.new, keyed: true);
  List<Thing120>? related({int? first}) => list(
    'related',
    Thing120.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing114 extends Accessor {
  Thing114(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State09? get state => enumValue('state', State09.fromGraphQL);
  set state(State09? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail09? get detail => object('detail', Detail09.new);
  Thing115? get next => object('next', Thing115.new, keyed: true);
  List<Thing121>? related({int? first}) => list(
    'related',
    Thing121.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing115 extends Accessor {
  Thing115(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State10? get state => enumValue('state', State10.fromGraphQL);
  set state(State10? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail10? get detail => object('detail', Detail10.new);
  Thing116? get next => object('next', Thing116.new, keyed: true);
  List<Thing122>? related({int? first}) => list(
    'related',
    Thing122.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing116 extends Accessor {
  Thing116(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State11? get state => enumValue('state', State11.fromGraphQL);
  set state(State11? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail11? get detail => object('detail', Detail11.new);
  Thing117? get next => object('next', Thing117.new, keyed: true);
  List<Thing123>? related({int? first}) => list(
    'related',
    Thing123.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing117 extends Accessor {
  Thing117(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State12? get state => enumValue('state', State12.fromGraphQL);
  set state(State12? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail12? get detail => object('detail', Detail12.new);
  Thing118? get next => object('next', Thing118.new, keyed: true);
  List<Thing124>? related({int? first}) => list(
    'related',
    Thing124.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing118 extends Accessor {
  Thing118(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State13? get state => enumValue('state', State13.fromGraphQL);
  set state(State13? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail13? get detail => object('detail', Detail13.new);
  Thing119? get next => object('next', Thing119.new, keyed: true);
  List<Thing125>? related({int? first}) => list(
    'related',
    Thing125.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing119 extends Accessor {
  Thing119(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State14? get state => enumValue('state', State14.fromGraphQL);
  set state(State14? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail14? get detail => object('detail', Detail14.new);
  Thing120? get next => object('next', Thing120.new, keyed: true);
  List<Thing126>? related({int? first}) => list(
    'related',
    Thing126.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing120 extends Accessor {
  Thing120(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State00? get state => enumValue('state', State00.fromGraphQL);
  set state(State00? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail00? get detail => object('detail', Detail00.new);
  Thing121? get next => object('next', Thing121.new, keyed: true);
  List<Thing127>? related({int? first}) => list(
    'related',
    Thing127.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing121 extends Accessor {
  Thing121(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State01? get state => enumValue('state', State01.fromGraphQL);
  set state(State01? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail01? get detail => object('detail', Detail01.new);
  Thing122? get next => object('next', Thing122.new, keyed: true);
  List<Thing128>? related({int? first}) => list(
    'related',
    Thing128.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing122 extends Accessor {
  Thing122(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State02? get state => enumValue('state', State02.fromGraphQL);
  set state(State02? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail02? get detail => object('detail', Detail02.new);
  Thing123? get next => object('next', Thing123.new, keyed: true);
  List<Thing129>? related({int? first}) => list(
    'related',
    Thing129.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing123 extends Accessor {
  Thing123(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State03? get state => enumValue('state', State03.fromGraphQL);
  set state(State03? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail03? get detail => object('detail', Detail03.new);
  Thing124? get next => object('next', Thing124.new, keyed: true);
  List<Thing130>? related({int? first}) => list(
    'related',
    Thing130.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing124 extends Accessor {
  Thing124(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State04? get state => enumValue('state', State04.fromGraphQL);
  set state(State04? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail04? get detail => object('detail', Detail04.new);
  Thing125? get next => object('next', Thing125.new, keyed: true);
  List<Thing131>? related({int? first}) => list(
    'related',
    Thing131.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing125 extends Accessor {
  Thing125(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State05? get state => enumValue('state', State05.fromGraphQL);
  set state(State05? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail05? get detail => object('detail', Detail05.new);
  Thing126? get next => object('next', Thing126.new, keyed: true);
  List<Thing132>? related({int? first}) => list(
    'related',
    Thing132.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing126 extends Accessor {
  Thing126(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State06? get state => enumValue('state', State06.fromGraphQL);
  set state(State06? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail06? get detail => object('detail', Detail06.new);
  Thing127? get next => object('next', Thing127.new, keyed: true);
  List<Thing133>? related({int? first}) => list(
    'related',
    Thing133.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing127 extends Accessor {
  Thing127(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State07? get state => enumValue('state', State07.fromGraphQL);
  set state(State07? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail07? get detail => object('detail', Detail07.new);
  Thing128? get next => object('next', Thing128.new, keyed: true);
  List<Thing134>? related({int? first}) => list(
    'related',
    Thing134.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing128 extends Accessor {
  Thing128(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State08? get state => enumValue('state', State08.fromGraphQL);
  set state(State08? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail08? get detail => object('detail', Detail08.new);
  Thing129? get next => object('next', Thing129.new, keyed: true);
  List<Thing135>? related({int? first}) => list(
    'related',
    Thing135.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing129 extends Accessor {
  Thing129(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State09? get state => enumValue('state', State09.fromGraphQL);
  set state(State09? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail09? get detail => object('detail', Detail09.new);
  Thing130? get next => object('next', Thing130.new, keyed: true);
  List<Thing136>? related({int? first}) => list(
    'related',
    Thing136.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing130 extends Accessor {
  Thing130(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State10? get state => enumValue('state', State10.fromGraphQL);
  set state(State10? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail10? get detail => object('detail', Detail10.new);
  Thing131? get next => object('next', Thing131.new, keyed: true);
  List<Thing137>? related({int? first}) => list(
    'related',
    Thing137.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing131 extends Accessor {
  Thing131(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State11? get state => enumValue('state', State11.fromGraphQL);
  set state(State11? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail11? get detail => object('detail', Detail11.new);
  Thing132? get next => object('next', Thing132.new, keyed: true);
  List<Thing138>? related({int? first}) => list(
    'related',
    Thing138.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing132 extends Accessor {
  Thing132(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State12? get state => enumValue('state', State12.fromGraphQL);
  set state(State12? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail12? get detail => object('detail', Detail12.new);
  Thing133? get next => object('next', Thing133.new, keyed: true);
  List<Thing139>? related({int? first}) => list(
    'related',
    Thing139.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing133 extends Accessor {
  Thing133(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State13? get state => enumValue('state', State13.fromGraphQL);
  set state(State13? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail13? get detail => object('detail', Detail13.new);
  Thing134? get next => object('next', Thing134.new, keyed: true);
  List<Thing140>? related({int? first}) => list(
    'related',
    Thing140.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing134 extends Accessor {
  Thing134(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State14? get state => enumValue('state', State14.fromGraphQL);
  set state(State14? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail14? get detail => object('detail', Detail14.new);
  Thing135? get next => object('next', Thing135.new, keyed: true);
  List<Thing141>? related({int? first}) => list(
    'related',
    Thing141.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing135 extends Accessor {
  Thing135(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State00? get state => enumValue('state', State00.fromGraphQL);
  set state(State00? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail00? get detail => object('detail', Detail00.new);
  Thing136? get next => object('next', Thing136.new, keyed: true);
  List<Thing142>? related({int? first}) => list(
    'related',
    Thing142.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing136 extends Accessor {
  Thing136(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State01? get state => enumValue('state', State01.fromGraphQL);
  set state(State01? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail01? get detail => object('detail', Detail01.new);
  Thing137? get next => object('next', Thing137.new, keyed: true);
  List<Thing143>? related({int? first}) => list(
    'related',
    Thing143.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing137 extends Accessor {
  Thing137(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State02? get state => enumValue('state', State02.fromGraphQL);
  set state(State02? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail02? get detail => object('detail', Detail02.new);
  Thing138? get next => object('next', Thing138.new, keyed: true);
  List<Thing144>? related({int? first}) => list(
    'related',
    Thing144.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing138 extends Accessor {
  Thing138(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State03? get state => enumValue('state', State03.fromGraphQL);
  set state(State03? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail03? get detail => object('detail', Detail03.new);
  Thing139? get next => object('next', Thing139.new, keyed: true);
  List<Thing145>? related({int? first}) => list(
    'related',
    Thing145.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing139 extends Accessor {
  Thing139(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State04? get state => enumValue('state', State04.fromGraphQL);
  set state(State04? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail04? get detail => object('detail', Detail04.new);
  Thing140? get next => object('next', Thing140.new, keyed: true);
  List<Thing146>? related({int? first}) => list(
    'related',
    Thing146.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing140 extends Accessor {
  Thing140(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State05? get state => enumValue('state', State05.fromGraphQL);
  set state(State05? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail05? get detail => object('detail', Detail05.new);
  Thing141? get next => object('next', Thing141.new, keyed: true);
  List<Thing147>? related({int? first}) => list(
    'related',
    Thing147.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing141 extends Accessor {
  Thing141(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State06? get state => enumValue('state', State06.fromGraphQL);
  set state(State06? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail06? get detail => object('detail', Detail06.new);
  Thing142? get next => object('next', Thing142.new, keyed: true);
  List<Thing148>? related({int? first}) => list(
    'related',
    Thing148.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing142 extends Accessor {
  Thing142(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State07? get state => enumValue('state', State07.fromGraphQL);
  set state(State07? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail07? get detail => object('detail', Detail07.new);
  Thing143? get next => object('next', Thing143.new, keyed: true);
  List<Thing149>? related({int? first}) => list(
    'related',
    Thing149.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing143 extends Accessor {
  Thing143(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State08? get state => enumValue('state', State08.fromGraphQL);
  set state(State08? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail08? get detail => object('detail', Detail08.new);
  Thing144? get next => object('next', Thing144.new, keyed: true);
  List<Thing000>? related({int? first}) => list(
    'related',
    Thing000.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing144 extends Accessor {
  Thing144(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State09? get state => enumValue('state', State09.fromGraphQL);
  set state(State09? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail09? get detail => object('detail', Detail09.new);
  Thing145? get next => object('next', Thing145.new, keyed: true);
  List<Thing001>? related({int? first}) => list(
    'related',
    Thing001.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing145 extends Accessor {
  Thing145(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State10? get state => enumValue('state', State10.fromGraphQL);
  set state(State10? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail10? get detail => object('detail', Detail10.new);
  Thing146? get next => object('next', Thing146.new, keyed: true);
  List<Thing002>? related({int? first}) => list(
    'related',
    Thing002.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing146 extends Accessor {
  Thing146(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State11? get state => enumValue('state', State11.fromGraphQL);
  set state(State11? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail11? get detail => object('detail', Detail11.new);
  Thing147? get next => object('next', Thing147.new, keyed: true);
  List<Thing003>? related({int? first}) => list(
    'related',
    Thing003.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing147 extends Accessor {
  Thing147(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State12? get state => enumValue('state', State12.fromGraphQL);
  set state(State12? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail12? get detail => object('detail', Detail12.new);
  Thing148? get next => object('next', Thing148.new, keyed: true);
  List<Thing004>? related({int? first}) => list(
    'related',
    Thing004.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing148 extends Accessor {
  Thing148(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State13? get state => enumValue('state', State13.fromGraphQL);
  set state(State13? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail13? get detail => object('detail', Detail13.new);
  Thing149? get next => object('next', Thing149.new, keyed: true);
  List<Thing005>? related({int? first}) => list(
    'related',
    Thing005.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Thing149 extends Accessor {
  Thing149(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get rank => scalar<int>('rank');
  set rank(int? v) => write('rank', v);
  double? get score => scalar<double>('score');
  set score(double? v) => write('score', v);
  bool? get active => scalar<bool>('active');
  set active(bool? v) => write('active', v);
  State14? get state => enumValue('state', State14.fromGraphQL);
  set state(State14? v) => write('state', v?.graphqlName);
  List<String?>? get tags => scalarList<String>('tags');
  Detail14? get detail => object('detail', Detail14.new);
  Thing000? get next => object('next', Thing000.new, keyed: true);
  List<Thing006>? related({int? first}) => list(
    'related',
    Thing006.new,
    args: {'first': Arg('Int', first)},
    keyed: true,
  );
}

class Detail00 extends Accessor {
  Detail00(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail01 extends Accessor {
  Detail01(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail02 extends Accessor {
  Detail02(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail03 extends Accessor {
  Detail03(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail04 extends Accessor {
  Detail04(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail05 extends Accessor {
  Detail05(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail06 extends Accessor {
  Detail06(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail07 extends Accessor {
  Detail07(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail08 extends Accessor {
  Detail08(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail09 extends Accessor {
  Detail09(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail10 extends Accessor {
  Detail10(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail11 extends Accessor {
  Detail11(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail12 extends Accessor {
  Detail12(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail13 extends Accessor {
  Detail13(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Detail14 extends Accessor {
  Detail14(super.recorder, super.selection, super.path);

  String? get label => scalar<String>('label');
  set label(String? v) => write('label', v);
  int? get size => scalar<int>('size');
  set size(int? v) => write('size', v);
}

class Node extends Accessor {
  Node(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);

  /// The `... on Thing000` view of this object; `null` for another type.
  Thing000? get asThing000 => on('Thing000', Thing000.new, keyed: true);

  /// The `... on Thing001` view of this object; `null` for another type.
  Thing001? get asThing001 => on('Thing001', Thing001.new, keyed: true);

  /// The `... on Thing002` view of this object; `null` for another type.
  Thing002? get asThing002 => on('Thing002', Thing002.new, keyed: true);

  /// The `... on Thing003` view of this object; `null` for another type.
  Thing003? get asThing003 => on('Thing003', Thing003.new, keyed: true);

  /// The `... on Thing004` view of this object; `null` for another type.
  Thing004? get asThing004 => on('Thing004', Thing004.new, keyed: true);

  /// The `... on Thing005` view of this object; `null` for another type.
  Thing005? get asThing005 => on('Thing005', Thing005.new, keyed: true);

  /// The `... on Thing006` view of this object; `null` for another type.
  Thing006? get asThing006 => on('Thing006', Thing006.new, keyed: true);

  /// The `... on Thing007` view of this object; `null` for another type.
  Thing007? get asThing007 => on('Thing007', Thing007.new, keyed: true);

  /// The `... on Thing008` view of this object; `null` for another type.
  Thing008? get asThing008 => on('Thing008', Thing008.new, keyed: true);

  /// The `... on Thing009` view of this object; `null` for another type.
  Thing009? get asThing009 => on('Thing009', Thing009.new, keyed: true);

  /// The `... on Thing010` view of this object; `null` for another type.
  Thing010? get asThing010 => on('Thing010', Thing010.new, keyed: true);

  /// The `... on Thing011` view of this object; `null` for another type.
  Thing011? get asThing011 => on('Thing011', Thing011.new, keyed: true);

  /// The `... on Thing012` view of this object; `null` for another type.
  Thing012? get asThing012 => on('Thing012', Thing012.new, keyed: true);

  /// The `... on Thing013` view of this object; `null` for another type.
  Thing013? get asThing013 => on('Thing013', Thing013.new, keyed: true);

  /// The `... on Thing014` view of this object; `null` for another type.
  Thing014? get asThing014 => on('Thing014', Thing014.new, keyed: true);

  /// The `... on Thing015` view of this object; `null` for another type.
  Thing015? get asThing015 => on('Thing015', Thing015.new, keyed: true);

  /// The `... on Thing016` view of this object; `null` for another type.
  Thing016? get asThing016 => on('Thing016', Thing016.new, keyed: true);

  /// The `... on Thing017` view of this object; `null` for another type.
  Thing017? get asThing017 => on('Thing017', Thing017.new, keyed: true);

  /// The `... on Thing018` view of this object; `null` for another type.
  Thing018? get asThing018 => on('Thing018', Thing018.new, keyed: true);

  /// The `... on Thing019` view of this object; `null` for another type.
  Thing019? get asThing019 => on('Thing019', Thing019.new, keyed: true);

  /// The `... on Thing020` view of this object; `null` for another type.
  Thing020? get asThing020 => on('Thing020', Thing020.new, keyed: true);

  /// The `... on Thing021` view of this object; `null` for another type.
  Thing021? get asThing021 => on('Thing021', Thing021.new, keyed: true);

  /// The `... on Thing022` view of this object; `null` for another type.
  Thing022? get asThing022 => on('Thing022', Thing022.new, keyed: true);

  /// The `... on Thing023` view of this object; `null` for another type.
  Thing023? get asThing023 => on('Thing023', Thing023.new, keyed: true);

  /// The `... on Thing024` view of this object; `null` for another type.
  Thing024? get asThing024 => on('Thing024', Thing024.new, keyed: true);

  /// The `... on Thing025` view of this object; `null` for another type.
  Thing025? get asThing025 => on('Thing025', Thing025.new, keyed: true);

  /// The `... on Thing026` view of this object; `null` for another type.
  Thing026? get asThing026 => on('Thing026', Thing026.new, keyed: true);

  /// The `... on Thing027` view of this object; `null` for another type.
  Thing027? get asThing027 => on('Thing027', Thing027.new, keyed: true);

  /// The `... on Thing028` view of this object; `null` for another type.
  Thing028? get asThing028 => on('Thing028', Thing028.new, keyed: true);

  /// The `... on Thing029` view of this object; `null` for another type.
  Thing029? get asThing029 => on('Thing029', Thing029.new, keyed: true);

  /// The `... on Thing030` view of this object; `null` for another type.
  Thing030? get asThing030 => on('Thing030', Thing030.new, keyed: true);

  /// The `... on Thing031` view of this object; `null` for another type.
  Thing031? get asThing031 => on('Thing031', Thing031.new, keyed: true);

  /// The `... on Thing032` view of this object; `null` for another type.
  Thing032? get asThing032 => on('Thing032', Thing032.new, keyed: true);

  /// The `... on Thing033` view of this object; `null` for another type.
  Thing033? get asThing033 => on('Thing033', Thing033.new, keyed: true);

  /// The `... on Thing034` view of this object; `null` for another type.
  Thing034? get asThing034 => on('Thing034', Thing034.new, keyed: true);

  /// The `... on Thing035` view of this object; `null` for another type.
  Thing035? get asThing035 => on('Thing035', Thing035.new, keyed: true);

  /// The `... on Thing036` view of this object; `null` for another type.
  Thing036? get asThing036 => on('Thing036', Thing036.new, keyed: true);

  /// The `... on Thing037` view of this object; `null` for another type.
  Thing037? get asThing037 => on('Thing037', Thing037.new, keyed: true);

  /// The `... on Thing038` view of this object; `null` for another type.
  Thing038? get asThing038 => on('Thing038', Thing038.new, keyed: true);

  /// The `... on Thing039` view of this object; `null` for another type.
  Thing039? get asThing039 => on('Thing039', Thing039.new, keyed: true);

  /// The `... on Thing040` view of this object; `null` for another type.
  Thing040? get asThing040 => on('Thing040', Thing040.new, keyed: true);

  /// The `... on Thing041` view of this object; `null` for another type.
  Thing041? get asThing041 => on('Thing041', Thing041.new, keyed: true);

  /// The `... on Thing042` view of this object; `null` for another type.
  Thing042? get asThing042 => on('Thing042', Thing042.new, keyed: true);

  /// The `... on Thing043` view of this object; `null` for another type.
  Thing043? get asThing043 => on('Thing043', Thing043.new, keyed: true);

  /// The `... on Thing044` view of this object; `null` for another type.
  Thing044? get asThing044 => on('Thing044', Thing044.new, keyed: true);

  /// The `... on Thing045` view of this object; `null` for another type.
  Thing045? get asThing045 => on('Thing045', Thing045.new, keyed: true);

  /// The `... on Thing046` view of this object; `null` for another type.
  Thing046? get asThing046 => on('Thing046', Thing046.new, keyed: true);

  /// The `... on Thing047` view of this object; `null` for another type.
  Thing047? get asThing047 => on('Thing047', Thing047.new, keyed: true);

  /// The `... on Thing048` view of this object; `null` for another type.
  Thing048? get asThing048 => on('Thing048', Thing048.new, keyed: true);

  /// The `... on Thing049` view of this object; `null` for another type.
  Thing049? get asThing049 => on('Thing049', Thing049.new, keyed: true);

  /// The `... on Thing050` view of this object; `null` for another type.
  Thing050? get asThing050 => on('Thing050', Thing050.new, keyed: true);

  /// The `... on Thing051` view of this object; `null` for another type.
  Thing051? get asThing051 => on('Thing051', Thing051.new, keyed: true);

  /// The `... on Thing052` view of this object; `null` for another type.
  Thing052? get asThing052 => on('Thing052', Thing052.new, keyed: true);

  /// The `... on Thing053` view of this object; `null` for another type.
  Thing053? get asThing053 => on('Thing053', Thing053.new, keyed: true);

  /// The `... on Thing054` view of this object; `null` for another type.
  Thing054? get asThing054 => on('Thing054', Thing054.new, keyed: true);

  /// The `... on Thing055` view of this object; `null` for another type.
  Thing055? get asThing055 => on('Thing055', Thing055.new, keyed: true);

  /// The `... on Thing056` view of this object; `null` for another type.
  Thing056? get asThing056 => on('Thing056', Thing056.new, keyed: true);

  /// The `... on Thing057` view of this object; `null` for another type.
  Thing057? get asThing057 => on('Thing057', Thing057.new, keyed: true);

  /// The `... on Thing058` view of this object; `null` for another type.
  Thing058? get asThing058 => on('Thing058', Thing058.new, keyed: true);

  /// The `... on Thing059` view of this object; `null` for another type.
  Thing059? get asThing059 => on('Thing059', Thing059.new, keyed: true);

  /// The `... on Thing060` view of this object; `null` for another type.
  Thing060? get asThing060 => on('Thing060', Thing060.new, keyed: true);

  /// The `... on Thing061` view of this object; `null` for another type.
  Thing061? get asThing061 => on('Thing061', Thing061.new, keyed: true);

  /// The `... on Thing062` view of this object; `null` for another type.
  Thing062? get asThing062 => on('Thing062', Thing062.new, keyed: true);

  /// The `... on Thing063` view of this object; `null` for another type.
  Thing063? get asThing063 => on('Thing063', Thing063.new, keyed: true);

  /// The `... on Thing064` view of this object; `null` for another type.
  Thing064? get asThing064 => on('Thing064', Thing064.new, keyed: true);

  /// The `... on Thing065` view of this object; `null` for another type.
  Thing065? get asThing065 => on('Thing065', Thing065.new, keyed: true);

  /// The `... on Thing066` view of this object; `null` for another type.
  Thing066? get asThing066 => on('Thing066', Thing066.new, keyed: true);

  /// The `... on Thing067` view of this object; `null` for another type.
  Thing067? get asThing067 => on('Thing067', Thing067.new, keyed: true);

  /// The `... on Thing068` view of this object; `null` for another type.
  Thing068? get asThing068 => on('Thing068', Thing068.new, keyed: true);

  /// The `... on Thing069` view of this object; `null` for another type.
  Thing069? get asThing069 => on('Thing069', Thing069.new, keyed: true);

  /// The `... on Thing070` view of this object; `null` for another type.
  Thing070? get asThing070 => on('Thing070', Thing070.new, keyed: true);

  /// The `... on Thing071` view of this object; `null` for another type.
  Thing071? get asThing071 => on('Thing071', Thing071.new, keyed: true);

  /// The `... on Thing072` view of this object; `null` for another type.
  Thing072? get asThing072 => on('Thing072', Thing072.new, keyed: true);

  /// The `... on Thing073` view of this object; `null` for another type.
  Thing073? get asThing073 => on('Thing073', Thing073.new, keyed: true);

  /// The `... on Thing074` view of this object; `null` for another type.
  Thing074? get asThing074 => on('Thing074', Thing074.new, keyed: true);

  /// The `... on Thing075` view of this object; `null` for another type.
  Thing075? get asThing075 => on('Thing075', Thing075.new, keyed: true);

  /// The `... on Thing076` view of this object; `null` for another type.
  Thing076? get asThing076 => on('Thing076', Thing076.new, keyed: true);

  /// The `... on Thing077` view of this object; `null` for another type.
  Thing077? get asThing077 => on('Thing077', Thing077.new, keyed: true);

  /// The `... on Thing078` view of this object; `null` for another type.
  Thing078? get asThing078 => on('Thing078', Thing078.new, keyed: true);

  /// The `... on Thing079` view of this object; `null` for another type.
  Thing079? get asThing079 => on('Thing079', Thing079.new, keyed: true);

  /// The `... on Thing080` view of this object; `null` for another type.
  Thing080? get asThing080 => on('Thing080', Thing080.new, keyed: true);

  /// The `... on Thing081` view of this object; `null` for another type.
  Thing081? get asThing081 => on('Thing081', Thing081.new, keyed: true);

  /// The `... on Thing082` view of this object; `null` for another type.
  Thing082? get asThing082 => on('Thing082', Thing082.new, keyed: true);

  /// The `... on Thing083` view of this object; `null` for another type.
  Thing083? get asThing083 => on('Thing083', Thing083.new, keyed: true);

  /// The `... on Thing084` view of this object; `null` for another type.
  Thing084? get asThing084 => on('Thing084', Thing084.new, keyed: true);

  /// The `... on Thing085` view of this object; `null` for another type.
  Thing085? get asThing085 => on('Thing085', Thing085.new, keyed: true);

  /// The `... on Thing086` view of this object; `null` for another type.
  Thing086? get asThing086 => on('Thing086', Thing086.new, keyed: true);

  /// The `... on Thing087` view of this object; `null` for another type.
  Thing087? get asThing087 => on('Thing087', Thing087.new, keyed: true);

  /// The `... on Thing088` view of this object; `null` for another type.
  Thing088? get asThing088 => on('Thing088', Thing088.new, keyed: true);

  /// The `... on Thing089` view of this object; `null` for another type.
  Thing089? get asThing089 => on('Thing089', Thing089.new, keyed: true);

  /// The `... on Thing090` view of this object; `null` for another type.
  Thing090? get asThing090 => on('Thing090', Thing090.new, keyed: true);

  /// The `... on Thing091` view of this object; `null` for another type.
  Thing091? get asThing091 => on('Thing091', Thing091.new, keyed: true);

  /// The `... on Thing092` view of this object; `null` for another type.
  Thing092? get asThing092 => on('Thing092', Thing092.new, keyed: true);

  /// The `... on Thing093` view of this object; `null` for another type.
  Thing093? get asThing093 => on('Thing093', Thing093.new, keyed: true);

  /// The `... on Thing094` view of this object; `null` for another type.
  Thing094? get asThing094 => on('Thing094', Thing094.new, keyed: true);

  /// The `... on Thing095` view of this object; `null` for another type.
  Thing095? get asThing095 => on('Thing095', Thing095.new, keyed: true);

  /// The `... on Thing096` view of this object; `null` for another type.
  Thing096? get asThing096 => on('Thing096', Thing096.new, keyed: true);

  /// The `... on Thing097` view of this object; `null` for another type.
  Thing097? get asThing097 => on('Thing097', Thing097.new, keyed: true);

  /// The `... on Thing098` view of this object; `null` for another type.
  Thing098? get asThing098 => on('Thing098', Thing098.new, keyed: true);

  /// The `... on Thing099` view of this object; `null` for another type.
  Thing099? get asThing099 => on('Thing099', Thing099.new, keyed: true);

  /// The `... on Thing100` view of this object; `null` for another type.
  Thing100? get asThing100 => on('Thing100', Thing100.new, keyed: true);

  /// The `... on Thing101` view of this object; `null` for another type.
  Thing101? get asThing101 => on('Thing101', Thing101.new, keyed: true);

  /// The `... on Thing102` view of this object; `null` for another type.
  Thing102? get asThing102 => on('Thing102', Thing102.new, keyed: true);

  /// The `... on Thing103` view of this object; `null` for another type.
  Thing103? get asThing103 => on('Thing103', Thing103.new, keyed: true);

  /// The `... on Thing104` view of this object; `null` for another type.
  Thing104? get asThing104 => on('Thing104', Thing104.new, keyed: true);

  /// The `... on Thing105` view of this object; `null` for another type.
  Thing105? get asThing105 => on('Thing105', Thing105.new, keyed: true);

  /// The `... on Thing106` view of this object; `null` for another type.
  Thing106? get asThing106 => on('Thing106', Thing106.new, keyed: true);

  /// The `... on Thing107` view of this object; `null` for another type.
  Thing107? get asThing107 => on('Thing107', Thing107.new, keyed: true);

  /// The `... on Thing108` view of this object; `null` for another type.
  Thing108? get asThing108 => on('Thing108', Thing108.new, keyed: true);

  /// The `... on Thing109` view of this object; `null` for another type.
  Thing109? get asThing109 => on('Thing109', Thing109.new, keyed: true);

  /// The `... on Thing110` view of this object; `null` for another type.
  Thing110? get asThing110 => on('Thing110', Thing110.new, keyed: true);

  /// The `... on Thing111` view of this object; `null` for another type.
  Thing111? get asThing111 => on('Thing111', Thing111.new, keyed: true);

  /// The `... on Thing112` view of this object; `null` for another type.
  Thing112? get asThing112 => on('Thing112', Thing112.new, keyed: true);

  /// The `... on Thing113` view of this object; `null` for another type.
  Thing113? get asThing113 => on('Thing113', Thing113.new, keyed: true);

  /// The `... on Thing114` view of this object; `null` for another type.
  Thing114? get asThing114 => on('Thing114', Thing114.new, keyed: true);

  /// The `... on Thing115` view of this object; `null` for another type.
  Thing115? get asThing115 => on('Thing115', Thing115.new, keyed: true);

  /// The `... on Thing116` view of this object; `null` for another type.
  Thing116? get asThing116 => on('Thing116', Thing116.new, keyed: true);

  /// The `... on Thing117` view of this object; `null` for another type.
  Thing117? get asThing117 => on('Thing117', Thing117.new, keyed: true);

  /// The `... on Thing118` view of this object; `null` for another type.
  Thing118? get asThing118 => on('Thing118', Thing118.new, keyed: true);

  /// The `... on Thing119` view of this object; `null` for another type.
  Thing119? get asThing119 => on('Thing119', Thing119.new, keyed: true);

  /// The `... on Thing120` view of this object; `null` for another type.
  Thing120? get asThing120 => on('Thing120', Thing120.new, keyed: true);

  /// The `... on Thing121` view of this object; `null` for another type.
  Thing121? get asThing121 => on('Thing121', Thing121.new, keyed: true);

  /// The `... on Thing122` view of this object; `null` for another type.
  Thing122? get asThing122 => on('Thing122', Thing122.new, keyed: true);

  /// The `... on Thing123` view of this object; `null` for another type.
  Thing123? get asThing123 => on('Thing123', Thing123.new, keyed: true);

  /// The `... on Thing124` view of this object; `null` for another type.
  Thing124? get asThing124 => on('Thing124', Thing124.new, keyed: true);

  /// The `... on Thing125` view of this object; `null` for another type.
  Thing125? get asThing125 => on('Thing125', Thing125.new, keyed: true);

  /// The `... on Thing126` view of this object; `null` for another type.
  Thing126? get asThing126 => on('Thing126', Thing126.new, keyed: true);

  /// The `... on Thing127` view of this object; `null` for another type.
  Thing127? get asThing127 => on('Thing127', Thing127.new, keyed: true);

  /// The `... on Thing128` view of this object; `null` for another type.
  Thing128? get asThing128 => on('Thing128', Thing128.new, keyed: true);

  /// The `... on Thing129` view of this object; `null` for another type.
  Thing129? get asThing129 => on('Thing129', Thing129.new, keyed: true);

  /// The `... on Thing130` view of this object; `null` for another type.
  Thing130? get asThing130 => on('Thing130', Thing130.new, keyed: true);

  /// The `... on Thing131` view of this object; `null` for another type.
  Thing131? get asThing131 => on('Thing131', Thing131.new, keyed: true);

  /// The `... on Thing132` view of this object; `null` for another type.
  Thing132? get asThing132 => on('Thing132', Thing132.new, keyed: true);

  /// The `... on Thing133` view of this object; `null` for another type.
  Thing133? get asThing133 => on('Thing133', Thing133.new, keyed: true);

  /// The `... on Thing134` view of this object; `null` for another type.
  Thing134? get asThing134 => on('Thing134', Thing134.new, keyed: true);

  /// The `... on Thing135` view of this object; `null` for another type.
  Thing135? get asThing135 => on('Thing135', Thing135.new, keyed: true);

  /// The `... on Thing136` view of this object; `null` for another type.
  Thing136? get asThing136 => on('Thing136', Thing136.new, keyed: true);

  /// The `... on Thing137` view of this object; `null` for another type.
  Thing137? get asThing137 => on('Thing137', Thing137.new, keyed: true);

  /// The `... on Thing138` view of this object; `null` for another type.
  Thing138? get asThing138 => on('Thing138', Thing138.new, keyed: true);

  /// The `... on Thing139` view of this object; `null` for another type.
  Thing139? get asThing139 => on('Thing139', Thing139.new, keyed: true);

  /// The `... on Thing140` view of this object; `null` for another type.
  Thing140? get asThing140 => on('Thing140', Thing140.new, keyed: true);

  /// The `... on Thing141` view of this object; `null` for another type.
  Thing141? get asThing141 => on('Thing141', Thing141.new, keyed: true);

  /// The `... on Thing142` view of this object; `null` for another type.
  Thing142? get asThing142 => on('Thing142', Thing142.new, keyed: true);

  /// The `... on Thing143` view of this object; `null` for another type.
  Thing143? get asThing143 => on('Thing143', Thing143.new, keyed: true);

  /// The `... on Thing144` view of this object; `null` for another type.
  Thing144? get asThing144 => on('Thing144', Thing144.new, keyed: true);

  /// The `... on Thing145` view of this object; `null` for another type.
  Thing145? get asThing145 => on('Thing145', Thing145.new, keyed: true);

  /// The `... on Thing146` view of this object; `null` for another type.
  Thing146? get asThing146 => on('Thing146', Thing146.new, keyed: true);

  /// The `... on Thing147` view of this object; `null` for another type.
  Thing147? get asThing147 => on('Thing147', Thing147.new, keyed: true);

  /// The `... on Thing148` view of this object; `null` for another type.
  Thing148? get asThing148 => on('Thing148', Thing148.new, keyed: true);

  /// The `... on Thing149` view of this object; `null` for another type.
  Thing149? get asThing149 => on('Thing149', Thing149.new, keyed: true);

  /// Runs the branch for this object's `__typename`, [orElse] for a type
  /// without one. On a skeleton every branch runs (so all record their
  /// fields) and the first one's result is returned.
  T? when<T>({
    T Function(Thing000 thing000)? thing000,
    T Function(Thing001 thing001)? thing001,
    T Function(Thing002 thing002)? thing002,
    T Function(Thing003 thing003)? thing003,
    T Function(Thing004 thing004)? thing004,
    T Function(Thing005 thing005)? thing005,
    T Function(Thing006 thing006)? thing006,
    T Function(Thing007 thing007)? thing007,
    T Function(Thing008 thing008)? thing008,
    T Function(Thing009 thing009)? thing009,
    T Function(Thing010 thing010)? thing010,
    T Function(Thing011 thing011)? thing011,
    T Function(Thing012 thing012)? thing012,
    T Function(Thing013 thing013)? thing013,
    T Function(Thing014 thing014)? thing014,
    T Function(Thing015 thing015)? thing015,
    T Function(Thing016 thing016)? thing016,
    T Function(Thing017 thing017)? thing017,
    T Function(Thing018 thing018)? thing018,
    T Function(Thing019 thing019)? thing019,
    T Function(Thing020 thing020)? thing020,
    T Function(Thing021 thing021)? thing021,
    T Function(Thing022 thing022)? thing022,
    T Function(Thing023 thing023)? thing023,
    T Function(Thing024 thing024)? thing024,
    T Function(Thing025 thing025)? thing025,
    T Function(Thing026 thing026)? thing026,
    T Function(Thing027 thing027)? thing027,
    T Function(Thing028 thing028)? thing028,
    T Function(Thing029 thing029)? thing029,
    T Function(Thing030 thing030)? thing030,
    T Function(Thing031 thing031)? thing031,
    T Function(Thing032 thing032)? thing032,
    T Function(Thing033 thing033)? thing033,
    T Function(Thing034 thing034)? thing034,
    T Function(Thing035 thing035)? thing035,
    T Function(Thing036 thing036)? thing036,
    T Function(Thing037 thing037)? thing037,
    T Function(Thing038 thing038)? thing038,
    T Function(Thing039 thing039)? thing039,
    T Function(Thing040 thing040)? thing040,
    T Function(Thing041 thing041)? thing041,
    T Function(Thing042 thing042)? thing042,
    T Function(Thing043 thing043)? thing043,
    T Function(Thing044 thing044)? thing044,
    T Function(Thing045 thing045)? thing045,
    T Function(Thing046 thing046)? thing046,
    T Function(Thing047 thing047)? thing047,
    T Function(Thing048 thing048)? thing048,
    T Function(Thing049 thing049)? thing049,
    T Function(Thing050 thing050)? thing050,
    T Function(Thing051 thing051)? thing051,
    T Function(Thing052 thing052)? thing052,
    T Function(Thing053 thing053)? thing053,
    T Function(Thing054 thing054)? thing054,
    T Function(Thing055 thing055)? thing055,
    T Function(Thing056 thing056)? thing056,
    T Function(Thing057 thing057)? thing057,
    T Function(Thing058 thing058)? thing058,
    T Function(Thing059 thing059)? thing059,
    T Function(Thing060 thing060)? thing060,
    T Function(Thing061 thing061)? thing061,
    T Function(Thing062 thing062)? thing062,
    T Function(Thing063 thing063)? thing063,
    T Function(Thing064 thing064)? thing064,
    T Function(Thing065 thing065)? thing065,
    T Function(Thing066 thing066)? thing066,
    T Function(Thing067 thing067)? thing067,
    T Function(Thing068 thing068)? thing068,
    T Function(Thing069 thing069)? thing069,
    T Function(Thing070 thing070)? thing070,
    T Function(Thing071 thing071)? thing071,
    T Function(Thing072 thing072)? thing072,
    T Function(Thing073 thing073)? thing073,
    T Function(Thing074 thing074)? thing074,
    T Function(Thing075 thing075)? thing075,
    T Function(Thing076 thing076)? thing076,
    T Function(Thing077 thing077)? thing077,
    T Function(Thing078 thing078)? thing078,
    T Function(Thing079 thing079)? thing079,
    T Function(Thing080 thing080)? thing080,
    T Function(Thing081 thing081)? thing081,
    T Function(Thing082 thing082)? thing082,
    T Function(Thing083 thing083)? thing083,
    T Function(Thing084 thing084)? thing084,
    T Function(Thing085 thing085)? thing085,
    T Function(Thing086 thing086)? thing086,
    T Function(Thing087 thing087)? thing087,
    T Function(Thing088 thing088)? thing088,
    T Function(Thing089 thing089)? thing089,
    T Function(Thing090 thing090)? thing090,
    T Function(Thing091 thing091)? thing091,
    T Function(Thing092 thing092)? thing092,
    T Function(Thing093 thing093)? thing093,
    T Function(Thing094 thing094)? thing094,
    T Function(Thing095 thing095)? thing095,
    T Function(Thing096 thing096)? thing096,
    T Function(Thing097 thing097)? thing097,
    T Function(Thing098 thing098)? thing098,
    T Function(Thing099 thing099)? thing099,
    T Function(Thing100 thing100)? thing100,
    T Function(Thing101 thing101)? thing101,
    T Function(Thing102 thing102)? thing102,
    T Function(Thing103 thing103)? thing103,
    T Function(Thing104 thing104)? thing104,
    T Function(Thing105 thing105)? thing105,
    T Function(Thing106 thing106)? thing106,
    T Function(Thing107 thing107)? thing107,
    T Function(Thing108 thing108)? thing108,
    T Function(Thing109 thing109)? thing109,
    T Function(Thing110 thing110)? thing110,
    T Function(Thing111 thing111)? thing111,
    T Function(Thing112 thing112)? thing112,
    T Function(Thing113 thing113)? thing113,
    T Function(Thing114 thing114)? thing114,
    T Function(Thing115 thing115)? thing115,
    T Function(Thing116 thing116)? thing116,
    T Function(Thing117 thing117)? thing117,
    T Function(Thing118 thing118)? thing118,
    T Function(Thing119 thing119)? thing119,
    T Function(Thing120 thing120)? thing120,
    T Function(Thing121 thing121)? thing121,
    T Function(Thing122 thing122)? thing122,
    T Function(Thing123 thing123)? thing123,
    T Function(Thing124 thing124)? thing124,
    T Function(Thing125 thing125)? thing125,
    T Function(Thing126 thing126)? thing126,
    T Function(Thing127 thing127)? thing127,
    T Function(Thing128 thing128)? thing128,
    T Function(Thing129 thing129)? thing129,
    T Function(Thing130 thing130)? thing130,
    T Function(Thing131 thing131)? thing131,
    T Function(Thing132 thing132)? thing132,
    T Function(Thing133 thing133)? thing133,
    T Function(Thing134 thing134)? thing134,
    T Function(Thing135 thing135)? thing135,
    T Function(Thing136 thing136)? thing136,
    T Function(Thing137 thing137)? thing137,
    T Function(Thing138 thing138)? thing138,
    T Function(Thing139 thing139)? thing139,
    T Function(Thing140 thing140)? thing140,
    T Function(Thing141 thing141)? thing141,
    T Function(Thing142 thing142)? thing142,
    T Function(Thing143 thing143)? thing143,
    T Function(Thing144 thing144)? thing144,
    T Function(Thing145 thing145)? thing145,
    T Function(Thing146 thing146)? thing146,
    T Function(Thing147 thing147)? thing147,
    T Function(Thing148 thing148)? thing148,
    T Function(Thing149 thing149)? thing149,
    T Function()? orElse,
  }) => whenType({
    if (thing000 != null) 'Thing000': () => thing000(asThing000!),
    if (thing001 != null) 'Thing001': () => thing001(asThing001!),
    if (thing002 != null) 'Thing002': () => thing002(asThing002!),
    if (thing003 != null) 'Thing003': () => thing003(asThing003!),
    if (thing004 != null) 'Thing004': () => thing004(asThing004!),
    if (thing005 != null) 'Thing005': () => thing005(asThing005!),
    if (thing006 != null) 'Thing006': () => thing006(asThing006!),
    if (thing007 != null) 'Thing007': () => thing007(asThing007!),
    if (thing008 != null) 'Thing008': () => thing008(asThing008!),
    if (thing009 != null) 'Thing009': () => thing009(asThing009!),
    if (thing010 != null) 'Thing010': () => thing010(asThing010!),
    if (thing011 != null) 'Thing011': () => thing011(asThing011!),
    if (thing012 != null) 'Thing012': () => thing012(asThing012!),
    if (thing013 != null) 'Thing013': () => thing013(asThing013!),
    if (thing014 != null) 'Thing014': () => thing014(asThing014!),
    if (thing015 != null) 'Thing015': () => thing015(asThing015!),
    if (thing016 != null) 'Thing016': () => thing016(asThing016!),
    if (thing017 != null) 'Thing017': () => thing017(asThing017!),
    if (thing018 != null) 'Thing018': () => thing018(asThing018!),
    if (thing019 != null) 'Thing019': () => thing019(asThing019!),
    if (thing020 != null) 'Thing020': () => thing020(asThing020!),
    if (thing021 != null) 'Thing021': () => thing021(asThing021!),
    if (thing022 != null) 'Thing022': () => thing022(asThing022!),
    if (thing023 != null) 'Thing023': () => thing023(asThing023!),
    if (thing024 != null) 'Thing024': () => thing024(asThing024!),
    if (thing025 != null) 'Thing025': () => thing025(asThing025!),
    if (thing026 != null) 'Thing026': () => thing026(asThing026!),
    if (thing027 != null) 'Thing027': () => thing027(asThing027!),
    if (thing028 != null) 'Thing028': () => thing028(asThing028!),
    if (thing029 != null) 'Thing029': () => thing029(asThing029!),
    if (thing030 != null) 'Thing030': () => thing030(asThing030!),
    if (thing031 != null) 'Thing031': () => thing031(asThing031!),
    if (thing032 != null) 'Thing032': () => thing032(asThing032!),
    if (thing033 != null) 'Thing033': () => thing033(asThing033!),
    if (thing034 != null) 'Thing034': () => thing034(asThing034!),
    if (thing035 != null) 'Thing035': () => thing035(asThing035!),
    if (thing036 != null) 'Thing036': () => thing036(asThing036!),
    if (thing037 != null) 'Thing037': () => thing037(asThing037!),
    if (thing038 != null) 'Thing038': () => thing038(asThing038!),
    if (thing039 != null) 'Thing039': () => thing039(asThing039!),
    if (thing040 != null) 'Thing040': () => thing040(asThing040!),
    if (thing041 != null) 'Thing041': () => thing041(asThing041!),
    if (thing042 != null) 'Thing042': () => thing042(asThing042!),
    if (thing043 != null) 'Thing043': () => thing043(asThing043!),
    if (thing044 != null) 'Thing044': () => thing044(asThing044!),
    if (thing045 != null) 'Thing045': () => thing045(asThing045!),
    if (thing046 != null) 'Thing046': () => thing046(asThing046!),
    if (thing047 != null) 'Thing047': () => thing047(asThing047!),
    if (thing048 != null) 'Thing048': () => thing048(asThing048!),
    if (thing049 != null) 'Thing049': () => thing049(asThing049!),
    if (thing050 != null) 'Thing050': () => thing050(asThing050!),
    if (thing051 != null) 'Thing051': () => thing051(asThing051!),
    if (thing052 != null) 'Thing052': () => thing052(asThing052!),
    if (thing053 != null) 'Thing053': () => thing053(asThing053!),
    if (thing054 != null) 'Thing054': () => thing054(asThing054!),
    if (thing055 != null) 'Thing055': () => thing055(asThing055!),
    if (thing056 != null) 'Thing056': () => thing056(asThing056!),
    if (thing057 != null) 'Thing057': () => thing057(asThing057!),
    if (thing058 != null) 'Thing058': () => thing058(asThing058!),
    if (thing059 != null) 'Thing059': () => thing059(asThing059!),
    if (thing060 != null) 'Thing060': () => thing060(asThing060!),
    if (thing061 != null) 'Thing061': () => thing061(asThing061!),
    if (thing062 != null) 'Thing062': () => thing062(asThing062!),
    if (thing063 != null) 'Thing063': () => thing063(asThing063!),
    if (thing064 != null) 'Thing064': () => thing064(asThing064!),
    if (thing065 != null) 'Thing065': () => thing065(asThing065!),
    if (thing066 != null) 'Thing066': () => thing066(asThing066!),
    if (thing067 != null) 'Thing067': () => thing067(asThing067!),
    if (thing068 != null) 'Thing068': () => thing068(asThing068!),
    if (thing069 != null) 'Thing069': () => thing069(asThing069!),
    if (thing070 != null) 'Thing070': () => thing070(asThing070!),
    if (thing071 != null) 'Thing071': () => thing071(asThing071!),
    if (thing072 != null) 'Thing072': () => thing072(asThing072!),
    if (thing073 != null) 'Thing073': () => thing073(asThing073!),
    if (thing074 != null) 'Thing074': () => thing074(asThing074!),
    if (thing075 != null) 'Thing075': () => thing075(asThing075!),
    if (thing076 != null) 'Thing076': () => thing076(asThing076!),
    if (thing077 != null) 'Thing077': () => thing077(asThing077!),
    if (thing078 != null) 'Thing078': () => thing078(asThing078!),
    if (thing079 != null) 'Thing079': () => thing079(asThing079!),
    if (thing080 != null) 'Thing080': () => thing080(asThing080!),
    if (thing081 != null) 'Thing081': () => thing081(asThing081!),
    if (thing082 != null) 'Thing082': () => thing082(asThing082!),
    if (thing083 != null) 'Thing083': () => thing083(asThing083!),
    if (thing084 != null) 'Thing084': () => thing084(asThing084!),
    if (thing085 != null) 'Thing085': () => thing085(asThing085!),
    if (thing086 != null) 'Thing086': () => thing086(asThing086!),
    if (thing087 != null) 'Thing087': () => thing087(asThing087!),
    if (thing088 != null) 'Thing088': () => thing088(asThing088!),
    if (thing089 != null) 'Thing089': () => thing089(asThing089!),
    if (thing090 != null) 'Thing090': () => thing090(asThing090!),
    if (thing091 != null) 'Thing091': () => thing091(asThing091!),
    if (thing092 != null) 'Thing092': () => thing092(asThing092!),
    if (thing093 != null) 'Thing093': () => thing093(asThing093!),
    if (thing094 != null) 'Thing094': () => thing094(asThing094!),
    if (thing095 != null) 'Thing095': () => thing095(asThing095!),
    if (thing096 != null) 'Thing096': () => thing096(asThing096!),
    if (thing097 != null) 'Thing097': () => thing097(asThing097!),
    if (thing098 != null) 'Thing098': () => thing098(asThing098!),
    if (thing099 != null) 'Thing099': () => thing099(asThing099!),
    if (thing100 != null) 'Thing100': () => thing100(asThing100!),
    if (thing101 != null) 'Thing101': () => thing101(asThing101!),
    if (thing102 != null) 'Thing102': () => thing102(asThing102!),
    if (thing103 != null) 'Thing103': () => thing103(asThing103!),
    if (thing104 != null) 'Thing104': () => thing104(asThing104!),
    if (thing105 != null) 'Thing105': () => thing105(asThing105!),
    if (thing106 != null) 'Thing106': () => thing106(asThing106!),
    if (thing107 != null) 'Thing107': () => thing107(asThing107!),
    if (thing108 != null) 'Thing108': () => thing108(asThing108!),
    if (thing109 != null) 'Thing109': () => thing109(asThing109!),
    if (thing110 != null) 'Thing110': () => thing110(asThing110!),
    if (thing111 != null) 'Thing111': () => thing111(asThing111!),
    if (thing112 != null) 'Thing112': () => thing112(asThing112!),
    if (thing113 != null) 'Thing113': () => thing113(asThing113!),
    if (thing114 != null) 'Thing114': () => thing114(asThing114!),
    if (thing115 != null) 'Thing115': () => thing115(asThing115!),
    if (thing116 != null) 'Thing116': () => thing116(asThing116!),
    if (thing117 != null) 'Thing117': () => thing117(asThing117!),
    if (thing118 != null) 'Thing118': () => thing118(asThing118!),
    if (thing119 != null) 'Thing119': () => thing119(asThing119!),
    if (thing120 != null) 'Thing120': () => thing120(asThing120!),
    if (thing121 != null) 'Thing121': () => thing121(asThing121!),
    if (thing122 != null) 'Thing122': () => thing122(asThing122!),
    if (thing123 != null) 'Thing123': () => thing123(asThing123!),
    if (thing124 != null) 'Thing124': () => thing124(asThing124!),
    if (thing125 != null) 'Thing125': () => thing125(asThing125!),
    if (thing126 != null) 'Thing126': () => thing126(asThing126!),
    if (thing127 != null) 'Thing127': () => thing127(asThing127!),
    if (thing128 != null) 'Thing128': () => thing128(asThing128!),
    if (thing129 != null) 'Thing129': () => thing129(asThing129!),
    if (thing130 != null) 'Thing130': () => thing130(asThing130!),
    if (thing131 != null) 'Thing131': () => thing131(asThing131!),
    if (thing132 != null) 'Thing132': () => thing132(asThing132!),
    if (thing133 != null) 'Thing133': () => thing133(asThing133!),
    if (thing134 != null) 'Thing134': () => thing134(asThing134!),
    if (thing135 != null) 'Thing135': () => thing135(asThing135!),
    if (thing136 != null) 'Thing136': () => thing136(asThing136!),
    if (thing137 != null) 'Thing137': () => thing137(asThing137!),
    if (thing138 != null) 'Thing138': () => thing138(asThing138!),
    if (thing139 != null) 'Thing139': () => thing139(asThing139!),
    if (thing140 != null) 'Thing140': () => thing140(asThing140!),
    if (thing141 != null) 'Thing141': () => thing141(asThing141!),
    if (thing142 != null) 'Thing142': () => thing142(asThing142!),
    if (thing143 != null) 'Thing143': () => thing143(asThing143!),
    if (thing144 != null) 'Thing144': () => thing144(asThing144!),
    if (thing145 != null) 'Thing145': () => thing145(asThing145!),
    if (thing146 != null) 'Thing146': () => thing146(asThing146!),
    if (thing147 != null) 'Thing147': () => thing147(asThing147!),
    if (thing148 != null) 'Thing148': () => thing148(asThing148!),
    if (thing149 != null) 'Thing149': () => thing149(asThing149!),
  }, orElse: orElse);
}

class Group0 extends Accessor {
  Group0(super.recorder, super.selection, super.path);

  /// The `... on Thing000` view of this object; `null` for another type.
  Thing000? get asThing000 => on('Thing000', Thing000.new, keyed: true);

  /// The `... on Thing010` view of this object; `null` for another type.
  Thing010? get asThing010 => on('Thing010', Thing010.new, keyed: true);

  /// The `... on Thing020` view of this object; `null` for another type.
  Thing020? get asThing020 => on('Thing020', Thing020.new, keyed: true);

  /// The `... on Thing030` view of this object; `null` for another type.
  Thing030? get asThing030 => on('Thing030', Thing030.new, keyed: true);

  /// The `... on Thing040` view of this object; `null` for another type.
  Thing040? get asThing040 => on('Thing040', Thing040.new, keyed: true);

  /// The `... on Thing050` view of this object; `null` for another type.
  Thing050? get asThing050 => on('Thing050', Thing050.new, keyed: true);

  /// The `... on Thing060` view of this object; `null` for another type.
  Thing060? get asThing060 => on('Thing060', Thing060.new, keyed: true);

  /// The `... on Thing070` view of this object; `null` for another type.
  Thing070? get asThing070 => on('Thing070', Thing070.new, keyed: true);

  /// The `... on Thing080` view of this object; `null` for another type.
  Thing080? get asThing080 => on('Thing080', Thing080.new, keyed: true);

  /// The `... on Thing090` view of this object; `null` for another type.
  Thing090? get asThing090 => on('Thing090', Thing090.new, keyed: true);

  /// The `... on Thing100` view of this object; `null` for another type.
  Thing100? get asThing100 => on('Thing100', Thing100.new, keyed: true);

  /// The `... on Thing110` view of this object; `null` for another type.
  Thing110? get asThing110 => on('Thing110', Thing110.new, keyed: true);

  /// The `... on Thing120` view of this object; `null` for another type.
  Thing120? get asThing120 => on('Thing120', Thing120.new, keyed: true);

  /// The `... on Thing130` view of this object; `null` for another type.
  Thing130? get asThing130 => on('Thing130', Thing130.new, keyed: true);

  /// The `... on Thing140` view of this object; `null` for another type.
  Thing140? get asThing140 => on('Thing140', Thing140.new, keyed: true);

  /// Runs the branch for this object's `__typename`, [orElse] for a type
  /// without one. On a skeleton every branch runs (so all record their
  /// fields) and the first one's result is returned.
  T? when<T>({
    T Function(Thing000 thing000)? thing000,
    T Function(Thing010 thing010)? thing010,
    T Function(Thing020 thing020)? thing020,
    T Function(Thing030 thing030)? thing030,
    T Function(Thing040 thing040)? thing040,
    T Function(Thing050 thing050)? thing050,
    T Function(Thing060 thing060)? thing060,
    T Function(Thing070 thing070)? thing070,
    T Function(Thing080 thing080)? thing080,
    T Function(Thing090 thing090)? thing090,
    T Function(Thing100 thing100)? thing100,
    T Function(Thing110 thing110)? thing110,
    T Function(Thing120 thing120)? thing120,
    T Function(Thing130 thing130)? thing130,
    T Function(Thing140 thing140)? thing140,
    T Function()? orElse,
  }) => whenType({
    if (thing000 != null) 'Thing000': () => thing000(asThing000!),
    if (thing010 != null) 'Thing010': () => thing010(asThing010!),
    if (thing020 != null) 'Thing020': () => thing020(asThing020!),
    if (thing030 != null) 'Thing030': () => thing030(asThing030!),
    if (thing040 != null) 'Thing040': () => thing040(asThing040!),
    if (thing050 != null) 'Thing050': () => thing050(asThing050!),
    if (thing060 != null) 'Thing060': () => thing060(asThing060!),
    if (thing070 != null) 'Thing070': () => thing070(asThing070!),
    if (thing080 != null) 'Thing080': () => thing080(asThing080!),
    if (thing090 != null) 'Thing090': () => thing090(asThing090!),
    if (thing100 != null) 'Thing100': () => thing100(asThing100!),
    if (thing110 != null) 'Thing110': () => thing110(asThing110!),
    if (thing120 != null) 'Thing120': () => thing120(asThing120!),
    if (thing130 != null) 'Thing130': () => thing130(asThing130!),
    if (thing140 != null) 'Thing140': () => thing140(asThing140!),
  }, orElse: orElse);
}

class Group1 extends Accessor {
  Group1(super.recorder, super.selection, super.path);

  /// The `... on Thing001` view of this object; `null` for another type.
  Thing001? get asThing001 => on('Thing001', Thing001.new, keyed: true);

  /// The `... on Thing011` view of this object; `null` for another type.
  Thing011? get asThing011 => on('Thing011', Thing011.new, keyed: true);

  /// The `... on Thing021` view of this object; `null` for another type.
  Thing021? get asThing021 => on('Thing021', Thing021.new, keyed: true);

  /// The `... on Thing031` view of this object; `null` for another type.
  Thing031? get asThing031 => on('Thing031', Thing031.new, keyed: true);

  /// The `... on Thing041` view of this object; `null` for another type.
  Thing041? get asThing041 => on('Thing041', Thing041.new, keyed: true);

  /// The `... on Thing051` view of this object; `null` for another type.
  Thing051? get asThing051 => on('Thing051', Thing051.new, keyed: true);

  /// The `... on Thing061` view of this object; `null` for another type.
  Thing061? get asThing061 => on('Thing061', Thing061.new, keyed: true);

  /// The `... on Thing071` view of this object; `null` for another type.
  Thing071? get asThing071 => on('Thing071', Thing071.new, keyed: true);

  /// The `... on Thing081` view of this object; `null` for another type.
  Thing081? get asThing081 => on('Thing081', Thing081.new, keyed: true);

  /// The `... on Thing091` view of this object; `null` for another type.
  Thing091? get asThing091 => on('Thing091', Thing091.new, keyed: true);

  /// The `... on Thing101` view of this object; `null` for another type.
  Thing101? get asThing101 => on('Thing101', Thing101.new, keyed: true);

  /// The `... on Thing111` view of this object; `null` for another type.
  Thing111? get asThing111 => on('Thing111', Thing111.new, keyed: true);

  /// The `... on Thing121` view of this object; `null` for another type.
  Thing121? get asThing121 => on('Thing121', Thing121.new, keyed: true);

  /// The `... on Thing131` view of this object; `null` for another type.
  Thing131? get asThing131 => on('Thing131', Thing131.new, keyed: true);

  /// The `... on Thing141` view of this object; `null` for another type.
  Thing141? get asThing141 => on('Thing141', Thing141.new, keyed: true);

  /// Runs the branch for this object's `__typename`, [orElse] for a type
  /// without one. On a skeleton every branch runs (so all record their
  /// fields) and the first one's result is returned.
  T? when<T>({
    T Function(Thing001 thing001)? thing001,
    T Function(Thing011 thing011)? thing011,
    T Function(Thing021 thing021)? thing021,
    T Function(Thing031 thing031)? thing031,
    T Function(Thing041 thing041)? thing041,
    T Function(Thing051 thing051)? thing051,
    T Function(Thing061 thing061)? thing061,
    T Function(Thing071 thing071)? thing071,
    T Function(Thing081 thing081)? thing081,
    T Function(Thing091 thing091)? thing091,
    T Function(Thing101 thing101)? thing101,
    T Function(Thing111 thing111)? thing111,
    T Function(Thing121 thing121)? thing121,
    T Function(Thing131 thing131)? thing131,
    T Function(Thing141 thing141)? thing141,
    T Function()? orElse,
  }) => whenType({
    if (thing001 != null) 'Thing001': () => thing001(asThing001!),
    if (thing011 != null) 'Thing011': () => thing011(asThing011!),
    if (thing021 != null) 'Thing021': () => thing021(asThing021!),
    if (thing031 != null) 'Thing031': () => thing031(asThing031!),
    if (thing041 != null) 'Thing041': () => thing041(asThing041!),
    if (thing051 != null) 'Thing051': () => thing051(asThing051!),
    if (thing061 != null) 'Thing061': () => thing061(asThing061!),
    if (thing071 != null) 'Thing071': () => thing071(asThing071!),
    if (thing081 != null) 'Thing081': () => thing081(asThing081!),
    if (thing091 != null) 'Thing091': () => thing091(asThing091!),
    if (thing101 != null) 'Thing101': () => thing101(asThing101!),
    if (thing111 != null) 'Thing111': () => thing111(asThing111!),
    if (thing121 != null) 'Thing121': () => thing121(asThing121!),
    if (thing131 != null) 'Thing131': () => thing131(asThing131!),
    if (thing141 != null) 'Thing141': () => thing141(asThing141!),
  }, orElse: orElse);
}

class Group2 extends Accessor {
  Group2(super.recorder, super.selection, super.path);

  /// The `... on Thing002` view of this object; `null` for another type.
  Thing002? get asThing002 => on('Thing002', Thing002.new, keyed: true);

  /// The `... on Thing012` view of this object; `null` for another type.
  Thing012? get asThing012 => on('Thing012', Thing012.new, keyed: true);

  /// The `... on Thing022` view of this object; `null` for another type.
  Thing022? get asThing022 => on('Thing022', Thing022.new, keyed: true);

  /// The `... on Thing032` view of this object; `null` for another type.
  Thing032? get asThing032 => on('Thing032', Thing032.new, keyed: true);

  /// The `... on Thing042` view of this object; `null` for another type.
  Thing042? get asThing042 => on('Thing042', Thing042.new, keyed: true);

  /// The `... on Thing052` view of this object; `null` for another type.
  Thing052? get asThing052 => on('Thing052', Thing052.new, keyed: true);

  /// The `... on Thing062` view of this object; `null` for another type.
  Thing062? get asThing062 => on('Thing062', Thing062.new, keyed: true);

  /// The `... on Thing072` view of this object; `null` for another type.
  Thing072? get asThing072 => on('Thing072', Thing072.new, keyed: true);

  /// The `... on Thing082` view of this object; `null` for another type.
  Thing082? get asThing082 => on('Thing082', Thing082.new, keyed: true);

  /// The `... on Thing092` view of this object; `null` for another type.
  Thing092? get asThing092 => on('Thing092', Thing092.new, keyed: true);

  /// The `... on Thing102` view of this object; `null` for another type.
  Thing102? get asThing102 => on('Thing102', Thing102.new, keyed: true);

  /// The `... on Thing112` view of this object; `null` for another type.
  Thing112? get asThing112 => on('Thing112', Thing112.new, keyed: true);

  /// The `... on Thing122` view of this object; `null` for another type.
  Thing122? get asThing122 => on('Thing122', Thing122.new, keyed: true);

  /// The `... on Thing132` view of this object; `null` for another type.
  Thing132? get asThing132 => on('Thing132', Thing132.new, keyed: true);

  /// The `... on Thing142` view of this object; `null` for another type.
  Thing142? get asThing142 => on('Thing142', Thing142.new, keyed: true);

  /// Runs the branch for this object's `__typename`, [orElse] for a type
  /// without one. On a skeleton every branch runs (so all record their
  /// fields) and the first one's result is returned.
  T? when<T>({
    T Function(Thing002 thing002)? thing002,
    T Function(Thing012 thing012)? thing012,
    T Function(Thing022 thing022)? thing022,
    T Function(Thing032 thing032)? thing032,
    T Function(Thing042 thing042)? thing042,
    T Function(Thing052 thing052)? thing052,
    T Function(Thing062 thing062)? thing062,
    T Function(Thing072 thing072)? thing072,
    T Function(Thing082 thing082)? thing082,
    T Function(Thing092 thing092)? thing092,
    T Function(Thing102 thing102)? thing102,
    T Function(Thing112 thing112)? thing112,
    T Function(Thing122 thing122)? thing122,
    T Function(Thing132 thing132)? thing132,
    T Function(Thing142 thing142)? thing142,
    T Function()? orElse,
  }) => whenType({
    if (thing002 != null) 'Thing002': () => thing002(asThing002!),
    if (thing012 != null) 'Thing012': () => thing012(asThing012!),
    if (thing022 != null) 'Thing022': () => thing022(asThing022!),
    if (thing032 != null) 'Thing032': () => thing032(asThing032!),
    if (thing042 != null) 'Thing042': () => thing042(asThing042!),
    if (thing052 != null) 'Thing052': () => thing052(asThing052!),
    if (thing062 != null) 'Thing062': () => thing062(asThing062!),
    if (thing072 != null) 'Thing072': () => thing072(asThing072!),
    if (thing082 != null) 'Thing082': () => thing082(asThing082!),
    if (thing092 != null) 'Thing092': () => thing092(asThing092!),
    if (thing102 != null) 'Thing102': () => thing102(asThing102!),
    if (thing112 != null) 'Thing112': () => thing112(asThing112!),
    if (thing122 != null) 'Thing122': () => thing122(asThing122!),
    if (thing132 != null) 'Thing132': () => thing132(asThing132!),
    if (thing142 != null) 'Thing142': () => thing142(asThing142!),
  }, orElse: orElse);
}

class Group3 extends Accessor {
  Group3(super.recorder, super.selection, super.path);

  /// The `... on Thing003` view of this object; `null` for another type.
  Thing003? get asThing003 => on('Thing003', Thing003.new, keyed: true);

  /// The `... on Thing013` view of this object; `null` for another type.
  Thing013? get asThing013 => on('Thing013', Thing013.new, keyed: true);

  /// The `... on Thing023` view of this object; `null` for another type.
  Thing023? get asThing023 => on('Thing023', Thing023.new, keyed: true);

  /// The `... on Thing033` view of this object; `null` for another type.
  Thing033? get asThing033 => on('Thing033', Thing033.new, keyed: true);

  /// The `... on Thing043` view of this object; `null` for another type.
  Thing043? get asThing043 => on('Thing043', Thing043.new, keyed: true);

  /// The `... on Thing053` view of this object; `null` for another type.
  Thing053? get asThing053 => on('Thing053', Thing053.new, keyed: true);

  /// The `... on Thing063` view of this object; `null` for another type.
  Thing063? get asThing063 => on('Thing063', Thing063.new, keyed: true);

  /// The `... on Thing073` view of this object; `null` for another type.
  Thing073? get asThing073 => on('Thing073', Thing073.new, keyed: true);

  /// The `... on Thing083` view of this object; `null` for another type.
  Thing083? get asThing083 => on('Thing083', Thing083.new, keyed: true);

  /// The `... on Thing093` view of this object; `null` for another type.
  Thing093? get asThing093 => on('Thing093', Thing093.new, keyed: true);

  /// The `... on Thing103` view of this object; `null` for another type.
  Thing103? get asThing103 => on('Thing103', Thing103.new, keyed: true);

  /// The `... on Thing113` view of this object; `null` for another type.
  Thing113? get asThing113 => on('Thing113', Thing113.new, keyed: true);

  /// The `... on Thing123` view of this object; `null` for another type.
  Thing123? get asThing123 => on('Thing123', Thing123.new, keyed: true);

  /// The `... on Thing133` view of this object; `null` for another type.
  Thing133? get asThing133 => on('Thing133', Thing133.new, keyed: true);

  /// The `... on Thing143` view of this object; `null` for another type.
  Thing143? get asThing143 => on('Thing143', Thing143.new, keyed: true);

  /// Runs the branch for this object's `__typename`, [orElse] for a type
  /// without one. On a skeleton every branch runs (so all record their
  /// fields) and the first one's result is returned.
  T? when<T>({
    T Function(Thing003 thing003)? thing003,
    T Function(Thing013 thing013)? thing013,
    T Function(Thing023 thing023)? thing023,
    T Function(Thing033 thing033)? thing033,
    T Function(Thing043 thing043)? thing043,
    T Function(Thing053 thing053)? thing053,
    T Function(Thing063 thing063)? thing063,
    T Function(Thing073 thing073)? thing073,
    T Function(Thing083 thing083)? thing083,
    T Function(Thing093 thing093)? thing093,
    T Function(Thing103 thing103)? thing103,
    T Function(Thing113 thing113)? thing113,
    T Function(Thing123 thing123)? thing123,
    T Function(Thing133 thing133)? thing133,
    T Function(Thing143 thing143)? thing143,
    T Function()? orElse,
  }) => whenType({
    if (thing003 != null) 'Thing003': () => thing003(asThing003!),
    if (thing013 != null) 'Thing013': () => thing013(asThing013!),
    if (thing023 != null) 'Thing023': () => thing023(asThing023!),
    if (thing033 != null) 'Thing033': () => thing033(asThing033!),
    if (thing043 != null) 'Thing043': () => thing043(asThing043!),
    if (thing053 != null) 'Thing053': () => thing053(asThing053!),
    if (thing063 != null) 'Thing063': () => thing063(asThing063!),
    if (thing073 != null) 'Thing073': () => thing073(asThing073!),
    if (thing083 != null) 'Thing083': () => thing083(asThing083!),
    if (thing093 != null) 'Thing093': () => thing093(asThing093!),
    if (thing103 != null) 'Thing103': () => thing103(asThing103!),
    if (thing113 != null) 'Thing113': () => thing113(asThing113!),
    if (thing123 != null) 'Thing123': () => thing123(asThing123!),
    if (thing133 != null) 'Thing133': () => thing133(asThing133!),
    if (thing143 != null) 'Thing143': () => thing143(asThing143!),
  }, orElse: orElse);
}

class Group4 extends Accessor {
  Group4(super.recorder, super.selection, super.path);

  /// The `... on Thing004` view of this object; `null` for another type.
  Thing004? get asThing004 => on('Thing004', Thing004.new, keyed: true);

  /// The `... on Thing014` view of this object; `null` for another type.
  Thing014? get asThing014 => on('Thing014', Thing014.new, keyed: true);

  /// The `... on Thing024` view of this object; `null` for another type.
  Thing024? get asThing024 => on('Thing024', Thing024.new, keyed: true);

  /// The `... on Thing034` view of this object; `null` for another type.
  Thing034? get asThing034 => on('Thing034', Thing034.new, keyed: true);

  /// The `... on Thing044` view of this object; `null` for another type.
  Thing044? get asThing044 => on('Thing044', Thing044.new, keyed: true);

  /// The `... on Thing054` view of this object; `null` for another type.
  Thing054? get asThing054 => on('Thing054', Thing054.new, keyed: true);

  /// The `... on Thing064` view of this object; `null` for another type.
  Thing064? get asThing064 => on('Thing064', Thing064.new, keyed: true);

  /// The `... on Thing074` view of this object; `null` for another type.
  Thing074? get asThing074 => on('Thing074', Thing074.new, keyed: true);

  /// The `... on Thing084` view of this object; `null` for another type.
  Thing084? get asThing084 => on('Thing084', Thing084.new, keyed: true);

  /// The `... on Thing094` view of this object; `null` for another type.
  Thing094? get asThing094 => on('Thing094', Thing094.new, keyed: true);

  /// The `... on Thing104` view of this object; `null` for another type.
  Thing104? get asThing104 => on('Thing104', Thing104.new, keyed: true);

  /// The `... on Thing114` view of this object; `null` for another type.
  Thing114? get asThing114 => on('Thing114', Thing114.new, keyed: true);

  /// The `... on Thing124` view of this object; `null` for another type.
  Thing124? get asThing124 => on('Thing124', Thing124.new, keyed: true);

  /// The `... on Thing134` view of this object; `null` for another type.
  Thing134? get asThing134 => on('Thing134', Thing134.new, keyed: true);

  /// The `... on Thing144` view of this object; `null` for another type.
  Thing144? get asThing144 => on('Thing144', Thing144.new, keyed: true);

  /// Runs the branch for this object's `__typename`, [orElse] for a type
  /// without one. On a skeleton every branch runs (so all record their
  /// fields) and the first one's result is returned.
  T? when<T>({
    T Function(Thing004 thing004)? thing004,
    T Function(Thing014 thing014)? thing014,
    T Function(Thing024 thing024)? thing024,
    T Function(Thing034 thing034)? thing034,
    T Function(Thing044 thing044)? thing044,
    T Function(Thing054 thing054)? thing054,
    T Function(Thing064 thing064)? thing064,
    T Function(Thing074 thing074)? thing074,
    T Function(Thing084 thing084)? thing084,
    T Function(Thing094 thing094)? thing094,
    T Function(Thing104 thing104)? thing104,
    T Function(Thing114 thing114)? thing114,
    T Function(Thing124 thing124)? thing124,
    T Function(Thing134 thing134)? thing134,
    T Function(Thing144 thing144)? thing144,
    T Function()? orElse,
  }) => whenType({
    if (thing004 != null) 'Thing004': () => thing004(asThing004!),
    if (thing014 != null) 'Thing014': () => thing014(asThing014!),
    if (thing024 != null) 'Thing024': () => thing024(asThing024!),
    if (thing034 != null) 'Thing034': () => thing034(asThing034!),
    if (thing044 != null) 'Thing044': () => thing044(asThing044!),
    if (thing054 != null) 'Thing054': () => thing054(asThing054!),
    if (thing064 != null) 'Thing064': () => thing064(asThing064!),
    if (thing074 != null) 'Thing074': () => thing074(asThing074!),
    if (thing084 != null) 'Thing084': () => thing084(asThing084!),
    if (thing094 != null) 'Thing094': () => thing094(asThing094!),
    if (thing104 != null) 'Thing104': () => thing104(asThing104!),
    if (thing114 != null) 'Thing114': () => thing114(asThing114!),
    if (thing124 != null) 'Thing124': () => thing124(asThing124!),
    if (thing134 != null) 'Thing134': () => thing134(asThing134!),
    if (thing144 != null) 'Thing144': () => thing144(asThing144!),
  }, orElse: orElse);
}

class Group5 extends Accessor {
  Group5(super.recorder, super.selection, super.path);

  /// The `... on Thing005` view of this object; `null` for another type.
  Thing005? get asThing005 => on('Thing005', Thing005.new, keyed: true);

  /// The `... on Thing015` view of this object; `null` for another type.
  Thing015? get asThing015 => on('Thing015', Thing015.new, keyed: true);

  /// The `... on Thing025` view of this object; `null` for another type.
  Thing025? get asThing025 => on('Thing025', Thing025.new, keyed: true);

  /// The `... on Thing035` view of this object; `null` for another type.
  Thing035? get asThing035 => on('Thing035', Thing035.new, keyed: true);

  /// The `... on Thing045` view of this object; `null` for another type.
  Thing045? get asThing045 => on('Thing045', Thing045.new, keyed: true);

  /// The `... on Thing055` view of this object; `null` for another type.
  Thing055? get asThing055 => on('Thing055', Thing055.new, keyed: true);

  /// The `... on Thing065` view of this object; `null` for another type.
  Thing065? get asThing065 => on('Thing065', Thing065.new, keyed: true);

  /// The `... on Thing075` view of this object; `null` for another type.
  Thing075? get asThing075 => on('Thing075', Thing075.new, keyed: true);

  /// The `... on Thing085` view of this object; `null` for another type.
  Thing085? get asThing085 => on('Thing085', Thing085.new, keyed: true);

  /// The `... on Thing095` view of this object; `null` for another type.
  Thing095? get asThing095 => on('Thing095', Thing095.new, keyed: true);

  /// The `... on Thing105` view of this object; `null` for another type.
  Thing105? get asThing105 => on('Thing105', Thing105.new, keyed: true);

  /// The `... on Thing115` view of this object; `null` for another type.
  Thing115? get asThing115 => on('Thing115', Thing115.new, keyed: true);

  /// The `... on Thing125` view of this object; `null` for another type.
  Thing125? get asThing125 => on('Thing125', Thing125.new, keyed: true);

  /// The `... on Thing135` view of this object; `null` for another type.
  Thing135? get asThing135 => on('Thing135', Thing135.new, keyed: true);

  /// The `... on Thing145` view of this object; `null` for another type.
  Thing145? get asThing145 => on('Thing145', Thing145.new, keyed: true);

  /// Runs the branch for this object's `__typename`, [orElse] for a type
  /// without one. On a skeleton every branch runs (so all record their
  /// fields) and the first one's result is returned.
  T? when<T>({
    T Function(Thing005 thing005)? thing005,
    T Function(Thing015 thing015)? thing015,
    T Function(Thing025 thing025)? thing025,
    T Function(Thing035 thing035)? thing035,
    T Function(Thing045 thing045)? thing045,
    T Function(Thing055 thing055)? thing055,
    T Function(Thing065 thing065)? thing065,
    T Function(Thing075 thing075)? thing075,
    T Function(Thing085 thing085)? thing085,
    T Function(Thing095 thing095)? thing095,
    T Function(Thing105 thing105)? thing105,
    T Function(Thing115 thing115)? thing115,
    T Function(Thing125 thing125)? thing125,
    T Function(Thing135 thing135)? thing135,
    T Function(Thing145 thing145)? thing145,
    T Function()? orElse,
  }) => whenType({
    if (thing005 != null) 'Thing005': () => thing005(asThing005!),
    if (thing015 != null) 'Thing015': () => thing015(asThing015!),
    if (thing025 != null) 'Thing025': () => thing025(asThing025!),
    if (thing035 != null) 'Thing035': () => thing035(asThing035!),
    if (thing045 != null) 'Thing045': () => thing045(asThing045!),
    if (thing055 != null) 'Thing055': () => thing055(asThing055!),
    if (thing065 != null) 'Thing065': () => thing065(asThing065!),
    if (thing075 != null) 'Thing075': () => thing075(asThing075!),
    if (thing085 != null) 'Thing085': () => thing085(asThing085!),
    if (thing095 != null) 'Thing095': () => thing095(asThing095!),
    if (thing105 != null) 'Thing105': () => thing105(asThing105!),
    if (thing115 != null) 'Thing115': () => thing115(asThing115!),
    if (thing125 != null) 'Thing125': () => thing125(asThing125!),
    if (thing135 != null) 'Thing135': () => thing135(asThing135!),
    if (thing145 != null) 'Thing145': () => thing145(asThing145!),
  }, orElse: orElse);
}

class Group6 extends Accessor {
  Group6(super.recorder, super.selection, super.path);

  /// The `... on Thing006` view of this object; `null` for another type.
  Thing006? get asThing006 => on('Thing006', Thing006.new, keyed: true);

  /// The `... on Thing016` view of this object; `null` for another type.
  Thing016? get asThing016 => on('Thing016', Thing016.new, keyed: true);

  /// The `... on Thing026` view of this object; `null` for another type.
  Thing026? get asThing026 => on('Thing026', Thing026.new, keyed: true);

  /// The `... on Thing036` view of this object; `null` for another type.
  Thing036? get asThing036 => on('Thing036', Thing036.new, keyed: true);

  /// The `... on Thing046` view of this object; `null` for another type.
  Thing046? get asThing046 => on('Thing046', Thing046.new, keyed: true);

  /// The `... on Thing056` view of this object; `null` for another type.
  Thing056? get asThing056 => on('Thing056', Thing056.new, keyed: true);

  /// The `... on Thing066` view of this object; `null` for another type.
  Thing066? get asThing066 => on('Thing066', Thing066.new, keyed: true);

  /// The `... on Thing076` view of this object; `null` for another type.
  Thing076? get asThing076 => on('Thing076', Thing076.new, keyed: true);

  /// The `... on Thing086` view of this object; `null` for another type.
  Thing086? get asThing086 => on('Thing086', Thing086.new, keyed: true);

  /// The `... on Thing096` view of this object; `null` for another type.
  Thing096? get asThing096 => on('Thing096', Thing096.new, keyed: true);

  /// The `... on Thing106` view of this object; `null` for another type.
  Thing106? get asThing106 => on('Thing106', Thing106.new, keyed: true);

  /// The `... on Thing116` view of this object; `null` for another type.
  Thing116? get asThing116 => on('Thing116', Thing116.new, keyed: true);

  /// The `... on Thing126` view of this object; `null` for another type.
  Thing126? get asThing126 => on('Thing126', Thing126.new, keyed: true);

  /// The `... on Thing136` view of this object; `null` for another type.
  Thing136? get asThing136 => on('Thing136', Thing136.new, keyed: true);

  /// The `... on Thing146` view of this object; `null` for another type.
  Thing146? get asThing146 => on('Thing146', Thing146.new, keyed: true);

  /// Runs the branch for this object's `__typename`, [orElse] for a type
  /// without one. On a skeleton every branch runs (so all record their
  /// fields) and the first one's result is returned.
  T? when<T>({
    T Function(Thing006 thing006)? thing006,
    T Function(Thing016 thing016)? thing016,
    T Function(Thing026 thing026)? thing026,
    T Function(Thing036 thing036)? thing036,
    T Function(Thing046 thing046)? thing046,
    T Function(Thing056 thing056)? thing056,
    T Function(Thing066 thing066)? thing066,
    T Function(Thing076 thing076)? thing076,
    T Function(Thing086 thing086)? thing086,
    T Function(Thing096 thing096)? thing096,
    T Function(Thing106 thing106)? thing106,
    T Function(Thing116 thing116)? thing116,
    T Function(Thing126 thing126)? thing126,
    T Function(Thing136 thing136)? thing136,
    T Function(Thing146 thing146)? thing146,
    T Function()? orElse,
  }) => whenType({
    if (thing006 != null) 'Thing006': () => thing006(asThing006!),
    if (thing016 != null) 'Thing016': () => thing016(asThing016!),
    if (thing026 != null) 'Thing026': () => thing026(asThing026!),
    if (thing036 != null) 'Thing036': () => thing036(asThing036!),
    if (thing046 != null) 'Thing046': () => thing046(asThing046!),
    if (thing056 != null) 'Thing056': () => thing056(asThing056!),
    if (thing066 != null) 'Thing066': () => thing066(asThing066!),
    if (thing076 != null) 'Thing076': () => thing076(asThing076!),
    if (thing086 != null) 'Thing086': () => thing086(asThing086!),
    if (thing096 != null) 'Thing096': () => thing096(asThing096!),
    if (thing106 != null) 'Thing106': () => thing106(asThing106!),
    if (thing116 != null) 'Thing116': () => thing116(asThing116!),
    if (thing126 != null) 'Thing126': () => thing126(asThing126!),
    if (thing136 != null) 'Thing136': () => thing136(asThing136!),
    if (thing146 != null) 'Thing146': () => thing146(asThing146!),
  }, orElse: orElse);
}

class Group7 extends Accessor {
  Group7(super.recorder, super.selection, super.path);

  /// The `... on Thing007` view of this object; `null` for another type.
  Thing007? get asThing007 => on('Thing007', Thing007.new, keyed: true);

  /// The `... on Thing017` view of this object; `null` for another type.
  Thing017? get asThing017 => on('Thing017', Thing017.new, keyed: true);

  /// The `... on Thing027` view of this object; `null` for another type.
  Thing027? get asThing027 => on('Thing027', Thing027.new, keyed: true);

  /// The `... on Thing037` view of this object; `null` for another type.
  Thing037? get asThing037 => on('Thing037', Thing037.new, keyed: true);

  /// The `... on Thing047` view of this object; `null` for another type.
  Thing047? get asThing047 => on('Thing047', Thing047.new, keyed: true);

  /// The `... on Thing057` view of this object; `null` for another type.
  Thing057? get asThing057 => on('Thing057', Thing057.new, keyed: true);

  /// The `... on Thing067` view of this object; `null` for another type.
  Thing067? get asThing067 => on('Thing067', Thing067.new, keyed: true);

  /// The `... on Thing077` view of this object; `null` for another type.
  Thing077? get asThing077 => on('Thing077', Thing077.new, keyed: true);

  /// The `... on Thing087` view of this object; `null` for another type.
  Thing087? get asThing087 => on('Thing087', Thing087.new, keyed: true);

  /// The `... on Thing097` view of this object; `null` for another type.
  Thing097? get asThing097 => on('Thing097', Thing097.new, keyed: true);

  /// The `... on Thing107` view of this object; `null` for another type.
  Thing107? get asThing107 => on('Thing107', Thing107.new, keyed: true);

  /// The `... on Thing117` view of this object; `null` for another type.
  Thing117? get asThing117 => on('Thing117', Thing117.new, keyed: true);

  /// The `... on Thing127` view of this object; `null` for another type.
  Thing127? get asThing127 => on('Thing127', Thing127.new, keyed: true);

  /// The `... on Thing137` view of this object; `null` for another type.
  Thing137? get asThing137 => on('Thing137', Thing137.new, keyed: true);

  /// The `... on Thing147` view of this object; `null` for another type.
  Thing147? get asThing147 => on('Thing147', Thing147.new, keyed: true);

  /// Runs the branch for this object's `__typename`, [orElse] for a type
  /// without one. On a skeleton every branch runs (so all record their
  /// fields) and the first one's result is returned.
  T? when<T>({
    T Function(Thing007 thing007)? thing007,
    T Function(Thing017 thing017)? thing017,
    T Function(Thing027 thing027)? thing027,
    T Function(Thing037 thing037)? thing037,
    T Function(Thing047 thing047)? thing047,
    T Function(Thing057 thing057)? thing057,
    T Function(Thing067 thing067)? thing067,
    T Function(Thing077 thing077)? thing077,
    T Function(Thing087 thing087)? thing087,
    T Function(Thing097 thing097)? thing097,
    T Function(Thing107 thing107)? thing107,
    T Function(Thing117 thing117)? thing117,
    T Function(Thing127 thing127)? thing127,
    T Function(Thing137 thing137)? thing137,
    T Function(Thing147 thing147)? thing147,
    T Function()? orElse,
  }) => whenType({
    if (thing007 != null) 'Thing007': () => thing007(asThing007!),
    if (thing017 != null) 'Thing017': () => thing017(asThing017!),
    if (thing027 != null) 'Thing027': () => thing027(asThing027!),
    if (thing037 != null) 'Thing037': () => thing037(asThing037!),
    if (thing047 != null) 'Thing047': () => thing047(asThing047!),
    if (thing057 != null) 'Thing057': () => thing057(asThing057!),
    if (thing067 != null) 'Thing067': () => thing067(asThing067!),
    if (thing077 != null) 'Thing077': () => thing077(asThing077!),
    if (thing087 != null) 'Thing087': () => thing087(asThing087!),
    if (thing097 != null) 'Thing097': () => thing097(asThing097!),
    if (thing107 != null) 'Thing107': () => thing107(asThing107!),
    if (thing117 != null) 'Thing117': () => thing117(asThing117!),
    if (thing127 != null) 'Thing127': () => thing127(asThing127!),
    if (thing137 != null) 'Thing137': () => thing137(asThing137!),
    if (thing147 != null) 'Thing147': () => thing147(asThing147!),
  }, orElse: orElse);
}

class Group8 extends Accessor {
  Group8(super.recorder, super.selection, super.path);

  /// The `... on Thing008` view of this object; `null` for another type.
  Thing008? get asThing008 => on('Thing008', Thing008.new, keyed: true);

  /// The `... on Thing018` view of this object; `null` for another type.
  Thing018? get asThing018 => on('Thing018', Thing018.new, keyed: true);

  /// The `... on Thing028` view of this object; `null` for another type.
  Thing028? get asThing028 => on('Thing028', Thing028.new, keyed: true);

  /// The `... on Thing038` view of this object; `null` for another type.
  Thing038? get asThing038 => on('Thing038', Thing038.new, keyed: true);

  /// The `... on Thing048` view of this object; `null` for another type.
  Thing048? get asThing048 => on('Thing048', Thing048.new, keyed: true);

  /// The `... on Thing058` view of this object; `null` for another type.
  Thing058? get asThing058 => on('Thing058', Thing058.new, keyed: true);

  /// The `... on Thing068` view of this object; `null` for another type.
  Thing068? get asThing068 => on('Thing068', Thing068.new, keyed: true);

  /// The `... on Thing078` view of this object; `null` for another type.
  Thing078? get asThing078 => on('Thing078', Thing078.new, keyed: true);

  /// The `... on Thing088` view of this object; `null` for another type.
  Thing088? get asThing088 => on('Thing088', Thing088.new, keyed: true);

  /// The `... on Thing098` view of this object; `null` for another type.
  Thing098? get asThing098 => on('Thing098', Thing098.new, keyed: true);

  /// The `... on Thing108` view of this object; `null` for another type.
  Thing108? get asThing108 => on('Thing108', Thing108.new, keyed: true);

  /// The `... on Thing118` view of this object; `null` for another type.
  Thing118? get asThing118 => on('Thing118', Thing118.new, keyed: true);

  /// The `... on Thing128` view of this object; `null` for another type.
  Thing128? get asThing128 => on('Thing128', Thing128.new, keyed: true);

  /// The `... on Thing138` view of this object; `null` for another type.
  Thing138? get asThing138 => on('Thing138', Thing138.new, keyed: true);

  /// The `... on Thing148` view of this object; `null` for another type.
  Thing148? get asThing148 => on('Thing148', Thing148.new, keyed: true);

  /// Runs the branch for this object's `__typename`, [orElse] for a type
  /// without one. On a skeleton every branch runs (so all record their
  /// fields) and the first one's result is returned.
  T? when<T>({
    T Function(Thing008 thing008)? thing008,
    T Function(Thing018 thing018)? thing018,
    T Function(Thing028 thing028)? thing028,
    T Function(Thing038 thing038)? thing038,
    T Function(Thing048 thing048)? thing048,
    T Function(Thing058 thing058)? thing058,
    T Function(Thing068 thing068)? thing068,
    T Function(Thing078 thing078)? thing078,
    T Function(Thing088 thing088)? thing088,
    T Function(Thing098 thing098)? thing098,
    T Function(Thing108 thing108)? thing108,
    T Function(Thing118 thing118)? thing118,
    T Function(Thing128 thing128)? thing128,
    T Function(Thing138 thing138)? thing138,
    T Function(Thing148 thing148)? thing148,
    T Function()? orElse,
  }) => whenType({
    if (thing008 != null) 'Thing008': () => thing008(asThing008!),
    if (thing018 != null) 'Thing018': () => thing018(asThing018!),
    if (thing028 != null) 'Thing028': () => thing028(asThing028!),
    if (thing038 != null) 'Thing038': () => thing038(asThing038!),
    if (thing048 != null) 'Thing048': () => thing048(asThing048!),
    if (thing058 != null) 'Thing058': () => thing058(asThing058!),
    if (thing068 != null) 'Thing068': () => thing068(asThing068!),
    if (thing078 != null) 'Thing078': () => thing078(asThing078!),
    if (thing088 != null) 'Thing088': () => thing088(asThing088!),
    if (thing098 != null) 'Thing098': () => thing098(asThing098!),
    if (thing108 != null) 'Thing108': () => thing108(asThing108!),
    if (thing118 != null) 'Thing118': () => thing118(asThing118!),
    if (thing128 != null) 'Thing128': () => thing128(asThing128!),
    if (thing138 != null) 'Thing138': () => thing138(asThing138!),
    if (thing148 != null) 'Thing148': () => thing148(asThing148!),
  }, orElse: orElse);
}

class Group9 extends Accessor {
  Group9(super.recorder, super.selection, super.path);

  /// The `... on Thing009` view of this object; `null` for another type.
  Thing009? get asThing009 => on('Thing009', Thing009.new, keyed: true);

  /// The `... on Thing019` view of this object; `null` for another type.
  Thing019? get asThing019 => on('Thing019', Thing019.new, keyed: true);

  /// The `... on Thing029` view of this object; `null` for another type.
  Thing029? get asThing029 => on('Thing029', Thing029.new, keyed: true);

  /// The `... on Thing039` view of this object; `null` for another type.
  Thing039? get asThing039 => on('Thing039', Thing039.new, keyed: true);

  /// The `... on Thing049` view of this object; `null` for another type.
  Thing049? get asThing049 => on('Thing049', Thing049.new, keyed: true);

  /// The `... on Thing059` view of this object; `null` for another type.
  Thing059? get asThing059 => on('Thing059', Thing059.new, keyed: true);

  /// The `... on Thing069` view of this object; `null` for another type.
  Thing069? get asThing069 => on('Thing069', Thing069.new, keyed: true);

  /// The `... on Thing079` view of this object; `null` for another type.
  Thing079? get asThing079 => on('Thing079', Thing079.new, keyed: true);

  /// The `... on Thing089` view of this object; `null` for another type.
  Thing089? get asThing089 => on('Thing089', Thing089.new, keyed: true);

  /// The `... on Thing099` view of this object; `null` for another type.
  Thing099? get asThing099 => on('Thing099', Thing099.new, keyed: true);

  /// The `... on Thing109` view of this object; `null` for another type.
  Thing109? get asThing109 => on('Thing109', Thing109.new, keyed: true);

  /// The `... on Thing119` view of this object; `null` for another type.
  Thing119? get asThing119 => on('Thing119', Thing119.new, keyed: true);

  /// The `... on Thing129` view of this object; `null` for another type.
  Thing129? get asThing129 => on('Thing129', Thing129.new, keyed: true);

  /// The `... on Thing139` view of this object; `null` for another type.
  Thing139? get asThing139 => on('Thing139', Thing139.new, keyed: true);

  /// The `... on Thing149` view of this object; `null` for another type.
  Thing149? get asThing149 => on('Thing149', Thing149.new, keyed: true);

  /// Runs the branch for this object's `__typename`, [orElse] for a type
  /// without one. On a skeleton every branch runs (so all record their
  /// fields) and the first one's result is returned.
  T? when<T>({
    T Function(Thing009 thing009)? thing009,
    T Function(Thing019 thing019)? thing019,
    T Function(Thing029 thing029)? thing029,
    T Function(Thing039 thing039)? thing039,
    T Function(Thing049 thing049)? thing049,
    T Function(Thing059 thing059)? thing059,
    T Function(Thing069 thing069)? thing069,
    T Function(Thing079 thing079)? thing079,
    T Function(Thing089 thing089)? thing089,
    T Function(Thing099 thing099)? thing099,
    T Function(Thing109 thing109)? thing109,
    T Function(Thing119 thing119)? thing119,
    T Function(Thing129 thing129)? thing129,
    T Function(Thing139 thing139)? thing139,
    T Function(Thing149 thing149)? thing149,
    T Function()? orElse,
  }) => whenType({
    if (thing009 != null) 'Thing009': () => thing009(asThing009!),
    if (thing019 != null) 'Thing019': () => thing019(asThing019!),
    if (thing029 != null) 'Thing029': () => thing029(asThing029!),
    if (thing039 != null) 'Thing039': () => thing039(asThing039!),
    if (thing049 != null) 'Thing049': () => thing049(asThing049!),
    if (thing059 != null) 'Thing059': () => thing059(asThing059!),
    if (thing069 != null) 'Thing069': () => thing069(asThing069!),
    if (thing079 != null) 'Thing079': () => thing079(asThing079!),
    if (thing089 != null) 'Thing089': () => thing089(asThing089!),
    if (thing099 != null) 'Thing099': () => thing099(asThing099!),
    if (thing109 != null) 'Thing109': () => thing109(asThing109!),
    if (thing119 != null) 'Thing119': () => thing119(asThing119!),
    if (thing129 != null) 'Thing129': () => thing129(asThing129!),
    if (thing139 != null) 'Thing139': () => thing139(asThing139!),
    if (thing149 != null) 'Thing149': () => thing149(asThing149!),
  }, orElse: orElse);
}

enum State00 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State00(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State00 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State00',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State01 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State01(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State01 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State01',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State02 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State02(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State02 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State02',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State03 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State03(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State03 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State03',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State04 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State04(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State04 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State04',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State05 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State05(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State05 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State05',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State06 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State06(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State06 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State06',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State07 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State07(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State07 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State07',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State08 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State08(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State08 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State08',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State09 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State09(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State09 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State09',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State10 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State10(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State10 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State10',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State11 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State11(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State11 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State11',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State12 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State12(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State12 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State12',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State13 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State13(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State13 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State13',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

enum State14 {
  draft('DRAFT'),
  active('ACTIVE'),
  archived('ARCHIVED'),
  deleted('DELETED'),

  /// A wire value this client does not know (forward compatibility).
  unknown('');

  const State14(this.graphqlName);

  /// The value as spelled in the GraphQL schema.
  final String graphqlName;

  /// Maps a wire value to its constant, [unknown] when unmatched.
  static State14 fromGraphQL(String value) =>
      values.firstWhere((v) => v.graphqlName == value, orElse: () => unknown);

  /// The wire value to send as an argument; [unknown] has none.
  String toGraphQL() {
    if (this == unknown) {
      throw ArgumentError.value(
        this,
        'State14',
        'unknown cannot be sent as an argument',
      );
    }
    return graphqlName;
  }
}

class Filter0 {
  const Filter0({this.text, this.minRank, this.active});

  final String? text;
  final int? minRank;
  final bool? active;

  Map<String, Object?> toJson() => {
    if (text != null) 'text': text,
    if (minRank != null) 'minRank': minRank,
    if (active != null) 'active': active,
  };
}

class Filter1 {
  const Filter1({this.text, this.minRank, this.active});

  final String? text;
  final int? minRank;
  final bool? active;

  Map<String, Object?> toJson() => {
    if (text != null) 'text': text,
    if (minRank != null) 'minRank': minRank,
    if (active != null) 'active': active,
  };
}

class Filter2 {
  const Filter2({this.text, this.minRank, this.active});

  final String? text;
  final int? minRank;
  final bool? active;

  Map<String, Object?> toJson() => {
    if (text != null) 'text': text,
    if (minRank != null) 'minRank': minRank,
    if (active != null) 'active': active,
  };
}

class Filter3 {
  const Filter3({this.text, this.minRank, this.active});

  final String? text;
  final int? minRank;
  final bool? active;

  Map<String, Object?> toJson() => {
    if (text != null) 'text': text,
    if (minRank != null) 'minRank': minRank,
    if (active != null) 'active': active,
  };
}

class Filter4 {
  const Filter4({this.text, this.minRank, this.active});

  final String? text;
  final int? minRank;
  final bool? active;

  Map<String, Object?> toJson() => {
    if (text != null) 'text': text,
    if (minRank != null) 'minRank': minRank,
    if (active != null) 'active': active,
  };
}
