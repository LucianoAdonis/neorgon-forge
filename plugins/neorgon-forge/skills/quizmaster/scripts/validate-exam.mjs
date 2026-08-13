#!/usr/bin/env node
// validate-exam.mjs — check an exam JSON against the Proctor format
// (spec: https://proctor.neorgon.com/llms.txt) before a human loads it.
//
// Errors = Proctor would misload or misgrade. Warnings = craft debts the
// quizmaster skill says to fix or justify. Exit 0 clean · 1 findings ·
// 2 unreadable (a run that checked nothing must never read as a pass).
//
// Usage: node validate-exam.mjs exam.json

import { readFileSync } from 'node:fs';

const file = process.argv[2];
if (!file) { console.error('usage: validate-exam.mjs <exam.json>'); process.exit(2); }

let raw;
try { raw = readFileSync(file, 'utf8'); }
catch (e) { console.error(`cannot read ${file}: ${e.message}`); process.exit(2); }

let doc;
try { doc = JSON.parse(raw); }
catch (e) {
  console.error(`${file}: not valid JSON (${e.message})`);
  if (/^\s*(title|questions)\s*:/m.test(raw))
    console.error('  looks like YAML — JSON is the canonical Proctor format; emit JSON');
  process.exit(2);
}

const findings = [];
const err  = (where, msg) => findings.push({ level: 'error', where, msg });
const warn = (where, msg) => findings.push({ level: 'warn',  where, msg });

if (typeof doc !== 'object' || doc === null || Array.isArray(doc))
  { console.error(`${file}: top level must be one JSON object`); process.exit(2); }

if (typeof doc.title !== 'string' || !doc.title.trim())
  err('top', 'title is required and must be a non-empty string');
for (const k of ['timeLimitMinutes', 'passingScore'])
  if (doc[k] !== undefined && typeof doc[k] !== 'number')
    err('top', `${k} must be a number`);

const qs = doc.questions;
if (!Array.isArray(qs) || qs.length === 0) {
  err('top', 'questions is required and must be a non-empty array');
} else {
  if (qs.length < 10 || qs.length > 20)
    warn('top', `${qs.length} questions — the spec recommends 10-20`);

  const seenPrompts = new Map();
  const types = new Set();

  qs.forEach((q, i) => {
    const where = `q${i + 1}`;
    if (typeof q !== 'object' || q === null) { err(where, 'question must be an object'); return; }

    const prompt = q.prompt ?? q.question;
    if (typeof prompt !== 'string' || !prompt.trim())
      err(where, 'prompt (or question) is required');
    else {
      const key = prompt.trim();
      if (seenPrompts.has(key)) warn(where, `duplicate stem of ${seenPrompts.get(key)}`);
      else seenPrompts.set(key, where);
    }

    // Type, as Proctor infers it when omitted.
    let type = q.type;
    if (!type) {
      if (typeof q.answer === 'boolean') type = 'truefalse';
      else if (Array.isArray(q.answers)) type = 'multi';
      else if (Array.isArray(q.accept))  type = 'fill';
      else type = 'single';
    }
    if (!['single', 'multi', 'truefalse', 'fill'].includes(type))
      { err(where, `unknown type "${q.type}"`); return; }
    types.add(type);

    const opts = q.options;
    if (type === 'single' || type === 'multi') {
      if (!Array.isArray(opts) || opts.length < 2 || !opts.every(o => typeof o === 'string'))
        err(where, `${type} needs options: an array of at least 2 strings`);
      else {
        const dup = opts.find((o, j) => opts.indexOf(o) !== j);
        if (dup !== undefined) err(where, `duplicate option: ${JSON.stringify(dup)}`);
        if (/^```/m.test(opts.join('\n')) || opts.some(o => /^[-] |^\d+\. /m.test(o)))
          warn(where, 'options are inline-only markdown — fenced blocks and lists will not render');
      }
    }

    const optOk = Array.isArray(opts) ? opts : [];
    const inRange = (v) => Number.isInteger(v) && v >= 0 && v < optOk.length;
    const matches = (v) => typeof v === 'string' && optOk.includes(v);

    if (type === 'single') {
      if (q.answer === undefined) err(where, 'single needs answer (index or exact option text)');
      else if (typeof q.answer === 'number' && !inRange(q.answer))
        err(where, `answer index ${q.answer} is out of range (0-${optOk.length - 1})`);
      else if (typeof q.answer === 'string' && !matches(q.answer))
        err(where, `answer text does not exactly match any option: ${JSON.stringify(q.answer)}`);
      else if (typeof q.answer === 'boolean')
        err(where, 'boolean answer on a single question — did you mean type truefalse?');
    }
    if (type === 'multi') {
      if (!Array.isArray(q.answers) || q.answers.length === 0)
        err(where, 'multi needs answers: a non-empty array of indexes or option texts');
      else {
        q.answers.forEach(a => {
          if (typeof a === 'number' && !inRange(a)) err(where, `answers index ${a} out of range`);
          else if (typeof a === 'string' && !matches(a))
            err(where, `answers text not an exact option: ${JSON.stringify(a)}`);
        });
        if (new Set(q.answers.map(String)).size !== q.answers.length)
          err(where, 'answers contains duplicates — grading is exact-set');
        if (q.answers.length === optOk.length && optOk.length > 0)
          warn(where, 'every option is correct — a multi where nothing discriminates');
      }
    }
    if (type === 'truefalse' && typeof q.answer !== 'boolean')
      err(where, 'truefalse needs answer: true or false');
    if (type === 'fill') {
      if (!Array.isArray(q.accept) || q.accept.length === 0 || !q.accept.every(a => typeof a === 'string'))
        err(where, 'fill needs accept: a non-empty array of strings');
    }

    if (q.points !== undefined && !(typeof q.points === 'number' && q.points > 0))
      err(where, 'points must be a positive number');
    if (!q.explanation) warn(where, 'no explanation — study mode shows nothing that teaches');
    if (!q.category)    warn(where, 'no category — results cannot aggregate by topic');
  });

  if (qs.length >= 8 && types.size === 1)
    warn('top', `all ${qs.length} questions are type "${[...types][0]}" — mix types where content earns them`);
  if (!qs.some(q => q.ensure === true))
    warn('top', 'no ensure:true questions — random draws may skip every must-know item');
}

for (const f of findings) console.log(`${file}: ${f.where}: ${f.level}: ${f.msg}`);
const errors = findings.filter(f => f.level === 'error').length;
if (findings.length) {
  console.log(`${errors} error(s), ${findings.length - errors} warning(s)` +
    (errors ? ' — Proctor would misload or misgrade this' : ''));
  process.exit(1);
}
console.log(`valid Proctor exam: ${doc.title} (${qs.length} questions)`);
process.exit(0);
