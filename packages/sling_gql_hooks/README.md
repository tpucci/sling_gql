# sling_gql_hooks

[flutter_hooks](https://pub.dev/packages/flutter_hooks) adapter for
[sling_gql](https://pub.dev/packages/sling_gql): `useSlingQuery`,
`useSlingMutation` and `useSlingSubscription` are `QueryBuilder`,
`MutationBuilder` and `SubscriptionBuilder` for a `HookWidget`. Same
machinery (one `QueryScope` per widget, per-frame batching, per-field
rebuilds, sticky errors, fetch policies), no builder nesting.

Docs: https://tpucci.github.io/sling_gql/guides/hooks/ · Source:
https://github.com/tpucci/sling_gql

```sh
flutter pub add sling_gql sling_gql_hooks flutter_hooks
```

## `useSlingQuery`

```dart
class LaunchTile extends HookWidget {
  const LaunchTile({super.key});

  @override
  Widget build(BuildContext context) {
    final (launch, state) = useSlingQuery(
      (Query q) => q.latestLaunch?..name..rocket?.name,
    );
    if (state.error != null) return RetryTile(onRetry: state.refetch);
    return ListTile(
      title: Text(launch?.name ?? '…'),
      subtitle: Text(launch?.rocket?.name ?? '…'),
    );
  }
}
```

The selector is what `QueryBuilder`'s `builder` is: every field it reads is
recorded, fetched in the frame's batched request and becomes a dependency of
the widget. It returns whatever the build needs — an accessor (a cascade
reads fields and returns the object) or a record of values. **Read in the
selector everything the build needs**: its reads decide
`state.hasMissingData`, `maxAge` staleness and what `cacheAndNetwork`
refetches. Accessors it returns stay bound to the widget's scope, so reading
more fields through them later still fetches them (like a `QueryBuilder`'s
children), but outside that bookkeeping.

`fetchPolicy:`, `maxAge:`, `debugLabel:` and `scheduler:` are
`QueryBuilder`'s. The state is sling_gql's `QueryState` (`isLoading`,
`hasMissingData`, `isSkeleton`, `isStale`, `error`, `refetch`, `revalidate`).

## `useSlingMutation`

```dart
final (mutate, state) = useSlingMutation<Mutation>();
// …
onPressed: state.isLoading
    ? null
    : () => mutate(
          (m) => m.toggleFavorite(launchId: id)?.favorite,
          optimistic: () => launch.favorite = !favorite,
        ),
```

`mutate` resolves to the body's value computed from the cache, or `null` on
failure (never throws; the exception is on `state.error`). `state` is
sling_gql's `MutationState` for the latest call. The root comes from the
`SlingScope`'s `schema:` unless `root:` is given.

## `useSlingSubscription`

```dart
final (s, state) = useSlingSubscription<Subscription>(
  (s) => s.launchStatusChanged?..status..name,
  onEvent: (s) => showSnack(s.launchStatusChanged?.name),
);
```

Opens at the end of the first frame, closes when the widget is disposed;
each event is normalized into the cache (queries showing the same entities
rebuild) and rebuilds this widget. `retryAfter:`, `root:` and `debugLabel:`
are `SubscriptionBuilder`'s.

## Testing

Hooks run on the same client as the builders, so
[sling_gql_test](https://pub.dev/packages/sling_gql_test)'s
`MockGraphQLServer` and `tester.pumpUntilSettled(client)` work unchanged.
