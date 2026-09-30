import 'package:sling_gql/sling_gql.dart';

// Hand-written "generated" code for the tiny schema of these tests (the same
// as sling_gql's own runtime tests):
//
// type Query        { me: User!  user(id: ID!): User }
// type User         { id: ID!  name: String!  age: Int }
// type Mutation     { rename(id: ID!, name: String!): User! }
// type Subscription { userRenamed(id: ID!): User! }

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
  int? get age => scalar<int>('age');
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

class Subscription extends Accessor {
  Subscription(super.recorder, super.selection, super.path);
  Subscription.root(Recorder r) : super(r, r.root, const []);

  User? userRenamed({required String id}) => object(
    'userRenamed',
    User.new,
    args: {'id': Arg('ID!', id)},
    keyed: true,
  );
}

const slingSchema = SlingSchema<Query, Mutation>(
  query: Query.root,
  mutation: Mutation.root,
  subscription: Subscription.root,
);

final testEndpoint = Uri.parse('http://test/graphql');

Map<String, Object?> ada() => {
  '__typename': 'User',
  'id': '1',
  'name': 'Ada',
  'age': 36,
};
