// Browser entry of the mock API, bundled by `npm run build:browser` into
// `example/web/mock-api.js` (schema inlined). Exposes
// `globalThis.slingMockApi.fetch(url, init)`, which answers like the server
// would — including `text/event-stream` subscriptions — without a network.
// The example's web build sends every request there (lib/in_browser_api).
import typeDefs from "./schema.graphql";
import { createMockYoga } from "./app.mjs";

const yoga = createMockYoga({
  typeDefs,
  // Same defaults as `npm start`; the in-app latency picker overrides them.
  latencyMs: 400,
  sequenceMs: 4000,
  log: (line) => console.debug(`mock-api ${line}`),
});

globalThis.slingMockApi = {
  fetch: (url, init) => yoga.fetch(url, init),
};
