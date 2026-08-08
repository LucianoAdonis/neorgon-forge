# Neorgon overlay — writeup

Read this only when working inside the Neorgon monorepo (`Documents/Projects/Personal`).
Everything here is a local convention, not part of the portable skill.

## Palette

`scripts/diagram-kit.mjs` ships with the Neorgon dark canvas so diagrams read as part of the
site:

| Token | Value | Use |
|---|---|---|
| `BG` | `#040714` | Canvas |
| `INK` | `#f9f9f9` | Primary text |
| `DIM` / `MUTE` | white at 62% / 46% | Secondary text |
| `LINE` | white at 16% | Rules, borders |
| `ACCENT` | `#B015B0` | Eyebrow text, emphasis |

`FONT` is `'Avenir Next','Segoe UI',Roboto,sans-serif`.

**Outside this monorepo, change these first.** A post for another context rendered in Neorgon
magenta looks like it was copied from somewhere else, which is the one impression a write-up
cannot afford.

Per-site accent colours are canonical in `PROJECTS.md`. When a post is about one site, use that
site's accent rather than the default magenta, and the diagrams will match the screenshots.

## sharp lives at the monorepo root

`rasterize.mjs` resolves `sharp` from the current working directory's `node_modules`, and in
this monorepo that means the root — not the project. Run it from the root:

```bash
node <project>/post/build-visuals.mjs && node <project>/post/rasterize.mjs
```

Or point it elsewhere: `SHARP_FROM=/path/to/dir/with/node_modules/ node post/rasterize.mjs`.

If `sharp` is missing entirely, `npm install sharp` at the root rather than per project.

## Voice

The author's voice for Neorgon posts is tracked by the **`voicecheck`** skill via a per-project
`VOICE.md`. Read that file if it exists before drafting — it is a record of decisions already
made about register, and re-deciding them produces a post that does not match the last one.

Copy rules for headlines, subtitles and button labels are canonical in `PROJECTS.md`.

## Spanish

The author is Chilean, which is why `reference/spanish.md` weights the Chilean regionalism list
most heavily — those are the ones that slip through unnoticed. That file is portable; this note
is just the reason it looks the way it does.

## Where posts live

`<project>/post/`, alongside the code the post is about, so a diagram generator can import the
project's model with a relative path. That colocation is what makes the no-drift guarantee work
— a post in a separate repo cannot import anything, and its numbers go stale silently.
