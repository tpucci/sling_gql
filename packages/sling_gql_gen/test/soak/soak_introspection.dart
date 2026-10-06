/// A large synthetic schema, as an introspection document, for the soak
/// tests: [soakThings] keyed object types (`Thing000`…), each with scalars,
/// an enum, a list of strings, an inline object, a keyed reference, a keyed
/// list with arguments and an interface; unions over them; one lookup and one
/// paged list root field per type, one mutation per type and a subscription.
///
/// `test/soak_test.dart` feeds it through the generator;
/// `tool/generate_soak_schema.dart` writes the result to
/// `packages/sling_gql_sqflite/test/soak/soak_schema.dart`, which the
/// runtime soak test (`sling_gql_sqflite/test/soak_test.dart`) runs on.
library;

import 'dart:io';

import 'package:sling_gql_gen/sling_gql_gen.dart';

/// Keyed object types.
const soakThings = 150;

/// Enum types (`State00`…), inline object types (`Detail00`…).
const soakEnums = 15;

/// Union types (`Group0`…), each over the things whose index ≡ its own
/// modulo [soakUnions].
const soakUnions = 10;

/// Input object types (`Filter0`…).
const soakInputs = 5;

String thingName(int k) => 'Thing${k.toString().padLeft(3, '0')}';
String _two(int k) => k.toString().padLeft(2, '0');

Map<String, Object?> _named(String kind, String name) => {
  'kind': kind,
  'name': name,
  'ofType': null,
};
Map<String, Object?> _nonNull(Map<String, Object?> inner) => {
  'kind': 'NON_NULL',
  'name': null,
  'ofType': inner,
};
Map<String, Object?> _list(Map<String, Object?> inner) => {
  'kind': 'LIST',
  'name': null,
  'ofType': inner,
};
Map<String, Object?> _scalar(String name) => _named('SCALAR', name);
Map<String, Object?> _object(String name) => _named('OBJECT', name);

Map<String, Object?> _field(
  String name,
  Map<String, Object?> type, [
  List<Map<String, Object?>> args = const [],
]) => {
  'name': name,
  'description': null,
  'args': args,
  'type': type,
  'isDeprecated': false,
  'deprecationReason': null,
};

Map<String, Object?> _arg(
  String name,
  Map<String, Object?> type, [
  Object? defaultValue,
]) => {
  'name': name,
  'description': null,
  'type': type,
  'defaultValue': defaultValue,
};

Map<String, Object?> _type(
  String kind,
  String name, {
  List<Map<String, Object?>>? fields,
  List<Map<String, Object?>>? inputFields,
  List<String>? enumValues,
  List<String>? interfaces,
  List<String>? possibleTypes,
}) => {
  'kind': kind,
  'name': name,
  'description': null,
  'fields': fields,
  'inputFields': inputFields,
  'interfaces': interfaces?.map((n) => _named('INTERFACE', n)).toList(),
  'enumValues': enumValues
      ?.map(
        (v) => {
          'name': v,
          'description': null,
          'isDeprecated': false,
          'deprecationReason': null,
        },
      )
      .toList(),
  'possibleTypes': possibleTypes?.map(_object).toList(),
};

final _id = _nonNull(_scalar('ID'));

