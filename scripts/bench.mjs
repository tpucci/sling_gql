#!/usr/bin/env node
// Runs the read-path and persistence benchmarks and fails on a large
// regression against scripts/bench-baseline.json (CI's bench job).
//
//   node scripts/bench.mjs                 # check (5 runs, fail above 1.5×)
//   node scripts/bench.mjs --update        # re-measure and rewrite the baseline
//   node scripts/bench.mjs --runs 3 --out bench-results.json
//
// Every metric is a ratio to work measured in the same run on the same
// machine (jsonDecode of the same response, plain sqflite inserts/reads of
// the same rows), so a faster or slower machine moves numerator and
// denominator together. Each benchmark runs in a fresh `flutter test`
// process `--runs` times; the median of the runs is compared, so one noisy
// run (a GC pause, a busy CI neighbour) cannot fail the check. A metric
// fails when it is more than `--threshold` times its baseline (default from
// the baseline file, 1.5): only large regressions, by design.

import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const baselinePath = join(root, 'scripts', 'bench-baseline.json');

const benches = [
  { name: 'read path', cwd: join(root, 'example'), file: 'benchmark/bench_test.dart', out: 'read_path.json' },
  {
    name: 'persistence',
    cwd: join(root, 'packages', 'sling_gql_sqflite'),
    file: 'benchmark/persistence_bench_test.dart',
    out: 'persistence.json',
  },
];

const argv = process.argv.slice(2);
const flag = (name) => argv.includes(name);
const option = (name) => {
  const i = argv.indexOf(name);
  return i >= 0 ? argv[i + 1] : undefined;
};
const update = flag('--update');
const runs = Number(option('--runs') ?? 5);
const outPath = option('--out');

let baseline;
try {
  baseline = JSON.parse(readFileSync(baselinePath, 'utf8'));
} catch {
  if (!update) {
    console.error(`No baseline at ${baselinePath}: run with --update first.`);
    process.exit(2);
  }
}
const threshold = Number(option('--threshold') ?? baseline?.threshold ?? 1.5);

const samples = {};
for (let run = 1; run <= runs; run++) {
  for (const bench of benches) {
    const dir = mkdtempSync(join(tmpdir(), 'sling_bench_'));
    process.stdout.write(`run ${run}/${runs}: ${bench.name}… `);
    const result = spawnSync('flutter', ['test', bench.file], {
      cwd: bench.cwd,
      env: { ...process.env, SLING_BENCH_OUT: dir },
      encoding: 'utf8',
    });
    if (result.status !== 0) {
      console.log('failed');
      console.error(result.stdout, result.stderr);
      process.exit(1);
    }
    const metrics = JSON.parse(readFileSync(join(dir, bench.out), 'utf8'));
    rmSync(dir, { recursive: true, force: true });
    for (const [key, value] of Object.entries(metrics)) {
      (samples[key] ??= []).push(value);
    }
    console.log('ok');
  }
}

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = sorted.length >> 1;
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
};
const current = Object.fromEntries(
  Object.entries(samples).map(([key, values]) => [key, Number(median(values).toFixed(4))]),
);

if (outPath) {
  writeFileSync(outPath, `${JSON.stringify({ runs, samples, median: current }, null, 2)}\n`);
}

if (update) {
  const next = {
    _comment:
      'Medians of `node scripts/bench.mjs --update`: each metric is a cost divided by a ' +
      'reference cost measured in the same run (lower is faster). The bench job fails when ' +
      'a median exceeds `threshold` × its value here.',
    threshold,
    runs,
    measuredOn: `${process.platform}-${process.arch}`,
    metrics: current,
  };
  writeFileSync(baselinePath, `${JSON.stringify(next, null, 2)}\n`);
  console.log(`\nBaseline written to ${baselinePath}:`);
  console.table(current);
  process.exit(0);
}

const rows = [];
let failed = false;
for (const [key, base] of Object.entries(baseline.metrics)) {
  const value = current[key];
  if (value === undefined) {
    rows.push({ metric: key, baseline: base, current: 'missing', ratio: '', verdict: 'FAIL' });
    failed = true;
    continue;
  }
  const ratio = value / base;
  const regressed = ratio > threshold;
  failed ||= regressed;
  rows.push({
    metric: key,
    baseline: base,
    current: value,
    ratio: `${ratio.toFixed(2)}×`,
    verdict: regressed ? 'FAIL' : 'ok',
  });
}
for (const key of Object.keys(current)) {
  if (!(key in baseline.metrics)) {
    rows.push({ metric: key, baseline: 'none', current: current[key], ratio: '', verdict: 'new (update the baseline)' });
  }
}
console.log(`\nMedians of ${runs} runs vs ${baselinePath} (fail above ${threshold}×):`);
console.table(rows);
if (failed) {
  console.error(
    `A metric regressed by more than ${threshold}×. If the slowdown is intended, ` +
      'rerun with --update and commit scripts/bench-baseline.json.',
  );
  process.exit(1);
}
