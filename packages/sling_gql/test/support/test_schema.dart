import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sling_gql/sling_gql.dart';

// Hand-written "generated" code for the tiny schema shared by the runtime
// tests (the reference copy lives at the top of `core_test.dart`):
//
// type Query    { me: User!  user(id: ID!): User }
// type User     { id: ID!  name: String!  age: Int  friends(limit: Int): [User!]! }
// type Mutation { rename(id: ID!, name: String!): User! }

class Query extends Accessor {
  Query(super.recorder, super.selection, super.path);
  Query.root(Recorder r) : super(r, r.root, const []);

  User get me => object('me', User.new, keyed: true)!;
  User? user({required String id}) =>
      object('user', User.new, args: {'id': Arg('ID!', id)}, lookup: 'User');
}

class User extends Accessor {
  User(super.recorder, super.selection, super.path);

  String? get id => scalar<String>('id');
  String? get name => scalar<String>('name');
  set name(String? v) => write('name', v);
  int? get age => scalar<int>('age');
  set age(int? v) => write('age', v);
  List<User> friends({int? limit}) =>
      list('friends', User.new, args: {'limit': Arg('Int', limit)}, keyed: true)!;
}

class Mutation extends Accessor {
  Mutation(super.recorder, super.selection, super.path);
  Mutation.root(Recorder r) : super(r, r.root, const []);

  User? rename({required String id, required String name}) => object(
        'rename',
        User.new,
        args: {'id': Arg('ID!', id), 'name': Arg('String!', name)},
        keyed: true,
      );
}

/// What the generator emits so apps never name roots by hand.
const slingSchema = SlingSchema<Query, Mutation>(query: Query.root, mutation: Mutation.root);

/// `me` with two friends, as the mock endpoint would answer.
Map<String, Object?> meWithFriends() => {
      'me': {
        '__typename': 'User',
        'id': '1',
        'name': 'Ada',
        'age': 36,
        'friends': [
          {'__typename': 'User', 'id': 'a', 'name': 'Bob'},
          {'__typename': 'User', 'id': 'b', 'name': 'Cy'},
        ],
      },
    };

/// A JSON-over-HTTP mock that answers every operation with [handler]'s data.
http.Client mockGraphQL(
  Map<String, Object?> Function(String query, Map<String, Object?> vars) handler,
) =>
    MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, Object?>;
      final data = handler(
        body['query'] as String,
        (body['variables'] as Map).cast<String, Object?>(),
      );
      return http.Response(jsonEncode({'data': data}), 200);
    });

final testEndpoint = Uri.parse('http://test/graphql');
