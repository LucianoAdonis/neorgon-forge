#!/usr/bin/env node
/**
 * validate-book.mjs: judge a generated Book with the site's own validator.
 *
 * There is exactly one definition of a valid Book and it lives in the Runcible
 * repo at tools/validate-book.mjs, which the shell also imports at load time.
 * This script finds that file and calls it. It never re-implements a rule, so
 * a Book this accepts is a Book the site accepts, and the two cannot drift into
 * disagreeing about a file that renders fine.
 *
 * What it adds on top is the half a schema cannot check: the house rules in
 * C9.3 that the skill enforces on itself. A goal that names a topic, a goal
 * whose evidence no exercise in the Book can ever produce, a catalog that never
 * got its one line, an em dash. Those are craft debts, not schema errors, and
 * they are reported as this script's own findings rather than pushed into the
 * site's validator, which belongs to the site.
 *
 * Usage:
 *   node validate-book.mjs <book-dir> [--site <runcible-site-dir>]
 *
 * Exit: 0 clean, 1 findings, 2 the site validator could not be found or read.
 * Exit 2 matters: a run that checked nothing must never read as a pass.
 */

import { readFile, access } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

function usage(message) {
  if (message) console.error(`validate-book: ${message}`);
  console.error('usage: validate-book.mjs <book-dir> [--site <runcible-site-dir>]');
  process.exit(2);
}

const argv = process.argv.slice(2);
let siteArg = null;
const positional = [];
for (let i = 0; i < argv.length; i += 1) {
  const a = argv[i];
  if (a === '--site') { siteArg = argv[i + 1]; i += 1; continue; }
  if (a.startsWith('--site=')) { siteArg = a.slice(7); continue; }
  if (!a.startsWith('-')) positional.push(a);
}
const bookDir = resolve(positional[0] || '.');

const exists = async (p) => { try { await access(p); return true; } catch { return false; } };
const RELATIVE_VALIDATOR = join('tools', 'validate-book.mjs');

/**
 * Find the Runcible checkout. Every layout this supports is named here, because
 * a detection gate fails closed: when it misses, the caller gets exit 2 and a
 * message rather than a silent pass.
 *   1. --site, which always wins
 *   2. any ancestor of the book directory (the normal case: books/<id> is
 *      inside the site)
 *   3. the working directory, then projects/runcible-site and runcible-site
 *      under it, which are the monorepo and standalone-clone layouts
 */
async function findSite() {
  const tries = [];
  if (siteArg) tries.push(resolve(siteArg));
  for (let dir = bookDir; ; dir = dirname(dir)) {
    tries.push(dir);
    if (dirname(dir) === dir) break;
  }
  const cwd = process.cwd();
  tries.push(cwd, join(cwd, 'projects', 'runcible-site'), join(cwd, 'runcible-site'));
  for (const dir of tries) {
    if (await exists(join(dir, RELATIVE_VALIDATOR))) return dir;
  }
  return null;
}

const site = await findSite();
if (!site) {
  console.error('validate-book: no Runcible checkout found, so nothing was checked.');
  console.error(`  Looked for ${RELATIVE_VALIDATOR} beside the book directory, in the working`);
  console.error('  directory, and at projects/runcible-site. Pass --site <dir> to name it.');
  process.exit(2);
}

// The site validator ends with `if (process.argv[1].endsWith('validate-book.mjs'))
// main(...)`, which is a correct guard for a file run directly and a trap for a
// file imported by a script of the same name: it would run the site's whole CLI
// on our arguments and exit before we printed anything. Blank argv[1] for the
// length of the import and put it back.
let V;
const argv1 = process.argv[1];
try {
  process.argv[1] = '';
  V = await import(pathToFileURL(join(site, RELATIVE_VALIDATOR)).href);
} catch (e) {
  console.error(`validate-book: cannot load ${join(site, RELATIVE_VALIDATOR)}: ${e.message}`);
  process.exit(2);
} finally {
  process.argv[1] = argv1;
}

const findings = [];
const err = (where, message) => findings.push({ level: 'error', where, message });
const warn = (where, message) => findings.push({ level: 'warn', where, message });

