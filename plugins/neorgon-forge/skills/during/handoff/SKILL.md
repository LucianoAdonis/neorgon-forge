---
name: handoff
description: Compact the current conversation into a portable document another agent can pick up cold. Writes .forge/handoff-<slug>.md beside the task brief, references artifacts by path instead of restating them, and names the skills the next session should call.
argument-hint: "[what the next session is for]"
user-invocable: true
disable-model-invocation: true
license: MIT
---

# handoff: what the next session needs, and nothing else

A context window is about to end, or the work is about to move: to another machine, another
harness, another directory, or another person. Everything the next agent needs has to survive
the gap, and everything it does not need has to be left behind.

The failure mode is not losing information. It is a handoff that transcribes the conversation,
which the next agent then reads in full to discover that four fifths of it was exploration that
went nowhere.

## Write it to `.forge/`

```
.forge/handoff-<slug>.md
```

Beside `brief.md`, `map.md`, and `evidence.md`, in the root the forge already treats as
ephemeral and gitignored. The next agent opens one directory and finds everything.

Where the work is genuinely leaving the machine (a colleague, a different harness, a directory
that is not a repo), write it to the OS temp directory instead and print the absolute path. A
handoff inside a repo the recipient cannot reach is not portable.

## What goes in

```markdown
# Handoff: <one line, what the next session is for>

<date>. Written by <harness>. Read this, then delete it.

## Where the work is

The one-paragraph state of play. What is done, what is half done, what has not
been started. Present tense.

## Artifacts

Paths and URLs, not contents.

- `.forge/brief.md`: the problem, the approach, the rejected alternative, decisions
- `<path>`: <what it is, and why the next agent needs it>

## Next action

The single next thing, concretely enough to start on without re-deriving why.

## Landmines

What has already been tried and did not work, what looks safe and is not, and any
environment fact that cost time to discover. This section is the reason the handoff
beats reading the diff.

## Suggested skills

Which skills the next agent should call the Skill tool for, and for what.
```

## The three rules

**Never duplicate an artifact.** If `.forge/brief.md` records the rejected approach, the handoff
points at it and does not restate it. Two copies of a decision drift, and the reader has no way
to tell which is current. This is what makes the handoff short.

**Read the brief first.** When `task` has been running, `.forge/brief.md` already holds the
problem, the approach, the decisions and the open items. The handoff's job is then only the
things a brief does not carry: live session state, what is half-finished, and the landmines.
Handing off without reading it produces a document that contradicts the record beside it.

**Redact.** API keys, tokens, passwords, personal data, customer identifiers. A handoff is a
file that gets pasted into another session, mailed, and forgotten in a temp directory. Where
the work touched anything sensitive, run the sweep:

```bash
bash "$FORGE/skills/secret-safe-reporting/scripts/sweep.sh" .forge/handoff-<slug>.md
```

## Sizing it

If the handoff is longer than the brief it references, it is transcribing rather than compacting.
Cut in this order: conversation narrative, restated file contents, options that were considered
and dropped without changing anything, and your own reasoning about steps already completed.

What survives is state, next action, and landmines. A good handoff is usually under a page.

## Invariants

- **Artifacts by reference, never by copy.**
- **Read `.forge/brief.md` before writing**, wherever one exists.
- **The next action is one action**, not a plan.
- **Nothing sensitive survives the redaction pass.**
- **Landmines are stated even when they are embarrassing.** A failed approach omitted from the
  handoff gets tried again by the next agent, at full cost.
