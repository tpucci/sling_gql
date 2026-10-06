import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

// Builds a selection tree with the runtime's `@internal` printer: the parser
// is checked against exactly what the client sends.
// ignore_for_file: invalid_use_of_internal_member

void main() {
  test('parses what the runtime prints: aliases, variables, nesting', () {
    final root = Selection.root('query');
    root.objectChild('me', const {}, 'id').child('name');
    root
        .objectChild('user', {'id': Arg('ID!', '1')}, 'id')
        .objectChild('friends', {'limit': Arg('Int', 2)}, 'id')
        .child('age');
    final op = PrintedOperation.from(root);

    final parsed = parseOperation(op.document, op.variables);
    expect(parsed.type, 'query');
    expect(parsed.name, isNull);
    expect(parsed.fields.map((f) => f.name), ['me', 'user']);

    final me = parsed.fields[0];
    expect(me.alias, 'me');
    expect(me.args, isEmpty);
    expect(me.selection.map((f) => f.name), ['__typename', 'id', 'name']);

    final user = parsed.fields[1];
    expect(user.alias, isNot('user'));
    expect(user.alias, startsWith('user_'));
    expect(user.args, {'id': '1'});
    final friends = user.selection.singleWhere((f) => f.name == 'friends');
    expect(friends.args, {'limit': 2});
    expect(friends.selection.map((f) => f.name), ['__typename', 'id', 'age']);
  });

  test('parses literals, named operations and shorthand queries', () {
    final parsed = parseOperation('''
      # a comment
      mutation Rename {
        rename(id: "1", name: "A \\"quoted\\" name", tags: [A, B], meta: {n: 1.5, ok: true, none: null}) {
          id
        }
      }
    ''');
    expect(parsed.type, 'mutation');
    expect(parsed.name, 'Rename');
    final rename = parsed.fields.single;
    expect(rename.args, {
      'id': '1',
      'name': 'A "quoted" name',
      'tags': ['A', 'B'],
      'meta': {'n': 1.5, 'ok': true, 'none': null},
    });
    expect(rename.selection.single.name, 'id');

    expect(parseOperation('{ me { name } }').fields.single.name, 'me');
  });

  test('parses inline fragments', () {
    final parsed = parseOperation('''
      query {
        search {
          __typename
          ... on Launch { id name }
          ... on Rocket { id }
        }
      }
    ''');
    final search = parsed.fields.single;
    expect(search.selection.map((f) => f.isFragment), [false, true, true]);
    final launch = search.selection[1];
    expect(launch.typeCondition, 'Launch');
    expect(launch.selection.map((f) => f.name), ['id', 'name']);
  });

  test('rejects what it does not support, loudly', () {
    expect(
      () => parseOperation('query { ...Frag }'),
      throwsA(isA<GraphQLSyntaxError>()),
    );
    expect(
      () => parseOperation('query { me @include(if: true) { id } }'),
      throwsA(isA<GraphQLSyntaxError>()),
    );
    expect(
      () => parseOperation(r'query ($id: ID!) { user(id: $id) { id } }'),
      throwsA(
        isA<GraphQLSyntaxError>().having(
          (e) => e.message,
          'message',
          contains(r'$id'),
        ),
      ),
      reason: 'variable not provided',
    );
    expect(
      () => parseOperation('query { me { id }'),
      throwsA(isA<GraphQLSyntaxError>()),
    );
  });
}
