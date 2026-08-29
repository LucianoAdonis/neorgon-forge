# pathfinder

Read and write Pathfinder canvases (pathfinder.neorgon.com): take an exported
brief or canvas JSON in the frame its author set, and hand results back as a
canvas that provably loads.

## What it does

Pathfinder's export opens with a `## Situation` section and a mode; this skill
obeys them instead of skimming to the block list. In the other direction it
emits canvas JSON or a `#s=` share link against the app's published contract,
maps findings onto the canvas (an answered question gets its `answer`, a
verified assumption becomes a `decision` with the evidence in `rationale`),
and proves the result loads with the app's own `validate.mjs` before anything
is handed over.

The defining constraint: what the validator accepts is exactly what the app
accepts, because they are the same `normalize.js`. A canvas that validates
lossy is reported item by item, never silently trimmed.

## When to reach for it

Type `/pathfinder`, or the agent reaches for it when a Pathfinder export,
link, or JSON shows up, or when finished work should return to the map it
was planned on.

For arguing with the plan itself, that is [grill](grill.md). For presenting
the finished work, [debrief](debrief.md). The work in the middle is ordinary
work, or [task](task.md).

## The write-back loop

An investigation that ends in a chat log gets run again in three weeks. The
skill's second half exists for that: answers land in the question blocks,
settled assumptions become decisions, new findings become wired blocks, and
the canvas comes out worth more than it went in.
