# Writing a docs page

Every skill has a human-facing page at `docs/skills/<name>.md`. The path is **flat**, matching
how skills install rather than how the repo stores them, so moving a skill between buckets does
not move its page.

The page is not the skill and not a summary of `SKILL.md`. Most of these skills are reached for
by a person who has to *remember they exist*. That memory is the cognitive load the page exists
to relieve: orient one reader around one skill so they can hold it in their head and know when
to reach for it. The pages together are a distributed router; `forge` is the index over them.

Re-sync a page whenever the skill is added, renamed, or changes behaviour. A rename moves the
file.

## The frame

Four sections, in this order. The first two orient; the last two are where the page stops
describing the skill and starts answering the reader's own situation.

```markdown
# <name>

<One line: what it does. No heading above it.>

## What it does

One or two plain paragraphs. Lead with the one-sentence job, then state the
**defining constraint**: the single fact that makes this behave differently
from the obvious default. For `handoff` it is that artifacts are referenced,
never copied. For `grill` it is that the whole frontier is asked at once.

Write it as a plain declarative sentence. Never as a labelled aside ("The key
thing is:"), which reads as filler. This line is the most valuable on the page.

## When to reach for it

Two beats, both effectively always present:

- **Invocation.** "You type `/<name>`; the agent will not reach for it on its
  own" (user-invoked), or "Type `/<name>`, or the agent reaches for it when a
  task fits" (model-invoked).
- **The boundary.** "Reach for this when ...", and where it is confusable with
  a sibling, the other half: "for X instead, use [<sibling>](<sibling>.md)."

## <one or two free-form sections>

In the skill's own vocabulary. The loop it runs, the artifact it leaves, the
fork it makes, the one anti-pattern it kills. No prescribed heading.

The single non-negotiable: **surface the skill's leading word**. The frontier.
The design tree. The deep module. The brief. The reader learns what the skill
is, and learns the word they will later think with to reach for it.

## It's working if

A few bullets naming what the reader sees when it is doing its job. The bar:
checkable without opening `SKILL.md`. "The document gets shorter as it gets
better" passes. "The stage function clears the screen" is a compliance check on
the skill's internals wearing this section's name.
```

## Conventions

- **Explain the why, never the process.** The page situates the skill; it does not reproduce
  the steps. A person choosing a tool does not need the runbook.
- **Branches go in a table or a list, never a paragraph.** Where the page presents a choice, the
  reader is scanning for the one row that matches their situation, and a paragraph makes them
  read all of it to find out.
- **Name no author, quote no author.** Every claim stands on its own.
- **Write no install command.** The README owns install wording, in one place. Two copies drift,
  and the reader is shown the same command twice.
- Keep the page low-load. It is documentation about low-cognitive-load tools; spare headings and
  restated links are the thing it argues against.

## Done when

- `docs/skills/<name>.md` exists and no stale page survived a rename.
- `## What it does` states the defining constraint as plain prose.
- `## When to reach for it` gives the invocation mode and the boundary against its nearest
  sibling.
- The middle surfaces the leading word.
- Every `## It's working if` bullet is checkable without opening `SKILL.md`.
- The page writes no install command and names no author.
- Every link resolves.
