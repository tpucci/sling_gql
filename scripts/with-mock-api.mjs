#!/usr/bin/env node
// Starts mock-api (port 4000), waits for it to answer, runs the given command,
// then shuts the server down. Exit code mirrors the command's.
//
//   node scripts/with-mock-api.mjs flutter test
//
// `--server <file>` / `--port <n>` (before the command) start another entry
// of mock-api/ on another port, e.g. the graphql-http + graphql-sse server:
//
//   node scripts/with-mock-api.mjs --server graphql-http-server.mjs --port 4001 \
//     flutter test --dart-define=SLING_API=http://localhost:4001/graphql
//
// Set MOCK_API_REUSE=1 to silence the notice when a server is already up.

import { spawn } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const mockDir = join(root, 'mock-api');
const argv = process.argv.slice(2);
let serverFile = 'server.mjs';
let port = 4000;
while (argv[0] === '--server' || argv[0] === '--port') {
  const [flag, value] = argv.splice(0, 2);
  if (flag === '--server') serverFile = value;
  else port = Number(value);
}
const url = `http://localhost:${port}/graphql`;
const [cmd, ...args] = argv;

if (!cmd) {
  console.error('usage: with-mock-api.mjs [--server <file>] [--port <n>] <command> [args...]');
  process.exit(2);
}

async function isUp() {
  try {
    const r = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ query: '{ __typename }' }),
    });
    return r.ok;
  } catch {
    return false;
  }
}

function run(command, argv, opts = {}) {
  return new Promise((resolve) => {
    const p = spawn(command, argv, { stdio: 'inherit', ...opts });
    p.on('exit', (code) => resolve(code ?? 1));
  });
}

let server;
if (await isUp()) {
  if (!process.env.MOCK_API_REUSE) {
    console.error(`mock-api already listening on ${url}; reusing it (set MOCK_API_REUSE=1 to silence).`);
  }
} else {
  // Not installed yet, or a dependency was added since.
  const pkg = JSON.parse(readFileSync(join(mockDir, 'package.json'), 'utf8'));
  const deps = Object.keys({ ...pkg.dependencies, ...pkg.devDependencies });
  if (deps.some((d) => !existsSync(join(mockDir, 'node_modules', d)))) {
    const code = await run('npm', ['ci', '--no-audit', '--no-fund'], { cwd: mockDir });
    if (code !== 0) process.exit(code);
  }
  // A fast launch sequence keeps the subscription test short.
  server = spawn('node', [serverFile], {
    cwd: mockDir,
    stdio: 'inherit',
    env: { SEQUENCE_MS: '700', ...process.env, PORT: String(port) },
  });
  const deadline = Date.now() + 20_000;
  while (!(await isUp())) {
    if (Date.now() > deadline) {
      console.error(`mock-api (${serverFile}) did not come up within 20s`);
      server.kill();
      process.exit(1);
    }
    await new Promise((r) => setTimeout(r, 200));
  }
}

const code = await run(cmd, args);
server?.kill();
process.exit(code);
