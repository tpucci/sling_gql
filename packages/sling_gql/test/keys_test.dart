import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/internal.dart';
import 'package:sling_gql/sling_gql.dart';

/// The printed form of a 64-bit value, as [Selection.fnv1a64] prints it.
String printed(String hex) {
  final v = BigInt.parse(hex, radix: 16);
  final hi = (v >> 32).toInt(), lo = (v & BigInt.from(0xffffffff)).toInt();
  return hi.toRadixString(36) + lo.toRadixString(36).padLeft(7, '0');
}

void main() {
  group('64-bit FNV-1a aliases (#33)', () {
    test('matches the reference vectors', () {
      expect(Selection.fnv1a64(''), printed('cbf29ce484222325'));
      expect(Selection.fnv1a64('a'), printed('af63dc4c8601ec8c'));
      expect(Selection.fnv1a64('foobar'), printed('85944171f73967e8'));
      // Non-ASCII: hashed per UTF-16 code unit.
      expect(Selection.fnv1a64('é'), isNot(Selection.fnv1a64('e')));
    });

    test('aliases carry the 64-bit hash of the canonical args', () {
      final alias = Selection.root('query')
          .child('launch', {'id': Arg('ID!', 'launch-181')})
          .alias;
      expect(alias, 'launch_${Selection.fnv1a64('{"id":"launch-181"}')}');
    });

    test('10k by-id aliases are distinct', () {
      final root = Selection.root('query');
      final aliases = {
        for (var i = 0; i < 10000; i++)
          root.child('launch', {'id': Arg('ID!', 'launch-$i')}).alias,
      };
      expect(aliases, hasLength(10000));
    });
  });

  group('dependency keys with dotted ids (#26)', () {
    test('an id containing ".field" does not share keys with another', () {
      final cache = NormalizedCache();
      final a = cache.writeResponse('query', Selection.root('query'), {
        'a': {'__typename': 'User', 'id': 'x', 'name': 'Ada'},
      });
      final b = cache.writeResponse('query', Selection.root('query'), {
        'b': {'__typename': 'User', 'id': 'x.name', 'name': 'Bob'},
      });
      expect(a, contains(depKey('User:x', 'name')));
      expect(b, contains(depKey('User:x.name', 'name')));
      expect(a.intersection(b.difference({'ROOT_QUERY.b'})), isEmpty);

      final deps = <String>{};
      cache.read('query', ['a', 'name'], deps: deps);
      final next = cache.writeResponse('query', Selection.root('query'), {
        'b': {'__typename': 'User', 'id': 'x.name', 'name': 'Grace'},
      });
      expect(next.intersection(deps), isEmpty);
    });
  });
}
