---
name: grill
description: "Use when a plan, design, or decision needs stress-testing before anyone builds it, and the user wants to be argued with rather than agreed with. Runs a relentless multi-round interview: every round asks the whole frontier of answerable questions at once, each with a recommended answer, and the user's replies push the frontier outward. Facts are the agent's job, decisions are the user's. In a repo it leaves a paper trail: a glossary at .forge/context.md and a numbered decision record for anything hard to reverse. Triggers on: 'grill me', 'poke holes in this', 'stress-test this plan', 'what am I missing', 'argue with me', 'challenge this design', 'interview me about', 'before I build this'. Not for a problem whose shape is unknown (use untangle), not for scoping work already decided (use task), and not for auditing code that exists (use code-review)."
argument-hint: "[the plan, design or decision] [--stateless]"
user-invocable: true
license: MIT
---

# grill: be argued with before you build

An agent that agrees with your plan has told you nothing. This runs the opposite: a structured
interview that keeps asking until every branch of the design has been visited, so the thing
that would have surfaced in week three surfaces in the first hour instead.

It exists because the expensive failure in a plan is never the part you were unsure about. It
is the part you never noticed you had assumed.

## The design tree, and the frontier

Model the plan as a **design tree**: every decision branches into the decisions that hang off
it. The **frontier** is every decision whose prerequisites are already settled, the questions
answerable *now* without guessing at answers you have not heard.

Ask the whole frontier in one round. Not one question at a time: a plan with fourteen open
decisions becomes fourteen exchanges, and the user quits at six.

```
Q1 - <question title>
<the question, with the options where there are options>
-> <your recommended answer, and the one line of reasoning behind it>

Q2 - <question title>
...
```

Number them, recommend an answer to every one, then **stop and wait**. Each round's answers
reshape the tree: settled decisions push the frontier outward and unblock what depended on
them. Recompute and ask the next round.

A question whose answer depends on another question still open in this round belongs to a
**later** round. Asking it now produces an answer built on a guess, and the user cannot tell
which of their answers was contaminated.

## Facts are yours, decisions are theirs

When a frontier question needs a fact from the environment (what the config already sets, which
sites use the token, whether the API supports it), **go and find it**. Never ask the user
something the filesystem or a command can answer. A question whose answer is in the repo reads
as not having looked, and it spends the user's attention on the cheapest possible thing.

Dispatch a subagent for anything slow, and do not block on it: a running investigation is an
unsettled prerequisite, so only the questions downstream of it wait. Ask the rest of the
frontier now.

The **decisions** are the user's, every one. Recommending an answer is not deciding it. When
the user picks against your recommendation, record what they picked and move on: arguing the
same point twice is how an interview turns into a lecture.

## Two grips, chosen by the environment, not by preference

| Situation | What it does |
|---|---|
| Inside a git repo (default) | Interviews **and** leaves a paper trail: `.forge/context.md` for the vocabulary, a numbered record for each hard-to-reverse decision |
| No repo, or `--stateless` | Interviews only. Nothing is written. For a plan, a piece of writing, a career decision, anything with no working directory under it |

Detect it, do not ask: `git rev-parse --git-dir` succeeding is the whole test. Say which grip
you are in, in one line, before the first round. A user who expected a paper trail and got none
finds out at the end, which is the wrong time.

## The paper trail

Two artifacts, and they are different in kind. Keep them separate.

**`.forge/context.md` is the vocabulary.** Every term the plan leans on, defined once, with the
words it is *not* to be called. It gets written the moment a term is contested in an answer,
not at the end. The format, and the decision-record format below, are in
`reference/paper-trail.md`.

**A decision record is one hard-to-reverse choice.** Numbered, dated, and carrying the
alternative that lost. Write one when a decision would be expensive to undo, and not otherwise:
a repo with forty decision records has none, because nobody reads forty.

The test for whether a term belongs in the glossary: has anyone in this conversation used two
words for it, or one word for two things? Both are answers of yes.

## When to stop

The session ends when the frontier is empty: every branch visited, nothing left silently
assumed. Then say so, and **do not start building**. The output of a grilling is a shared
understanding, and the user confirms they have it. An agent that finishes the interview and
starts writing code has decided that its own summary was good enough.

Two honest things to say at the end where they are true:

- **The scope was too big.** A grilling that ran past five or six rounds is usually telling you
  the plan is two plans. Say that; it is more useful than the transcript.
- **A question got no real answer.** A shrug is not a decision. It goes on the open list, never
  quietly resolved to your recommendation.

## Invariants

- **The whole frontier, every round.** One question at a time is the failure mode this skill
  exists to prevent.
- **Every question carries your recommended answer.** An unrecommended question makes the user
  do the work twice.
- **Never ask what you can look up.** Facts are the agent's job.
- **Never decide.** Recommend, record what they chose, move on.
- **Say which grip you are in before round one**, so nobody discovers at the end that nothing
  was written down.