const readJson = async (p) => JSON.parse(await readFile(p, 'utf8'));
// Paths are printed relative to the site when they are inside it, which is the
// normal case, and printed whole when a Book is being scaffolded somewhere else.
const relative = (p) => (p.startsWith(`${site}/`) ? p.slice(site.length + 1) : p);

let manifest;
try {
  manifest = await readJson(join(bookDir, 'book.json'));
} catch (e) {
  console.error(`validate-book: cannot read ${join(bookDir, 'book.json')}: ${e.message}`);
  process.exit(2);
}

/** Report one of the site validator's reports under our own labels. */
function adopt(file, report) {
  for (const w of report.warnings || []) warn(`${file}: ${w.path}`, w.message);
  for (const e of report.errors || []) err(`${file}: ${e.path}`, e.message);
}

adopt(relative(join(bookDir, 'book.json')), V.validateManifest(manifest));

const chapterDocs = [];
for (const entry of manifest.chapters || []) {
  if (!entry || !entry.src) continue;
  const file = join(bookDir, entry.src);
  let doc;
  try {
    doc = await readJson(file);
  } catch (e) {
    err(relative(file), e.message);
    continue;
  }
  chapterDocs.push({ entry, doc, file: relative(file) });
  adopt(relative(file), V.validateChapter(doc, manifest));
  // The one join the schema cannot see: the id in the manifest and the id in
  // the file are two copies of one fact, and the scaffold exists because they
  // drift when a chapter is renamed by hand.
  if (doc.id !== entry.id) {
    err(`${relative(file)}: id`, `is "${doc.id}" but the manifest entry is "${entry.id}"`);
  }
}

// ── C1.1: one array entry plus a directory ──────────────────────
// The catalog is the sibling of the Book directory, not a fixed path under the
// site: that is what makes the C1.1 claim checkable for a Book being drafted
// outside a checkout as much as for one already in books/.
const catalogPath = join(dirname(bookDir), 'index.json');
if (await exists(catalogPath)) {
  let catalog = null;
  try { catalog = await readJson(catalogPath); } catch (e) { err('books/index.json', e.message); }
  if (catalog) {
    adopt('books/index.json', V.validateCatalog(catalog));
    const listed = (catalog.books || []).find((b) => b && b.id === manifest.id);
    if (!listed) {
      err('books/index.json', `has no entry for "${manifest.id}", so the Book exists on disk and nothing links to it. `
        + `Add: ${JSON.stringify({ id: manifest.id, title: manifest.title, glyph: manifest.glyph, state: 'ready' })}`);
    } else if (listed.glyph !== manifest.glyph) {
      warn('books/index.json', `lists glyph ${JSON.stringify(listed.glyph)} where book.json has ${JSON.stringify(manifest.glyph)}`);
    }
  }
}

// ── C9.3 rule 1: a goal is something the learner can do ─────────
// A short list of openers that name a state of mind rather than an observable
// act. Kept short on purpose: a checker that misfires on good prose is one
// authors learn to switch off.
const WEAK = ['learn', 'understand', 'know', 'study', 'review', 'explore', 'cover',
  'introduction', 'intro', 'overview', 'basics', 'familiarity', 'appreciate'];
const englishOf = (v) => (typeof v === 'string' ? v : (v && (v.en || v.es)) || '');

for (const { doc, file } of chapterDocs) {
  const statement = englishOf(doc.goal && doc.goal.statement).trim();
  const first = statement.toLowerCase().split(/[\s,.]+/)[0] || '';
  if (statement && WEAK.includes(first)) {
    // A warning, not an error, and deliberately so. The phrasing of a goal is a
    // craft debt rather than a broken file, and a checker that fails a build on
    // a sentence a person defends is one that gets switched off. Fix it or say
    // why not, the way quizmaster treats a missing explanation.
    warn(`${file}: goal.statement`, `opens with "${first}", which names a state of mind. C3.4 wants something `
      + 'the learner can be seen to do: "Play any major scale hands separately at 60 bpm", not "Understand scales"');
  }
  if (statement && statement.split(/\s+/).length < 5) {
    warn(`${file}: goal.statement`, `is ${statement.split(/\s+/).length} words: "${statement}". A goal short enough `
      + 'to be a topic usually is one');
  }
}

