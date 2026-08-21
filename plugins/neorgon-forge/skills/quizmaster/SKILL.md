---
name: quizmaster
description: "Use when turning source material into a runnable exam. A study guide, a doc set, a codebase, meeting notes, a certification syllabus. Triggers on: 'make a quiz from this', 'generate an exam', 'test me on these docs', 'create practice questions', 'turn this guide into a test', 'proctor test'. Maps coverage before writing a single question, authors in the four proctor types (single, multi, truefalse, fill) with per-option reasoning, then validates the JSON mechanically with scripts/validate-exam.mjs before a human loads it. Output runs in the Proctor exam runner (proctor.neorgon.com, study mode, timed simulator, share links, embeds). Not for grading free-text answers, and not for building an exam UI, Proctor is the runner."
argument-hint: "[source] [question count]"
user-invocable: true
license: MIT
---

# quizmaster: source material in, runnable exam out

Turns documents into an exam in Proctor's format, with the same discipline slides
decks get: a validator script checks the output against the format before a human
loads it. The failure mode it exists to prevent is the plausible-looking exam that is
secretly broken: an `answer` index pointing past the options, a multi question
grading against a misspelled option text, a test that quizzes three paragraphs of the
source and silently skips the other twelve.

Format source of truth: `https://proctor.neorgon.com/llms.txt` (JSON is canonical;
the runner also takes YAML/Aiken/GIFT/CSV, but generate JSON).

## Step 1: Scope the exam

Three answers before any question exists: **who** is being tested (what they can be
assumed to know already), **what the exam certifies** (recall of the doc, or the
judgment to apply it), and **the pass bar** (`passingScore`, and whether a timer
belongs: `timeLimitMinutes` turns the simulator into a real rehearsal).

## Step 2: Map coverage before writing questions

Enumerate the source's testable claims first: read it and list every fact, rule,
boundary, and misconception-magnet as one line each, grouped into 3–6 categories.
Then assign question counts per category **by weight, out loud** ("limits: 4,
setup: 3, edge cases: 5"). Questions come from the map, so coverage is a decision;
written straight from memory of the source, an exam tests whatever was most
memorable, which is the opposite of what needs testing.

Set `ensure: true` on the must-know items: Proctor always includes those when the
user draws a random slice.

## Step 3: Author, one discriminator per stem

The craft rules (expanded in `reference/question-patterns.md`):

- **One discriminator per question.** The stem should hinge on exactly one fact or
  judgment. A stem that requires three facts grades three things with one point and
  teaches nothing when missed.
- **Distractors are real misconceptions**, not jokes and not syntactic noise. The
  wrong option should be what someone who *almost* understands would pick.
- **The explanation teaches the discriminator**, not just names the right answer.
  It is shown as the correction in study mode; write it as feedback ("`**` is
  exponentiation; `^` is XOR in Python") and put the why, not a citation.
- **Every question carries `category`**: Proctor aggregates scores per category,
  which is what makes the results diagnostic instead of a number.
- **Mix the four types where the content earns them**: `single` for discrimination,
  `multi` for "which of these apply" boundaries (grading is exact-set, say so in
  the stem: "select all that apply"), `truefalse` for misconception checks, `fill`
  for the names and commands that must be recalled cold (list every acceptable
  spelling in `accept`).
- 10–20 questions unless the user asked for otherwise; markdown is allowed in
  prompts and explanations (fenced code blocks work), but options are inline-only.

## Step 4: Validate before anyone loads it

```bash
node "$FORGE/skills/quizmaster/scripts/validate-exam.mjs" exam.json
```

Errors are things Proctor would misload or misgrade (missing prompt, answer index
out of range, multi answer naming a nonexistent option, duplicate options);
warnings are craft debts (missing explanation or category, all questions one type,
duplicate stems). Exit 0 clean · 1 findings · 2 unreadable (never a pass). Fix
errors always; fix warnings or say why not.

## Step 5: Deliver as something runnable

A validated `exam.json` plus how to run it: drag onto proctor.neorgon.com, or a
`?src=URL` link if the file is hosted with CORS, or, for small exams. A share
link with the whole test in the fragment (`#t=<base64url(JSON)>`, no server
involved). For a page embed, the iframe snippet from the spec (`embed=1`,
`mode=study|exam|review`, `draw=N`, `time=N`). Say which delivery you chose and why.

## Invariants

- **Coverage map before questions.** An exam without one tests what was memorable.
- **Every question: category + explanation.** No diagnostic value, no teaching
  value, then no question.
- **Distractors are believable mistakes.** A joke option is a free point.
- **The validator runs before delivery**, and exit 2 is a failure, not a pass.
- **Answers are verified against the source**, not against recollection. A wrong
  answer key is worse than no exam, because it teaches the error with authority.
