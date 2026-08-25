---
name: pathfinder
description: "Use when a Pathfinder canvas is in play: the user hands over an exported brief (it opens with '## Situation'), pastes canvas JSON, shares a pathfinder.neorgon.com link, or wants finished work folded back into their map. Covers reading the brief in its intended mode, emitting canvas JSON or a #s= share link that provably loads, the acceptance-criteria and rationale fields, and validating with validate.mjs before handing over. Triggers on: 'here is my pathfinder export', 'turn this plan into a pathfinder canvas', 'update my canvas with what we found', 'make me a pathfinder link'. Not for arguing with the plan itself (use grill) or building the deck about it (use debrief)."
argument-hint: "[brief|json|link] [target]"
user-invocable: true
license: MIT
---

# pathfinder: read and write Pathfinder canvases

Reads a Pathfinder handover (brief, JSON, or share link) the way its author
framed it, and writes results back as a canvas that provably loads. The
failure it prevents: hand-rolled canvas JSON that silently drops half its
blocks on import, and investigations whose answers die in the chat log
instead of returning to the map they came from.

## Step 1: read what arrived

- **A brief** (opens with `## Situation`): obey that section literally before
  anything else. It says whether a codebase exists, whether you can reach it,
  and what to do first. `## Task` carries the mode; Assumptions are unverified
  bets to pressure-test, Open Questions are genuine unknowns, Connections are
  the dependency order. Do the work the brief asks for; this skill takes over
  again when results must go back.
- **Canvas JSON or a `#s=` link**: load `reference/contract.md` for the exact
  shape and enums before touching it. A `#s=` payload decodes as
  `decodeURIComponent(atob(hash))`.
- **Nothing yet, the user wants a canvas from a plan**: build JSON per the
  contract. Rough x/y are fine; the app's Tidy arranges it.

## Step 2: write the result back

Emit one of:

- **Full canvas JSON** for Export ▾ → Import JSON (replace or merge).
- **An updated copy of their canvas**: keep every existing block `id` stable
  so a merge stays sane; wire new blocks to existing ids.
- **A share link**: `https://pathfinder.neorgon.com/#s=` +
  `btoa(encodeURIComponent(JSON.stringify(payload)))`, and append
  `?via=<your-name>` (letters, digits, dashes) before the hash so the arrival
  is countable. Over roughly 50 KB of JSON, prefer handing the file itself.

## Step 3: prove it loads

```bash
bash "$FORGE/skills/pathfinder/scripts/validate-canvas.sh" canvas.json
```

It runs the app's own normalizer (fetching it from the live site when no
checkout is nearby), names every item that would be dropped or coerced, and
exits 0 clean / 1 lossy / 2 unreadable. Fix what it names; never hand over a
canvas that validates lossy without telling the user exactly what drops.

## Folding findings back: what becomes what

The judgment this skill exists for. Results map onto the canvas, not beside it:

| What you found | What it becomes |
|---|---|
| The answer to an Open Question | The question's `answer` field, evidence included; the block stays |
| An assumption you verified | A `decision` block with the evidence in `rationale`; delete the assumption, it is not one any more |
| An assumption you refuted | Same, but the decision records the refutation and what changes because of it |
| Something new that matters | A new block, typed honestly, wired to what it affects |
| Work that defines "done" | `criteria` entries on the requirement/goal/output, one short string each |
| A step you took | Leave it out unless it changes the plan; the canvas is the plan, not the log |

## Invariants

- **Never invent what you were not given.** No acceptance criteria, no
  rationale, no answers you do not have; the app renders `[NEEDS INPUT]` for
  a reason.
- **Assumption versus question is semantic, not stylistic.** A belief being
  acted on unverified is an `assumption`; a known unknown is a `question`.
  The export instructs the reader differently for each.
- **Prefer real types over `custom`.** Every enum is in the contract; an
  unknown type is dropped on import, not preserved.
- **Validate before handing over.** Every canvas, every time; the script is
  one line.
