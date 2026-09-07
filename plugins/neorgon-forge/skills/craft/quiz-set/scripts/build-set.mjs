#!/usr/bin/env node
/**
 * build-set.mjs: a list in, one neo-quiz-set/1 document out.
 *
 * The skill needs this because the mechanical half of a set is where the
 * expensive mistake lives, and it is invisible in the result. An item's id is
 * what `quiz:answer` carries as `itemId`, and what Runcible stores as the
 * evidence a chapter goal is gated on, so an id derived from a row number is a
 * time bomb: the same list re-exported in a different order produces a set that
 * validates perfectly, plays identically, and has thrown away every attempt a
 * learner made. This script derives an id from a column of the material and
 * refuses to invent one, which is the whole reason it exists rather than the
 * model writing the JSON by hand.
 *
 * The other mechanical half is the beats split. A beat starts at every kana
 * except a small ya/yu/yo or a small vowel, which attaches to the kana before
 * it; a small tsu and a long bar are each a beat of their own. That is a rule,
 * not a judgment, so it is derived here and cross-checked against any `beats`
 * column rather than trusted from either side.
 *
 * It invents no content. Every string in the output came from the input or from
 * a flag, and a column the format does not know is dropped loudly rather than
 * carried.
 *
 * Usage:
 *   node build-set.mjs <list.tsv|list.csv|list.json> --game <g> --id <set-id>
 *        [--id-from <column>] [--id-prefix <p>] [--name "En"] [--name-es "Es"]
 *        [--skill <dotted>] [--lang <bcp47>] [--version <YYYY-MM-DD>]
 *        --licence <spdx> [--screen required|none] [--attribution "..."]
 *        [--source <url>] [--line-join ""|" "] [--out <file>]
 *
 * Exit: 0 clean, 1 the list could not be built as asked, 2 usage.
 */

import { readFile, writeFile } from 'node:fs/promises';
import { basename } from 'node:path';

const GAMES = ['beats', 'sound', 'pairs', 'order'];
const ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
// A small kana joins the beat before it. A small tsu and a long bar do not.
const SMALL = new Set([...'ャュョァィゥェォヮゃゅょぁぃぅぇぉゎ']);
// The fields each game knows. Anything else in the list is reported and dropped.
const FIELDS = {
  beats: ['id', 'word', 'kana', 'romaji', 'beats', 'split', 'rule', 'explain'],
  sound: ['id', 'kana', 'sound', 'row', 'column', 'distractors'],
  pairs: ['id', 'left', 'right', 'note'],
  order: ['id', 'tokens', 'line', 'gloss'],
};
// The field an id is derived from when --id-from is not given a column of its own.
const IDENTITY = { beats: 'kana', sound: 'kana', pairs: 'left', order: 'line' };

function usage(message) {
  if (message) console.error(`build-set: ${message}`);
  console.error('usage: build-set.mjs <list> --game beats|sound|pairs|order --id <set-id> \\');
  console.error('         --licence <spdx> [--id-from <column>] [--name "En"] [--name-es "Es"] \\');
  console.error('         [--skill <dotted>] [--lang <tag>] [--screen required|none] \\');
  console.error('         [--attribution "..."] [--source <url>] [--line-join ""] [--out <file>]');
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
const listPath = positional[0];
if (!listPath) usage('no list file given');

const game = opts.get('game');
if (!GAMES.includes(game)) usage(`--game must be one of ${GAMES.join(', ')}`);
const setId = opts.get('id');
if (!setId || !ID_RE.test(setId)) usage('--id must start with a letter or digit, then letters, digits, dot, dash, underscore');
const spdx = opts.get('licence');
if (!spdx) usage('--licence is required: an SPDX id, or "public-domain". A set with no licence is one nobody can reuse');
const screen = opts.get('screen') || 'none';
if (screen !== 'required' && screen !== 'none') usage('--screen must be "required" or "none"');
const attribution = opts.get('attribution');
if (screen === 'required' && !attribution) {
  usage('--screen required needs --attribution: the licensor\'s own wording, quoted, not a paraphrase');
}
const version = opts.get('version') || new Date().toISOString().slice(0, 10);
if (!DATE_RE.test(version)) usage('--version must be a YYYY-MM-DD date');

// ── Reading the list ────────────────────────────────────────────
/** One row of a delimited line, with "" quoting. Enough for an exported list. */
function splitLine(line, sep) {
  const out = [];
  let cur = '';
  let quoted = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (quoted) {
      if (ch === '"' && line[i + 1] === '"') { cur += '"'; i += 1; continue; }
      if (ch === '"') { quoted = false; continue; }
      cur += ch;
      continue;
    }
    if (ch === '"') { quoted = true; continue; }
    if (ch === sep) { out.push(cur); cur = ''; continue; }
    cur += ch;
  }
  out.push(cur);
  return out.map((v) => v.trim());
}

