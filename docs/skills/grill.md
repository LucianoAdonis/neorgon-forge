# grill

Be argued with before you build.

## What it does

`grill` runs a relentless interview against a plan, a design, or a decision. It models the plan
as a **design tree**, works out which decisions are answerable right now, and asks all of them
at once, each with a recommended answer. Your replies settle branches, which unblocks the next
round.

The defining constraint is the **frontier**: it asks the whole set of currently-answerable
questions in one round, never one at a time. A plan with fourteen open decisions becomes
fourteen exchanges under the obvious approach, and the user quits at six.

## When to reach for it

Type `/grill`, or the agent reaches for it when you ask to have a plan stress-tested.

Reach for it before building, when the plan feels agreed but untested, or when every response
so far has been agreement. For a problem whose shape is not yet known, [untangle](untangle.md)
comes first: grilling a plan you cannot state produces confident answers to the wrong questions.

## Facts are the agent's job, decisions are yours

It never asks you something the filesystem can answer. A question whose answer is in the repo
spends your attention on the cheapest possible thing, and reads as not having looked.

It never decides, either. Recommending an answer to every question is not the same as picking
one, and when you go against a recommendation it records the choice and moves on rather than
arguing the point twice.

## Two grips

| Situation | What you get |
|---|---|
| Inside a git repo | The interview, plus `.forge/context.md` (the vocabulary) and a numbered record for each hard-to-reverse decision |
| No repo, or `--stateless` | The interview only. For a plan, a piece of writing, a decision with no working directory under it |

It says which grip it is in before the first round, so nobody discovers at the end that nothing
was written down.

## It's working if

- A round arrives with six numbered questions, not one.
- It goes and finds a fact instead of asking you for it.
- Something surfaces that you had assumed without noticing you had assumed it.
- It ends by telling you the scope was too big, where that is true. A grilling running past six
  rounds is usually two plans.
