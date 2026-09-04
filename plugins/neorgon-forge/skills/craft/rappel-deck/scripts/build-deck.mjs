#!/usr/bin/env node
/**
 * build-deck.mjs: a word list in, a neo-deck/1 document out.
 *
 * The part worth automating is not the JSON. It is note identity. A card is
 * `noteId + ":" + templateId`, and that string is the foreign key the review
 * ledger holds, so renumbering notes on a rebuild silently discards a person's
 * study history on every card in the deck. --against reads the previous version
 * of the deck and keeps each existing id attached to the same first field, so a
 * rebuild is an edit rather than a reset.
 *
 * It also reads Anki's own `#separator:` / `#columns:` header dialect, so a TSV
 * exported from Anki round trips without being reshaped by hand.
 *
 * Nothing here judges the output. Run the validator next:
 *   node scripts/validate-deck.mjs <deck.json>
 * which imports Rappel's own validator rather than holding a second opinion.
 *
 * Usage:
 *   node build-deck.mjs <list.tsv|csv|json> --id <deck-id> [options]
 *
 * Options:
 *   --id <slug>            deck id. Required.
 *   --out <file>           where to write. Default <id>.json in the working directory.
 *   --name <text>          human name. --name-es adds the Spanish half.
 *   --fields A,B,C         field names, when the file has no #columns header.
 *   --lang front,back      default en,en.
 *   --templates a,b,c      any of recognition, recall, pick, cloze. Default recognition.
 *   --skill <dotted>       stem for template skills, e.g. es.verbs -> es.verbs.read.
 *   --tag-field <Field>    that field's value becomes a tag, and feeds sibling distractors.
 *   --transform <id>       kana or kana-katakana, on the typed template only.
 *   --compare <tokens>     pipe separated. Default trim|casefold.
 *   --licence <spdx>       SPDX id, or public-domain.
 *   --attribution <text>   exact on screen wording. Required when licence starts with CC-BY.
 *   --source <url>         where the material came from.
 *   --media-base <path>    relative path for [sound:x.mp3] and <img src="x.png">.
 *   --version <date>       YYYY-MM-DD. Default today.
 *   --against <deck.json>  keep every note id this deck already assigned.
 *
 * Exit: 0 written, 1 the list could not be turned into notes, 2 usage error.
 */

import { readFile, writeFile } from 'node:fs/promises';
import { resolve, extname } from 'node:path';

