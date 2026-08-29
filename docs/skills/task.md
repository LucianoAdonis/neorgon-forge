# task

A problem to solve rather than an edit to make: scoped, sized, and recorded while it happens.

## What it does

`task` picks an execution mode proportional to the work (`quick`, `standard`, `campaign`),
resolves the ambiguities that would change the result in one round of questions, then builds,
splitting a campaign into workstreams it can delegate and verify.

The defining constraint is **the brief**. It maintains `.forge/brief.md` *during* the work: the
symptom before the fix, the alternative that lost, the number actually measured. Those three
are exactly what a diff cannot show and a long session reliably forgets, and they are what
[debrief](debrief.md) and [writeup](writeup.md) read afterwards.

## When to reach for it

Type `/task`, or the agent reaches for it when a request is phrased as a goal rather than a
diff: implement X, refactor Y, figure out why Z broke.

Reach for it for a feature, a refactor, a migration, or a bug whose cause is already known. Not
for a one-line change you already know how to make; not when the shape of the problem is still
unknown, where [untangle](untangle.md) comes first.

## Mode is the decision that matters

| Mode | Fits | Costs |
|---|---|---|
| `quick` | One file, cause known, under ~30 lines | No brief, no plan |
| `standard` | A few files, one subsystem | Brief plus an inline plan |
| `campaign` | Many files or subsystems, or work spanning sessions | Brief plus tracked workstreams |

Getting this wrong in either direction is the common failure: ceremony on a small task wastes
the user's time, and a campaign run as a quick fix produces half a migration. It escalates out
loud and never downgrades silently.

## Delegated work is verified against the diff

A subagent reporting success is evidence, not proof. Returned work gets read as a diff, its
counts spot-checked, and its silences investigated, because silence about a hard case usually
means the case was skipped.

## It's working if

- It names its mode in the first message, and says why.
- `.forge/brief.md` has entries timestamped during the work, not all at the end.
- The final report has a "still open" section with something real in it, or one line saying
  there is genuinely nothing.
- A guard it added has a test that trips it.
