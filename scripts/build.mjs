#!/usr/bin/env node
// Inlines <egg>/install.sh into <egg>/egg.base.json -> <egg>/egg-<egg>.json. --check fails if stale.
import { readdirSync, readFileSync, statSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const check = process.argv.includes('--check');
let stale = 0;
for (const dir of readdirSync('.').filter((d) => existsSync(join(d, 'egg.base.json')) && statSync(d).isDirectory())) {
  const egg = JSON.parse(readFileSync(join(dir, 'egg.base.json'), 'utf8'));
  egg.scripts.installation.content = readFileSync(join(dir, 'install.sh'), 'utf8');
  const out = join(dir, `egg-${dir}.json`);
  const json = JSON.stringify(egg, null, 2) + '\n';
  if (check) {
    if (!existsSync(out) || readFileSync(out, 'utf8') !== json) {
      console.error(`${out} is out of date: run node scripts/build.mjs`);
      stale++;
    }
  } else {
    writeFileSync(out, json);
    console.log(`built ${out}`);
  }
}
process.exit(stale ? 1 : 0);
