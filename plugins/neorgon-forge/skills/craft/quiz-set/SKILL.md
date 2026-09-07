---
name: quiz-set
description: "Use when material should become a Quiz game: a word list, a kana or symbol table, a glossary, a set of song lines, or a slice of a corpus that a learner will drill as beats, sound, pairs or order. Triggers on: 'make a quiz set', 'turn this list into a Quiz game', 'a set for quiz.neorgon.com', 'a matching game from these words', 'a beats set from these loanwords', 'put these lines in the order game', 'a quiz round for this chapter'. Writes one neo-quiz-set/1 document whose item ids come from the material rather than from row numbers, validates it with Quiz's own validator, and hands back the iframe snippet and the Runcible exercise. Not for spaced repetition flashcards, that is rappel-deck; not for a graded exam, that is quizmaster; not for the chapters and goals around the round, that is runcible-book."
argument-hint: "[word list or corpus slice] [beats|sound|pairs|order]"
user-invocable: true
license: MIT
---

# quiz-set: material in, a round someone can lose and learn from out

Turns a list into a `neo-quiz-set/1` document the Quiz engine plays, Runcible
embeds, and any page can iframe, then hands back the snippet for each. The
failure mode it exists to prevent is silent and expensive: `quiz:answer` carries
an item's `id` as `itemId`, Runcible stores that string as the evidence a chapter
goal is gated on, so a set rebuilt with ids numbered by position orphans every
attempt a learner ever made on that item, gates a chapter that was already passed,
and reports nothing at all.

The second failure mode is cheaper and more common: a round where the prompt
already contains the answer. Four ascending numerals under a word whose romaji is
printed beside it is not a question, and a pairs board carrying the reading is a
free point.

`reference/set.md` is the format, game by game. `reference/embed.md` is the iframe,
the events a host reads, and the Runcible exercise. The live spec is
`https://quiz.neorgon.com/llms.txt`, and it wins over both if they ever disagree.

## Step 0: Is this set generated already?

**A set built from a corpus that already has a generator is not authored here.**
Runcible's Japanese Book derives every one of its sets from
`./tools/build-sets.mjs` over `./tools/selection/sets.json`, out of the same
corpora its decks and chapters read. Adding a set there is a row in that
selection file and a re-run, never a hand-written JSON document: the generator is
what keeps the two copies (Quiz's library and the Book's `sets/`) from drifting,
and what derives an item id from the corpus record it came from rather than from
a position in a list.

```bash
{ [ -f projects/runcible-site/tools/selection/sets.json ] \
  || [ -f runcible-site/tools/selection/sets.json ]; } && echo "a generator owns these sets"
```

If the material is already in that corpus, stop and say so: the answer is a
selection row, and this skill is for material with no generator behind it. Adding
a second path to the same set is how the two copies start disagreeing.

## Step 1: Find Quiz, or say you could not

The validator has to call Quiz's own. Both layouts:

```bash
{ [ -d projects/quiz-site ] || [ -d quiz-site ]; } && echo "site found"
```

Without it the set can still be built, and `scripts/validate-set.mjs` exits 2
rather than passing, because a run that checked nothing must never read as a
pass. Say so instead of delivering an unchecked set.

## Step 2: Pick the game the material can explain

A set serves exactly one game, and the choice is decided by what the material can
say back after a miss. Every round owes the learner a reason, so a game whose
`why` the material cannot fill is the wrong game.

| Game | Ask it when the material carries | The `why` it owes on a miss |
|---|---|---|
| `beats` | A written form whose length is countable, plus the rule that makes it that length | The form cut into beats, then the one line naming the rule |
| `sound` | A symbol, its sound, and a grid the symbol sits in (a row and a column) | The symbol's own row, drawn from the set's siblings |
| `pairs` | Two sides where neither spells out the other | The pair side by side, plus an optional reading |
| `order` | A sequence of 3 to 9 pieces with no two the same | The correct line with the first misplaced piece marked |

