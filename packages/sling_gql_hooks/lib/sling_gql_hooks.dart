/// flutter_hooks adapter for sling_gql: the builders of
/// `package:sling_gql/sling_gql.dart` as hooks for a `HookWidget`.
///
/// - [useSlingQuery]: `QueryBuilder` — a selector run in the widget's own
///   `QueryScope` on every build, returning its value and a `QueryState`.
/// - [useSlingMutation]: `MutationBuilder` — `mutate` and a `MutationState`.
/// - [useSlingSubscription]: `SubscriptionBuilder` — the event accessor and a
///   `SubscriptionState`, open while the widget is mounted.
///
/// Same machinery, same semantics: per-frame batching, per-field rebuilds,
/// sticky errors, fetch policies. Only the shape changes.
library;

export 'src/use_sling_mutation.dart' show useSlingMutation;
export 'src/use_sling_query.dart' show useSlingQuery;
export 'src/use_sling_subscription.dart' show useSlingSubscription;
