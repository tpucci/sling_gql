import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { graphql, getIntrospectionQuery } from "graphql";
import { createSchema } from "graphql-yoga";
import { resolvers } from "./resolvers.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));

const typeDefs = readFileSync(join(__dirname, "schema.graphql"), "utf8");
const schema = createSchema({ typeDefs, resolvers });

const result = await graphql({
  schema,
  source: getIntrospectionQuery({ descriptions: true }),
});

if (result.errors?.length) {
  console.error("Introspection failed:", result.errors);
  process.exit(1);
}

const outPath = join(__dirname, "..", "example", "graphql", "schema.json");
writeFileSync(outPath, JSON.stringify(result.data, null, 2) + "\n", "utf8");

const typeCount = result.data.__schema.types.length;
console.log(`Wrote introspection result to ${outPath}`);
console.log(`Types: ${typeCount}`);
