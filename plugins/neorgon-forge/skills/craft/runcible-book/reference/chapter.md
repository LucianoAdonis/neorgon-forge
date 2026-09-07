# The chapter, page by page

Format `neo-chapter/1`, at `books/<id>/chapters/<n>-<slug>.json`. Contract C3.

A chapter is a goal, a ladder of rungs, and the pages and exercises on each
rung. A rung is one sitting: something that can be finished before the reader
puts the tab away.

## Shape

```json
{
  "format": "neo-chapter/1",
  "id": "1-intervals",
  "title": { "en": "Intervals", "es": "Intervalos" },
  "goal": {
    "statement": { "en": "Name any interval inside one octave on sight" },
    "evidence": { "skill": "theory.interval.name", "accuracy": 0.9, "min": 20, "window": 40 }
  },
  "requires": [],
  "state": "ready",
  "estimate": { "minutes": 180, "note": { "en": "Two or three sittings, most of it ear work" } },
  "data": ["data/theory/intervals.json"],
  "rungs": [
    {
      "id": "distance",
      "title": { "en": "An interval is a distance, not a note" },
      "unlocks": { "en": "every chord, because a chord is three intervals stacked" },
      "pages": [ { "id": "p-distance", "kind": "prose", "title": { "en": "Count the letters" },
                   "body": { "en": ["One paragraph per array entry."] } } ],
      "exercises": [ { "id": "e-name", "type": "choice", "skill": "theory.interval.name",
                       "items": "data/theory/intervals.json#simple",
                       "prompt": "pair", "answer": "name",
                       "distractors": { "from": "siblings", "n": 3 },
                       "count": 10, "pass": { "accuracy": 0.8 } } ]
    }
  ]
}
```

## The goal, and how a chapter is passed

`goal.statement` is **something the learner can do**, never a topic. "Read a
song line without romaji", not "Songs". If the sentence starts with learn,
understand, know or study, it is naming a state of mind rather than an act, and
nothing can observe it.

`goal.evidence` is what actually passes the chapter:

> over the most recent `window` attempts carrying `skill`, at least `min`
> attempts exist and at least `accuracy` of them were correct.

Attempts arrive from the chapter's own exercises and from an embedded Rappel
deck, so a skill string is the join between the two. **An evidence skill that no
exercise in the Book carries is a goal that can never be met**, which is why the
validator treats it as an error rather than a warning.

`pass` on an exercise is only the tick beside that exercise. It is not the gate.

A chapter is available when everything in `requires` is passed, and every locked
chapter carries a visible manual override. A gate a self taught adult cannot open
is a wall, so write the ladder as advice rather than as a fence.

## Page kinds

| `kind` | Fields |
|---|---|
| `prose` | `title`, `body` (array of paragraphs), optional `note`, optional `figure` |
| `table` | `title`, `columns`, then `rows` or an `items` pointer |
| `figure` | `figure` with a `caption` |
| `callout` | `tone` (`note`, `warn` or `win`), `body` |

`figure.kind` is `svg` (a data pointer plus a named `render`) or `viz` (a viz kit
builder plus data). An `svg` figure draws geometry only, and the shell prints a
visible line naming anything it could not draw.

**No inline HTML in any content field.** Everything is escaped, and the
validator refuses a tag. Content is authored by a skill and the shell has to be
safe against it.

## The ten exercise types

None of them names a subject. That is the whole design: a Book supplies
material, the shell supplies drills.

| `type` | What the learner sees | Graded | Required fields |
|---|---|---|---|
| `read` | one or more pages | no | `pages` |
| `choice` | a prompt, N options, one right | yes | `items`, `prompt`, `answer`, `distractors` |
| `typed` | a prompt and a text box | yes | `items`, `prompt`, `answer` |
| `match` | two shuffled columns to pair | yes | `items`, `left`, `right`, `n` |
| `order` | shuffled tokens to arrange | yes | `items`, `sequence` |
| `listen` | speech, then pick or type | yes | `items`, `speak`, `answer`, `respond` |
| `speak` | speech modelled, said back | never | `items`, `expect` |
| `deck` | an embedded Rappel session | yes | `src`, optional `limit`, `mode` |
| `quiz` | an embedded Quiz round | yes | `game`, `src`, optional `limit` and `filter` |
| `custom` | a module the Book ships | module decides | `module`, optional `props` |

Every exercise also needs `id` and `skill`. `read` and `speak` record
`correct: null` always, so a `pass` threshold on either can never be met and is
refused.

**Reach for `custom` last.** It is the only field in the format that makes a
Book carry code, and code is the thing that does not travel. Before writing a
module, say in one sentence which of the nine others cannot express the drill.
"More attractive" is not that sentence.

## The quiz exercise, and when a round beats a generic drill

An embedded round from the Quiz engine, contract `neo-quiz-set/1` and
`neo-quiz-embed/1`, both published at `https://quiz.neorgon.com/llms.txt`.

```json
{ "id": "e-beats", "type": "quiz", "game": "beats", "skill": "jp.mora.count",
  "src": "books/japanese/sets/jp-loanwords-beats.json", "limit": 10,
  "title": { "en": "Count the beats", "es": "Cuenta los pulsos" } }

{ "id": "e-k-read", "type": "quiz", "game": "sound", "skill": "kana.hiragana.read",
  "src": "books/japanese/sets/jp-hiragana-sound.json", "limit": 5,
  "filter": "row:k", "title": { "en": "The k row" } }
```

