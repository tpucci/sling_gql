## 0.1.0

Initial release.

- `useSlingQuery`: `QueryBuilder` as a hook — a selector run in the widget's own `QueryScope`, returning its value and a `QueryState`; `fetchPolicy`, `maxAge`, `debugLabel`, `scheduler`.
- `useSlingMutation`: `MutationBuilder` as a hook — `mutate` and a `MutationState`.
- `useSlingSubscription`: `SubscriptionBuilder` as a hook — the event accessor and a `SubscriptionState`, open while the widget is mounted.
