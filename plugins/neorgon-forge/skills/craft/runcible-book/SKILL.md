---
name: runcible-book
description: "Use when a subject should become a Runcible Book: a topic, a syllabus, a table of contents, or new chapters for a Book that already exists. Triggers on: 'add a book to Runcible', 'teach Runcible music theory', 'make a Runcible book', 'turn this syllabus into chapters', 'new chapter for the japanese book'. Plans the ladder, states every chapter goal as something the learner can do and backs it with evidence, scaffolds the directory with scripts/scaffold-book.mjs, then judges the result with the site's own validator rather than a second opinion. Not for the flashcard deck a chapter embeds, that is rappel-deck; not for shell code or a new exercise type, since the nine generic ones are the point."
argument-hint: "[subject or syllabus] [chapter count]"
user-invocable: true
license: MIT
---

# runcible-book: a subject in, a Book Runcible can load out

Turns a subject into the data package Runcible reads: a manifest, a chapter file
per chapter, and one line in the catalog. The failure mode it exists to prevent
is the Book that teaches the shell its subject, where adding music theory ends
with a commit under `js/` and the next Book after that needs another one.

Runcible's whole claim is that a Book is data. **Adding one is one array entry
plus a directory, and no file under `js/` changes.** If your subject seems to
need a shell change, that is the finding: say it out loud rather than making the
change quietly.

The format is frozen. `reference/manifest.md` is the manifest, `reference/chapter.md`
is the chapter and the nine exercise types, `reference/plan.md` is the input the
scaffold takes. Read the first two before writing anything.

## Step 1: Find the site, or say you could not

The Book has to land in a Runcible checkout. Both layouts:

```bash
{ [ -d projects/runcible-site ] || [ -d runcible-site ]; } && echo "site found"
```

If neither exists, ask where it is rather than writing a Book into the current
directory. The scripts take `--site`, and the validator exits 2 rather than
passing when it cannot find the real validator to call.

## Step 2: Write the ladder before writing a page

A Book is a sequence of chapters where each one is the prerequisite of the next,
so the ladder is the design and the pages are the filling. Three answers first:

- **The Book's goal**, as one act. Not "learn music theory" but "name any
  interval by ear and write a four chord progression that resolves".
- **The chapters**, five to twelve. Each is a goal, not a topic, and the reason
  chapter N+1 needs chapter N should be sayable in one clause.
- **Whether the ladder forks.** Where good teachers disagree about ordering,
  that disagreement is a `tracks[]` entry rather than a decision you make for
  the reader. Where they agree, one array of `requires` covers every track.

Then, per chapter, the rungs. **A rung is one sitting.** If it cannot be
finished before the reader closes the tab, it is two rungs.

## Step 3: Every goal carries evidence

`goal.statement` is what the learner can do. `goal.evidence` is how the shell
knows they can:

```json
"evidence": { "skill": "theory.interval.name", "accuracy": 0.9, "min": 20, "window": 40 }
```

The `skill` string is a join. Attempts carrying it come from this chapter's
exercises and from any Rappel deck the chapter embeds, and both count toward the
same gate. **An evidence skill no exercise in the Book produces is a goal that
can never be met**, and the validator treats that as an error, because it looks
completely fine on screen.

A chapter with no evidence block cannot gate the one after it. That is legal for
a stub Book with no exercises, and it is a defect anywhere else.

## Step 4: Prefer a generic type, every time

Nine types ship in the shell and none of them names a subject. Pick from the
table in `reference/chapter.md`. A `custom` module is the last resort, and
proposing one costs a sentence naming which of the eight cannot express the
drill. That sentence is the rule that keeps the shell topic agnostic, and
"it would feel nicer" is not it.

Where a chapter wants spaced repetition over an item inventory, the answer is a
`deck` exercise pointing at a Rappel deck, not a new exercise type. Build the
deck with `rappel-deck`.

## Step 5: Declare data, never invent it

A Book points at corpora; it does not contain them. If a chapter needs a word
list, a stroke order file, a sentence corpus or lyrics, write the `data[]` entry
and the pointer, then name the file a human has to produce and the licence it
carries.

**Never write a dictionary gloss, a lyric or a corpus entry.** An invented one is
wrong, and it arrives wearing a licence claim that is also wrong. Where the
licence starts with `CC-BY`, the attribution wording is required on every screen
that shows the data, so it goes in `credits[]` and the `data[]` entry names it.

## Step 6: Scaffold, then validate

`$FORGE` is the directory containing `skills/`: `~/.claude` after `bin/install.sh`, `plugins/neorgon-forge` inside this repo.

```bash
node "$FORGE/skills/runcible-book/scripts/scaffold-book.mjs" plan.json --out <site>/books --index
node "$FORGE/skills/runcible-book/scripts/validate-book.mjs" <site>/books/<id>
```

The scaffold writes the joins: the format strings, the `src` of every chapter
file, the ids that have to agree in two places, each chapter's gathered `data[]`,
the catalog line. It makes no judgments and it refuses to overwrite an existing
Book without `--force`.

The validator **imports the site's own validator**, the same one the shell runs
at load time, so a Book it accepts is a Book the site accepts. On top of that it
checks the house rules: a goal that names a state of mind, an evidence skill
nothing produces, a catalog with no entry for the Book, an em dash, a banned
word. Errors are always fixed. Warnings are fixed or answered in one sentence.

## Judgment: what makes a chapter worth reading

The steps produce a valid Book. These are what separate one worth working
through from a syllabus in JSON.

| The temptation | What to do instead |
|---|---|
| A chapter per topic heading in the source | A chapter per thing the learner can newly do. Two headings often collapse into one rung |
| A goal restating the title | A goal a stranger could verify by watching. If the title is "Intervals", the goal is not "Intervals" |
| Prose that explains everything before the first exercise | One rung of prose, then a drill. Reading is not evidence and `read` records nothing |
| Ten distractors drawn from the whole corpus | Distractors from siblings. A wrong option nobody would pick is a free point |
| A `custom` module for the interesting drill | The interesting drill in `choice` or `typed` first. Ship it, then argue for the module with a real complaint |
| Filling every chapter to the same depth | The later chapters as `planned` entries with a note. A visible gap beats invented filler |

**Say what you did not build.** A `planned` chapter with an honest note is part
of the ladder. Silence is the thing that reads as an oversight later.

## Invariants

- **No file under `js/` changes.** A Book that needs a shell change is a finding
  to report, not a change to make.
- **Every goal is an act, and every goal carries evidence** whose skill some
  exercise in the Book actually produces.
- **A generic type unless a sentence says why not.** The nine are the product.
- **Content is declared, never invented.** The skill writes pointers and licence
  entries; a human writes the corpus.
- **The `es` half of every `{en, es}` string is neutral Spanish with correct
  orthography**: accents (qué, está, más, también, japonés, teoría), ñ, and the
  opening ¿ and ¡. Accentless Spanish is a spelling error the shell will render.
- **The site's validator is the only judge**, and exit 2 is a failure rather
  than a pass. A second definition of valid is how a Book renders fine and the
  site refuses it.