| Field | Rule |
|---|---|
| `game` | Required, one of `beats`, `sound`, `pairs`, `order`. Any other value is refused before the frame mounts |
| `src` | Required. A `neo-quiz-set/1` document **on Runcible's own origin**, and declared in the manifest's `data[]` |
| `skill` | Required. Every `quiz:answer` is recorded as one attempt under **this** string |
| `limit` | Optional positive integer, capped at the length of the set, or of the filtered part of it |
| `filter` | Optional. `<field>:<value>[,<value>...]`, one field, from `row`, `column`, `group` and `rule`. Narrows the round to the part of the set this rung taught |

**A filter is how one set serves a whole chapter.** The rung that teaches the k
row embeds the whole hiragana table with `"filter": "row:k"`, and the rung that
drills greetings embeds the whole word list with `"filter": "group:greetings"`.
Two things make this better than one set per rung: the distractors and the
`sound` game's feedback strip are drawn from the **whole** set, so a five item
round still shows all five cells of its row, and the score, the ids and the
licence stay in one document instead of fifteen.

The filter is on the frame and on the "Open in Quiz" link beside it, so the
escape hatch is the same round rather than a different exercise.
`tools/validate-book.mjs` reads the grammar and then opens the set and counts:
under four matches is an error for `pairs`, whose board is four pairs, under
three for the other games, since a kana row ships whole even when it is short.
A filter matching nothing would be the engine's `filter-empty` screen, so it is
a build error and never a learner's.

Three rules ride along, and each is a rule the `deck` exercise already has:

1. **The `src` is declared or the chapter does not load.** An undeclared path is
   a load error naming `book.json`, not a missing game. C1.3 rule 2 makes no
   exception for an embed.
2. **The attempt is recorded under the spec's `skill`, never the set's.** The
   set's `skill` is informational and the engine only echoes it. Recording under
   the engine's is how a whole term of reviews lands nowhere.
3. **The skill rule is the deck's, unchanged.** It should be this chapter's
   `goal.evidence.skill`; a skill some other goal or non-quiz exercise reads is
   allowed and warned, so the choice is visible; a skill nothing in the Book
   reads is an error, because the attempts are recorded and never counted.

**Prefer a quiz round whenever a set exists or can be generated for the
material.** Over a generic `choice`, `match` or `order` on the same items, the
round buys two things the generic types do not have: it shows the **reason** on a
wrong answer (the beats cut into tiles and the rule named, the kana's own row
drawn out of the set, the pair side by side, the correct line with the first
misplaced piece marked), and it **keeps the answer off the prompt** by holding
the romaji, the note and the gloss back until the answer is in. A `choice`
exercise over the same word list can do neither, so it is the right call only
when no set exists and none can be generated.

`quiz` is not a subject in the shell any more than `deck` is. Both are one
iframe and one postMessage vocabulary, so a Book that adds a round still changes
no file under `js/`.

### Where a set comes from

**A set is generated from the Book's own corpus, not written by hand.**
`./tools/build-sets.mjs` reads `./tools/selection/sets.json`, one row per set,
and writes each set twice from the one source: into Quiz's own library and into
`books/<id>/sets/`, so the two copies cannot drift. Adding a set to a Book that
already has the corpus is a row in that selection file and a re-run, then
`quiz-site`'s `tools/validate-set.mjs` over what it wrote.

Two facts make it a generator rather than a convenience. An item id is derived
from the corpus id of the record it came from, never from a position, because
`quiz:answer` carries that id as `itemId` and this Book stores it as evidence: an
id that moves between runs orphans every attempt a learner made on that item, and
nothing reports it. And the generator supplies no language of its own, so a
gloss, a lyric or an explain line it cannot find in the corpus comes out `null`
rather than invented.

For material with no corpus behind it, the set is authored by `quiz-set`, which
owns the format and the validator. This skill owns the chapter around the round.

## Pointing at data

`"<path>#<dotted.path>"`. The path half must appear in the manifest's `data[]`.
The fragment half is a dotted lookup into the loaded JSON, and a bare key works
for a top level map: `strokes.json#あ`.

A chapter's own `data[]` lists the files it needs when it opens, which is what
lets the shell fetch them together rather than one at a time. The scaffold
gathers that list from the pointers the chapter actually uses, so it is one less
thing to keep in sync by hand. A `deck` or `quiz` exercise's `src` is **not** in
it: the engine fetches that across origins, so it needs the manifest's
permission but not a place in the chapter's fetch list.

## Typing, transforms and comparison

`transform` names something the **Book** registered, because the shell ships no
transforms at all. A kana deck that accepts romaji typing is a Book capability.
Transform ids are free form; exercise ids must contain a dot and must not start
with a generic type name.

`compare` is the separate axis of how a typed answer is graded. Pipe separated,
applied in order: `trim`, `casefold`, `strip-accents`, `collapse-space`, `kana`.
The default is `trim|casefold`.

## Two speech facts

1. `getVoices()` is asynchronous on Chrome and returns an empty array until
   `voiceschanged` fires. Anything listing voices must listen for that event.
2. `speak` is never graded. Where recognition exists the transcript is shown to
   the learner as their own feedback, never as a score, so an exercise that only
   works with a microphone is not one to write.
