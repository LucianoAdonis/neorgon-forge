# The deck format, field by field

Format `neo-deck/1`. Published spec: `https://rappel.neorgon.com/llms.txt`.
Contract C4.

One JSON object. Fields, templates, notes, and a licence block. The renderer is
a switch over four template kinds, not a template language, so anything clever
in a template string is a card that renders as literal text.

## Shape

```json
{
  "format": "neo-deck/1",
  "id": "es-core-verbs",
  "version": "2026-09-04",
  "name": { "en": "Spanish core verbs", "es": "Verbos base del español" },
  "lang": { "front": "es", "back": "en" },
  "licence": "CC-BY-SA-4.0",
  "attribution": "The exact sentence the source requires on screen.",
  "source": "https://example.org/licence",
  "screen": "required",
  "media_base": "media/",
  "fields": ["Infinitive", "English", "Group"],
  "templates": [
    { "id": "recognition", "kind": "basic", "skill": "es.verbs.read",
      "front": "{{Infinitive}}", "back": "{{English}}" },
    { "id": "recall", "kind": "typed", "skill": "es.verbs.write",
      "answer_field": "Infinitive", "front": "{{English}}", "back": "{{Infinitive}}",
      "compare": "trim|casefold" },
    { "id": "pick", "kind": "choice", "skill": "es.verbs.read",
      "answer_field": "English", "front": "{{Infinitive}}",
      "distractors": "siblings", "count": 4 }
  ],
  "notes": [
    { "id": "n_0001", "f": { "Infinitive": "ser", "English": "to be (essence)", "Group": "irregular" },
      "tags": ["irregular"], "templates": ["recognition", "recall", "pick"] }
  ]
}
```

`name` may be a bare string. `templates` on a note is optional and defaults to
every template in the deck.

## Card identity, which is the one thing never to get wrong

**A card is `noteId + ":" + templateId`.** A string, stable across
re-downloads, never an index and never a generated integer.

The review ledger is a separate document keyed on exactly that string, which is
what lets a learner re-download an updated deck without losing a year of
scheduling. Renumber the notes and every card in the deck goes back to new,
silently, in a file that validates perfectly. A cloze note expands to one card
per distinct marker, so the id is `n_0001:cloze:1`.

This is why `build-deck.mjs` takes `--against <previous.json>` and why
`validate-deck.mjs` takes it too. Rebuilding without it is the mistake.

## The four template kinds

| `kind` | What it does | Needs |
|---|---|---|
| `basic` | front, then back | `front`, `back` |
| `typed` | the learner types the answer | `answer_field`, optional `transform`, `compare` |
| `cloze` | `{{cN::text::hint}}` markers become one card each | `text_field` |
| `choice` | one right option among N | `answer_field`, `distractors`, `count` (2 to 8) |

`{{Field}}` substitution only. No conditionals, no filters, no `{{FrontSide}}`,
no `{{hint:}}`, no `{{tts:}}`. Every field named by a template must be in
`fields[]`.

`transform` is `kana` or `kana-katakana`, and only on `typed`. `compare` is
pipe separated from `trim`, `casefold`, `strip-accents`, `collapse-space`,
`kana`, applied in order.

A template's `skill` is what a host reads off `rappel:answer`. Without it, a
review inside a Runcible chapter counts toward nothing, so give every template
one whenever the deck might be embedded.

## Licence, and the sentence that has to render

`licence` is an SPDX id or `public-domain`. **When it starts with `CC-BY`,
`attribution` and `screen: "required"` are both mandatory** and the validator
refuses the deck without them, because an SPDX id does not carry the wording a
source requires on screen. `attribution` is that exact wording, quoted, not
paraphrased.

Ask rather than guess. A deck built from someone else's word list with no
licence field is a deck nobody can reuse and a claim nobody can check.

## Media, and what a deck is not allowed to do

`media_base` is a same origin relative path with no `..` segment. Media is
referenced by filename, never inlined as base64, and Anki's own spellings are
kept so a converted deck needs no field rewriting: `[sound:a.mp3]` and
`<img src="a.png">`.

A deck fetched from another origin is stored under
`ext:<12 hex of sha256 of the url>:<deck.id>`, so a third party deck claiming a
familiar id cannot merge into a learner's real progress.

## Importing an existing list

TSV, CSV and JSON. `.apkg` is not supported: its inner collection is zstd, which
only recent Firefox can decompress in a browser, and reading it needs a SQLite
build that a zero build site will not carry.

TSV and CSV use Anki's own header dialect verbatim, so a file exported from Anki
round trips:

```
#separator:tab
#html:false
#notetype:Basic
#deck:Spanish core verbs
#columns:Front	Back	Tags
#guid column:1
#tags column:3
```

`build-deck.mjs` reads `#separator:` and `#columns:` and ignores the rest. With
no header it takes the first row as field names and says that it did.
