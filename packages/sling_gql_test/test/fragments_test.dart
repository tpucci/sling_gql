import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';
import 'package:sling_gql_test/sling_gql_test.dart';

// union Hit = Person | Place
// type Query { hits: [Hit!]! }

class Q extends Accessor {
  Q(super.recorder, super.selection, super.path);
  Q.root(Recorder r) : super(r, r.root, const []);

  List<Hit>? get hits => list('hits', Hit.new);
}

class Hit extends Accessor {
  Hit(super.recorder, super.selection, super.path);

  Person? get asPerson => on('Person', Person.new, keyed: true);
  Place? get asPlace => on('Place', Place.new);

  T? when<T>({
    T Function(Person person)? person,
    T Function(Place place)? place,
    T Function()? orElse,
  }) => whenType({
    if (person != null) 'Person': () => person(asPerson!),
    if (place != null) 'Place': () => place(asPlace!),
  }, orElse: orElse);
}

class Person extends Accessor {
  Person(super.recorder, super.selection, super.path);
  String? get name => scalar<String>('name');
}

class Place extends Accessor {
  Place(super.recorder, super.selection, super.path);
  String? get city => scalar<String>('city');
}

void main() {
  test('MockGraphQLServer resolves inline fragments by __typename', () async {
    final server = MockGraphQLServer(
      query: {
        'hits': [
          {'__typename': 'Person', 'id': 'p1', 'name': 'Ada', 'age': 36},
          {'__typename': 'Place', 'city': 'Turin', 'country': 'IT'},
        ],
      },
    );
    final client = server.client(Q.root);

    final out = await client.resolve(
      (q) => q.hits!
          .map((h) => h.when(person: (p) => p.name, place: (p) => p.city))
          .toList(),
    );
    expect(out, ['Ada', 'Turin']);
    expect(server.requests, hasLength(1));
    expect(server.lastRequest.selects('hits.on Person.name'), isTrue);
    expect(server.lastRequest.selects('hits.on Place.city'), isTrue);
    expect(server.lastRequest.selects('hits.on Place.name'), isFalse);
    expect(client.cache.entity('Person:p1'), {
      '__typename': 'Person',
      'id': 'p1',
      'name': 'Ada',
    });
  });
}
