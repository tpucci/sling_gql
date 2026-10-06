# Security policy

## Reporting a vulnerability

Please report security issues **privately**, through GitHub's security
advisories: [Report a vulnerability](https://github.com/tpucci/sling_gql/security/advisories/new)
(repository → *Security* → *Advisories* → *Report a vulnerability*). Do not
open a public issue, pull request or discussion for it.

Include what you can of: the package and version, the platform, a minimal
reproduction (a failing test against `MockGraphQLServer` is ideal), and the
impact you see. You can expect an acknowledgement within a week; a fix is
released as a patch of the affected packages, with a GitHub security advisory
(and a CVE when it warrants one) once users can upgrade.

## Supported versions

| Package | Supported |
| --- | --- |
| `sling_gql`, `sling_gql_gen`, `sling_gql_test`, `sling_gql_hooks`, `sling_gql_link`, `sling_gql_sqflite` 1.x | ✅ latest minor |
| 0.x | ❌ — upgrade to 1.x ([guide](https://tpucci.github.io/sling_gql/guides/upgrading-to-1-0/)) |

## Scope

In scope — sling_gql's own code in this repository, in particular:

- **Persistence and its codec** (`sling_gql_sqflite`): data written to or read
  from the SQLite store outside what is documented (rows surviving `clear()`,
  rows readable under another `SqfliteCodec` id, a codec bypassed for some
  rows or tables, the stored mutation queue leaking past `clear()`), and
  crashes or code paths reachable from a crafted database file.
- **Auth and token handling** (`SlingAuth`, `SlingClient.headers`, the
  transports): credentials sent to another endpoint, logged by sling_gql
  itself (`logRequests`, `SlingRequest`, the request overlay), kept after a
  refresh failed, or a request replayed with credentials it was not meant to
  carry.
- **Sign-out clearing**: offline mutations surviving
  `SlingClient.clearMutationQueue()` / `SqflitePersistence.clear()`, or
  replayed under the next user's credentials after both were called.
- Response handling: a server response that makes the client write data under
  another entity's key or another query's cache entry.

Out of scope:

- The encryption itself: `sling_gql_sqflite` ships no cipher. A
  `SqfliteCodec` (or an SQLCipher `databaseFactory`) is the app's choice and
  responsibility, as is key storage.
- What the app does with data: caching a field means it is stored in memory
  and, with `sling_gql_sqflite`, on disk **unencrypted unless you pass a
  codec**. Do not cache secrets you would not write to disk.
- Debug tooling enabled in a release build by the app
  (`SlingRequestOverlay(enabled: true)`, `logRequests: true`,
  `onOperation` printing documents).
- The example app, the mock API (`mock-api/`) and the documentation site:
  demo code, not shipped to users.
- Vulnerabilities in dependencies (`http`, `sqflite`, `gql_link`, Flutter):
  report them upstream; tell us if sling_gql needs to raise a constraint.