async function readList(path) {
  const text = await readFile(path, 'utf8');
  if (path.endsWith('.json')) {
    const doc = JSON.parse(text);
    const rows = Array.isArray(doc) ? doc : doc.items;
    if (!Array.isArray(rows)) throw new Error('a JSON list must be an array, or an object with an items array');
    return rows.map((r) => {
      const row = {};
      for (const [k, v] of Object.entries(r)) row[k] = v === null || v === undefined ? '' : v;
      return row;
    });
  }
  const sep = path.endsWith('.csv') ? ',' : '\t';
  const lines = text.split(/\r?\n/).filter((l) => l.trim() !== '' && !l.startsWith('#'));
  if (!lines.length) throw new Error('the list is empty');
  const header = splitLine(lines[0], sep);
  return lines.slice(1).map((line) => {
    const cells = splitLine(line, sep);
    const row = {};
    header.forEach((name, i) => { row[name] = cells[i] === undefined ? '' : cells[i]; });
    return row;
  });
}

let rows;
try {
  rows = await readList(listPath);
} catch (e) {
  console.error(`build-set: cannot read ${listPath}: ${e.message}`);
  process.exit(2);
}
if (!rows.length) { console.error('build-set: the list has no rows'); process.exit(2); }

const problems = [];
const notes = [];
const at = (i) => `row ${i + 2}`;

// ── Ids ─────────────────────────────────────────────────────────
const idFrom = opts.get('id-from');
const idPrefix = opts.get('id-prefix') || '';
const hasIdColumn = Object.prototype.hasOwnProperty.call(rows[0], 'id')
  && rows.some((r) => String(r.id || '').trim() !== '');
if (!hasIdColumn && !idFrom) {
  console.error('build-set: the list has no "id" column and no --id-from was given.');
  console.error(`  An item id is what quiz:answer carries as itemId and what a host stores as`);
  console.error('  evidence, so it has to come from the material. Give the list an ASCII key');
  console.error(`  column, or point --id-from at one (the identity field for ${game} is "${IDENTITY[game]}",`);
  console.error('  which is only usable as an id when it is already ASCII).');
  process.exit(2);
}

