import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { createYoga, createSchema, createPubSub } from "graphql-yoga";
import { resolvers } from "./resolvers.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));

const typeDefs = readFileSync(join(__dirname, "schema.graphql"), "utf8");

const schema = createSchema({ typeDefs, resolvers });

const pubsub = createPubSub();

const PORT = Number(process.env.PORT) || 4000;
const LATENCY_MS = Number(process.env.LATENCY_MS ?? 400);

function timestamp() {
  return new Date().toTimeString().slice(0, 8);
}

// Log one line per operation, e.g.:
// [14:03:21] query launches, stats  (402ms)
const latencyPlugin = {
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
        console.log(`[${timestamp()}] ${operationType} ${rootFields}  (${ms}ms)`);
      },
    };
  },
};

const yoga = createYoga({
  schema,
  graphiql: true,
  context: async () => {
    // One artificial delay per HTTP request (not per field/resolver).
    if (LATENCY_MS > 0) {
      await new Promise((resolve) => setTimeout(resolve, LATENCY_MS));
    }
    return { pubsub };
  },
  plugins: [latencyPlugin],
});

const server = createServer(yoga);

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Mock GraphQL API ready at http://0.0.0.0:${PORT}/graphql`);
  console.log(`Artificial latency: ${LATENCY_MS}ms per request`);
});
