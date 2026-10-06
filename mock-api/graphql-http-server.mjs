// The mock API's schema and resolvers behind a second, independent server
// implementation: graphql-http (the GraphQL-over-HTTP reference server) for
// queries and mutations, graphql-sse ("distinct connections" mode) for
// subscriptions, both on plain `node:http`. Only the schema builder and the
// in-memory pubsub come from graphql-yoga's utilities; yoga's HTTP handling
// is not involved. Used to run the example's end-to-end tests against a
// server sling_gql was not developed against:
//
//   PORT=4001 node graphql-http-server.mjs
//   melos run test:example:graphql-http --no-select   (from the repo root)
import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { createSchema, createPubSub } from "graphql-yoga";
import { createHandler as createHttpHandler } from "graphql-http/lib/use/http";
import { createHandler as createSseHandler } from "graphql-sse/lib/use/http";
import { resolvers } from "./resolvers.mjs";
import { LATENCY_HEADER } from "./app.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));

const PORT = Number(process.env.PORT) || 4001;
const LATENCY_MS = Number(process.env.LATENCY_MS ?? 400);
const SEQUENCE_MS = Number(process.env.SEQUENCE_MS ?? 4000);

const schema = createSchema({
  typeDefs: readFileSync(join(__dirname, "schema.graphql"), "utf8"),
  resolvers,
});
const pubsub = createPubSub();

// graphql-http hands over Node's header object, graphql-sse a `get` wrapper.
function header(headers, name) {
  const value =
    typeof headers.get === "function" ? headers.get(name) : headers[name];
  return Array.isArray(value) ? value[0] : value;
}

// Same contract as app.mjs: one delay per HTTP request, overridable per
// request with the x-mock-latency-ms header.
async function context(req) {
  const value = header(req.headers, LATENCY_HEADER);
  const requested = value == null || value.trim() === "" ? NaN : Number(value);
  const ms =
    Number.isFinite(requested) && requested >= 0 ? requested : LATENCY_MS;
  if (ms > 0) await new Promise((resolve) => setTimeout(resolve, ms));
  return { pubsub, sequenceMs: SEQUENCE_MS };
}

const http = createHttpHandler({ schema, context });
const sse = createSseHandler({ schema, context });

const server = createServer((req, res) => {
  const path = (req.url ?? "").split("?")[0];
  if (path !== "/graphql") {
    res.writeHead(404).end();
    return;
  }
  const accept = req.headers.accept ?? "";
  if (accept.includes("text/event-stream")) return sse(req, res);
  return http(req, res);
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(
    `Mock GraphQL API (graphql-http + graphql-sse) ready at http://0.0.0.0:${PORT}/graphql`
  );
  console.log(
    `Artificial latency: ${LATENCY_MS}ms per request (override: ${LATENCY_HEADER} header)`
  );
});
