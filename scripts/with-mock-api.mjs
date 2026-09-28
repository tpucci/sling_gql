#!/usr/bin/env node
// Starts mock-api (port 4000), waits for it to answer, runs the given command,
// then shuts the server down. Exit code mirrors the command's.
//
//   node scripts/with-mock-api.mjs flutter test
//
// Set MOCK_API_REUSE=1 to skip starting the server when one is already up.

import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const mockDir = join(root, 'mock-api');
const url = 'http://localhost:4000/graphql';
const [cmd, ...args] = process.argv.slice(2);

if (!cmd) {
  console.error('usage: with-mock-api.mjs <command> [args...]');
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
  if (!existsSync(join(mockDir, 'node_modules'))) {
    const code = await run('npm', ['ci', '--no-audit', '--no-fund'], { cwd: mockDir });
    if (code !== 0) process.exit(code);
  }
  server = spawn('node', ['server.mjs'], { cwd: mockDir, stdio: 'inherit' });
  const deadline = Date.now() + 20_000;
  while (!(await isUp())) {
    if (Date.now() > deadline) {
      console.error('mock-api did not come up within 20s');
      server.kill();
      process.exit(1);
    }
    await new Promise((r) => setTimeout(r, 200));
  }
}

const code = await run(cmd, args);
server?.kill();
process.exit(code);
