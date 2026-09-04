# The plan file

The input to `scripts/scaffold-book.mjs`. It is the two documents with the
mechanical joins left out, so everything in it is judgment and everything the
script adds is bookkeeping.

**The plan is an input, not an artifact.** Nothing reads it once the Book
exists. Keep it beside your notes, or throw it away; it is not part of the Book
and it is not a format anything else in the fleet knows.

## What the script fills in, so you do not

| Join | How it is derived |
|---|---|
| `format` on both documents | The two constants, written for you |
| `version` | Today, unless `book.version` says otherwise |
| the manifest's `chapters[]` | Built from each chapter's `id`, `requires` and `state` |
| each chapter's `src` | `chapters/<id>.json`, matching the file it writes |
| the chapter file's `id` | Copied from the plan, so the two copies agree |
| a chapter's `data[]` | Gathered from the pointers that chapter actually uses |
| a `planned` chapter | Entry with `"src": null` carrying `title` and `note`, and no file |
| the catalog line | Printed, and applied with `--index` |
| `modules`, `data`, `credits` | Default to empty arrays when the plan omits them |

## Shape

```json
{
  "book": {
    "id": "music-theory",
    "title": { "en": "Music theory", "es": "Teoría musical" },
    "tagline": { "en": "From naming an interval by ear to writing a cadence" },
    "glyph": "♭",
    "lang": { "content": "en", "ui": ["en", "es"] },
    "goal": { "en": "Name any interval by ear and write a progression that resolves" },
    "data": [
      { "src": "data/theory/intervals.json", "licence": "public-domain", "screen": "none" }
    ],
    "credits": []
  },
  "chapters": [
    {
      "id": "1-intervals",
      "title": { "en": "Intervals" },
      "goal": {
        "statement": { "en": "Name any interval inside one octave on sight" },
        "evidence": { "skill": "theory.interval.name", "accuracy": 0.9, "min": 20, "window": 40 }
      },
      "requires": [],
      "rungs": [ { "id": "distance", "title": { "en": "A distance, not a note" },
                   "pages": [], "exercises": [] } ]
    },
    {
      "id": "3-modulation",
      "state": "planned",
      "requires": ["2-cadences"],
      "title": { "en": "Modulation" },
      "note": { "en": "Leave one key and arrive in another. Not built yet." }
    }
  ]
}
```

Everything under `book` is a manifest field and everything under `chapters` is a
chapter field, so `reference/manifest.md` and `reference/chapter.md` are the
whole vocabulary. There is nothing else to learn.

## Running it

```bash
node scripts/scaffold-book.mjs plan.json --out <site>/books
node scripts/validate-book.mjs <site>/books/<id>
```

`--index` adds the catalog entry instead of printing it. It rewrites
`books/index.json` with two space indentation, so on a catalog whose entries were
hand formatted on one line each it produces a whitespace diff on the other Books
as well. Where that matters, leave the flag off and paste the printed line.

`--force` overwrites a Book that already exists, which is refused by default
because a Book on disk is somebody's authored content and a regeneration is not
a merge.

Exit codes are the house contract: 0 clean, 1 findings, 2 usage or environment.
The validator exits 2 when it cannot find the Runcible checkout, so a run that
checked nothing can never be mistaken for a pass.

## Adding chapters to a Book that exists

Do not re-run the scaffold over it. Write the new chapter file by hand against
`reference/chapter.md`, add its entry to the manifest's `chapters[]`, bump the
manifest's `version`, and run the validator. The scaffold is for a Book that
does not exist yet; `--force` on a live Book discards edits made since it was
generated.
