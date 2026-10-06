## 1.0.0

> Note: This release has breaking changes.

 - First stable release. Upgrading from 0.x: see [Upgrading to 1.0](https://tpucci.github.io/sling_gql/guides/upgrading-to-1-0/).

 - **DOCS**(repo): Versioning sections in the adapter, test and generator READMEs ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([a3574704](https://github.com/tpucci/sling_gql/commit/a35747046d8fa901476b73825661861c9acf78ce))
 - **BREAKING** **REFACTOR**(sling_gql_test): rename GraphQLError to MockGraphQLError ([#73](https://github.com/tpucci/sling_gql/issues/73)). ([b144a1d8](https://github.com/tpucci/sling_gql/commit/b144a1d88bd38ce1105cfccaac50622777b3f4fd))
 - **BREAKING** **FEAT**(sling_gql_link): map LinkExceptions to the typed SlingExceptions. ([e4fa73b4](https://github.com/tpucci/sling_gql/commit/e4fa73b412d7d182526f863540fefe3af3915ac6))

## 0.1.0+1

 - Update a dependency to the latest release.

## 0.1.0

Initial release.

- `linkTransport(link)`: a `gql_link` `Link` as sling_gql's `Transport` (queries and mutations).
- `linkSubscriptionTransport(link)`: the same `Link` as the `SubscriptionTransport`.
- `SlingLinkException`: a `LinkException` as the `SlingException` the client reports.
