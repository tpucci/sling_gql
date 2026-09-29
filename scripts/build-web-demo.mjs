#!/usr/bin/env node
// Builds the example's web version for the docs site ("Try it"):
//
//   1. bundles the mock API for the browser (mock-api → example/web/mock-api.js),
//   2. `flutter build web` with the site's base path,
//   3. copies the result to website/public/demo/ (served at /sling_gql/demo/).
//
//   node scripts/build-web-demo.mjs          # or: melos run build:web
//   node scripts/build-web-demo.mjs --no-copy   # stop after step 2
//
// The site builds without it (the Try-it page then shows a missing demo);
// website.yml runs it before `astro build`.

import { spawn } from 'node:child_process';
import { cpSync, existsSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const mockDir = join(root, 'mock-api');
const exampleDir = join(root, 'example');
const target = join(root, 'website', 'public', 'demo');
const baseHref = '/sling_gql/demo/';

function run(command, argv, cwd) {
  return new Promise((resolve, reject) => {
    const p = spawn(command, argv, { cwd, stdio: 'inherit' });
    p.on('error', reject);
    p.on('exit', (code) =>
      code === 0 ? resolve() : reject(new Error(`${command} ${argv.join(' ')} exited with ${code}`)),
    );
  });
}

if (!existsSync(join(mockDir, 'node_modules'))) {
  await run('npm', ['ci', '--no-audit', '--no-fund'], mockDir);
}
await run('npm', ['run', 'build:browser'], mockDir);
await run(
  'flutter',
  ['build', 'web', '--release', '--base-href', baseHref, '--no-wasm-dry-run'],
  exampleDir,
);

if (!process.argv.includes('--no-copy')) {
  rmSync(target, { recursive: true, force: true });
  cpSync(join(exampleDir, 'build', 'web'), target, { recursive: true });
  console.log(`Web demo copied to ${target}`);
}
