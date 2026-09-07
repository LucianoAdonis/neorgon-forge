#!/usr/bin/env node
/**
 * validate-set.mjs: judge a generated set with Quiz's own validator.
 *
 * There is exactly one definition of a valid set and it lives in the Quiz repo:
 * js/validate-set.js, which the engine imports before a fetched document is
 * played, behind tools/validate-set.mjs on the command line. This script finds
 * that file and calls it, so a set this accepts is a set the engine accepts, and
 * the two cannot drift into disagreeing about a document that plays fine.
 *
 * What it adds is the half a schema cannot see, and the largest of it is
 * --against. An item id is what quiz:answer carries as itemId and what a host
 * stores as the evidence a chapter goal is gated on. A rebuilt set with
 * renumbered ids validates perfectly and orphans every attempt anybody made,
 * because both versions are individually correct. Nothing in the schema can
 * catch that. The rest are craft rules: a round whose prompt shows the answer, a
 * sound row too thin to draw its own feedback strip, a library index that never
 * learned about the set.
 *
 * Usage:
 *   node validate-set.mjs <set.json> [--against <previous.json>] [--site <quiz-site-dir>]
 *
 * Exit: 0 clean, 1 findings, 2 Quiz's validator could not be found or read.
 * Exit 2 matters: a run that checked nothing must never read as a pass.
 */

import { readFile, access } from 'node:fs/promises';
import { dirname, join, resolve, basename } from 'node:path';
import { pathToFileURL } from 'node:url';

function usage(message) {
  if (message) console.error(`validate-set: ${message}`);
  console.error('usage: validate-set.mjs <set.json> [--against <previous.json>] [--site <dir>]');
  process.exit(2);
}

const argv = process.argv.slice(2);
const opts = new Map();
const positional = [];
for (let i = 0; i < argv.length; i += 1) {
  const a = argv[i];
  if (a.startsWith('--')) {
    const eq = a.indexOf('=');
    if (eq > 0) opts.set(a.slice(2, eq), a.slice(eq + 1));
    else { opts.set(a.slice(2), argv[i + 1]); i += 1; }
    continue;
  }
  positional.push(a);
}
const setPath = positional[0];
if (!setPath) usage('no set file given');

const exists = async (p) => { try { await access(p); return true; } catch { return false; } };
const RELATIVE_VALIDATOR = join('tools', 'validate-set.mjs');

/**
 * Find the Quiz checkout. Every layout this supports is named here, because a
 * detection gate fails closed: when it misses, the caller gets exit 2 and a
 * message rather than a silent pass.
 *   1. --site, which always wins
 *   2. any ancestor of the set file (a set already inside data/sets)
 *   3. the working directory, then projects/quiz-site and quiz-site under it,
 *      which are the monorepo and standalone-clone layouts
 */
async function findSite() {
  const tries = [];
  if (opts.get('site')) tries.push(resolve(opts.get('site')));
  for (let dir = dirname(resolve(setPath)); ; dir = dirname(dir)) {
    tries.push(dir);
    if (dirname(dir) === dir) break;
  }
  const cwd = process.cwd();
  tries.push(cwd, join(cwd, 'projects', 'quiz-site'), join(cwd, 'quiz-site'));
  for (const dir of tries) if (await exists(join(dir, RELATIVE_VALIDATOR))) return dir;
  return null;
}

const site = await findSite();
if (!site) {
  console.error('validate-set: no Quiz checkout found, so nothing was checked.');
  console.error(`  Looked for ${RELATIVE_VALIDATOR} beside the set, in the working directory,`);
  console.error('  and at projects/quiz-site. Pass --site <dir> to name it.');
  process.exit(2);
}

// The site validator ends with a guard on argv[1] ending in validate-set.mjs,
// which is correct for a file run directly and a trap for a file imported by a
// script of the same name: it would run the site's whole CLI on our arguments
// and exit before we printed anything. Blank argv[1] for the length of the
// import and put it back.
let V;
const argv1 = process.argv[1];
try {
  process.argv[1] = '';
  V = await import(pathToFileURL(join(site, RELATIVE_VALIDATOR)).href);
} catch (e) {
  console.error(`validate-set: cannot load ${join(site, RELATIVE_VALIDATOR)}: ${e.message}`);
  process.exit(2);
} finally {
  process.argv[1] = argv1;
}

