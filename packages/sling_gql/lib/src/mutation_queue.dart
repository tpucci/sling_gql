import 'dart:async';

import 'cache/cache.dart';
import 'errors.dart';

/// A mutation sent with `mutateWith(offline: true)` that has not landed
/// yet: what a [MutationQueueStore] keeps so it can be sent again — after
/// the network came back, or after the app was killed and restarted —
/// without the closure that recorded it.
///
/// Everything here is JSON (see [toJson]): the printed [document] and its
/// [variables] as they were when the call was made, and [rollback], the
/// undo log of the call's optimistic writes, so they can still be rolled
/// back by a later run of the app when the mutation finally fails.
final class QueuedMutation {
  const QueuedMutation({
    required this.id,
    required this.document,
    required this.variables,
    required this.createdAt,
    this.rollback = const [],
    this.refetchQueries = const [],
    this.renamesFields = false,
  });

  factory QueuedMutation.fromJson(Map<String, Object?> json) => QueuedMutation(
    id: json['id']! as String,
    document: json['document']! as String,
    variables: (json['variables']! as Map).cast<String, Object?>(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']! as int),
    rollback: [
      for (final w in (json['rollback'] as List?) ?? const [])
        (w as Map).cast<String, Object?>(),
    ],
    refetchQueries: [
      for (final f in (json['refetchQueries'] as List?) ?? const [])
        f as String,
    ],
    renamesFields: json['renamesFields'] as bool? ?? false,
  );

  /// Unique per queued call; the key a store files it under.
  final String id;

  /// The mutation document, printed when the call was made.
  final String document;

  /// Its variables, captured when the call was made.
  final Map<String, Object?> variables;

  /// When the call was made.
  final DateTime createdAt;

  /// The optimistic writes' undo log, newest last (JSON: per write, the
  /// operation, the cache path with entity refs as `{"__ref": key}`, and the
  /// previous value, or `"absent": true` when the path did not exist).
  /// Replayed in reverse when the mutation fails for good.
  final List<Map<String, Object?>> rollback;

  /// The call's `refetchQueries`, run once it lands.
  final List<String> refetchQueries;

  /// The document prints some fields under a response key other than their
  /// cache alias (fragments selecting one field twice, merging field
  /// policies; see `PrintedOperation.renamesFields`). The mapping back lives
  /// in the call's selection, which a restarted app no longer has: the
  /// response of such a mutation is then not written to the cache (the
  /// optimistic writes stand; queries fetch the real values).
  final bool renamesFields;

  Map<String, Object?> toJson() => {
    'id': id,
    'document': document,
    'variables': variables,
    'createdAt': createdAt.millisecondsSinceEpoch,
    if (rollback.isNotEmpty) 'rollback': rollback,
    if (refetchQueries.isNotEmpty) 'refetchQueries': refetchQueries,
    if (renamesFields) 'renamesFields': true,
  };

  @override
  String toString() => 'QueuedMutation($id, created $createdAt)';
}

/// Where a `SlingClient` keeps its queued mutations (see
/// `SlingClient.mutationQueue`) so they survive the app being killed:
/// [InMemoryMutationQueueStore] (the default) lasts as long as the
/// process; `sling_gql_sqflite`'s `SqflitePersistence.mutationQueue` keeps
/// them in the cache's database.
///
/// The client calls [load] once, when it is created, and replays what it
/// returns before anything queued later; then it [add]s an entry when an
/// offline mutation is sent and [remove]s it when the mutation landed or
/// failed for good. Writes are fire-and-forget: a store reports its own
/// failures (the client does not wait for them, and never sees them).
abstract interface class MutationQueueStore {
  /// The entries a previous run left, oldest first. A list (not a future)
  /// lets the client replay them right away.
  FutureOr<List<QueuedMutation>> load();

  /// Appends [entry] (the newest).
  Future<void> add(QueuedMutation entry);

  /// Drops the entry with [id]; a no-op when there is none.
  Future<void> remove(String id);
}

/// A [MutationQueueStore] in memory: queued mutations survive as long as
/// the store object does (share one between two clients to simulate an app
/// restart in a test).
final class InMemoryMutationQueueStore implements MutationQueueStore {
  InMemoryMutationQueueStore([Iterable<QueuedMutation> entries = const []])
    : _entries = List.of(entries);

  final List<QueuedMutation> _entries;

  /// What the store holds, oldest first.
  List<QueuedMutation> get entries => List.unmodifiable(_entries);

  @override
  List<QueuedMutation> load() => List.of(_entries);

  @override
  Future<void> add(QueuedMutation entry) async => _entries.add(entry);

  @override
  Future<void> remove(String id) async =>
      _entries.removeWhere((e) => e.id == id);
}

/// A queued mutation that failed for good when it was replayed (see
/// `SlingClient.onQueuedMutationFailed`): the server answered with an error
/// (or the response could not be cached), the entry was dropped and its
/// optimistic writes rolled back.
final class QueuedMutationFailure {
  const QueuedMutationFailure(this.mutation, this.error);

  final QueuedMutation mutation;
  final SlingException error;

  @override
  String toString() => 'QueuedMutationFailure(${mutation.id}: $error)';
}

/// [QueuedMutation.rollback]'s form of a journal of [CacheWrite]s.
List<Map<String, Object?>> encodeRollback(List<CacheWrite> journal) => [
  for (final w in journal)
    {
      'operation': w.operation,
      'path': [for (final p in w.path) p is Ref ? p.toJson() : p],
      if (w.previous == missing)
        'absent': true
      else
        'previous': _toJson(w.previous),
    },
];

/// The [CacheWrite]s [encodeRollback] stored (their `touched` keys empty:
/// undoing them reports what it touches).
List<CacheWrite> decodeRollback(List<Map<String, Object?>> rollback) => [
  for (final w in rollback)
    CacheWrite(
      w['operation']! as String,
      [
        for (final p in w['path']! as List)
          Ref.tryParse(p) ?? p! /* String alias or int index */,
      ],
      w['absent'] == true ? missing : _fromJson(w['previous']),
      const {},
    ),
];

Object? _toJson(Object? node) => switch (node) {
  Ref() => node.toJson(),
  Map() => {for (final e in node.entries) e.key as String: _toJson(e.value)},
  List() => [for (final e in node) _toJson(e)],
  _ => node,
};

Object? _fromJson(Object? node) {
  if (node is Map) {
    return Ref.tryParse(node) ??
        <String, Object?>{
          for (final e in node.entries) e.key as String: _fromJson(e.value),
        };
  }
  if (node is List) return <Object?>[for (final e in node) _fromJson(e)];
  return node;
}

/// The entity keys [journal]'s writes point into or would restore: kept by
/// `SlingClient.gc` while the mutation is queued, so a rollback finds them.
Iterable<String> rollbackEntities(List<CacheWrite> journal) sync* {
  Iterable<String> refs(Object? node) sync* {
    switch (node) {
      case Ref():
        yield node.key;
      case Map():
        for (final v in node.values) {
          yield* refs(v);
        }
      case List():
        for (final v in node) {
          yield* refs(v);
        }
    }
  }

  for (final w in journal) {
    for (final p in w.path) {
      if (p is Ref) yield p.key;
    }
    yield* refs(w.previous);
  }
}
