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
 * or 2 when no checkout can be found, because a run that generated nothing must
 * never read as a success.
 */
import { access } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const CLI = join('tools', 'callsign.mjs');
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

/**
 * Every layout this supports is named here, because a detection gate fails
 * closed: when it misses, the caller gets exit 2 and a message, never a name.
 *   1. --site, which is the only place looked at when it is given
 *   2. the working directory and each of its parents (run from inside the site)
 *   3. projects/callsign-site and callsign-site under the working directory,
 *      which are the monorepo and standalone-clone layouts
 */
async function findSite() {
  if (site) return (await exists(join(resolve(site), CLI))) ? resolve(site) : null;
  const tries = [];
  for (let dir = process.cwd(); ; dir = dirname(dir)) {
    tries.push(dir);
    if (dirname(dir) === dir) break;
  }
  tries.push(join(process.cwd(), 'projects', 'callsign-site'), join(process.cwd(), 'callsign-site'));
  for (const dir of tries) if (await exists(join(dir, CLI))) return dir;
  return null;
}

const dir = await findSite();
if (!dir) {
  console.error('callsign: no Callsign checkout found, so nothing was generated.');
  console.error(site
    ? `  ${resolve(site)} has no ${CLI}.`
    : `  Looked for ${CLI} in the working directory, its parents, projects/callsign-site and callsign-site.`);
  console.error('  Clone https://github.com/energon-a-secas/callsign-site, or pass --site <dir>.');
  process.exit(2);
}

let cli;
try {
  cli = await import(pathToFileURL(join(dir, CLI)).href);
} catch (e) {
  console.error(`callsign: cannot load ${join(dir, CLI)}: ${e.message}`);
  process.exit(2);
}
if (typeof cli.main !== 'function') {
  console.error(`callsign: ${join(dir, CLI)} exports no main(); that checkout predates the skill, so pull it`);
  process.exit(2);
}
process.exitCode = await cli.main(argv);
