// Read-path allocation work (#17, #18): alias memo on the selection tree,
// allocation-free `readField`, interned dependency keys, memoized scalar
// conversions. Behaviour must be identical to the unoptimized path.
import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/internal.dart';
import 'package:sling_gql/sling_gql.dart';

class _Recorder implements Recorder {
  _Recorder(this.cache);

  @override
  final Cache cache;
  @override
  String get operation => 'query';
  @override
  final Selection root = Selection.root('query');
  @override
  final Set<String> deps = {};
  final List<Selection> misses = [];
  @override
  void onMiss(Selection leaf) => misses.add(leaf);
  @override
  void onWrite(CacheWrite write) {}
}

class _Root extends Accessor {
  _Root(Recorder r) : super(r, r.root, const []);

  DateTime? at(String field, DateTime Function(String) parse) =>
      scalarAs<DateTime, String>(field, parse);
}

void main() {
  group('Selection.child (#18)', () {
    test('equal args in a fresh map find the same node', () {
      final root = Selection.root('query');
      final a = root.child('launches', {'first': const Arg('Int', 10)});
      final b = root.child('launches', {'first': const Arg('Int', 10)});
      expect(identical(a, b), isTrue);
      expect(root.children, hasLength(1));
    });

    test('alias is unchanged by the memo', () {
      final root = Selection.root('query');
      final a = root.child('launches', {
        'first': const Arg('Int', 10),
        'after': const Arg('String', 'c'),
      });
      // Same as a tree that never saw the field before, arguments reordered.
      final fresh = Selection.root('query').child('launches', {
        'after': const Arg('String', 'c'),
        'first': const Arg('Int', 10),
      });
      expect(a.alias, fresh.alias);
      expect(a.alias, startsWith('launches_'));
    });

    test('different values, null args, int vs double', () {
      final root = Selection.root('query');
      final ten = root.child('f', {'n': const Arg('Int', 10)});
      expect(root.child('f', {'n': const Arg('Int', 11)}), isNot(same(ten)));
      // A null argument is the same as an absent one.
      final plain = root.child('f');
      expect(root.child('f', {'n': const Arg('Int', null)}), same(plain));
      expect(
        root.child('f', {
          'n': const Arg('Int', 10),
          'm': const Arg('Int', null),
        }),
        same(ten),
      );
      // `10 == 10.0` in Dart, but they print (and alias) differently.
      final dbl = root.child('f', {'n': const Arg('Float', 10.0)});
      expect(dbl, isNot(same(ten)));
      expect(dbl.alias, isNot(ten.alias));
    });

    test('input objects compare deeply', () {
      final root = Selection.root('query');
      Map<String, Arg> filter(List<String> s) => {
        'filter': Arg('F', {
          'status': s,
          'range': {'from': 1, 'to': 2},
        }),
      };
      final a = root.child('launches', filter(['A', 'B']));
      expect(root.child('launches', filter(['A', 'B'])), same(a));
      expect(root.child('launches', filter(['B', 'A'])), isNot(same(a)));
    });
  });

  group('NormalizedCache.readField (#17)', () {
    late NormalizedCache cache;
    setUp(() {
      cache = NormalizedCache();
      cache.writeResponse('query', {
        'me': {'__typename': 'User', 'id': '1', 'name': 'Ada', 'age': null},
        'page': {
          '__typename': 'Page',
          'items': [
            {'__typename': 'User', 'id': '2', 'name': 'Bob'},
          ],
        },
      });
    });

    test('same result and deps as read of the joined path', () {
      for (final (path, field) in <(List<Object>, String)>[
        (['me'], 'name'),
        (['me'], 'age'),
        (['me'], 'nope'),
        (['page', 'items', 0], 'name'),
        (['page', 'items', 3], 'name'),
        (['page'], 'items'),
        (['me'], '__typename'),
        ([const Ref('User:2')], 'name'),
        ([const Ref('User:9')], 'name'),
        ([], 'me'),
      ]) {
        final d1 = <String>{};
        final d2 = <String>{};
        expect(
          cache.readField('query', path, field, deps: d1),
          cache.read('query', [...path, field], deps: d2),
          reason: '$path.$field',
        );
        expect(d1, d2, reason: '$path.$field');
      }
      expect(cache.readField('mutation', const [], 'x'), missing);
    });

    test('dependency keys are interned', () {
      final d1 = <String>{};
      final d2 = <String>{};
      cache.readField('query', const ['me'], 'name', deps: d1);
      cache.readField('query', const ['me'], 'name', deps: d2);
      expect(d1, {'ROOT_QUERY.me', 'User:1.name'});
      for (final k in d1) {
        expect(identical(k, d2.lookup(k)), isTrue);
      }
    });

    test('evict and clear drop interned keys with the data', () {
      cache.readField('query', const ['me'], 'name', deps: {});
      cache.evict('User:1');
      final deps = <String>{};
      expect(
        cache.readField('query', const ['me'], 'name', deps: deps),
        missing,
      );
      expect(deps, {'ROOT_QUERY.me'});
      cache.clear();
      expect(cache.readField('query', const ['page'], 'items'), missing);
    });
  });

  group('Accessor.scalarAs memo (#17)', () {
    test('parses each wire value once, same result', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {
        'a': '2026-01-02T00:00:00.000Z',
        'b': '2026-01-02T00:00:00.000Z',
        'c': '2027-01-02T00:00:00.000Z',
      });
      var calls = 0;
      DateTime parse(String s) {
        calls++;
        return DateTime.parse(s);
      }

      final root = _Root(_Recorder(cache));
      final a = root.at('a', parse);
      expect(a, DateTime.utc(2026, 1, 2));
      expect(root.at('a', parse), same(a));
      expect(root.at('b', parse), same(a)); // equal wire value
      expect(root.at('c', parse), DateTime.utc(2027, 1, 2));
      expect(calls, 2);
      expect(root.at('missing', parse), isNull);
    });
  });
}
