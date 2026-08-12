# Neorgon overlay — debrief

Read this when the deck targets the **slides-site player**. The player is public at
`slides.neorgon.com` and loads a YAML file the user supplies, so this format is usable from
**any repo** — being inside the Neorgon monorepo is not a precondition, only a convenience.

## Where the schema lives

The canonical schema — every slide type, the density rules, the flow audit checklist — is
**published at a stable URL**. Fetch it; never clone a repo to read it:

- **`https://slides.neorgon.com/CLAUDE.md`** — the schema and coaching rules (source of truth)
- **`https://slides.neorgon.com/template.yaml`** — a worked example that validates clean
- **`https://slides.neorgon.com/validate.mjs`** — density validator, runs anywhere with Node

A local checkout (`projects/slides-site/` in the monorepo, or `slides-site/` standalone) holds
the same files — prefer it when present, because it is faster and works offline. The directory
test picks **which copy of the schema to read**, never whether the format is available:

```bash
{ [ -d projects/slides-site ] || [ -d slides-site ]; } && echo "local checkout — read schema from disk"
```

Both paths, deliberately: an earlier single-path gate went dead when the monorepo moved its
sites under `projects/`, and because it failed closed, `debrief` silently stopped emitting YAML.
A later session then over-corrected in the other direction — no local directory, so it *cloned
the repo* to read a schema that was already published at the URL above. Neither mistake
survives the rule as now stated: **the format is always available; only the schema's source
varies.** `--format marp` or `--format md` remain for when the user prefers them, not as a
penalty for the directory being absent.

## Format

`--format yaml` targets the slides-site player. Read the schema (URL or local copy, above)
before writing YAML — it is the source of truth, and duplicating it here would fork it.

Save to `<project>/docs/debrief-<YYYY-MM>.yaml`.

## Validate, then preview

Before showing the deck to anyone, run the density validator — it applies the player's own
`js/parser.js` rules, so it cannot disagree with the audit bar:

```bash
node projects/slides-site/validate.mjs docs/debrief-<YYYY-MM>.yaml   # local checkout
# from any other repo: curl -sO https://slides.neorgon.com/validate.mjs && node validate.mjs <deck>
```

Exit 0 is clean, 1 is density warnings with slide numbers, 2 is an unreadable deck.

Then preview — locally in the monorepo, or on the public player anywhere:

```bash
make serve P=slides-site     # http://localhost:8806, monorepo only
```

Load the YAML in the player, click through, confirm no slide overflows. The validator checks
density, not geometry: a deck can pass and still overflow, so say which of the two checks
actually ran when reporting.

## Once reviewed, offer the PDF

When the deck has passed review — validator clean, no overflow in the click-through — offer to
export a PDF as the shareable deliverable. A YAML file needs the player; a PDF survives email,
Slack, and people who will never click a link. Two routes:

- **From the player:** export **↓ Reveal.js**, open the HTML with `?print-pdf` appended, then
  the browser's Print → Save as PDF — one slide per page.
- **From Marp output:** `marp deck.md --pdf` — the exact commands live in slides-site's
  `docs/references/export-workflow.md`.

Say which slides carry `pattern:` textures if the PDF route is Marp: Marp and PPTX render flat
theme/brand colors, so the PDF from Reveal is the one that keeps the textures.

## Backgrounds

`stats` and `divider` slides accept a `background` — `ocean` is the safe default for a measured-
numbers slide. Check the schema (local `slides-site/CLAUDE.md` or the published URL above) for
the current set rather than guessing a name; an unknown background renders as the default and
the mistake is invisible in the YAML.

## Deck themes

`presentation.theme:` sets the whole deck's palette in the player. The list of names lives in
the schema ("Deck themes" — local `slides-site/CLAUDE.md` or the published URL above); read it
there, never from memory; an unknown name falls back silently except for a warning in the
audit bar. Resolution order for a debrief:

1. `--theme` passed by the user
2. A `Deck theme:` line in the target project's own `CLAUDE.md`
3. Omit the key — the player's default applies

Names are colors (`royal`, `meadow`, `azure`, …), deliberately not brands or clients: the value
is written into the YAML and travels with every export, so a palette named after a company reads
as claiming their brand in any deck that leaves the room. Match by tone instead — the light
themes suit clinical or corporate settings, the dark ones suit engineering readouts.

## What the collector already knows about this repo

`scripts/collect-changes.sh` has a Neorgon-specific section: it flags vendored and generated
files (`neorgon-header.css`, `neorgon-footer.css`, `viz.css`, `png/`, `site-registry.*`) because
these inflate the diff volume without being the work. Read that section before quoting a line
count on a slide — a 4,000-line diff that is 3,600 lines of regenerated registry is a
misleading stat, and it is the kind an engineering audience checks.

## Per-project context

A project's own `CLAUDE.md` auto-loads inside it and usually states the invariants the work was
meant to preserve. Those invariants make good "what it cost" material: the trade-off you
accepted is often the one the invariant forced.
