// The mock API without a server: a graphql-yoga instance over the schema and
// resolvers, runnable anywhere the Fetch API exists. `server.mjs` serves it
// over `node:http`; `browser.mjs` runs it inside the web build of the example
// (bundled to `example/web/mock-api.js`), so every browser tab has its own
// in-memory data.
import { createYoga, createSchema, createPubSub } from "graphql-yoga";
import { resolvers } from "./resolvers.mjs";

// Per-request override of the default latency, e.g. `x-mock-latency-ms: 2000`
// (the example app's latency picker). A header rather than server state, so
// clients running in parallel never see each other's setting.
export const LATENCY_HEADER = "x-mock-latency-ms";

function timestamp() {
  return new Date().toTimeString().slice(0, 8);
}

// Log one line per operation, e.g.:
// [14:03:21] query launches, stats  (402ms)
function logPlugin(log) {
  return {
    onExecute({ args }) {
      const start = Date.now();
      const operation = args.document.definitions.find(
        (d) => d.kind === "OperationDefinition"
      );
      const operationType = operation?.operation ?? "query";
      const rootFields =
        operation?.selectionSet?.selections
          ?.map((s) => s.alias?.value ?? s.name?.value)
          .filter(Boolean)
          .join(", ") ?? "";

      return {
        onExecuteDone() {
          const ms = Date.now() - start;
          log(`[${timestamp()}] ${operationType} ${rootFields}  (${ms}ms)`);
        },
      };
    },
  };
}

/**
 * @param {object} options
 * @param {string} options.typeDefs  contents of `schema.graphql`
 * @param {number} [options.latencyMs]  delay per HTTP request (not per field)
 * @param {number} [options.sequenceMs]  step of a scheduled launch's sequence
 * @param {boolean} [options.graphiql]
 * @param {(line: string) => void} [options.log]
 */
export function createMockYoga({
  typeDefs,
  latencyMs = 400,
  sequenceMs = 4000,
  graphiql = false,
  log = console.log,
}) {
  const schema = createSchema({ typeDefs, resolvers });
  const pubsub = createPubSub();

  function requestLatencyMs(request) {
    const value = request.headers.get(LATENCY_HEADER);
    if (value == null || value.trim() === "") return latencyMs;
    const ms = Number(value);
    return Number.isFinite(ms) && ms >= 0 ? ms : latencyMs;
  }

  return createYoga({
    schema,
    graphiql,
    context: async ({ request }) => {
      // One artificial delay per HTTP request (not per field/resolver).
      const ms = requestLatencyMs(request);
      if (ms > 0) {
        await new Promise((resolve) => setTimeout(resolve, ms));
      }
      return { pubsub, sequenceMs };
    },
    plugins: [logPlugin(log)],
  });
}
