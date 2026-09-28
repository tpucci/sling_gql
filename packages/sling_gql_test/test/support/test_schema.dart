import 'package:sling_gql/sling_gql.dart';

// Hand-written "generated" code for the tiny schema shared by the tests
// (same as the runtime package's `test/support/test_schema.dart`):
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
  List<User> friends({int? limit}) => list(
    'friends',
    User.new,
    args: {'limit': Arg('Int', limit)},
    keyed: true,
  )!;
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

const slingSchema = SlingSchema<Query, Mutation>(
  query: Query.root,
  mutation: Mutation.root,
);

Map<String, Object?> user(String id, String name, {int? age}) => {
  '__typename': 'User',
  'id': id,
  'name': name,
  'age': age,
  'friends': (Map<String, Object?> args) {
    final all = [user('a', 'Bob'), user('b', 'Cy')];
    final limit = args['limit'] as int?;
    return limit == null ? all : all.take(limit).toList();
  },
};
