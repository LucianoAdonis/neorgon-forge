#!/usr/bin/env node
/**
 * scaffold-book.mjs: a Book plan in, the files Runcible actually loads out.
 *
 * The skill writes the plan, which is all judgment: the ladder, the goals, the
 * rungs, the exercises. This script writes the joins, which are all mechanics:
 * the two `format` strings, the `src` path of every chapter file, the chapter
 * ids that have to agree in two places, each chapter's `data[]` gathered from
 * the pointers it actually uses, and the one catalog line. Those joins are
 * where a hand-built Book breaks, and none of them is a decision.
 *
 * It writes nothing outside the books directory it is given, and it refuses to
 * overwrite an existing Book without --force, because a Book on disk is
 * somebody's authored content and a regeneration is not a merge.
 *
 * Nothing here judges whether the output is valid. Run the validator next:
 *   node scripts/validate-book.mjs <books-dir>/<id>
 * which imports the site's own validator rather than holding a second opinion.
 *
 * Usage:
 *   node scaffold-book.mjs <plan.json> --out <books-dir> [--force] [--index]
 *
 * Exit: 0 written, 1 refused (something exists, or the plan cannot be wired),
 *       2 usage or environment error.
 */

import { readFile, writeFile, mkdir, access } from 'node:fs/promises';
import { join, resolve } from 'node:path';

const SLUG = /^[a-z0-9][a-z0-9-]*$/;

function usage(message) {
  if (message) console.error(`scaffold-book: ${message}`);
  console.error('usage: scaffold-book.mjs <plan.json> --out <books-dir> [--force] [--index]');
  process.exit(2);
}

const argv = process.argv.slice(2);
const flags = new Set(argv.filter((a) => a.startsWith('--') && !a.includes('=')));
let outDir = null;
const positional = [];
for (let i = 0; i < argv.length; i += 1) {
  const a = argv[i];
  if (a === '--out') { outDir = argv[i + 1]; i += 1; continue; }
  if (a.startsWith('--out=')) { outDir = a.slice(6); continue; }
  if (a.startsWith('--')) continue;
  positional.push(a);
}
const planPath = positional[0];
if (!planPath) usage('no plan file given');
if (!outDir) usage('no --out <books-dir> given; it is the site\'s books/ directory');

let plan;
try {
  plan = JSON.parse(await readFile(resolve(planPath), 'utf8'));
} catch (e) {
  usage(`cannot read ${planPath}: ${e.message}`);
}

const book = plan && plan.book;
const chapters = plan && plan.chapters;
if (!book || typeof book !== 'object') usage('the plan needs a "book" object');
if (!Array.isArray(chapters) || chapters.length === 0) usage('the plan needs a non-empty "chapters" array');
if (!SLUG.test(String(book.id || ''))) usage(`book.id "${book.id}" must be a lowercase slug: it is the directory name`);

const problems = [];
const seen = new Set();
for (const [i, c] of chapters.entries()) {
  if (!c || typeof c !== 'object') { problems.push(`chapters[${i}] is not an object`); continue; }
  if (!SLUG.test(String(c.id || ''))) problems.push(`chapters[${i}].id "${c.id}" must be a lowercase slug: it is the file name`);
  else if (seen.has(c.id)) problems.push(`chapters[${i}].id "${c.id}" is a duplicate, so two chapters would share one file`);
  seen.add(c.id);
}
if (problems.length) {
  for (const p of problems) console.error(`  ERROR ${p}`);
  process.exit(1);
}

const today = new Date().toISOString().slice(0, 10);
const version = book.version || today;