/// The introspection document (`{"__schema": {...}}`).
Map<String, Object?> soakIntrospection() {
  final things = [for (var k = 0; k < soakThings; k++) thingName(k)];
  return {
    '__schema': {
      'queryType': {'name': 'Query'},
      'mutationType': {'name': 'Mutation'},
      'subscriptionType': {'name': 'Subscription'},
      'types': [
        for (final s in ['ID', 'String', 'Int', 'Float', 'Boolean'])
          _type('SCALAR', s),
        _type(
          'OBJECT',
          'Query',
          fields: [
            for (var k = 0; k < soakThings; k++) ...[
              _field('thing${_three(k)}', _object(things[k]), [
                _arg('id', _id),
              ]),
              _field(
                'things${_three(k)}',
                _nonNull(_list(_nonNull(_object(things[k])))),
                [
                  _arg('page', _nonNull(_scalar('Int'))),
                  _arg(
                    'filter',
                    _named('INPUT_OBJECT', 'Filter${k % soakInputs}'),
                  ),
                ],
              ),
            ],
            _field('node', _named('INTERFACE', 'Node'), [_arg('id', _id)]),
            for (var u = 0; u < soakUnions; u++)
              _field(
                'group$u',
                _nonNull(_list(_nonNull(_named('UNION', 'Group$u')))),
                [_arg('text', _nonNull(_scalar('String')))],
              ),
          ],
        ),
        _type(
          'OBJECT',
          'Mutation',
          fields: [
            for (var k = 0; k < soakThings; k++)
              _field('rename${_three(k)}', _nonNull(_object(things[k])), [
                _arg('id', _id),
                _arg('name', _nonNull(_scalar('String'))),
              ]),
          ],
        ),
        _type(
          'OBJECT',
          'Subscription',
          fields: [
            _field('nodeChanged', _nonNull(_named('INTERFACE', 'Node'))),
          ],
        ),
        _type(
          'INTERFACE',
          'Node',
          fields: [_field('id', _id), _field('name', _scalar('String'))],
          possibleTypes: things,
        ),
        for (var k = 0; k < soakThings; k++)
          _type(
            'OBJECT',
            things[k],
            interfaces: const ['Node'],
            fields: [
              _field('id', _id),
              _field('name', _scalar('String')),
              _field('rank', _scalar('Int')),
              _field('score', _scalar('Float')),
              _field('active', _scalar('Boolean')),
              _field(
                'state',
                _nonNull(_named('ENUM', 'State${_two(k % soakEnums)}')),
              ),
              _field('tags', _nonNull(_list(_nonNull(_scalar('String'))))),
              _field('detail', _object('Detail${_two(k % soakEnums)}')),
              _field('next', _object(things[(k + 1) % soakThings])),
              _field(
                'related',
                _nonNull(
                  _list(_nonNull(_object(things[(k + 7) % soakThings]))),
                ),
                [_arg('first', _scalar('Int'), '3')],
              ),
            ],
          ),
        for (var e = 0; e < soakEnums; e++) ...[
          _type(
            'ENUM',
            'State${_two(e)}',
            enumValues: const ['DRAFT', 'ACTIVE', 'ARCHIVED', 'DELETED'],
          ),
          _type(
            'OBJECT',
            'Detail${_two(e)}',
            fields: [
              _field('label', _scalar('String')),
              _field('size', _scalar('Int')),
            ],
          ),
        ],
        for (var u = 0; u < soakUnions; u++)
          _type(
            'UNION',
            'Group$u',
            possibleTypes: [
              for (var k = u; k < soakThings; k += soakUnions) things[k],
            ],
          ),
        for (var i = 0; i < soakInputs; i++)
          _type(
            'INPUT_OBJECT',
            'Filter$i',
            inputFields: [
              _arg('text', _scalar('String')),
              _arg('minRank', _scalar('Int')),
              _arg('active', _scalar('Boolean')),
            ],
          ),
      ],
    },
  };
}

String _three(int k) => k.toString().padLeft(3, '0');

/// Where the generated soak schema is committed, relative to this package.
const soakSchemaPath = '../sling_gql_sqflite/test/soak/soak_schema.dart';

/// The generator's output for [soakIntrospection], `dart format`ted like
/// the CLI leaves it.
Future<String> generateSoakSchema() async {
  final code = generate(IntrospectionSchema.fromJson(soakIntrospection()));
  final dir = await Directory.systemTemp.createTemp('sling_soak_');
  try {
    final file = File('${dir.path}/soak_schema.dart');
    await file.writeAsString(code);
    final result = await Process.run('dart', ['format', file.path]);
    if (result.exitCode != 0) {
      throw StateError('dart format failed: ${result.stderr}');
    }
    return await file.readAsString();
  } finally {
    await dir.delete(recursive: true);
  }
}
