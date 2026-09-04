#!/usr/bin/env node
/**
 * validate-deck.mjs: judge a generated deck with Rappel's own validator.
 *
 * There is exactly one definition of a valid deck and it lives in the Rappel
 * repo: js/validate-deck.js, which the browser imports before a fetched
 * document goes anywhere near persistent storage, behind tools/validate-deck.mjs
 * on the command line. This script finds that file and calls it, so a deck this
 * accepts is a deck the engine accepts.
 *
 * What it adds is the half a schema cannot see. The largest is --against: note
 * ids are the review ledger's foreign keys, so a rebuild that renumbers them
 * discards a person's study history while producing a file that validates
 * perfectly. Nothing in the schema can catch that, because both versions are
 * individually correct.
 *
 * Usage:
 *   node validate-deck.mjs <deck.json> [--against <previous.json>] [--site <rappel-site-dir>]
 *
 * Exit: 0 clean, 1 findings, 2 Rappel's validator could not be found or read.
 * Exit 2 matters: a run that checked nothing must never read as a pass.
 */

import { readFile, access } from 'node:fs/promises';
import { dirname, join, resolve, basename } from 'node:path';
import { pathToFileURL } from 'node:url';

function usage(message) {
  if (message) console.error(`validate-deck: ${message}`);
  console.error('usage: validate-deck.mjs <deck.json> [--against <previous.json>] [--site <dir>]');
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
const deckPath = positional[0];
if (!deckPath) usage('no deck file given');

const exists = async (p) => { try { await access(p); return true; } catch { return false; } };
const RELATIVE_VALIDATOR = join('tools', 'validate-deck.mjs');

/**
 * Find the Rappel checkout. Every layout this supports is named here, because a
 * detection gate fails closed: when it misses, the caller gets exit 2 and a
 * message rather than a silent pass.
 *   1. --site, which always wins
 *   2. any ancestor of the deck file (a deck already inside data/decks)
 *   3. the working directory, then projects/rappel-site and rappel-site under
 *      it, which are the monorepo and standalone-clone layouts
 */
async function findSite() {
  const tries = [];
  if (opts.get('site')) tries.push(resolve(opts.get('site')));
  for (let dir = dirname(resolve(deckPath)); ; dir = dirname(dir)) {
    tries.push(dir);
    if (dirname(dir) === dir) break;
  }
  const cwd = process.cwd();
  tries.push(cwd, join(cwd, 'projects', 'rappel-site'), join(cwd, 'rappel-site'));
  for (const dir of tries) if (await exists(join(dir, RELATIVE_VALIDATOR))) return dir;
  return null;
}

const site = await findSite();
if (!site) {
  console.error('validate-deck: no Rappel checkout found, so nothing was checked.');
  console.error(`  Looked for ${RELATIVE_VALIDATOR} beside the deck, in the working directory,`);
  console.error('  and at projects/rappel-site. Pass --site <dir> to name it.');
  process.exit(2);
}

let V;
try {
  V = await import(pathToFileURL(join(site, RELATIVE_VALIDATOR)).href);
} catch (e) {
  console.error(`validate-deck: cannot load ${join(site, RELATIVE_VALIDATOR)}: ${e.message}`);
  process.exit(2);
}

const findings = [];
const err = (where, message) => findings.push({ level: 'error', where, message });
const warn = (where, message) => findings.push({ level: 'warn', where, message });

// The schema half, entirely theirs. validateFile picks deck, catalog or ledger
// from the document's own format field, so there is one dispatch rather than two.
// validateFile labels findings with a path relative to the Rappel repo, which
// is right for a deck inside it and unreadable for one being drafted outside,
// so the summary line below names the file the caller actually passed.
const { report } = await V.validateFile(resolve(deckPath));
for (const w of report.warnings || []) warn(w.path, w.message);
for (const e of report.errors || []) err(e.path, e.message);

let deck = null;
try { deck = JSON.parse(await readFile(resolve(deckPath), 'utf8')); } catch { deck = null; }

if (deck && deck.format === 'neo-deck/1') {
  const label = basename(deckPath);

  // ── C10.3 rule 1: note ids are never reassigned ───────────────
  // The check this script exists for. A renumbered deck validates perfectly and
  // throws away every review the ledger recorded against the old ids.
  const againstPath = opts.get('against');
  if (againstPath) {
    let old = null;
    try { old = JSON.parse(await readFile(resolve(againstPath), 'utf8')); }
    catch (e) { usage(`cannot read --against ${againstPath}: ${e.message}`); }
    const oldFirst = (old.fields || [])[0];
    const newFirst = (deck.fields || [])[0];
    const nowById = new Map((deck.notes || []).map((n) => [n.id, n]));
    let dropped = 0;
    let moved = 0;
    for (const note of old.notes || []) {
      const still = nowById.get(note.id);
      if (!still) {
        dropped += 1;
        if (dropped <= 5) {
          err(`${label}.notes`, `id "${note.id}" is gone. Every card ${note.id}:<template> loses its `
            + 'scheduling, because the ledger keys on that string (C4.2 rule 1)');
        }
        continue;
      }
      const before = String((note.f || {})[oldFirst] ?? '');
      const after = String((still.f || {})[newFirst] ?? '');
      if (before !== after) {
        moved += 1;
        if (moved <= 5) {
          err(`${label}.notes`, `id "${note.id}" now holds ${JSON.stringify(after)} where it held `
            + `${JSON.stringify(before)}. A learner's history for that card is attached to the wrong material`);
        }
      }
    }
    if (dropped > 5) err(`${label}.notes`, `and ${dropped - 5} further id(s) dropped`);
    if (moved > 5) err(`${label}.notes`, `and ${moved - 5} further id(s) reused for different material`);
    if (!dropped && !moved) {
      console.log(`  ok    every one of the ${(old.notes || []).length} note id(s) in ${basename(againstPath)} survived`);
    }
  }

  // ── C10.3 rule 2: a licence is a decision, not a default ──────
  if (deck.licence === undefined) {
    warn(`${label}.licence`, 'is absent. Say where the material came from, even when the answer is '
      + '"mine": a deck with no licence is one nobody else can reuse');
  } else if (String(deck.licence).startsWith('CC-BY') && !deck.source) {
    warn(`${label}.source`, 'is absent on a CC-BY deck. The attribution wording renders, but a reader '
      + 'cannot reach the original');
  }

  // ── C10.3 rule 3: templates earn their place ──────────────────
  const templates = deck.templates || [];
  const notes = deck.notes || [];
  let cards = 0;
  for (const note of notes) {
    for (const t of templates) {
      if (t.kind !== 'cloze') { cards += 1; continue; }
      const text = String((note.f || {})[t.text_field] || '');
      const ordinals = new Set();
      const re = /\{\{c(\d+)::/g;
      let m;
      while ((m = re.exec(text)) !== null) ordinals.add(m[1]);
      cards += ordinals.size;
    }
  }
  if (cards > 150) {
    warn(`${label}.templates`, `${templates.length} template(s) over ${notes.length} note(s) is ${cards} cards, `
      + 'which is about a month of daily reviews from one paste. Drop a template, or split the deck');
  }

  // ── C10.3 rule 4: distractors from siblings where siblings exist ──
  const hasTags = notes.some((n) => Array.isArray(n.tags) && n.tags.length);
  for (const t of templates) {
    if (t.kind === 'choice' && t.distractors !== 'siblings' && hasTags) {
      warn(`${label}.templates.${t.id}`, 'draws distractors from the whole deck while the notes carry tags. '
        + 'A distractor drawn at random is not a discriminator; use "siblings"');
    }
  }

  // ── A12: a deck the engine ships has to be in the catalog ─────
  const catalogPath = join(site, 'data', 'decks', 'index.json');
  if (resolve(deckPath).startsWith(join(site, 'data', 'decks')) && await exists(catalogPath)) {
    try {
      const catalog = JSON.parse(await readFile(catalogPath, 'utf8'));
      if (!(catalog.decks || []).some((d) => d && d.id === deck.id)) {
        err('data/decks/index.json', `has no entry for "${deck.id}", so ?deck=${deck.id} finds nothing `
          + '(neo-deck-index/1, C12 A12)');
      }
    } catch (e) {
      err('data/decks/index.json', e.message);
    }
  }

  // ── C10.3 rule 5: no em dashes, no banned words ───────────────
  const EM_DASH = String.fromCharCode(0x2014);
  const BANNED = ['powerful', 'seamless', 'leverages', 'robust', 'utilize'];
  const scan = (value, path) => {
    if (typeof value === 'string') {
      if (value.includes(EM_DASH)) err(`${label}.${path}`, 'contains an em dash. Rewrite the sentence, never substitute the character');
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
  scan(deck, '');
}

for (const f of findings) console.log(`  ${f.level === 'error' ? 'ERROR' : 'warn '} ${f.where}: ${f.message}`);
const errors = findings.filter((f) => f.level === 'error').length;
const warnings = findings.length - errors;
console.log('');
console.log(`  ${deckPath}: ${errors} error(s), ${warnings} warning(s)`);
console.log(`  checked against ${join(site, RELATIVE_VALIDATOR)}`);
process.exit(errors ? 1 : 0);
