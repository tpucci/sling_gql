import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

void main() {
  test('a write notifies exactly the scopes whose deps intersect the touched keys',
      () async {
    final client = SlingClient<Query>(
      endpoint: testEndpoint,
      rootFactory: Query.root,
      httpClient: mockGraphQL((q, v) => meWithFriends()),
    );
    await client.resolve((q) => (q.me.age, q.me.friends().map((f) => f.name).toList()));

    // Many scopes with large, mostly irrelevant dep sets: `_notify` must still
    // find the one intersecting key.
    final rebuilds = <String, int>{};
    QueryScope<Query> scope(String label, void Function(Query q) body) {
      final s = client.createScope(onChanged: () => rebuilds.update(label, (n) => n + 1, ifAbsent: () => 1));
      s.run((q) {
        body(q);
        for (var i = 0; i < 500; i++) {
          s.deps.add('Padding:$i.field'); // unrelated deps, never touched
        }
      });
      return s;
    }

    scope('friendNames', (q) => q.me.friends().map((f) => f.name).toList());
    scope('bobName', (q) => q.user(id: 'a')?.name);
    scope('cyName', (q) => q.user(id: 'b')?.name);
    scope('age', (q) => q.me.age);
    final writer = scope('writer', (q) => q.me.friends()[1].age);

    // A write touching several keys at once, only some of which are read.
    final touched = <String>{
      ...client.cache.write('query', [const Ref('User:a'), 'name'], 'Robert'),
      'Nobody:0.name',
      'Nobody:1.name',
    };
    expect(touched, containsAll(['User:a.name']));
    writer.onWrite(CacheWrite('query', [const Ref('User:a'), 'name'], 'Bob', touched));

    expect(rebuilds, {'friendNames': 1, 'bobName': 1},
        reason: 'only readers of User:a.name; disjoint scopes stay quiet');

    // A write touching only keys nobody reads notifies nobody.
    writer.onWrite(CacheWrite('query', [const Ref('User:z'), 'name'], missing, {'User:z.name'}));
    expect(rebuilds, {'friendNames': 1, 'bobName': 1});

    // A disposed scope is no longer notified.
    writer.dispose();
    rebuilds.clear();
    client.cache.write('query', [const Ref('User:b'), 'age'], 12);
    scope('probe', (q) => q.me.name)
        .onWrite(CacheWrite('query', [const Ref('User:b'), 'age'], missing, {'User:b.age'}));
    expect(rebuilds, isEmpty, reason: 'writer read User:b.age but was disposed');
  });
}
