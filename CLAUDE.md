# CLAUDE.md

Maintainer rules for this repo. The skills themselves are the product; this file is about
keeping the set coherent as it grows.

## Layout

Skills live at `plugins/neorgon-forge/skills/<bucket>/<name>/`. The buckets are **arc
position**, not topic:

| Bucket | You are here when |
|---|---|
| `before/` | You have not started: which skill, where the change goes, what the problem is, whether the plan holds |
| `during/` | The work is happening |
| `after/` | It is done and someone has to hear about it |
| `craft/` | Standing quality of the fleet, reached for on its own schedule |

The bucket is repo organisation only. Skills **install flat** (`~/.claude/skills/<name>/`), so
a cross-skill path written in prose never carries a bucket: `skills/task/scripts/brief.sh`,
never `skills/during/task/scripts/brief.sh`. `bin/validate.sh` resolves those by searching the
buckets, which is the only reason the two layouts can disagree safely.

Move a skill between buckets when its arc position changed, not when its topic did. A move
means: `git mv`, update `plugin.json`'s `skills` array, and move `docs/skills/<name>.md` only if
it was wrong (the docs path is flat, so a bucket move does not touch it).

## What a new skill owes

Adding one is five things, and `bin/validate.sh` fails on four of them:

1. `SKILL.md`, with frontmatter whose `name` matches the directory.
2. `agents/openai.yaml` beside it, so the skill has an identity outside Claude Code.
3. An entry in `plugins/neorgon-forge/.claude-plugin/plugin.json`'s `skills` array. The plugin
   ships exactly what that array lists; a skill missing from it is installed by nobody.
4. A docs page at `docs/skills/<name>.md`, following `.agents/writing-docs.md`.
5. A line in **`before/forge`**, the router. This is the one nothing can check, and the one that
   decides whether the skill is ever reached for. A router that does not mention a skill is a
   router that lies, and so is one still routing to a skill that was renamed.

Scaffold with `make new NAME=x BUCKET=during PURPOSE="..."`, which creates 1 and prompts for
the rest.

## Invocation

Every skill is **user-invoked** or **model-invoked**, and the choice changes what a good
description looks like. The rules, and the test for which one a skill is, are in
`.agents/invocation.md`. The short version:

- **User-invoked** (`disable-model-invocation: true` in frontmatter, plus
  `policy.allow_implicit_invocation: false` in `agents/openai.yaml`): the description is
  human-facing, one or two sentences, no trigger phrases. Currently `forge`, `handoff`,
  `repitch`.
- **Model-invoked** (neither field): the description is the router and carries the whole
  routing decision. 300 to 900 characters, saying when to use it, the phrases that trigger it,
  and what it is **not** for.

A skill is user-invoked in both harnesses or in neither. `validate.sh` fails when the two
disagree, because a skill closed in one harness and open in the other is reachable by the model
through the gap.

## Output roots

Everything a skill writes lands under one of four roots, chosen by lifetime:

| Root | Lifetime |
|---|---|
| `.forge/` | Ephemeral, gitignored by the worked repo |
| `docs/atlas/` | Regenerable, committed |
| `post/`, `images/` | Shipped deliverables |
| `scripts/mascot/masters`, `.env` | Two argued exceptions, both in `docs/authoring.md` |

`validate.sh` fails a script that creates a fifth. **A new exception goes in
`docs/authoring.md` first**, with its argument, and only then in the validator. An exception
added to the checker alone leaves a repo with no rule about which directories are safe to
delete.

## Prose

**No em dashes.** Not in `SKILL.md` files, docs, the README, commit messages, or code comments.
Where a sentence reaches for one, use what it actually wants: a colon for a definition, a full
stop or semicolon for two clauses, commas or parentheses for an aside. Never a blind character
substitution.

`.forge/brief.md` and anything under a dated path is a record of what was written at the time
and is exempt; rewriting it changes the record.

## Before committing

```bash
make validate        # every skill, the manifests, and that they agree
make install         # re-point the symlinks after any move
```
