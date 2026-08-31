---
name: sigil
description: "Use when a Neorgon site needs its mark: the 24x24 card glyph, the accent colour, and the generated favicon set. Triggers on: 'give this site an icon', 'pick a glyph for', 'this favicon looks wrong', 'add the favicon set', 'what icon for this tool', 'the icon is too dense', 'regenerate the favicons', 'new project needs a mark'. Called by new-project and add-to-hub so a site is never born without one. Knows the standard (Energon hexagon tile, accent spark, one stroke weight, glyph fitted to its own ink), the measured thresholds that decide whether a drawing survives a 16px tab, and the order that keeps the fleet gate green. Not for third-party company logos (use brandmark), not for illustrated characters (use mascot-forge), not for generating an icon set from a photo."
argument-hint: "[<project> | audit | sweep]"
user-invocable: true
license: MIT
---

# sigil: give a site its mark

A tool's mark exists in two places that must not disagree: the card on the hub
and the favicon in the tab. They are the same object, so only one of them is
authored. **You draw the 24x24 glyph and choose the accent. Everything else is
generated**, by `packages/neorgon-ui/favicon/`, from the card itself.

Canonical rules live in `packages/neorgon-ui/favicon/README.md` and
`projects/neorgon-site/docs/ICONS.md`. This skill is the part neither of them
can hold: **which drawing to choose, and how to know before you ship it.**

## The only test that matters

A favicon is decided at 16 pixels. Everything that looks good at 96px and dies
at 16 has the same cause: too much ink in too little space. The set already
carries the numbers, so this is measured rather than argued:

```bash
python3 "$NEORGON_ROOT"/packages/neorgon-ui/favicon/generate.py --audit
```

| Column | What it means | Where the trouble starts |
|---|---|---|
| `ink%` | ink as a share of the glyph's own bounding box | above **55%** it reads heavy at any size the hexagon allows |
| `16px counters` | background pixels fully enclosed by ink | **0** means the drawing closed into a blob, unless it is open by design |
| `fill%` | how much of its 24 grid the ink spans | low is harmless, the generator fits to ink |
| `grid` | the authored viewBox | 24 is the standard; other sizes work but are drift |

`0` counters is not automatically a failure. Open forms have none by
construction: `snippets` is two chevrons, `parla` is two letterforms. Read it
next to `ink%`. Dense **and** zero is the combination that fails.

## Choosing the drawing

1. **Start at [lucide.dev](https://lucide.dev/icons)**, which is where the set
   comes from and why it is coherent. Search the *action*, not the noun: a
   planning tool is `compass` or `route` before it is `clipboard`.
2. **Prefer the simpler of two candidates**, always. At 16px inside a hexagon
   the glyph is roughly 13.6 units across. A drawing with four elements has
   about three pixels each.
3. **Reject anything with text, a screen full of rows, or a grid of dots.**
   Those are the three shapes that measure above 55%: `gamme`, `stack-rank`
   and `tubestack` are the standing examples, and no amount of sizing rescues
   them, because the density is in the drawing.
4. **Check it is not already taken.** Two tools with the same silhouette in one
   tab strip is worse than a duller second choice.
5. **Hand-draw only when nothing fits**, in the same language: 24x24,
   `fill="none"`, `stroke="#E326E4"` **on the root element**, round caps and
   joins. Stroke on the children only is the one mistake that used to pass
   every other check and ship the icon in authoring magenta; the icon lint now
   catches it, and fleet smoke check 25 runs that lint.

## Choosing the accent

- A **literal hex**, never `var(--something)`. It is inlined into a standalone
  SVG that has nothing to resolve a variable against, and the generator refuses
  it for that reason.
- It has to carry on **both a light and a dark tab strip**. Pale yellows and
  pale greens survive the dark strip and thin out on the light one.
- Not a near-duplicate of a neighbouring card's accent. The colour is what
  identifies the tool at 16px when the glyph no longer resolves.

## The procedure

```bash
# 1. the drawing lands in the hub's icon folder, and the card references it
#    (add-to-hub writes the card; this is the glyph half)
"$NEORGON_ROOT"/projects/neorgon-site/assets/icons/<name>.svg

# 2. it meets the drawing standard, or it is fixed in place
#    (make check is the documented entry point; it lints and rebuilds the sheet)
cd "$NEORGON_ROOT/projects/neorgon-site" && make check

# 3. it survives a tab
python3 "$NEORGON_ROOT"/packages/neorgon-ui/favicon/generate.py --audit | grep <project>

# 4. generate and wire the set (6 files, every top-level page)
"$NEORGON_ROOT"/packages/neorgon-ui/sync-favicon.sh --to <project>

# 5. the gate agrees
"$NEORGON_ROOT"/packages/neorgon-ui/sync-favicon.sh --check
```

Step 2 before step 3 is not arbitrary. The audit renders the glyph, so it
inherits whatever the lint would have fixed, and a stroke on the wrong element
changes what the audit measures.

## When a site has no card

The hub is the source of truth, so a site that is not on it cannot resolve a
mark. That is a legitimate state, not an error: a freshly scaffolded project
carries the template's brand default and `--check` reports it as "not on the
kit yet" without failing.

To give it one, either add the hub card, or add a `NO_CARD` entry in
`generate.py` naming its glyph and accent. Infrastructure surfaces (the hub,
the CDN, ops-console) take the Energon mark itself rather than a tool glyph,
and a brand mark becomes the whole silhouette with no tile and no spark:
nesting a hexagon inside a hexagon is redundant at 96px and mush at 16.

## What this skill does not decide

- **The stroke weight, the tile, the spark, the insets.** Those are the
  standard, they were measured once, and a per-site exception is how a fleet
  stops being one. Change them in the kit or not at all.
- **Whether a dense glyph is acceptable.** The audit reports; a person decides.
  A check that fails a build on taste teaches people to switch it off.
- **The rollout.** Sweeping many sites is `sync-favicon.sh` over a registry
  selection, which is mechanical and wants a loop, not a skill.

## Invariants

- **One authored artefact per mark.** The glyph and the accent are written on the
  hub card; everything else is generated from it. A hand-edited `favicon.svg`
  is drift, and `--check` reports it as such.
- **The 16px measurement decides, not the 96px view.** Run the audit before
  shipping a drawing, not after someone notices the tab.
- **The standard is fleet-wide.** Stroke weight, hexagon, spark and insets are
  not per-site choices. If one site needs an exception, the standard is wrong.
- **A brand mark is the silhouette, never nested.** Infrastructure surfaces take
  the Energon mark alone, with no tile and no spark.
- **The accent is a literal hex.** A variable resolves on the hub and paints
  nothing in a standalone SVG.
- **Advisory checks never fail a build.** Density is a drawing decision; a gate
  that fails on taste gets switched off, and then it guards nothing.
