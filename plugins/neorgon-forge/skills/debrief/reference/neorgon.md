# Neorgon overlay — debrief

Read this when the deck targets the **slides-site player**. The player is public at
`slides.neorgon.com` and loads a YAML file the user supplies, so this format is usable from
**any repo** — being inside the Neorgon monorepo is not a precondition, only a convenience.

## Where the schema lives

**Fetch `https://slides.neorgon.com/llms.txt` first.** It is the site's own index for agents:
it names every file below, the current slide types, the gradient and pattern presets, the
Markdown import path, and the build commands. Read it before writing YAML, because it is
maintained beside the player and this file is not.

That ordering is the lesson of a real failure. This section used to hardcode three URLs as if
they were the contract. They stayed correct and went stale anyway: the player grew a deck
library, a headless build CLI, an export checker and an `llms.txt`, and a user had to spell all
of it out in a prompt because the skill still described a three-file site. **A list maintained
in two places drifts in one.** So the list below is a fallback for when the fetch fails, not the
source of truth:

- **`https://slides.neorgon.com/llms.txt`** — the index. Start here
- **`https://slides.neorgon.com/CLAUDE.md`** — the schema and coaching rules
- **`https://slides.neorgon.com/deck-library/`** — twelve complete decks that validate clean
- **`https://slides.neorgon.com/validate.mjs`** — density validator, runs anywhere with Node
- **`https://slides.neorgon.com/render-deck.mjs`** — builds PPTX, PDF, HTML without the browser
- **`https://slides.neorgon.com/template.yaml`** — the single-file worked example

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

## Start from a library deck

`reference/deck-skeleton.yaml` is a skeleton with the reasoning in its comments. The **deck
library** is the other half: twelve finished decks that already validate clean, several of them
aimed at exactly the occasions debrief serves. Fetch the closest one and edit it. Starting from a
deck that renders beats starting from a stub that does not.

| The debrief you are writing | Start from |
|---|---|
| Sprint review, team update | `deck-library/decks/all-hands.yaml` |
| Retro | `deck-library/decks/retro.yaml` |
| Standup or a short readout | `deck-library/decks/standup.yaml` |
| Stakeholder or exec readout | `deck-library/decks/exec-review.yaml` |
| Engineering design readout | `deck-library/decks/design-review.yaml` |
| Incident or regression writeup | `deck-library/decks/postmortem.yaml` |
| Launch or feature announcement | `deck-library/decks/launch.yaml` |
| **Product or platform overview** (no diff behind it) | `deck-library/decks/pitch.yaml` |

```bash
curl -sO https://slides.neorgon.com/deck-library/decks/exec-review.yaml
```

`llms.txt` lists all twelve with what each one demonstrates. Check it rather than assuming this
table is current.

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

When the deck has passed review — validator clean, no overflow in the click-through — **produce
the PDF, do not describe how to.** A YAML file needs the player; a PDF survives email, Slack, and
people who will never click a link. One command:

```bash
node render-deck.mjs docs/debrief-<YYYY-MM>.yaml --pdf --out docs/
node render-deck.mjs docs/debrief-<YYYY-MM>.yaml --pptx --pdf   # both, if they want to edit it
```

It imports the same serializer the web app uses, so the file matches what the app would have
handed over. **It must run from a checkout**, not from a lone downloaded copy: it needs the
player's `js/state.js` and `js/serialize.js` beside it. In the monorepo that is
`projects/slides-site/`; anywhere else, clone the site once. `--pdf` needs
`@marp-team/marp-cli` and a Chrome it can drive, and a missing package prints its own install
line rather than a stack trace.

Two fallbacks when Node or Chrome is not available:

- **From the player:** export **↓ Reveal.js**, open the HTML with `?print-pdf` appended, then
  the browser's Print → Save as PDF, one slide per page.
- **From Marp output:** `--md` needs no browser at all, then `marp deck.md --pdf` elsewhere.

Say which slides carry `pattern:` textures whenever the route is Marp or PPTX: both render flat
theme colors, so the Reveal print is the only one that keeps the textures. Then run
`check-exports.mjs` on what you produced — it reads the built file rather than the deck, and
catches text that never made it out.

## Screenshots and demo assets

Capturing here is cheap — every site has a dev server (`make serve P=<project>`, ports in the
root CLAUDE.md) and the harness can screenshot it. For before/after: the **live site** still
serves the old state until the change deploys, and localhost serves the new one — capture both
while that window is open, it closes at push.

Where they go: save captures beside the deck as `docs/debrief-<YYYY-MM>-img/<name>.png` and
reference them relatively. For a deck that leaves the repo (published, PDF, shared YAML),
prefer **live-site URLs** instead — the sites are public, so
`https://<site>.neorgon.com/images/…` renders wherever the YAML travels, which no relative
path does. Assets that already exist (OG images at `png/` or `images/og-*`, mascot art under
`images/mascot/`) are linked, never copied.

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