Two rules fall out of that table and are worth stating before you write anything:

- **`sound` ships whole rows, not a sample of each.** The feedback strip is built
  from the set's own items sharing a `row`, in column order, so a row the author
  sampled renders with holes the writing system does not have. A row that is
  genuinely short is not a hole: the y row really has three kana. Take the rows
  the source has, all of them, or leave a row out entirely.
- **A label is a handle, so write it as one.** `row`, `column`, `group` and
  `rule` are what `?filter=` matches, exactly and after trim, which is how one
  set serves a chapter that drills a row at a time. Keep them ASCII letters,
  digits and dashes, keep them stable across rebuilds the way an id is, and put
  the words a reader sees in `groups` rather than in the label.
- **`order` refuses a two-piece line and refuses a repeated piece.** Two pieces is
  a coin flip, and two identical pieces have no wrong order. Split a long line
  into two items; merge a repeat with its neighbour.

## Step 3: Ids come from the material, never from the row

The identity rule, and the reason this skill exists. An item id has to be
derivable again from the same source record: a corpus id, a headword, a stable
key column. Not the row number, not the enumeration order, not a hash of the
whole item.

Ids are ASCII (`^[A-Za-z0-9][A-Za-z0-9._-]*$`), so material whose only key is
non-Latin needs an ASCII key column of its own. `scripts/build-set.mjs` refuses to
guess one, and that refusal is the point: an id it invented today is an id it
invents differently tomorrow.

When a set already exists, prove the ids survived with `--against`. A renumbered
set validates perfectly, plays identically, and throws away the history.

## Step 4: Keep the answer off the prompt

The format refuses the worst case by itself: a `pairs` item where either side
contains the other after folding is rejected. The rest is judgment.

- **`beats`**: `kana` is the prompt and `romaji` is shown only after the answer,
  because `baggu` spells out the count. The `word` under it is shown before, so a
  `word` that is itself a transliteration gives the answer away. Put the source
  word there, not its reading.
- **`sound`**: give `distractors` when the set has no grid to draw them from.
  Three sounds pulled from across the whole table are noise, and an option nobody
  would pick is a free point.
- **`pairs`**: `left` and `right` are the only things on the board. A reading, a
  gloss or a hint goes in `note`, which is shown after a miss and nowhere else.
- **`order`**: `gloss` is feedback, never a prompt. A translation printed above
  the pieces orders them for the learner.

## Step 5: Quote the licence, do not paraphrase it

If the material is not the user's own, the set carries `licence` with `spdx`,
`screen`, the exact `attribution` wording the source requires, and a `source` URL.
When `screen` is `"required"` that wording renders under every round showing the
set, in the embed too. The validator refuses a set that claims `required` without
the wording.

**Never write a gloss, a lyric or a dictionary entry.** An invented one is wrong
and it arrives wearing a licence claim that is also wrong. Name the file a human
has to produce instead. Where the material is the user's own, say so in `spdx`
anyway: a set with no licence is one nobody else can reuse.

## Step 6: Build

`$FORGE` is the directory containing `skills/`: `~/.claude` after `bin/install.sh`, `plugins/neorgon-forge` inside this repo.

```bash
node "$FORGE/skills/quiz-set/scripts/build-set.mjs" words.tsv \
  --game pairs --id es-kitchen-pairs --id-from key \
  --name "Kitchen words" --name-es "Palabras de cocina" \
  --skill es.kitchen.read --lang es \
  --licence CC-BY-4.0 --screen required \
  --attribution "Word list by the Cocina Abierta project, CC BY 4.0." \
  --source https://example.org/cocina \
  --out es-kitchen-pairs.json
```