/** An ASCII id from a key column. Empty means the column cannot be an id. */
function slug(value) {
  const s = String(value).toLowerCase().replace(/[^a-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '');
  return /^[a-z0-9]/.test(s) ? s : '';
}

const seen = new Map();
function idFor(row, i) {
  let id;
  if (hasIdColumn && String(row.id || '').trim() !== '') {
    id = String(row.id).trim();
  } else {
    const key = row[idFrom];
    if (key === undefined) { problems.push(`${at(i)}: no column named "${idFrom}"`); return null; }
    const s = slug(key);
    if (!s) {
      problems.push(`${at(i)}: --id-from ${idFrom} is ${JSON.stringify(String(key))}, which yields no ASCII id. `
        + 'Add a key column the material already carries rather than numbering the rows');
      return null;
    }
    id = idPrefix + s;
  }
  if (!ID_RE.test(id)) { problems.push(`${at(i)}: id ${JSON.stringify(id)} is not in the id character set`); return null; }
  if (seen.has(id)) {
    problems.push(`${at(i)}: id "${id}" is already used by ${at(seen.get(id))}. Two items with one id is a `
      + 'collision, and a numeric suffix would only turn it back into a position');
    return null;
  }
  seen.set(id, i);
  return id;
}

// ── Fields ──────────────────────────────────────────────────────
const listField = (row, name) => {
  const raw = row[name];
  if (Array.isArray(raw)) return raw.map((v) => String(v).trim()).filter((v) => v !== '');
  const s = String(raw === undefined ? '' : raw).trim();
  return s === '' ? null : s.split('|').map((v) => v.trim()).filter((v) => v !== '');
};

/** { en, es } from a plain column, an _en/_es pair, or an object in a JSON list. */
function bilingual(row, name) {
  const plain = row[name];
  if (plain && typeof plain === 'object' && !Array.isArray(plain)) {
    const en = typeof plain.en === 'string' && plain.en.trim() !== '' ? plain.en : null;
    const es = typeof plain.es === 'string' && plain.es.trim() !== '' ? plain.es : null;
    return en === null && es === null ? null : { en, es };
  }
  const en = String(row[`${name}_en`] ?? plain ?? '').trim();
  const es = String(row[`${name}_es`] ?? '').trim();
  if (en === '' && es === '') return null;
  return { en: en === '' ? null : en, es: es === '' ? null : es };
}

/** The kana cut into beats. Mechanical: llms.txt says split.join("") === kana. */
function splitKana(kana) {
  const out = [];
  for (const ch of kana) {
    if (SMALL.has(ch) && out.length) out[out.length - 1] += ch;
    else out.push(ch);
  }
  return out;
}

const str = (row, name) => {
  const v = row[name];
  const s = v === undefined || v === null ? '' : String(v).trim();
  return s === '' ? null : s;
};

function buildBeats(row, i, id) {
  const kana = str(row, 'kana');
  const word = str(row, 'word');
  if (!kana) { problems.push(`${at(i)}: beats needs a "kana" column, the form being counted`); return null; }
  if (!word) { problems.push(`${at(i)}: beats needs a "word" column, the source word shown under the kana`); return null; }
  const given = listField(row, 'split');
  const split = given || splitKana(kana);
  if (split.join('') !== kana) {
    problems.push(`${at(i)}: split ${JSON.stringify(split)} does not join back to ${JSON.stringify(kana)}`);
    return null;
  }
  const declared = str(row, 'beats');
  if (declared !== null && Number(declared) !== split.length) {
    problems.push(`${at(i)}: the beats column says ${declared} and the split is ${split.length} `
      + `(${split.join(' ')}). One of the two is wrong and this script will not pick`);
    return null;
  }
  if (split.length > 9) {
    problems.push(`${at(i)}: ${kana} is ${split.length} beats, past the 9 the numeral options can show. `
      + 'A word this long needs a different game');
    return null;
  }
  const item = { id, word, kana };
  const romaji = str(row, 'romaji');
  if (romaji) item.romaji = romaji;
  item.beats = split.length;
  item.split = split;
  const rule = str(row, 'rule');
  if (rule) item.rule = rule;
  const explain = bilingual(row, 'explain');
  if (explain) item.explain = explain;
  return item;
}

function buildSound(row, i, id) {
  const kana = str(row, 'kana');
  const sound = str(row, 'sound');
  if (!kana || !sound) { problems.push(`${at(i)}: sound needs both a "kana" and a "sound" column`); return null; }
  const item = { id, kana, sound };
  const rowLabel = str(row, 'row');
  if (rowLabel) item.row = rowLabel;
  const columnRaw = row.column;
  item.column = columnRaw === undefined || String(columnRaw).trim() === '' ? null : String(columnRaw).trim();
  const distractors = listField(row, 'distractors');
  if (distractors) {
    if (distractors.length < 3) {
      problems.push(`${at(i)}: distractors has ${distractors.length} value(s); the round shows four options, so it needs 3 or more`);
      return null;
    }
    item.distractors = distractors;
  }
  return item;
}

function buildPairs(row, i, id) {
  const left = str(row, 'left');
  const right = str(row, 'right');
  if (!left || !right) { problems.push(`${at(i)}: pairs needs both a "left" and a "right" column`); return null; }
  const item = { id, left, right };
  const note = str(row, 'note');
  if (note) item.note = note;
  return item;
}

const lineJoin = opts.has('line-join') ? String(opts.get('line-join') ?? '') : null;

function buildOrder(row, i, id) {
  const tokens = listField(row, 'tokens');
  if (!tokens) { problems.push(`${at(i)}: order needs a "tokens" column, the pieces in their correct order separated by |`); return null; }
  if (tokens.length < 3 || tokens.length > 9) {
    problems.push(`${at(i)}: ${tokens.length} piece(s). The format wants 3 to 9: two is a coin flip and the keys stop at 9`);
    return null;
  }
  if (new Set(tokens).size !== tokens.length) {
    problems.push(`${at(i)}: two pieces are identical, which has no wrong order. Merge the repeat with its neighbour`);
    return null;
  }
  let line = str(row, 'line');
  if (!line) {
    if (lineJoin === null) {
      problems.push(`${at(i)}: no "line" column and no --line-join. Whether the pieces join with "" or with " " `
        + 'is a property of the writing system, so it is stated rather than guessed');
      return null;
    }
    line = tokens.join(lineJoin);
  }
  if (line !== tokens.join('') && line !== tokens.join(' ')) {
    problems.push(`${at(i)}: line ${JSON.stringify(line)} is neither the tokens joined with "" nor with " "`);
    return null;
  }
  const item = { id, tokens, line };
  const gloss = bilingual(row, 'gloss');
  if (gloss) item.gloss = gloss;
  return item;
}

const BUILD = { beats: buildBeats, sound: buildSound, pairs: buildPairs, order: buildOrder };

const items = [];
rows.forEach((row, i) => {
  const id = idFor(row, i);
  if (!id) return;
  const item = BUILD[game](row, i, id);
  if (item) items.push(item);
});

// A column nobody read is a column somebody meant. Say so rather than dropping it.
const known = new Set([...FIELDS[game], ...FIELDS[game].flatMap((f) => [`${f}_en`, `${f}_es`])]);
if (idFrom) known.add(idFrom);
const dropped = Object.keys(rows[0]).filter((k) => !known.has(k));
if (dropped.length) notes.push(`columns the ${game} format does not carry, dropped: ${dropped.join(', ')}`);

if (game === 'pairs' && items.length < 4) {
  problems.push(`pairs shows a board of four, so the set needs at least 4 items and has ${items.length}`);
}

if (problems.length) {
  for (const p of problems) console.error(`  ERROR ${p}`);
  console.error(`\n  ${basename(listPath)}: ${problems.length} problem(s), nothing written`);
  process.exit(1);
}

// ── The document ────────────────────────────────────────────────
const nameEn = opts.get('name');
const nameEs = opts.get('name-es');
if (!nameEn && !nameEs) usage('--name is required: what the library and the round header call this set');

const set = { format: 'neo-quiz-set/1', id: setId, version, game };
set.name = nameEs === undefined ? { en: nameEn ?? null, es: null } : { en: nameEn ?? null, es: nameEs };
if (opts.get('lang')) set.lang = opts.get('lang');
else notes.push('no --lang: the engine reads this set as Japanese, which is the default for lang');
if (opts.get('skill')) set.skill = opts.get('skill');
else notes.push(`no --skill: quiz:answer will carry "quiz.${game}", and a Runcible exercise overrides it anyway`);
set.licence = { spdx, screen };
if (attribution) set.licence.attribution = attribution;
if (opts.get('source')) set.licence.source = opts.get('source');
else if (String(spdx).startsWith('CC-BY')) notes.push('no --source on a CC-BY set: the attribution renders, and a reader cannot reach the original');
set.items = items;

const json = `${JSON.stringify(set, null, 2)}\n`;
const out = opts.get('out');
if (out) {
  await writeFile(out, json, 'utf8');
  console.log(`  wrote ${out}: ${items.length} ${game} item(s), version ${version}`);
} else {
  process.stdout.write(json);
  console.error(`  ${items.length} ${game} item(s), version ${version}`);
}
for (const n of notes) console.error(`  note  ${n}`);
console.error('  next: validate-set.mjs on it, and --against the previous version if there is one');
process.exit(0);
