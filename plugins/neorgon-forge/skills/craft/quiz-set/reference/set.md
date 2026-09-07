# The set, field by field

Format `neo-quiz-set/1`. The contract is `https://quiz.neorgon.com/llms.txt` and
it wins wherever this page and the site disagree.

One JSON object, one game, at least one item.

```json
{
  "format": "neo-quiz-set/1",
  "id": "jp-loanwords-beats",
  "version": "2026-09-04",
  "game": "beats",
  "name": { "en": "Loanword beats", "es": "Pulsos de préstamos" },
  "lang": "ja",
  "skill": "jp.mora.count",
  "licence": {
    "spdx": "CC-BY-SA-4.0",
    "screen": "required",
    "attribution": "Word list by ...",
    "source": "https://..."
  },
  "items": []
}
```

| Field | Rule |
|---|---|
| `format` | `"neo-quiz-set/1"` |
| `id` | Starts with a letter or digit, then letters, digits, `.`, `-`, `_`. **Scores are keyed by it, so it never changes on a set that exists** |
| `version` | A `YYYY-MM-DD` date, bumped on any content change |
| `game` | One of `beats`, `sound`, `pairs`, `order`. A set serves one game |
| `name` | A string, or `{ "en", "es" }`. English is the fallback, then Spanish; `"es": null` means not translated |
| `lang` | BCP 47 tag of the content, default `"ja"` |
| `skill` | A dotted string echoed on every `quiz:answer`, unless the URL passes `?skill=`. With neither it is `quiz.<game>` |
| `licence` | `{ spdx, screen, attribution, source }`. `spdx` and `screen` are required; `attribution` is required when `screen` is `"required"` |
| `items` | At least 1, ids unique inside the set, in the same character set as the set id |

Two rules apply to every string in the document: **no markup** (a `<` followed by
a letter anywhere is an error), and every learner-facing string is a bilingual
value, where a bare string means English.

A field the format does not know is ignored by the engine and warned by the
validator. A field prefixed `_` is exempt, which is where a generator parks its
own provenance block (`_licence`).

## beats

```json
{ "id": "lw-baggu", "word": "bag", "kana": "バッグ", "romaji": "baggu",
  "beats": 3, "split": ["バ", "ッ", "グ"], "rule": "sokuon",
  "explain": { "en": "A small っ is a beat of its own, a held stop.",
               "es": "La っ pequeña es un pulso propio, una pausa sostenida." } }
```

- `kana` is the prompt, shown large. `word` sits under it before the answer;
  `romaji` is shown **only after**, because it spells the count out
- `beats` is 1 to 9 and equals `split.length`. The options are four ascending
  numerals around it, so a word past 9 beats needs a different game
- `split` is the kana cut into beats. Joined with `""` it must equal `kana`
- `rule` is a short code naming the rule; `explain` is its one-line human
  reading, and is what the feedback panel prints under the tiles

**The split is mechanical.** A beat starts at every kana except a small
`ャュョァィゥェォヮ`, which attaches to the one before it; a small `ッ` and a long
`ー` are each a beat of their own. `コンピューター` is `コ ン ピュ ー タ ー`, six.
`scripts/build-set.mjs` derives it, so a hand-written `split` is only for a form
the rule does not cover.

## sound

```json
{ "id": "hira-ki", "kana": "き", "sound": "ki", "row": "k", "column": "i",
  "distractors": ["ka", "sa", "ni"] }
```

- `kana` and `sound` are the two faces. The engine asks in either direction,
  chosen per item by seed, so both have to stand alone as a prompt
- `row` is a label shared by one row of the grid; `column` is `a`, `i`, `u`, `e`,
  `o`, or `null` for a symbol that is a row by itself
- `distractors` is optional, 3 or more sounds. Without it the engine draws three
  from the same row or column **in this set**

**The feedback is the set's own siblings.** The strip under a miss is built from
the items sharing `row`, ordered `a i u e o`, so a row shipped with holes in it
renders with holes in it. Ship whole rows.

## pairs

```json
{ "id": "w_0001", "left": "こんにちは", "right": "hello", "note": "konnichiwa" }
```

- `left` and `right` are the only things on the board. Neither may contain the
  other after trim, casefold and strip-accents, and they may not be equal: that
  is the rule keeping the answer off the visible text, and the format enforces it
- `note` is shown only in the feedback after a miss. The reading goes here
- A board is four pairs, so the set needs at least 4 items, and no two `right`
  values may fold to the same string

## order

```json
{ "id": "sakura-1", "tokens": ["さくら", "さくら", "野山も", "里も"],
  "line": "さくら さくら 野山も 里も",
  "gloss": { "en": "Cherry blossoms, cherry blossoms, over hills and villages",
             "es": "Flores de cerezo, flores de cerezo, por montes y aldeas" } }
```

- `tokens` is the correct order, 3 to 9 pieces, **no two equal**. Two pieces is a
  coin flip; two identical pieces have no wrong order. Split a longer line into
  two items, and merge a repeated piece with its neighbour
- `line` is the display of the correct line, equal to `tokens` joined with `""`
  or with `" "`. Which of the two is a property of the writing system, so it is
  stated rather than guessed
- `gloss` is shown after a miss and on the results screen, **never before**

## The licence block

```json
"licence": { "spdx": "CC-BY-SA-4.0", "screen": "required",
             "attribution": "This site uses ... in conformance with the licence.",
             "source": "https://www.edrdg.org/edrdg/licence.html" }
```

`spdx` is an SPDX id or `"public-domain"`. `screen` is `"required"` or `"none"`.
When it is `"required"` the attribution renders under the round on every screen
that shows the set, in the embed as well as standalone, with `source` linked
beside it. The wording is the licensor's own; a paraphrase is not an attribution.

## The catalog, for a set Quiz ships

A set living in Quiz's own `data/sets/` also needs a row in `data/sets/index.json`
(`neo-quiz-set-index/1`), or `?set=<id>` finds nothing:

```json
{ "id": "jp-hiragana-sound", "file": "data/sets/jp-hiragana-sound.json",
  "game": "sound", "name": { "en": "Hiragana sounds", "es": "Sonidos del hiragana" },
  "items": 69, "licence": "public-domain", "screen": "none" }
```

The row repeats five facts the file already states, and the site's own validator
cross-checks every one of them. A set fetched by URL instead, from a Book or from
a third-party page, needs no row.

## Where a fetched set's scores live

A set fetched from `?set=<url>` on an origin that is not `neorgon.com` or one of
its subdomains is stored under `ext:<12 hex of the URL's SHA-256>:<id>`, so a
third-party document claiming a built-in id cannot merge into it. Built-in sets
and `*.neorgon.com` sets keep their plain id, and `setId` on every message
carries whichever applies.