/** Every data pointer a chapter reaches for, so data[] is gathered rather than remembered. */
function pointersIn(chapter) {
  const out = new Set();
  const add = (p) => {
    if (typeof p !== 'string' || !p) return;
    const i = p.indexOf('#');
    out.add(i < 0 ? p : p.slice(0, i));
  };
  for (const rung of chapter.rungs || []) {
    for (const page of rung.pages || []) {
      if (typeof page.items === 'string') add(page.items);
      if (page.figure && page.figure.kind === 'svg') add(page.figure.src);
    }
    for (const ex of rung.exercises || []) {
      if (typeof ex.items === 'string') add(ex.items);
      // A deck src is fetched by the engine across origins, not by the shell
      // when the chapter opens, so it never belongs in the chapter's data[].
    }
  }
  return [...out].sort();
}

const manifestChapters = [];
const files = [];
for (const c of chapters) {
  const state = c.state || 'ready';
  const requires = c.requires === undefined ? [] : c.requires;
  if (state === 'planned') {
    // C1.3 rule 6: the ladder stays visible where it is not built, so the
    // title and the note ride in the manifest and no file is written.
    manifestChapters.push({ id: c.id, src: null, requires, state, title: c.title, note: c.note });
    continue;
  }
  manifestChapters.push({ id: c.id, src: `chapters/${c.id}.json`, requires, state });
  const doc = { format: 'neo-chapter/1', id: c.id, title: c.title, goal: c.goal, requires, state };
  if (c.estimate !== undefined) doc.estimate = c.estimate;
  const data = c.data === undefined ? pointersIn(c) : c.data;
  if (data.length) doc.data = data;
  doc.rungs = c.rungs || [];
  files.push({ path: `chapters/${c.id}.json`, doc });
}

const manifest = { format: 'neo-book/1', id: book.id, version };
for (const key of ['title', 'tagline', 'glyph', 'lang', 'goal', 'tracks']) {
  if (book[key] !== undefined) manifest[key] = book[key];
}
manifest.chapters = manifestChapters;
manifest.modules = book.modules || [];
manifest.data = book.data || [];
manifest.credits = book.credits || [];

const bookDir = join(resolve(outDir), book.id);
const exists = async (p) => { try { await access(p); return true; } catch { return false; } };
if (await exists(bookDir) && !flags.has('--force')) {
  console.error(`  ERROR ${bookDir} already exists. Pass --force to overwrite, after reading what is there.`);
  process.exit(1);
}

await mkdir(join(bookDir, 'chapters'), { recursive: true });
const write = async (rel, doc) => {
  await writeFile(join(bookDir, rel), `${JSON.stringify(doc, null, 2)}\n`, 'utf8');
  console.log(`  wrote ${join(book.id, rel)}`);
};
await write('book.json', manifest);
for (const f of files) await write(f.path, f.doc);

// C1.1: adding a Book is one array entry plus a directory. The entry is printed
// rather than applied by default, because the catalog is a file somebody else
// may be editing in the same pass.
const entry = { id: book.id, title: book.title, glyph: book.glyph, state: book.state || 'ready' };
const indexPath = join(resolve(outDir), 'index.json');
console.log('');
console.log(`  ${files.length} chapter file(s), ${manifestChapters.length - files.length} planned chapter(s) with no file, version ${version}`);
console.log('  books/index.json entry:');
console.log(`    ${JSON.stringify(entry)}`);

if (flags.has('--index')) {
  let catalog = { format: 'neo-book-index/1', books: [] };
  if (await exists(indexPath)) catalog = JSON.parse(await readFile(indexPath, 'utf8'));
  if (!Array.isArray(catalog.books)) catalog.books = [];
  if (catalog.books.some((b) => b && b.id === book.id)) {
    console.log(`  index.json already lists "${book.id}", left alone`);
  } else {
    catalog.books.push(entry);
    await writeFile(indexPath, `${JSON.stringify(catalog, null, 2)}\n`, 'utf8');
    console.log('  index.json updated');
  }
} else {
  console.log('  (add it by hand, or re-run with --index)');
}

console.log('');
console.log(`  next: node scripts/validate-book.mjs ${join(outDir, book.id)}`);
process.exit(0);