Column names are item field names, a bilingual column is `explain_en` and
`explain_es`, and a list column (`split`, `tokens`, `distractors`) is separated by
`|`. TSV, CSV and a JSON array of objects all read the same way. For `beats` the
script derives `split` from the kana and `beats` from the split, because that
half is mechanical, and it refuses a `beats` column that disagrees with its own
count rather than silently preferring one.

## Step 7: Validate with Quiz's validator, not a second opinion

```bash
node "$FORGE/skills/quiz-set/scripts/validate-set.mjs" es-kitchen-pairs.json --against previous.json
```

It imports `./tools/validate-set.mjs` from the Quiz checkout, the same rules the
engine applies to a fetched document, then adds what a schema cannot see: an item
id that vanished or changed hands, a `sound` row too thin to draw its own
feedback strip, a `beats` word that spells out its own count, a `CC-BY` set with
no source, a built-in set the library's index never names, a banned word. Errors
are always fixed. Warnings are fixed, or answered in one sentence.

## Step 8: Hand back something runnable

A JSON file is not a delivery. Give back, from `reference/embed.md`:

1. The **iframe snippet**, with `?embed=1&game=&set=` filled in and `set=` chosen
   by where the file actually lives: a built-in id, or the encoded absolute URL.
2. The two lines a host needs: filter on `e.origin` and `e.source`, and post
   `quiz:hello` on the iframe's `load` event. Without the second, the panel is
   intermittently blank on somebody else's machine.
3. For a Runcible chapter, the **exercise spec and the `data[]` line**, because
   an undeclared `src` is a load error naming `book.json`, not a missing game.

Say which of `store: "engine"` and `store: "ephemeral"` the host will get. On any
origin outside `*.neorgon.com` nothing is written, and the "Open in Quiz" link is
the path that persists.

## Judgment: what makes a round worth losing

| The temptation | What to do instead |
|---|---|
| Every row in the source | The rows that carry the distinction. A round is ten items; a set of 400 is a picker nobody reads |
| One small set per row, so a chapter can drill each one | One set holding the whole grid, and a `filter` on the host's side. `?filter=row:k` is a k row round, and the distractors and the row strip still draw from the whole set |
| Four games from one list, because the format has four | The one game the material can explain. A `pairs` set forced into `sound` has no row to draw |
| A `sound` set sampled across the table | Whole rows. The feedback strip is the set's own siblings, so a partial row teaches a gap |
| Distractors from anywhere in the set | Siblings: same row, same column, same tag. A wrong option nobody would pick is a free point |
| An `explain` line written to fill the field | The rule's own line, or `null`. An invented explanation is worse than a panel that shows only the tiles |
| An `order` set of whole verses | Lines of 3 to 9 pieces. Nine is the format's cap because the keys are 1 to 9 |
| Bumping `version` only when the shape changes | Bumping it on any content change. It is a date, and a host compares it to notice the set moved |
| Renaming a set id to something tidier | Leaving it. Scores are keyed by it, and a rename is a reset with no message |

## Invariants

- **An item id is derived from the material, never from its position**, and a
  rebuild that cannot prove the old ids survived is not delivered.
- **The prompt never contains the answer.** A reading, a romaji, a gloss or a
  translation belongs in the feedback, which is the half the round exists for.
- **A set is generated where a generator exists.** For Runcible's corpora that is
  `./tools/build-sets.mjs` and a row in `./tools/selection/sets.json`, so the two
  copies of a set cannot drift.
- **Content is quoted or declared, never invented**, and the licence wording is
  the source's own words rather than a paraphrase of them.
- **The `es` half of every `{en, es}` string is neutral Spanish with correct
  orthography**: accents (qué, está, más, también, japonés, sílaba), ñ, and the
  opening ¿ and ¡. Accentless Spanish is a spelling error on every screen, and
  `"es": null` is the honest answer when there is no translation yet.
- **Quiz's validator is the only judge**, and exit 2 is a failure rather than a
  pass. A second definition of valid is how a set looks fine and the engine
  refuses it.
