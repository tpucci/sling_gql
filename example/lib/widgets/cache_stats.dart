import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../theme.dart';

/// A live summary of `client.cache`: entities per type, the size of
/// [Cache.snapshot] (what a persistence layer would store), and of
/// [Cache.changesSince] the moment it opened (what an incremental one would
/// write to catch up).
///
/// It listens to [Cache.onChange] — each response, mutation, subscription
/// event or optimistic write fires it once, list-rule edits included, with
/// the dependency keys it touched — so the numbers move while the screens
/// behind it fetch.
class CacheStats extends StatefulWidget {
  const CacheStats({super.key});

  @override
  State<CacheStats> createState() => _CacheStatsState();
}

class _CacheStatsState extends State<CacheStats> {
  Cache? _cache;
  StreamSubscription<Set<String>>? _changes;
  int _changeCount = 0;
  int _lastTouched = 0;

  /// [Cache.version] when this opened: the "last persisted point".
  int _openedAt = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cache = SlingScope.clientOf(context).cache;
    if (identical(cache, _cache)) return;
    _cache = cache;
    _openedAt = cache.version;
    _changes?.cancel();
    _changes = cache.onChange.listen((touched) {
      if (!mounted) return;
      setState(() {
        _changeCount++;
        _lastTouched = touched.length;
      });
    });
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cache = _cache!;
    // `Launch:launch-181` → `Launch`; the `ROOT_*` operation roots are not
    // entities of a type.
    final perType = <String, int>{};
    for (final key in cache.entityKeys) {
      final colon = key.indexOf(':');
      if (colon < 0) continue;
      final type = key.substring(0, colon);
      perType[type] = (perType[type] ?? 0) + 1;
    }
    final entityCount = perType.values.fold(0, (a, b) => a + b);
    final types = perType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final snapshotKb = _kb(cache.snapshot);
    final delta = cache.changesSince(_openedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cache', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Every object the app has received, stored once. Updates live.',
          style: TextStyle(fontSize: 12, color: kColorTextSecondary),
        ),
        const SizedBox(height: 8),
        Text(
          '${_plural(entityCount, 'object')} · '
          '${snapshotKb.toStringAsFixed(1)} KB',
          key: const ValueKey('cache-stats'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          types.map((e) => _plural(e.value, _typeName(e.key))).join(' · '),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          _changeCount == 0
              ? 'No update since you opened this.'
              : '${_plural(_changeCount, 'update')} since you opened this '
                    '(last one touched ${_plural(_lastTouched, 'field')}); '
                    'saving them writes '
                    '${_plural(delta.changed.length, 'object')} '
                    '(${_kb(delta.changed).toStringAsFixed(1)} KB)'
                    '${delta.removed.isEmpty ? '' : ', deletes ${delta.removed.length}'}.',
          style: const TextStyle(fontSize: 12, color: kColorTextSecondary),
        ),
      ],
    );
  }
}

double _kb(Object json) => utf8.encode(jsonEncode(json)).length / 1024;

String _plural(int n, String one) => '$n ${n == 1 ? one : _many(one)}';

String _many(String one) => switch (one) {
  _ when one.endsWith('y') && !one.endsWith('ay') =>
    '${one.substring(0, one.length - 1)}ies',
  _ when RegExp(r'(s|x|ch|sh)$').hasMatch(one) => '${one}es',
  _ => '${one}s',
};

/// `Launchpad` → `launchpad`: the type name, as a word.
String _typeName(String type) => type.toLowerCase();
