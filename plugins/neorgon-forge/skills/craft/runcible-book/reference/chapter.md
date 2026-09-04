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

## The nine exercise types

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
| `custom` | a module the Book ships | module decides | `module`, optional `props` |

Every exercise also needs `id` and `skill`. `read` and `speak` record
`correct: null` always, so a `pass` threshold on either can never be met and is
refused.

**Reach for `custom` last.** It is the only field in the format that makes a
Book carry code, and code is the thing that does not travel. Before writing a
module, say in one sentence which of the eight others cannot express the drill.
"More attractive" is not that sentence.

## Pointing at data

`"<path>#<dotted.path>"`. The path half must appear in the manifest's `data[]`.
The fragment half is a dotted lookup into the loaded JSON, and a bare key works
for a top level map: `strokes.json#あ`.

A chapter's own `data[]` lists the files it needs when it opens, which is what
lets the shell fetch them together rather than one at a time. The scaffold
gathers that list from the pointers the chapter actually uses, so it is one less
thing to keep in sync by hand. A `deck` exercise's `src` is **not** in it: the
engine fetches that across origins, so it needs the manifest's permission but
not a place in the chapter's fetch list.

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
