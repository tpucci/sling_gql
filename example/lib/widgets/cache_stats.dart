import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:sling_gql/sling_gql.dart';

import '../theme.dart';

/// A live summary of `client.cache`: entities per type and the size of
/// [Cache.snapshot] (what a persistence layer would store).
///
/// It listens to [Cache.onChange] — every response, optimistic write,
/// subscription event or list-rule edit fires it with the dependency keys it
/// touched — so the numbers move while the screens behind it fetch.
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cache = SlingScope.clientOf(context).cache;
    if (identical(cache, _cache)) return;
    _cache = cache;
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
    final snapshotKb = utf8.encode(jsonEncode(cache.snapshot)).length / 1024;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$entityCount entities · '
          'snapshot ${snapshotKb.toStringAsFixed(1)} KB',
          key: const ValueKey('cache-stats'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          types.map((e) => '${e.key} ${e.value}').join(' · '),
          style: const TextStyle(fontSize: 12, color: kColorTextSecondary),
        ),
        Text(
          _changeCount == 0
              ? 'no change since opened'
              : '$_changeCount change(s) since opened · '
                    'last touched $_lastTouched key(s)',
          style: const TextStyle(fontSize: 12, color: kColorTextSecondary),
        ),
      ],
    );
  }
}
