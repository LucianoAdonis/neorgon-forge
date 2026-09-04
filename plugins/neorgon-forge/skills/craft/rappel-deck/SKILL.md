---
name: rappel-deck
description: "Use when a word list, glossary, term sheet or vocabulary set should become spaced repetition flashcards. Triggers on: 'make a deck from this list', 'turn these terms into flashcards', 'build a Rappel deck', 'anki deck from this csv', 'add these words to the deck'. Builds one neo-deck/1 JSON document with stable note ids, templates that earn their place, and the licence the source requires on screen, then validates it with Rappel's own validator rather than a second opinion, and hands back the iframe snippet. Not for an exam or a graded test, use quizmaster; not for the chapters and goals around the deck, that is runcible-book."
argument-hint: "[word list or file] [deck id]"
user-invocable: true
license: MIT
---

# rappel-deck: a word list in, a deck someone can study out

Turns a list into a `neo-deck/1` document that the Rappel engine schedules with
FSRS-6, and hands back the snippet for embedding it. The failure mode it exists
to prevent costs a person their study history: a deck rebuilt with renumbered
notes validates perfectly, looks identical, and quietly resets every card,
because a card is `noteId + ":" + templateId` and that string is the review
ledger's foreign key.

`reference/deck.md` is the format. `reference/embed.md` is the iframe and the
events a host reads. The live spec is `https://rappel.neorgon.com/llms.txt`, and
it wins over both if they ever disagree.

## Step 1: Find the site, or say you could not

The validator has to call Rappel's own. Both layouts:

```bash
{ [ -d projects/rappel-site ] || [ -d rappel-site ]; } && echo "site found"
```

Without it the deck can still be built, and `validate-deck.mjs` exits 2 rather
than passing, because a run that checked nothing must never read as a pass. Say
so instead of delivering an unchecked deck.

## Step 2: Decide the fields before touching the list

`fields[]` names the columns, and every template is written against those names,
so a field renamed later rewrites every template. Two are usually enough: the
thing being learned, and what it means. A third earns its place when it groups
the notes, because a group is what makes plausible distractors possible.

The first field is the note's identity. Pick the one that will not change: a
word, not a translation of it.

## Step 3: Templates earn their place, one at a time

| Template | Add it when |
|---|---|
| `recognition` | Always. Seeing the item and knowing what it is |
| `recall` | The reverse direction is a real skill, not the same one backwards. Producing a word is not recognising it |
| `pick` | The deck has enough same tag siblings to make a wrong option tempting |
| `cloze` | The material is sentences rather than pairs, and the gap is the point |

**Three templates over fifty notes is a hundred and fifty cards**, which is
roughly a month of daily reviews out of one paste. That is a real cost to the
person studying, so add the second and third template because the skill is
different, never because the format allows it.

Distractors come from siblings wherever a tag or a grouping field exists. Drawn
from the whole deck they are noise, and a wrong option nobody would pick is a
free point.

## Step 4: Ask about the licence rather than guessing

If the material is not the user's own, the deck carries `licence`,
`attribution` and `source`. When the licence starts with `CC-BY`, the exact
wording the source requires goes in `attribution` and `screen` is `required`,
and the validator refuses the deck without both. Quote the wording; do not
paraphrase it.

If the material is the user's own, say so in `licence` anyway. A deck with no
licence is one nobody else can reuse.

## Step 5: Build, keeping every id that already exists

`$FORGE` is the directory containing `skills/`: `~/.claude` after `bin/install.sh`, `plugins/neorgon-forge` inside this repo.

```bash
node "$FORGE/skills/rappel-deck/scripts/build-deck.mjs" list.tsv --id es-core-verbs \
  --name "Spanish core verbs" --lang es,en \
  --templates recognition,recall,pick --skill es.verbs \
  --tag-field Group --licence public-domain --out es-core-verbs.json
```

Extending a deck that already exists takes `--against <previous.json>`, which
keeps each existing id attached to the same first field and numbers only what is
new. The script reads Anki's `#separator:` and `#columns:` headers, so a TSV
exported from Anki needs no reshaping.

## Step 6: Validate, and prove the ids survived

```bash
node "$FORGE/skills/rappel-deck/scripts/validate-deck.mjs" es-core-verbs.json --against previous.json
```

It imports Rappel's validator, the same one the browser runs before a fetched
deck reaches storage, then adds what a schema cannot see: a note id that
vanished, a note id now holding different material, a missing licence, a choice
template ignoring its siblings, a card count that is a month of work, an em
dash. Errors are always fixed. Warnings are fixed or answered in one sentence.

## Step 7: Hand back something runnable

A deck file is not a delivery. Give the iframe snippet from
`reference/embed.md` with the right one of `?deck=`, `?src=` or `#d=` chosen by
where the file actually lives, and say which. If the deck is meant to be embedded
in a page that counts progress, say that every template carries a `skill` and
that the host reads it off `rappel:answer`.

## Judgment: what makes a deck worth studying

| The temptation | What to do instead |
|---|---|
| Every word in the source | The words that carry the meaning. A deck of 500 is abandoned; a deck of 60 is finished |
| One note per dictionary sense | One note per thing a learner has to tell apart. Two senses nobody confuses are one note |
| A translation as the note identity | The word as the identity. Translations get edited, and an id that moves is a lost card |
| Adding `recall` because it exists | Adding it when producing the item is a separate skill from recognising it |
| A definition long enough to read | An answer short enough to grade. Typed comparison is exact after the compare tokens |
| Rebuilding the deck from the list each time | Rebuilding with `--against`, so the ids and the history survive |

## Invariants

- **Note ids are never reassigned.** Extending a deck keeps every existing id,
  and a rebuild that cannot prove that is not delivered.
- **A licence and an attribution whenever the material is not the user's own**,
  with the required wording quoted rather than paraphrased.
- **A template is added because the skill is different**, never because the
  format has a slot for it.
- **Distractors come from siblings** wherever the notes carry a group.
- **The `es` half of every `{en, es}` string is neutral Spanish with correct
  orthography**: accents (qué, está, más, también, español, sílaba), ñ, and the
  opening ¿ and ¡. Accentless Spanish is a spelling error on every card.
- **Rappel's validator is the only judge**, and exit 2 is a failure rather than
  a pass. A second definition of valid is how a deck looks fine and the engine
  refuses it.
