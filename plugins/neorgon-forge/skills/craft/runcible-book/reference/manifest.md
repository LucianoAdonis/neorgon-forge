# The Book manifest, field by field

Format `neo-book/1`, at `books/<id>/book.json`. Contract C1.

The shell knows nothing about your subject. Everything it does with a Book, it
does by reading this file, so a field left out is a capability the Book does not
have and a field invented is a load error.

## The catalog: `books/index.json`

A static site cannot list a directory, so Books are discovered from one file.

```json
{
  "format": "neo-book-index/1",
  "books": [
    { "id": "japanese", "title": { "en": "Japanese", "es": "Japonés" },
      "glyph": "あ", "state": "ready" },
    { "id": "piano", "title": { "en": "Piano", "es": "Piano" },
      "glyph": "♪", "state": "stub" }
  ]
}
```

| `state` | What the reader gets |
|---|---|
| `ready` | Opens, chapters and exercises run |
| `stub` | Opens and shows its ladder, no exercises |
| `planned` | A locked card. The Book is never fetched |

**Adding a Book is one array entry plus a directory, and no file under `js/`
changes.** That sentence is the acceptance test for the whole shell, and it is
why this skill exists: if adding your subject needs a shell change, say so
loudly rather than making the change.

## The manifest

```json
{
  "format": "neo-book/1",
  "id": "music-theory",
  "version": "2026-09-04",
  "title":   { "en": "Music theory", "es": "Teoría musical" },
  "tagline": { "en": "From naming an interval by ear to writing a cadence that resolves" },
  "glyph": "♭",
  "lang": { "content": "en", "ui": ["en", "es"] },
  "goal": { "en": "Name any interval by ear and write a four chord progression that resolves" },
  "tracks": [
    { "id": "classical", "label": { "en": "Classical" },
      "description": { "en": "Notation first, ear training alongside." }, "default": true },
    { "id": "by-ear", "label": { "en": "By ear" },
      "description": { "en": "Intervals and chords before a stave appears." } }
  ],
  "chapters": [
    { "id": "1-intervals", "src": "chapters/1-intervals.json", "requires": [], "state": "ready" },
    { "id": "2-cadences",  "src": "chapters/2-cadences.json",
      "requires": { "classical": ["1-intervals"], "by-ear": ["1-intervals"] }, "state": "ready" },
    { "id": "3-modulation", "src": null, "requires": ["2-cadences"], "state": "planned",
      "title": { "en": "Modulation" },
      "note":  { "en": "Leave one key and arrive in another. Not built yet." } }
  ],
  "modules": [
    { "path": "exercises/ear.js", "provides": { "exercises": ["theory.ear"] } }
  ],
  "data": [
    { "src": "data/theory/intervals.json", "licence": "public-domain", "screen": "none" },
    { "src": "data/theory/chorales.json",  "licence": "CC-BY-SA-4.0", "screen": "required",
      "attribution": "imslp" }
  ],
  "credits": [
    { "id": "imslp", "name": "IMSLP, Petrucci Music Library" }
  ]
}
```

## The rules that are not obvious from the example

1. **A Book may not set a colour.** There is no `accent` field, and adding one
   is refused by the validator. The site owns its accent; a Book identifies
   itself with `glyph` and nothing else.
2. **`data[]` is a permission list, not documentation.** The shell resolves a
   `src` named by a chapter only if that exact path appears here. An undeclared
   path is a load error naming the file. This is what lets a Book and a data
   corpus be authored by different people without either trusting the other.
3. **`requires` is an array or an object keyed by track id.** The first three
   chapters must use the array form: the foundation is fixed across tracks. The
   object form must cover every declared track, with no extra keys.
4. **`modules[]` declares what a module registers**, and the shell asserts that
   exactly those ids appeared. An undeclared registration is refused, so a Book
   cannot shadow a generic exercise type.
5. **`version` is a date string**, bumped on any content change. A Rappel deck
   compares against it to notice the Book moved under a learner.
6. **A `planned` chapter has `"src": null`** and carries its `title` and `note`
   inline, so the ladder stays visible where it is not built.
7. **`screen: "required"` needs an `attribution`** naming a `credits[]` entry,
   and that entry's wording is what renders on every screen showing the data.
   Required whenever the licence starts with `CC-BY`.

## Licence, and the line the skill does not cross

A Book declares where content comes from. It does not produce the content.

If a chapter needs a word list, a corpus, a stroke order file or a set of song
lyrics, the skill writes the `data[]` entry and the pointer, then names the file
a human has to produce and the licence it will carry. It never invents a
dictionary gloss, a lyric or a corpus entry, because an invented one is wrong
and carries a licence claim that is also wrong.
