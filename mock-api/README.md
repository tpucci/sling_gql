# mock-api

A space-themed GraphQL mock server for `sling_gql`, built with
[graphql-yoga](https://the-guild.dev/graphql/yoga-server). Serves a fixed,
seeded dataset of launches, rockets, launchpads and astronauts — no external
network calls, no database.

The schema contract lives in `schema.graphql` and is loaded from disk at
startup (`readFileSync`); it is never generated or edited by this server.

## Run

```sh
cd mock-api
npm install
npm start        # or: npm run dev  (restarts on file change)
```

GraphiQL: http://localhost:4000/graphql

### Env vars

| Var          | Default | Meaning                                             |
| ------------ | ------- | ---------------------------------------------------- |
| `PORT`       | `4000`  | HTTP port, bound on `0.0.0.0`.                       |
| `LATENCY_MS` | `400`   | Artificial delay awaited once per HTTP request.      |

Each operation is logged to stdout as it completes, e.g.:

```
[14:03:21] query launches, stats  (401ms)
```

## Schema highlights

### `Viewer` and `me`

`me: Viewer!` returns a static signed-in user (id `viewer-1`, name `Mira Vance`,
agency `Sling Space`). Its field resolvers compute `favorites` and
`favoriteCount` lazily from the live launches array, so they reflect
`toggleFavorite` mutations within the same process:

```graphql
{
  me {
    id name agency avatarInitials favoriteCount
    favorites { id name date status }
  }
}
```

### `LaunchFilter.favorite`

`filter: { favorite: true }` on `launches` / `launchesPage` keeps only launches
whose `favorite` flag equals that value (server-side, i.e. `l.favorite ===
filter.favorite`):

```graphql
{
  launches(first: 20, filter: { favorite: true }) {
    totalCount
    nodes { id name favorite }
  }
}
```

## Example queries

Cursor-paginated launches, newest first, with the next page:

```graphql
{
  launches(first: 5) {
    totalCount
    pageInfo { hasNextPage endCursor }
    nodes { flightNumber name date status rocket { name } }
  }
}
```

```graphql
{
  launches(first: 5, after: "<endCursor from previous page>") {
    nodes { flightNumber name }
  }
}
```

Offset pagination with a filter and explicit ordering:

```graphql
{
  launchesPage(
    limit: 10
    offset: 0
    filter: { status: SUCCESS, year: 2022 }
    orderBy: NAME_ASC
  ) {
    name
    status
    date
  }
}
```

Nested cursor pagination on a rocket's own launch history:

```graphql
{
  rocket(id: "rocket-falcon") {
    name
    launches(first: 5) {
      totalCount
      nodes { name date status }
    }
  }
}
```

Mutations and subscriptions are also available, e.g.:

```graphql
mutation {
  toggleFavorite(launchId: "launch-1") { id favorite }
}
```

```graphql
subscription {
  launchScheduled { id name status }
}
```

## Regenerating the example app's introspection snapshot

```sh
npm run introspect
```

This imports the executable schema directly (no server needs to be running),
runs a full introspection query, and overwrites
`../example/graphql/schema.json`.

## Notes on the dataset

- Data is generated once at process start from a seeded PRNG (`data.mjs`), so
  ids and content are stable across restarts. The only thing that changes
  over time is which launches count as "past" vs. "upcoming", since that is
  computed relative to `Date.now()`.
- ~180 launches spread from 2010 through a few years out, ~15 of which are
  always in the future (`upcoming: true`, status `SCHEDULED`/`SCRUBBED`).
- 5 rockets (one per `RocketFamily`), 4 launchpads, 24 astronauts.