// ── C9.3 rule 2: evidence, and a skill something can actually produce ──
const producedSkills = new Set();
const deckChapters = new Set();
for (const { doc } of chapterDocs) {
  for (const rung of doc.rungs || []) {
    for (const ex of rung.exercises || []) {
      if (ex && ex.skill) producedSkills.add(ex.skill);
      if (ex && ex.type === 'deck') deckChapters.add(doc.id);
    }
  }
}
// The site validator already warns on a missing evidence block, so this adds
// only the fact it cannot see: which of those chapters gate a later one, and
// therefore leave a stretch of the ladder reachable by manual override alone.
const blockers = chapterDocs.filter(({ doc }) => !(doc.goal && doc.goal.evidence) && (manifest.chapters || []).some((c) => {
  const req = c && c.requires;
  const all = Array.isArray(req) ? req : (req && typeof req === 'object' ? Object.values(req).flat() : []);
  return all.includes(doc.id);
}));
if (blockers.length) {
  warn(`${relative(join(bookDir, 'book.json'))}: chapters`, `${blockers.map(({ doc }) => doc.id).join(', ')} `
    + 'carry no goal.evidence and gate a later chapter, so everything below them opens by manual override only (C3.4)');
}

for (const { doc, file } of chapterDocs) {
  const ev = doc.goal && doc.goal.evidence;
  if (!ev) continue;
  if (ev.skill && !producedSkills.has(ev.skill)) {
    const viaDeck = deckChapters.has(doc.id);
    const message = `is "${ev.skill}", which no exercise in this Book carries, so the goal can never be met`;
    if (viaDeck) {
      warn(`${file}: goal.evidence.skill`, `${message} unless an embedded deck's template declares it `
        + '(C4.3 amendment 2). Check the deck.');
    } else {
      err(`${file}: goal.evidence.skill`, message);
    }
  }
}

// ── C9.3 rule 3: a custom type has to earn itself ───────────────
for (const m of manifest.modules || []) {
  for (const id of (m.provides && m.provides.exercises) || []) {
    warn(`${relative(join(bookDir, 'book.json'))}: modules`, `registers the custom exercise type "${id}". C9.3 rule 3 `
      + 'asks for one sentence saying which of the eight generic types cannot express this drill');
  }
}

// ── C9.3 rule 5: no em dashes, no banned words ──────────────────
const EM_DASH = String.fromCharCode(0x2014);
const BANNED = ['powerful', 'seamless', 'leverages', 'robust', 'utilize'];
function scanStrings(value, path, report) {
  if (typeof value === 'string') {
    if (value.includes(EM_DASH)) report(path, 'contains an em dash. Rewrite the sentence, never substitute the character');
    const lower = value.toLowerCase();
    for (const word of BANNED) {
      if (new RegExp(`\\b${word}\\b`).test(lower)) report(path, `uses the banned word "${word}"`);
    }
    return;
  }
  if (Array.isArray(value)) { value.forEach((v, i) => scanStrings(v, `${path}[${i}]`, report)); return; }
  if (value && typeof value === 'object') {
    for (const [k, v] of Object.entries(value)) scanStrings(v, path ? `${path}.${k}` : k, report);
  }
}
scanStrings(manifest, '', (p, m) => err(`${relative(join(bookDir, 'book.json'))}: ${p}`, m));
for (const { doc, file } of chapterDocs) scanStrings(doc, '', (p, m) => err(`${file}: ${p}`, m));

// ── Report ──────────────────────────────────────────────────────
for (const f of findings) console.log(`  ${f.level === 'error' ? 'ERROR' : 'warn '} ${f.where} ${f.message}`);
const errors = findings.filter((f) => f.level === 'error').length;
const warnings = findings.length - errors;
console.log('');
console.log(`  ${relative(bookDir)}: ${chapterDocs.length} chapter file(s), ${errors} error(s), ${warnings} warning(s)`);
console.log(`  checked against ${join(site, RELATIVE_VALIDATOR)}`);
process.exit(errors ? 1 : 0);
