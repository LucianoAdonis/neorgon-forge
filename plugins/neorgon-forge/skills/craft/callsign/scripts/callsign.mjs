#!/usr/bin/env node
/**
 * callsign.mjs: run Callsign's own command line from the skill.
 *
 * A Callsign name has exactly one definition, the engine in the site repo, so
 * this finds a checkout and runs its tools/callsign.mjs instead of carrying a
 * copy that would drift the first time the site's grammar moves.
 *
 * Usage:
 *   node callsign.mjs [--site <callsign-site dir>] <command> [args] [options]
 * Every argument except --site goes to the site's CLI unchanged; `--help` lists them.
 *
 * Exit: whatever the site's CLI returns (0 done, 2 usage error or unknown id),
 * or 2 when no usable checkout can be found, because a run that generated
 * nothing must never read as a success. Needs Node 22 LTS or later: the engine
 * is plain .js modules, which older Node cannot load from a clone.
 */
import { access } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const CLI = join('tools', 'callsign.mjs');
// A directory counts as a Callsign checkout only when the engine sits beside the CLI.
const ENGINE = [join('js', 'forge.js'), join('js', 'links.js')];
const argv = process.argv.slice(2);

let site = null;
const at = argv.findIndex((a) => a === '--site' || a.startsWith('--site='));
if (at >= 0) {
  const inline = argv[at].startsWith('--site=');
  site = inline ? argv[at].slice('--site='.length) : argv[at + 1];
  argv.splice(at, inline ? 1 : 2);
  if (!site) {
    console.error('callsign: --site needs a directory');
    process.exit(2);
  }
}

const exists = async (p) => { try { await access(p); return true; } catch { return false; } };

const isEngine = async (dir) => (await Promise.all(ENGINE.map((f) => exists(join(dir, f))))).every(Boolean);

/**
 * Every layout this supports is named here, because a detection gate fails
 * closed: when it misses, the caller gets exit 2 and a message, never a name.
 *   1. --site, which is the only place looked at when it is given
 *   2. the working directory and each of its parents (run from inside the site)
 *   3. projects/callsign-site and callsign-site under the working directory and
 *      under each parent, which are the monorepo and standalone-clone layouts
 * Returns { dir } for a usable checkout, { old } for one that predates the
 * command line, or null.
 */
async function findSite() {
  const tries = [];
  if (site) tries.push(resolve(site));
  else {
    for (let dir = process.cwd(); ; dir = dirname(dir)) {
      tries.push(dir, join(dir, 'projects', 'callsign-site'), join(dir, 'callsign-site'));
      if (dirname(dir) === dir) break;
    }
  }
  let old = null;
  for (const dir of tries) {
    if (!(await isEngine(dir))) continue;
    if (await exists(join(dir, CLI))) return { dir };
    old ??= dir;
  }
  return old ? { old } : null;
}

const fail = (...lines) => { lines.forEach((l) => console.error(l)); process.exit(2); };

const found = await findSite();
if (found?.old) {
  fail(`callsign: ${found.old} is a Callsign checkout from before its command line, so nothing was generated.`,
    '  Run git pull there, or pass --site <dir> for a newer checkout.');
}
if (!found) {
  fail('callsign: no Callsign checkout found, so nothing was generated.',
    site
      ? `  ${resolve(site)} is not a Callsign checkout: it needs ${CLI} beside ${ENGINE.join(' and ')}.`
      : '  Looked in the working directory and its parents, and in projects/callsign-site and callsign-site under each.',
    '  Clone https://github.com/energon-a-secas/callsign-site, or pass --site <dir>.');
}

const file = join(found.dir, CLI);
let cli;
try {
  cli = await import(pathToFileURL(file).href);
} catch (e) {
  fail(`callsign: cannot load ${file}: ${e.message}`,
    ...(e instanceof SyntaxError ? [`  This Node (${process.version}) cannot load the engine's .js modules from a clone; use Node 22 LTS or later.`] : []));
}
// Only a module that says it is Callsign's command line is trusted to hand back names.
if (typeof cli.main !== 'function' || !String(cli.USAGE).startsWith('usage: callsign') || !Number.isInteger(cli.GRAMMAR)) {
  fail(`callsign: ${file} is not the Callsign command line this skill expects; pull the checkout, or pass --site <dir>.`);
}
process.exitCode = await cli.main(argv);