const KNOWN_TEMPLATES = ['recognition', 'recall', 'pick', 'cloze'];
const CLOZE_MARKER = /\{\{c(\d+)::/;

function usage(message) {
  if (message) console.error(`build-deck: ${message}`);
  console.error('usage: build-deck.mjs <list.tsv|csv|json> --id <deck-id> [--out <file>] [...]');
  console.error('       see the comment block at the top of this file for every option');
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
const opt = (name, fallback = null) => (opts.has(name) && opts.get(name) !== undefined ? opts.get(name) : fallback);

const listPath = positional[0];
if (!listPath) usage('no word list given');
const deckId = opt('id');
if (!deckId) usage('no --id given: it is the deck id and the ledger keys off it');

let raw;
try {
  raw = await readFile(resolve(listPath), 'utf8');
} catch (e) {
  usage(`cannot read ${listPath}: ${e.message}`);
}

// ── Reading the list ────────────────────────────────────────────
const SEPARATORS = { tab: '\t', comma: ',', semicolon: ';', space: ' ', pipe: '|' };

/** Anki's header dialect, verbatim, so an exported file needs no reshaping. */
function readDelimited(text, fallbackSep) {
  const headers = {};
  const rows = [];
  let sep = fallbackSep;
  let columns = null;
  for (const line of text.split(/\r?\n/)) {
    if (!line.trim()) continue;
    if (line.startsWith('#')) {
      const at = line.indexOf(':');
      if (at < 0) continue;
      const key = line.slice(1, at).trim().toLowerCase();
      const value = line.slice(at + 1);
      headers[key] = value.trim();
      if (key === 'separator') sep = SEPARATORS[value.trim().toLowerCase()] || value.trim();
      if (key === 'columns') columns = value.split(sep).map((c) => c.trim());
      continue;
    }
    rows.push(line.split(sep).map((c) => c.trim()));
  }
  return { headers, columns, rows };
}

const ext = extname(listPath).toLowerCase();
let fields = opt('fields') ? opt('fields').split(',').map((f) => f.trim()) : null;
let rows = [];
let ankiHeaders = {};

if (ext === '.json') {
  let doc;
  try { doc = JSON.parse(raw); } catch (e) { usage(`${listPath} is not valid JSON: ${e.message}`); }
  if (!Array.isArray(doc) || doc.length === 0) usage(`${listPath} must be a non-empty array`);
  if (Array.isArray(doc[0])) {
    if (!fields) usage('a JSON array of arrays needs --fields to name the columns');
    rows = doc.map((r) => r.map((v) => String(v ?? '')));
  } else {
    if (!fields) fields = [...new Set(doc.flatMap((o) => Object.keys(o)))];
    rows = doc.map((o) => fields.map((f) => String(o[f] ?? '')));
  }
} else {
  const parsed = readDelimited(raw, ext === '.csv' ? ',' : '\t');
  ankiHeaders = parsed.headers;
  if (!fields) fields = parsed.columns;
  rows = parsed.rows;
  if (!fields) {
    // No --fields and no #columns header: the first row names the columns only
    // if it plausibly does. Guessing wrong costs a note, so say what was assumed.
    fields = rows.shift();
    console.error(`  note: no #columns header, taking the first row as field names: ${fields.join(', ')}`);
  }
}

if (!fields || fields.length < 1) usage('no field names: pass --fields, or give the file a #columns header');
rows = rows.filter((r) => r.some((c) => c !== ''));
if (rows.length === 0) { console.error('build-deck: the list has no rows'); process.exit(1); }

// ── Note identity, which is the whole point ─────────────────────
const keyOf = (row) => row[0];
const previous = new Map();
let highest = 0;
const againstPath = opt('against');
if (againstPath) {
  let old;
  try { old = JSON.parse(await readFile(resolve(againstPath), 'utf8')); }
  catch (e) { usage(`cannot read --against ${againstPath}: ${e.message}`); }
  const first = (old.fields || [])[0];
  for (const note of old.notes || []) {
    if (!note || !note.id) continue;
    previous.set(String((note.f || {})[first] ?? ''), note.id);
    const n = /^n_(\d+)$/.exec(note.id);
    if (n) highest = Math.max(highest, Number(n[1]));
  }
}
const nextId = () => { highest += 1; return `n_${String(highest).padStart(4, '0')}`; };

const tagField = opt('tag-field');
const tagIndex = tagField ? fields.indexOf(tagField) : -1;
if (tagField && tagIndex < 0) usage(`--tag-field "${tagField}" is not one of ${fields.join(', ')}`);

const seenKeys = new Set();
const notes = [];
for (const row of rows) {
  const key = keyOf(row);
  if (seenKeys.has(key)) {
    console.error(`  note: "${key}" appears twice in the list, the second one is dropped`);
    continue;
  }
  seenKeys.add(key);
  const f = {};
  fields.forEach((name, i) => { f[name] = row[i] === undefined ? '' : row[i]; });
  const note = { id: previous.get(key) || nextId(), f };
  if (tagIndex >= 0 && row[tagIndex]) note.tags = [row[tagIndex]];
  notes.push(note);
}

// ── Templates ───────────────────────────────────────────────────
const wanted = (opt('templates', 'recognition')).split(',').map((t) => t.trim()).filter(Boolean);
for (const t of wanted) if (!KNOWN_TEMPLATES.includes(t)) usage(`--templates: "${t}" is not one of ${KNOWN_TEMPLATES.join(', ')}`);
const stem = opt('skill');
const skill = (suffix) => (stem ? `${stem}.${suffix}` : undefined);
const front = fields[0];
const back = fields[1];
if (wanted.some((t) => t !== 'cloze') && !back) {
  usage('a recognition, recall or pick template needs at least two fields');
}

const templates = [];
for (const id of wanted) {
  if (id === 'recognition') {
    templates.push({ id, kind: 'basic', skill: skill('read'), front: `{{${front}}}`, back: `{{${back}}}` });
  }
  if (id === 'recall') {
    const t = { id, kind: 'typed', skill: skill('write'), answer_field: front,
      front: `{{${back}}}`, back: `{{${front}}}` };
    if (opt('transform')) t.transform = opt('transform');
    t.compare = opt('compare', 'trim|casefold');
    templates.push(t);
  }
  if (id === 'pick') {
    templates.push({ id, kind: 'choice', skill: skill('read'), answer_field: back,
      front: `{{${front}}}`, distractors: tagIndex >= 0 ? 'siblings' : 'sample-from-deck', count: 4 });
  }
  if (id === 'cloze') {
    // C12 A13: a cloze template names its source field text_field.
    templates.push({ id, kind: 'cloze', skill: skill('recall'), text_field: front });
  }
}
for (const t of templates) if (t.skill === undefined) delete t.skill;

// ── The document, in the field order C4.1 gives it ──────────────
const deck = {
  format: 'neo-deck/1',
  id: deckId,
  version: opt('version', new Date().toISOString().slice(0, 10)),
  name: opt('name-es')
    ? { en: opt('name', deckId), es: opt('name-es') }
    : opt('name', ankiHeaders.deck || deckId),
  lang: (() => {
    const [f, b] = opt('lang', 'en,en').split(',').map((s) => s.trim());
    return { front: f || 'en', back: b || f || 'en' };
  })(),
};
if (opt('licence')) deck.licence = opt('licence');
if (opt('attribution')) deck.attribution = opt('attribution');
if (opt('source')) deck.source = opt('source');
if (opt('screen')) deck.screen = opt('screen');
else if (opt('licence', '').startsWith('CC-BY')) deck.screen = 'required';
if (opt('media-base')) deck.media_base = opt('media-base');
deck.fields = fields;
deck.templates = templates;
deck.notes = notes;

const outPath = resolve(opt('out', `${deckId}.json`));
await writeFile(outPath, `${JSON.stringify(deck, null, 2)}\n`, 'utf8');

// ── Say what was built, in cards rather than notes ──────────────
let cards = 0;
for (const note of notes) {
  for (const t of templates) {
    if (t.kind !== 'cloze') { cards += 1; continue; }
    const text = String(note.f[t.text_field] || '');
    const ordinals = new Set();
    const re = new RegExp(CLOZE_MARKER.source, 'g');
    let m;
    while ((m = re.exec(text)) !== null) ordinals.add(m[1]);
    cards += ordinals.size;
  }
}
const kept = [...previous.values()].filter((id) => notes.some((n) => n.id === id)).length;

console.log(`  wrote ${outPath}`);
console.log(`  ${notes.length} note(s) x ${templates.length} template(s) = ${cards} card(s)`);
if (againstPath) console.log(`  kept ${kept} of ${previous.size} note id(s) from ${againstPath}`);
if (cards > 150) console.log(`  ${cards} cards is a long first session. Consider dropping a template, or splitting the deck.`);
console.log('');
console.log('  next: node scripts/validate-deck.mjs ' + outPath);
process.exit(0);
