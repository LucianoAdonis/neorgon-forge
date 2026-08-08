# Authoring a skill

How to add a skill to this repo, and more importantly how to make one that actually fires and
actually beats a plain prompt. The mechanics take five minutes; the description takes an hour
and is the part that decides whether the skill gets used.

## The five-minute version

```bash
bash bin/new.sh my-skill "one-line purpose"   # scaffold
$EDITOR plugins/neorgon-forge/skills/my-skill/SKILL.md
bash bin/validate.sh my-skill                 # check it against the house standard
bash bin/install.sh                           # symlink into ~/.claude/skills
# restart Claude Code, then: /my-skill
```

Because `install.sh` symlinks rather than copies, every later edit is live immediately. You only
re-run `install.sh` when you add a *new* skill.

## What a skill is, and when you want one

A skill is a prompt that loads on demand, plus the files it needs. Two properties follow from
that and they are the whole design:

**It loads on demand.** Only the `description` sits in context until the skill fires. So a skill
costs nothing until it is relevant, and a 400-line skill is fine where a 400-line addition to
`CLAUDE.md` would not be.

**It can carry scripts.** Mechanical work — collecting a diff, grepping for patterns, rasterizing
images — belongs in a script the skill calls, not in instructions the model re-derives every run.
A model rewriting the same grep each time wastes tokens and gets it subtly different every time.

Write a skill when the work is **recurring**, needs **judgment** the model does not reliably
apply, and has a **failure mode you can name**. That last test is the one that matters:

| Instinct | Better home |
|---|---|
| "Always use tabs here" | `CLAUDE.md` — it is a constant, not a procedure |
| "Look up this library's API" | Nothing — that is what docs tools are for |
| "Run this exact 4-command sequence" | A slash command, or a shell script |
| "Turn finished work into a deck, without the deck becoming a flattering summary" | A skill |

If you cannot name what goes wrong without the skill, you have a preference, not a skill.
Preferences belong in `CLAUDE.md`.

### Skill or command?

Both live in this repo's plugin. The split:

- **Skill** — the model decides to use it, based on the description. Use for anything where
  recognising the situation is part of the value.
- **Command** — the user types `/name` to force it. Use for a deterministic sequence where there
  is nothing to recognise.

A `user-invocable: true` skill is both: the model can route to it *and* the user can type
`/name`. That is the default here, and it is usually right.

## The description is the router

The single highest-leverage string in the skill. It is the only thing loaded until the skill
fires, so it carries the entire decision about whether to fire. A vague description produces a
skill that is never used, which is indistinguishable from a skill that does not exist.

Four parts, in this order:

```
1. WHEN — the situation, in the words a user would actually type
2. WHAT — what it covers, concretely enough to distinguish it from neighbours
3. TRIGGERS — literal phrases: Triggers on: 'make a deck about this', 'slides for the demo'
4. BOUNDARY — Not for X (use Y instead)
```

Aim for 300–900 characters. Under ~120 there is nothing to route on; over ~1400 the signal
dilutes.

Compare:

```
description: "Creates presentations from your work."
```

Nothing to match against. "Presentation" is the only hook, and it will lose to any skill that
lists the phrases people actually type.

```
description: "Use at the END of a piece of work when the user wants a presentation, deck, or
slides explaining what they changed and why — for a demo, a standup, a sprint review, a
stakeholder update, a retro, or 'so I can show what I did'. Reads the actual git diff and the
task brief so the deck reports facts rather than a flattering summary. Triggers on: 'make a deck
about this', 'slides for the demo', 'build me a readout'. Not for writing a blog post (use
writeup) or a git commit message (use commit-work)."
```

Note what the second one does: it says **when** ("at the END of a piece of work"), it quotes the
user ("so I can show what I did"), and it names its **neighbours** so the model can tell three
similar skills apart. The boundary clause is what stops `debrief` and `writeup` fighting over
"document this work".

**Write the description first.** It forces you to decide what the skill is for before you write
what it does, and the decision is easier to change in one sentence than in four sections.

## Frontmatter

```yaml
---
name: my-skill              # must match the directory name exactly
description: "…"            # the router; see above
argument-hint: "[mode] [target]"   # shown in the / menu
user-invocable: true        # exposes it as /my-skill
license: MIT
---
```

`name` mismatching the directory is the most common mechanical error, and `validate.sh` catches
it.

## Body structure

What the skills here have in common, and what `validate.sh` checks for:

**Open with two sentences: what it does, and the failure mode it prevents.** The second sentence
is why the skill exists. If you cannot write it, stop and reconsider whether you need one.

**Numbered steps for the procedure.** Concrete enough to follow without interpretation. A step
that says "consider the audience" is not a step; a table of three audiences with what to cut for
each is.

**At least one judgment section that is not steps.** A trade-off table, a keep-versus-cut list,
the thing an experienced person knows and a first-timer does not. This is where a skill beats a
prompt — anyone can write steps, and the model can usually infer them. What it cannot infer is
which of two reasonable options is wrong here.

**An `## Invariants` section.** Three to five non-negotiables as imperatives — the things you
would call out in review. A list of twelve is a list nobody reads.

Keep `SKILL.md` under ~500 lines. Past that, move detail into `reference/`.

## Progressive disclosure

Three tiers, and putting a file in the wrong tier is the main way a skill gets expensive:

