import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sling_gql/internal.dart';
import 'package:sling_gql/sling_gql.dart';

import 'support/test_schema.dart';

/// #21 — the persistence hooks: `Cache.onChange` fires once per change
/// (a write outside a batch, or a whole `Cache.batch`; the client batches
/// every response, mutation, subscription event and optimistic callback),
/// and `Cache.version` / `Cache.changesSince` hand out only the entities
/// changed or removed since a persisted point.
void main() {
  Map<String, Object?> json(Object? value) =>
      jsonDecode(jsonEncode(value)) as Map<String, Object?>;

  Map<String, Object?> user(String id, {String? name, List<String>? friends}) =>
      {
        '__typename': 'User',
        'id': id,
        'name': ?name,
        if (friends != null)
          'friends': [for (final f in friends) user(f, name: f.toUpperCase())],
      };

  group('Cache.batch', () {
    test('one onChange event and one version per batch, nested too', () {
      final cache = NormalizedCache();
      final events = <Set<String>>[];
      cache.onChange.listen(events.add);

      final result = cache.batch(() {
        cache.writeResponse('query', {'me': user('1', name: 'Ada')});
        cache.batch(() => cache.write('query', ['me', 'age'], 36));
        expect(events, isEmpty, reason: 'held until the outer batch ends');
        return 'done';
      });

      expect(result, 'done');
      expect(events, hasLength(1));
      expect(
        events.single,
        containsAll(['ROOT_QUERY.me', 'User:1.name', 'User:1.age']),
      );
      expect(cache.version, 1);
    });

    test('a batch that throws still commits what it wrote', () {
      final cache = NormalizedCache();
      final events = <Set<String>>[];
      cache.onChange.listen(events.add);

      expect(
        () => cache.batch(() {
          cache.write('query', ['count'], 1);
          throw StateError('boom');
        }),
        throwsStateError,
      );
      expect(events, [
        {'ROOT_QUERY.count'},
      ]);
      expect(cache.version, 1);
    });

    test('an async body fails an assert (the batch would end at its first '
        'await)', () {
      final cache = NormalizedCache();
      expect(
        () => cache.batch(() async => cache.write('query', ['count'], 1)),
        throwsA(isA<AssertionError>()),
      );
      expect(cache.version, 1, reason: 'what it wrote is still committed');
    });

    test('nothing fires and the version stays when nothing changed', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {'me': user('1', name: 'Ada')});
      final events = <Set<String>>[];
      cache.onChange.listen(events.add);

      cache.writeResponse('query', {'me': user('1', name: 'Ada')});
      cache.batch(() {});

      expect(events, isEmpty);
      expect(cache.version, 1);
      expect(cache.changesSince(1).isEmpty, isTrue);
    });
  });

  group('Cache.changesSince', () {
    test('only the entities written since the version, as JSON', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {
        'me': user('1', name: 'Ada', friends: ['a', 'b']),
      });
      final first = cache.changesSince(0);
      expect(first.version, 1);
      expect(first.full, isFalse);
      expect(
        first.changed.keys,
        unorderedEquals(['User:1', 'User:a', 'User:b']),
      );
      // Roots are reported field by field.
      expect(first.changedFields['ROOT_QUERY'], {
        'me': {'__ref': 'User:1'},
      });
      expect(first.changed['User:1']!['friends'], [
        {'__ref': 'User:a'},
        {'__ref': 'User:b'},
      ]);

      cache.write('query', [const Ref('User:a'), 'name'], 'Bob');
      final second = cache.changesSince(first.version);
      expect(second.version, 2);
      expect(second.changed.keys, ['User:a']);
      expect(second.changed['User:a']!['name'], 'Bob');
      expect(second.removed, isEmpty);

      expect(cache.changesSince(second.version).isEmpty, isTrue);
    });

    test('the delta is a copy: later writes do not change it', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {
        'me': {
          ...user('1', name: 'Ada'),
          'stats': {'posts': 1},
        },
      });
      final delta = cache.changesSince(0);
      cache.write('query', ['me', 'stats', 'posts'], 2);
      expect(delta.changed['User:1']!['stats'], {'posts': 1});
    });

    test('evict: the entity is removed, the entities that referenced it '
        'changed', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {
        'me': user('1', name: 'Ada', friends: ['a', 'b']),
      });
      final v = cache.version;

      cache.evict('User:a');

      final delta = cache.changesSince(v);
      expect(delta.removed, {'User:a'});
      expect(delta.changed.keys, ['User:1']);
      expect(delta.changed['User:1']!['friends'], [
        {'__ref': 'User:b'},
      ]);
    });

    test('gc: collected entities are removed and reported on onChange', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {
        'me': user('1', name: 'Ada', friends: ['a', 'b']),
      });
      cache.writeResponse('query', {
        'me': user('1', friends: ['b']),
      });
      final v = cache.version;
      final events = <Set<String>>[];
      cache.onChange.listen(events.add);

      expect(cache.gc(), {'User:a'});

      expect(events, [
        {'User:a.__typename', 'User:a.id', 'User:a.name'},
      ]);
      expect(cache.version, v + 1);
      final delta = cache.changesSince(v);
      expect(delta.removed, {'User:a'});
      expect(delta.changed, isEmpty);
    });

    test('remove: the entity holding the field changed', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {'me': user('1', name: 'Ada')});
      final v = cache.version;

      cache.remove('query', [const Ref('User:1'), 'name']);

      final delta = cache.changesSince(v);
      expect(delta.changed.keys, ['User:1']);
      expect(delta.changed['User:1'], isNot(contains('name')));
    });

    test('an entity removed then written again is changed, not removed', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {'me': user('1', name: 'Ada')});
      final v = cache.version;

      cache.evict('User:1');
      cache.writeResponse('query', {'me': user('1', name: 'Grace')});

      final delta = cache.changesSince(v);
      expect(delta.removed, isEmpty);
      expect(delta.changed['User:1']!['name'], 'Grace');
    });

    test('clear: a full delta for anyone who has not seen it', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {'me': user('1', name: 'Ada')});
      final before = cache.version;

      cache.clear();
      cache.writeResponse('query', {'me': user('2', name: 'Bob')});

      final delta = cache.changesSince(before);
      expect(delta.full, isTrue);
      expect(delta.changed.keys, unorderedEquals(['ROOT_QUERY', 'User:2']));
      final stored = json(<String, Object?>{'User:1': {}, 'ROOT_QUERY': {}});
      delta.applyTo(stored);
      expect(stored, json(cache.snapshot));

      expect(cache.changesSince(delta.version).isEmpty, isTrue);
    });

    test('too many tombstones: older versions get a full delta', () {
      final cache = NormalizedCache();
      final ids = [for (var i = 0; i < 1100; i++) 'u$i'];
      cache.writeResponse('query', {'me': user('1', friends: ids)});
      final persisted = cache.snapshot;
      final v = cache.version;
      cache.writeResponse('query', {'me': user('1', friends: const [])});
      expect(cache.gc(), hasLength(1100));

      final delta = cache.changesSince(v);
      expect(delta.full, isTrue, reason: 'the 1100 tombstones were dropped');
      delta.applyTo(persisted);
      expect(json(persisted), json(cache.snapshot));
      expect(cache.changesSince(cache.version).isEmpty, isTrue);
    });

    test('snapshot + deltas round-trip to the current snapshot, and hydrate '
        'as version 0', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {
        'me': user('1', name: 'Ada', friends: ['a', 'b']),
      });
      var stored = json(cache.snapshot);
      var persisted = cache.version;

      void persist() {
        final delta = cache.changesSince(persisted);
        final copy = json(stored); // a store holds JSON, not live maps
        delta.applyTo(copy);
        stored = json(copy);
        persisted = delta.version;
      }

      cache.write('query', [const Ref('User:b'), 'name'], 'Cyrus');
      persist();
      cache.evict('User:a');
      cache.writeResponse('query', {
        'me': user('1', friends: ['b', 'c']),
      });
      persist();
      cache.writeResponse('query', {
        'me': user('1', friends: ['c']),
      });
      cache.gc();
      persist();

      expect(stored, json(cache.snapshot));

      final restored = Cache(initial: stored);
      expect(restored.version, 0);
      expect(restored.changesSince(0).isEmpty, isTrue);
      expect(json(restored.snapshot), stored);
      expect(restored.read('query', ['me', 'friends', 0, 'name']), 'C');
    });
  });

  // #69: a store acknowledging what it saved keeps a big gc from turning
  // the next save into a rewrite of every entity.
  group('Cache.compact', () {
    test('drops the records up to the version; later ones still count', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {
        'me': user('1', name: 'Ada', friends: ['a', 'b']),
      });
      final saved = cache.version;
      cache.write('query', [const Ref('User:a'), 'name'], 'Al');
      final middle = cache.version;
      cache.compact(upTo: saved);

      final delta = cache.changesSince(saved);
      expect(delta.full, isFalse);
      expect(delta.changed.keys, ['User:a']);
      expect(delta.changedFields, isEmpty);

      cache.compact(upTo: middle);
      expect(cache.changesSince(middle).isEmpty, isTrue);
      expect(
        cache.changesSince(saved).full,
        isTrue,
        reason: 'records before the compacted version are gone',
      );
    });

    test('a gc of more than a thousand entities after a compact: no full '
        'delta', () {
      final cache = NormalizedCache();
      final ids = [for (var i = 0; i < 1100; i++) 'u$i'];
      cache.writeResponse('query', {'me': user('1', friends: ids)});
      final stored = json(cache.snapshot);
      final v = cache.version;
      cache.compact(upTo: v);

      cache.writeResponse('query', {'me': user('1', friends: const [])});
      expect(cache.gc(), hasLength(1100));

      final delta = cache.changesSince(v);
      expect(delta.full, isFalse);
      expect(delta.removed, hasLength(1100));
      expect(delta.changed.keys, ['User:1']);
      delta.applyTo(stored);
      expect(stored, json(cache.snapshot));

      cache.compact(upTo: delta.version);
      expect(cache.changesSince(delta.version).isEmpty, isTrue);
    });

    test('removed root fields: no whole-root copy after a compact', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {'me': user('1', name: 'Ada')});
      final stored = json(cache.snapshot);
      final v = cache.version;
      cache.compact(upTo: v);
      cache.batch(() {
        for (var i = 0; i < 1100; i++) {
          cache.write('query', ['f$i'], i);
          cache.remove('query', ['f$i']);
        }
      });

      final delta = cache.changesSince(v);
      expect(delta.changed, isEmpty);
      expect(delta.removedFields['ROOT_QUERY'], hasLength(1100));
      delta.applyTo(stored);
      expect(stored, json(cache.snapshot));
    });

    test('a version past the current one compacts what there is', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {'me': user('1', name: 'Ada')});
      cache.compact(upTo: 99);
      expect(cache.changesSince(cache.version).isEmpty, isTrue);
      cache.write('query', ['me', 'name'], 'Grace');
      expect(cache.changesSince(1).changed.keys, ['User:1']);
    });
  });

  // #68: a root holds one field per query; copying it whole on every change
  // made a save cost the size of the session.
  group('Cache.changesSince roots field by field', () {
    test('only the root fields written since the version', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {
        'me': user('1', name: 'Ada'),
        'other': user('2', name: 'Bob'),
      });
      final v = cache.version;

      cache.writeResponse('query', {'third': user('3', name: 'Cy')});
      final delta = cache.changesSince(v);
      expect(delta.changed.keys, ['User:3']);
      expect(delta.changedFields, {
        'ROOT_QUERY': {
          'third': {'__ref': 'User:3'},
        },
      });
      expect(delta.removedFields, isEmpty);

      // Rewriting the same value changes nothing.
      cache.writeResponse('query', {'me': user('1', name: 'Ada')});
      expect(cache.changesSince(delta.version).isEmpty, isTrue);
    });

    test('removed root fields', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {
        'me': user('1', name: 'Ada'),
        'other': user('2', name: 'Bob'),
      });
      final stored = json(cache.snapshot);
      final v = cache.version;

      cache.remove('query', ['other']);
      cache.evict('User:1'); // scrubs `me`
      final delta = cache.changesSince(v);
      expect(delta.changedFields, isEmpty);
      expect(delta.removedFields, {
        'ROOT_QUERY': {'other', 'me'},
      });
      expect(delta.removed, {'User:1'});
      delta.applyTo(stored);
      expect(stored, json(cache.snapshot));
    });

    test('a root removed and written again is copied whole for versions '
        'before the removal', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {'me': user('1', name: 'Ada')});
      final before = json(cache.snapshot);
      final v = cache.version;

      cache.evict('ROOT_QUERY');
      final removedAt = cache.version;
      cache.writeResponse('query', {'other': user('2', name: 'Bob')});

      final delta = cache.changesSince(v);
      expect(delta.removed, isEmpty);
      expect(delta.changed['ROOT_QUERY'], {
        'other': {'__ref': 'User:2'},
      });
      expect(delta.changedFields, isEmpty);
      delta.applyTo(before);
      expect(before, json(cache.snapshot));

      // After the removal: field by field again.
      final after = cache.changesSince(removedAt);
      expect(after.changed.keys, ['User:2']);
      expect(after.changedFields['ROOT_QUERY']!.keys, ['other']);
    });

    test('too many stamps of removed root fields: older versions get the '
        'root whole', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {'me': user('1', name: 'Ada')});
      final stored = json(cache.snapshot);
      final v = cache.version;
      for (var i = 0; i < 1100; i++) {
        cache.write('query', ['f$i'], i);
        cache.remove('query', ['f$i']);
      }

      final delta = cache.changesSince(v);
      expect(delta.changed['ROOT_QUERY'], {
        'me': {'__ref': 'User:1'},
      });
      expect(delta.removedFields, isEmpty);
      delta.applyTo(stored);
      expect(stored, json(cache.snapshot));

      cache.write('query', ['late'], 1);
      expect(cache.changesSince(cache.version - 1).changedFields, {
        'ROOT_QUERY': {'late': 1},
      });
    });

    test('NormalizedCache.adopt hydrates decoded JSON in place', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {
        'me': user('1', name: 'Ada', friends: ['a', 'b']),
      });
      final decoded = (jsonDecode(jsonEncode(cache.snapshot)) as Map)
          .cast<String, Map<String, Object?>>();
      final user1 = decoded['User:1']!;

      final adopted = NormalizedCache.adopt(decoded);
      expect(adopted.version, 0);
      expect(adopted.changesSince(0).isEmpty, isTrue);
      expect(json(adopted.snapshot), json(cache.snapshot));
      expect(adopted.read('query', ['me', 'friends', 1, 'name']), 'B');
      // Taken over, not copied: the refs were converted in the given maps.
      expect((user1['friends']! as List).first, const Ref('User:a'));

      adopted.writeResponse('query', {'me': user('1', name: 'Grace')});
      expect(adopted.changesSince(0).changed['User:1']!['name'], 'Grace');
    });

    test('applyTo creates a root missing from the copy', () {
      final cache = NormalizedCache();
      cache.writeResponse('query', {'me': user('1', name: 'Ada')});
      final stored = <String, Object?>{};
      cache.changesSince(0).applyTo(stored);
      expect(json(stored), json(cache.snapshot));
    });
  });

  group('the client batches', () {
    SlingClient<Query> clientWith({
      bool failMutation = false,
      StreamController<Map<String, Object?>>? events,
      List<PrintedOperation>? ops,
      Map<String, Object?> Function()? answer,
    }) {
      final c = SlingClient<Query>(
        endpoint: testEndpoint,
        schema: slingSchema,
        onOperation: ops?.add,
        httpClient: mockGraphQL((query, vars) {
          if (query.startsWith('mutation')) {
            if (failMutation) throw StateError('offline');
            final alias = RegExp(r'(rename_\w+):').firstMatch(query)!.group(1)!;
            return {alias: user(vars['id'] as String, name: 'Grace')};
          }
          final data = (answer ?? meWithFriends)();
          final me = data['me'] as Map<String, Object?>;
          for (final m in RegExp(r'(friends_\w+):').allMatches(query)) {
            me[m.group(1)!] = me['friends'];
          }
          return data;
        }),
        subscriptionTransport: (_) => events!.stream,
        listRules: [
          ListRule<User>(
            field: 'friends',
            typename: 'User',
            ctor: User.new,
            belongs: (args, user) => user.age == null,
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a setter and the list-rule edit it causes are one change', () async {
      final c = clientWith();
      await c.resolve((q) => q.me.friends().map((f) => f.age).toList());
      final events = <Set<String>>[];
      c.cache.onChange.listen(events.add);
      final v = c.cache.version;

      // Ada loses her age: the rule adds her to `me.friends`.
      c.cacheScope.user('1')!.age = null;

      expect(events, hasLength(1));
      expect(events.single, contains('User:1.age'));
      expect(
        events.single.where((k) => k.startsWith('User:1.friends')),
        isNotEmpty,
      );
      expect(c.cache.version, v + 1);
    });

    test('a query response and the list-rule edit it causes are one '
        'change', () async {
      final c = clientWith(
        answer: () => {
          'me': {
            '__typename': 'User',
            'id': '1',
            'friends': [
              {'__typename': 'User', 'id': 'a', 'name': 'Bob', 'age': null},
              // Has an age: the rule removes Cy from the list it came in.
              {'__typename': 'User', 'id': 'b', 'name': 'Cy', 'age': 3},
            ],
          },
        },
      );
      final events = <Set<String>>[];
      c.cache.onChange.listen(events.add);

      await c.resolve(
        (q) => q.me.friends(limit: 2).map((f) => (f.name, f.age)).toList(),
      );

      expect(c.cacheScope.query.me.friends(limit: 2).map((f) => f.name), [
        'Bob',
      ]);
      expect(events, hasLength(1));
      expect(events.single, containsAll(['User:b.age', 'User:a.name']));
      expect(c.cache.version, 1);
    });

    test('a mutation: one change for the optimistic callback, one for the '
        'response and the root removal', () async {
      final c = clientWith();
      await c.resolve((q) => (q.me.name, q.me.age));
      final events = <Set<String>>[];
      c.cache.onChange.listen(events.add);
      final v = c.cache.version;

      final name = await c.mutateWith(
        Mutation.root,
        (m) => m.rename(id: '1', name: 'Grace')?.name,
        optimistic: () => c.cacheScope.user('1')!
          ..name = 'G'
          ..age = 1,
      );

      expect(name, 'Grace');
      expect(events, hasLength(2));
      expect(events.first, {'User:1.name', 'User:1.age'});
      expect(events.last, contains('User:1.name'));
      expect(c.cache.version, v + 2);
      final delta = c.cache.changesSince(v);
      expect(delta.changed['User:1']!['name'], 'Grace');
      expect(delta.changed['ROOT_MUTATION'], isNull);
      expect(delta.changedFields['ROOT_MUTATION'], isNull);
    });

    test('a failed mutation: the rollback is one change and the delta holds '
        'the restored values', () async {
      final c = clientWith(failMutation: true);
      await c.resolve((q) => (q.me.name, q.me.age));
      final events = <Set<String>>[];
      c.cache.onChange.listen(events.add);
      final v = c.cache.version;

      await expectLater(
        c.mutateWith(
          Mutation.root,
          (m) => m.rename(id: '1', name: 'Grace')?.name,
          optimistic: () => c.cacheScope.user('1')!
            ..name = 'G'
            ..age = 1,
        ),
        throwsA(anything),
      );

      expect(events, hasLength(2), reason: 'optimistic, then rollback');
      expect(events.last, {'User:1.name', 'User:1.age'});
      final delta = c.cache.changesSince(v);
      expect(delta.changed.keys, ['User:1']);
      expect(delta.changed['User:1']!['name'], 'Ada');
      expect(delta.changed['User:1']!['age'], 36);
    });

    test('a subscription event is one change', () async {
      final events = StreamController<Map<String, Object?>>();
      final ops = <PrintedOperation>[];
      final c = clientWith(events: events, ops: ops);
      await c.resolve((q) => q.me.friends().map((f) => f.name).toList());
      final changes = <Set<String>>[];
      c.cache.onChange.listen(changes.add);

      final sub = c
          .subscribeWith(Subscription.root, (s) => s.userChanged?.age)
          .stream
          .listen((_) {});
      await Future<void>.delayed(Duration.zero);
      final alias = RegExp(r'\{\s*(\w+)')
          .firstMatch(ops.last.document)!
          .group(1)!;
      // A new user with no age: written, and added to `me.friends`.
      events.add({
        'data': {
          alias: {'__typename': 'User', 'id': 'z', 'age': null},
        },
      });
      await Future<void>.delayed(Duration.zero);

      expect(changes, hasLength(1));
      expect(changes.single, contains('User:z.age'));
      expect(
        changes.single.where((k) => k.startsWith('User:1.friends')),
        isNotEmpty,
      );
      await sub.cancel();
    });
  });
}
