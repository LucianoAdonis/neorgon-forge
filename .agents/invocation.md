# User-invoked and model-invoked

Every `SKILL.md` here is a skill. The axis that splits them is **who can reach it**.

## The test

> Could the model usefully reach for this on its own, from a user request that never named it?

Yes means **model-invoked**. That is the default and most skills are it: `task`, `untangle`,
`writeup` and the rest all answer to requests a person makes without knowing a skill exists
("figure out why this breaks", "write this up").

No means **user-invoked**, and there are only three cases where the answer is genuinely no:

| Skill | Why the model must not fire it |
|---|---|
| `forge` | It answers "which skill do I want". A model that knows the answer does not need to ask, and a model that asks is stalling |
| `handoff` | Compacting a session is a judgment about the session, which is the user's, not a step in a task |
| `repitch` | It is a correction *to* the agent. An agent that decides its own last message did not land is guessing at the user's comprehension |

Reuse is not the test. A skill extracted because three other skills call it is still
model-invoked, and probably more so.

## How each one is declared

**Model-invoked**: omit both fields. Nothing to do.

**User-invoked**, both of these, always together:

```yaml
# SKILL.md frontmatter
disable-model-invocation: true
```
```yaml
# agents/openai.yaml
policy:
  allow_implicit_invocation: false
```

`bin/validate.sh` fails when only one is present. Two harnesses disagreeing is worse than
either setting, because the skill stays reachable through whichever one was missed, and the
gap is invisible from inside the other.

## It changes the description

This is the part that gets missed. The two kinds of description are read by different readers
for different reasons.

**A model-invoked description is the router.** It is the only thing loaded until the skill
fires, so it carries the entire routing decision: when to use it, the phrases a user actually
types, and what it is **not** for. 300 to 900 characters. The overlap clause is not optional
furniture; without it the model picks between two plausible skills by coin flip.

**A user-invoked description is a line in a list.** A person is skimming slash commands. One or
two sentences saying what it does. **Strip the trigger phrases**: nothing can ever act on them,
so they are noise in the one place a human is reading closely. `validate.sh` fails on this
specifically, because copying a model-invoked description into a user-invoked skill is the easy
mistake.

## Calling one skill from another

Name the tool: `Call the Skill tool with "untangle"`. Not a bare `/untangle` left for the model
to interpret, and not a `../other-skill/reference/x.md` path.

Two consequences:

- **One skill per call.** A step needing two is two calls. "Call it with X and Y" reads as one
  call taking both.
- **A user-invoked skill can never be called this way.** If a step's precondition is `forge`,
  `handoff` or `repitch`, phrase it as an instruction to the human: "tell the user to run
  `/handoff`", never as a Skill tool call.

Router prose is different. `forge` names skills for a human to choose from; it is not invoking
anything, so it keeps `/name` as a plain label.

## Shared material

A reference doc lives inside the skill that **owns** it, meaning the one that writes the
artifact it describes. The glossary format sits in `grill/reference/paper-trail.md` because
`grill` writes the glossary; `atlas` reads the result and reports drift, and reaches that
material by calling the Skill tool, not by linking across folders. Two copies of a format is
two formats within a month.