| Tier | Loaded | Put here |
|---|---|---|
| `description` | Always | The routing decision, nothing else |
| `SKILL.md` | When the skill fires | The procedure and the judgment |
| `reference/*.md` | When SKILL.md says to read it | Detail needed occasionally |
| `scripts/*` | Executed, never read into context | Anything mechanical |

`reference/` is for the long tail: a full schema, a regionalism blacklist, a per-repo overlay.
Reference it explicitly from `SKILL.md` — an unreferenced reference file never gets read, and
`validate.sh` flags a reference that points at a file which does not exist.

`scripts/` is the cheapest tier by a wide margin, because output enters context but the source
does not. If a step can be a script, make it a script.

## Scripts

Conventions across this repo:

- `#!/usr/bin/env bash` and `set -uo pipefail`. Not `-e`: these scripts are diagnostic and should
  report every problem, not exit on the first one.
- A comment block at the top saying what it gathers and **why the skill needs it**.
- Print grouped, labelled output. The consumer is a model reading a transcript.
- Never mutate the user's repo. Collectors collect.
- Take the target directory as an argument, defaulting to `.`.
- Executable (`chmod +x`) — `validate.sh` checks. Python modules imported by a sibling script are
  the exception; they only have to parse.

Scripts are also where anything time-dependent has to live. A model cannot read a clock, so
`brief.sh` stamps its own timestamps with `date`.

**Anchor paths on the cwd, never on `__file__`.** A skill is installed once and run against many
projects, so `Path(__file__).parents[2]` resolves inside the install, not the work. `mascot-forge`
learned this the hard way on migration: three scripts derived their output directory from their own
location, which was correct only while they lived inside the project. The one legitimate use of
`__file__` is reaching the skill's own bundled assets.

**Calling a sibling skill's script is allowed.** `untangle` opens a brief with `task`'s
`brief.sh` rather than shipping its own, and `validate.sh` resolves a `skills/<name>/scripts/…`
reference against the skills root so the dead-reference check still applies across the boundary.
Reach for this when two skills would otherwise maintain the same artifact; do not reach for it to
avoid deciding which skill owns a step.

**When several scripts in one skill need the same derived fact, extract a module.** `atlas` has
four entry-point scripts that all need "which modules are hubs" and "what is the import cycle",
so those live in `atlas_model.py`, which the others import via
`sys.path.insert(0, str(Path(__file__).resolve().parent))`. This is the one legitimate use of
`__file__` — reaching the skill's own bundled files, not the work directory. Computing the same
derivation in four places yields four slightly different answers with no way to tell which is
right. Such a module is not executable and `validate.sh` exempts it from the `chmod +x` check.

**A skill that generates files must declare which ones it owns.** `atlas` writes only under
`docs/reference/` and states in every generated page that it is generated. Without that boundary a
corpus becomes a mix of current and stale pages with nothing to distinguish them, which is worse
than no corpus — a reader trusts it either way. If a skill writes into a directory a human also
edits, decide the ownership split before writing the first file.

`validate.sh` also greps every skill for API keys and `/Users/...` paths, because this repo is
public and neither is recoverable by deleting it in a later commit.

## Portability

The rule this repo follows: **portable core, overlay for local convention.**

`SKILL.md` should work in any repo. Anything true only of one monorepo — a specific deck player,
a brand palette, the suite's chrome strings — goes in `reference/neorgon.md`, and `SKILL.md`
points at it with a detection step. `debrief` shows the pattern: it emits YAML when `slides-site/`
exists, and falls back to Marp or plain Markdown when it does not.

**Detect, do not assume.** `voicecheck`'s loader prints its overlay only when it finds the suite,
and says `not applicable` otherwise. That line matters: an overlay printed in the wrong repo
invents invariants the project never agreed to, and the audit then reports violations of a rule
that does not exist there.

This matters more than it looks. A skill that hardcodes one repo's assumptions is a skill you
cannot use on your next project, and you will not notice until you are on that project.

## Registering

Skills in `plugins/neorgon-forge/skills/` are picked up automatically — the plugin manifest lists
no individual skills, so there is nothing to update when you add one.

Update `plugin.json`'s `version` when you change behaviour in a way an installed user would
notice.

## Testing

There is no unit-test story for a prompt. What there is:

1. `bash bin/validate.sh my-skill` — mechanical checks.
2. **Does it fire?** Start a fresh session and describe the situation *without* naming the skill.
   If it does not fire, the description is wrong — this is the test that catches the real defect,
   and the one people skip.
3. **Does it fire when it should not?** Describe an adjacent task that belongs to a different
   skill. If yours fires, tighten the boundary clause.
4. **Run it on real work** and read what it produced against its own invariants.

Step 2 is the whole game. A skill that never fires is worse than no skill, because you believe
you have one.

## Iterating

When a skill produces a bad result, the fix is almost always one of:

- **It did not fire** → description. Add the phrase the user actually typed.
- **It fired for the wrong task** → boundary clause. Name the skill that should have won.
- **It fired and did the wrong thing** → the step was ambiguous. Make it concrete, or add the
  judgment table that resolves the ambiguity.
- **It fired and did the right thing slowly** → move a mechanical step into a script.

Record the fix in the skill, not in your head. A skill is a place to put a lesson so it survives
the session that taught it to you.