const findings = [];
const err = (where, message) => findings.push({ level: 'error', where, message });
const warn = (where, message) => findings.push({ level: 'warn', where, message });

// The schema half, entirely theirs. validateFile picks the set or the index
// schema from the document's own format field, so there is one dispatch.
const { report } = await V.validateFile(resolve(setPath));
for (const w of report.warnings || []) warn(w.path, w.message);
for (const e of report.errors || []) err(e.path, e.message);

let set = null;
try { set = JSON.parse(await readFile(resolve(setPath), 'utf8')); } catch { set = null; }

// The identity of an item, per game: the face a learner would recognise it by,
// and therefore what an id has to keep pointing at across a rebuild.
const IDENTITY = { beats: 'kana', sound: 'kana', pairs: 'left', order: 'line' };
const fold = typeof V.fold === 'function'
  ? V.fold
  : (s) => String(s).trim().toLowerCase().normalize('NFD').replace(/\p{M}/gu, '');

if (set && set.format === 'neo-quiz-set/1') {
  const label = basename(setPath);
  const items = Array.isArray(set.items) ? set.items : [];
  const idField = IDENTITY[set.game];

  // ── Rule 1: an item id is a foreign key, not a row number ─────
  // The check this script exists for. A renumbered set validates perfectly and
  // every attempt recorded against the old ids is orphaned, silently.
  const againstPath = opts.get('against');
  if (againstPath) {
    let old = null;
    try { old = JSON.parse(await readFile(resolve(againstPath), 'utf8')); }
    catch (e) { usage(`cannot read --against ${againstPath}: ${e.message}`); }
    if (old.id !== set.id) {
      err(`${label}.id`, `is "${set.id}" where ${basename(againstPath)} is "${old.id}". Scores are keyed by the `
        + 'set id, so a rename is a reset with no message');
    }
    if (old.version === set.version && JSON.stringify(old.items) !== JSON.stringify(set.items)) {
      err(`${label}.version`, `is still ${set.version} while the items changed. A host compares the version to `
        + 'notice the set moved under a learner');
    }
    const nowById = new Map(items.map((it) => [it.id, it]));
    const oldField = IDENTITY[old.game] || idField;
    let dropped = 0;
    let moved = 0;
    for (const it of old.items || []) {
      const still = nowById.get(it.id);
      if (!still) {
        dropped += 1;
        if (dropped <= 5) {
          err(`${label}.items`, `id "${it.id}" is gone. Every attempt recorded with that itemId is orphaned, `
            + 'and a chapter gated on those attempts silently loses them');
        }
        continue;
      }
      const before = String(it[oldField] ?? '');
      const after = String(still[idField] ?? '');
      if (before !== after) {
        moved += 1;
        if (moved <= 5) {
          err(`${label}.items`, `id "${it.id}" now holds ${JSON.stringify(after)} where it held `
            + `${JSON.stringify(before)}. A learner's history for that item is attached to different material`);
        }
      }
    }
    if (dropped > 5) err(`${label}.items`, `and ${dropped - 5} further id(s) dropped`);
    if (moved > 5) err(`${label}.items`, `and ${moved - 5} further id(s) reused for different material`);
    if (!dropped && !moved) {
      console.log(`  ok    every one of the ${(old.items || []).length} item id(s) in ${basename(againstPath)} survived`);
    }
  }

  // ── Rule 2: the prompt never contains the answer ──────────────
  // The format refuses the pairs case by itself. These are the two it cannot:
  // a beats word that is its own reading, and a sound item with nothing to draw
  // a plausible option from.
  if (set.game === 'beats') {
    // Counted over the set, not flagged per item, and on purpose. A loanword
    // whose source spelling happens to equal its romaji is a coincidence the
    // author cannot fix (anime, banana, pen), so per item this fires on correct
    // material. Over half the set it is not a coincidence: the word column was
    // filled with the reading, and the prompt now spells out its own answer.
    const echoes = items.filter((it) => it.romaji && it.word && fold(it.word) === fold(it.romaji)).length;
    if (items.length >= 4 && echoes * 2 > items.length) {
      warn(`${label}.items`, `${echoes} of ${items.length} item(s) have a word equal to their romaji. word is shown `
        + 'before the answer and romaji is held back, so a word column filled with the reading prints the count '
        + 'on the prompt. Put the source word there');
    }
    const explained = items.filter((it) => it.explain).length;
    if (items.length && explained * 2 < items.length) {
      warn(`${label}.items`, `${items.length - explained} of ${items.length} item(s) carry no explain line, so a miss `
        + 'shows the tiles and no rule. Take the line from the source, or leave it null and say why');
    }
  }

  if (set.game === 'sound') {
    // A partial row is NOT checked, deliberately: the y row really has three
    // kana and the w row really has two, so a checker that calls those holes
    // fires on the most canonical set there is, and a checker that misfires on
    // correct material is one authors learn to switch off. What is checkable is
    // an item the engine has no grouping for at all.
    const ungrouped = items.filter((it) => !Array.isArray(it.distractors) && !it.row
      && (it.column === null || it.column === undefined || it.column === ''));
    if (ungrouped.length) {
      warn(`${label}.items`, `${ungrouped.length} item(s) carry no distractors and neither a row nor a column `
        + `(first: ${ungrouped[0].id}), so the engine has no siblings to draw a tempting option from. `
        + 'An option nobody would pick is a free point');
    }
    if (items.length && !items.some((it) => it.row)) {
      warn(`${label}.items`, 'no item carries a row, so a miss can never show the row strip, which is this '
        + 'game\'s whole explanation. Give the items the grid they sit in');
    }
  }

  if (set.game === 'order') {
    const glossed = items.filter((it) => it.gloss).length;
    if (items.length && glossed === 0) {
      warn(`${label}.items`, 'no item carries a gloss, so a miss shows the marked line and nothing about what it '
        + 'means. That is legal; say it was a choice');
    }
  }

  // ── Rule 3: a licence is a decision, not a default ────────────
  const licence = set.licence || {};
  if (String(licence.spdx || '').startsWith('CC-BY') && !licence.source) {
    warn(`${label}.licence.source`, 'is absent on a CC-BY set. The attribution renders, and a reader cannot reach '
      + 'the original');
  }

  // ── Rule 4: a set Quiz ships has to be in the library index ───
  const catalogPath = join(site, 'data', 'sets', 'index.json');
  if (resolve(setPath).startsWith(join(site, 'data', 'sets')) && await exists(catalogPath)) {
    try {
      const catalog = JSON.parse(await readFile(catalogPath, 'utf8'));
      const row = (catalog.sets || []).find((s) => s && s.id === set.id);
      if (!row) {
        err('data/sets/index.json', `has no entry for "${set.id}", so ?set=${set.id} finds nothing `
          + '(neo-quiz-set-index/1)');
      } else if (row.items !== items.length) {
        err('data/sets/index.json', `says "${set.id}" has ${row.items} item(s) and the file carries ${items.length}`);
      }
    } catch (e) {
      err('data/sets/index.json', e.message);
    }
  }

  // ── Rule 5: no banned words ───────────────────────────────────
  // The site's validator already refuses an em or en dash in any string, so
  // this is only the half it does not own.
  const BANNED = ['powerful', 'seamless', 'leverages', 'robust', 'utilize'];
  const scan = (value, path) => {
    if (typeof value === 'string') {
      const lower = value.toLowerCase();
      for (const word of BANNED) {
        if (new RegExp(`\\b${word}\\b`).test(lower)) err(`${label}.${path}`, `uses the banned word "${word}"`);
      }
      return;
    }
    if (Array.isArray(value)) { value.forEach((v, i) => scan(v, `${path}[${i}]`)); return; }
    if (value && typeof value === 'object') {
      for (const [k, v] of Object.entries(value)) scan(v, path ? `${path}.${k}` : k);
    }
  };
  scan(set, '');
}

for (const f of findings) console.log(`  ${f.level === 'error' ? 'ERROR' : 'warn '} ${f.where}: ${f.message}`);
const errors = findings.filter((f) => f.level === 'error').length;
const warnings = findings.length - errors;
console.log('');
console.log(`  ${setPath}: ${errors} error(s), ${warnings} warning(s)`);
console.log(`  checked against ${join(site, RELATIVE_VALIDATOR)}`);
process.exit(errors ? 1 : 0);
