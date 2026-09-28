# sling_gql_gen example

Given this schema (`schema.graphql`):

```graphql
type Query {
  me: User!
  user(id: ID!): User
}

type User {
  id: ID!
  name: String!
  age: Int
  friends(limit: Int): [User!]!
}

type Mutation {
  rename(id: ID!, name: String!): User!
}
```

fetch its introspection and generate the accessors:

```sh
flutter pub add sling_gql
flutter pub add --dev sling_gql_gen

# Either straight from the endpoint (add -H "Authorization: Bearer …" if needed)…
dart run sling_gql_gen \
  --endpoint https://example.com/graphql \
  --out lib/generated/schema.dart

# …or from an introspection JSON you already have on disk.
dart run sling_gql_gen \
  --schema graphql/schema.json \
  --out lib/generated/schema.dart \
  --scalar DateTime=DateTime
```

`lib/generated/schema.dart` then contains (trimmed):

```dart
import 'package:sling_gql/sling_gql.dart';

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

extension SlingCacheAccess on CacheScope<Query> {
  User? user(String id) => entity('User', id, User.new);
}

extension SlingMutations on SlingClient<Query> {
  Future<T> mutate<T>(T Function(Mutation m) body, {...}) =>
      mutateWith(Mutation.root, body, ...);
}

const slingSchema = SlingSchema<Query, Mutation>(
  query: Query.root,
  mutation: Mutation.root,
);
```

- `keyed: true` marks types with an `id` so the runtime normalizes them into
  `User:<id>` entities; `lookup: 'User'` lets `user(id:)` be served from the
  cache when the entity is already there.
- Every getter is nullable: a value can always be absent from the cache.
- Setters exist on scalar fields for optimistic writes (never on the key
  field).

Use it from a widget:

```dart
QueryBuilder<Query>(
  builder: (context, query, state) {
    final me = query.me;
    return Text(me.name ?? '…');
  },
)
```

The [`sling_gql` example](https://pub.dev/packages/sling_gql/example) is a
full runnable app for this same schema.
