import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { createMockYoga, LATENCY_HEADER } from "./app.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));

const PORT = Number(process.env.PORT) || 4000;
const LATENCY_MS = Number(process.env.LATENCY_MS ?? 400);

const yoga = createMockYoga({
  typeDefs: readFileSync(join(__dirname, "schema.graphql"), "utf8"),
  latencyMs: LATENCY_MS,
  sequenceMs: Number(process.env.SEQUENCE_MS ?? 4000),
  graphiql: true,
});

const server = createServer(yoga);

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Mock GraphQL API ready at http://0.0.0.0:${PORT}/graphql`);
  console.log(
    `Artificial latency: ${LATENCY_MS}ms per request (override: ${LATENCY_HEADER} header)`
  );
});
