## 0.1.0

Initial release — proof of concept.

- `QueryBuilder` / `MutationBuilder` / `SlingScope`: read typed accessors
  during `build()`, get the query.
- Selection recording, per-frame batching into one GraphQL document, argument
  → variable extraction with deterministic aliases.
- Normalized cache (`__typename:id` entities, by-id lookups, `evict`, `gc`,
  `snapshot` / `onChange`), per-field rebuild notifications.
- Skeleton state before data arrives, `prepare` for conditional reads,
  waterfall warnings in dev mode.
- Mutations with optimistic writes, journaled and rolled back on failure.
- Partial `errors[]` handling, sticky errors with `refetch`, retry cooldown.
- Cursor pagination helpers, `CacheScope.list` for list membership updates.
