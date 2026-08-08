# neorgon-forge

Skills for taking on large work, then explaining it, then keeping the result consistent.

Three of them share one artifact. `task` scopes a problem, splits it into workstreams that can
be delegated, and keeps a brief on disk while the work happens. `debrief` and `writeup` read
that brief afterwards — so the account of the work comes from a record written at the time
rather than reconstructed from a diff at the end. The other two are about what a fleet of
projects drifts on: how the copy reads, and how the art holds together.

| Skill | Use it when | Produces |
|---|---|---|
| **`task`** | A problem to solve, not an edit to make | Working code, plus `.forge/brief.md` |
| **`debrief`** | You need to present what changed | A deck (slides YAML, Marp, or Markdown) |
| **`writeup`** | You need to publish what changed | `post/POST.md` plus diagrams that cannot drift |
| **`voicecheck`** | Copy needs auditing, aligning, or de-AI-ing | A `file:line` report, or the rewrite |
| **`mascot-forge`** | A character to generate, cut out, and rig | Aligned frames plus a CSS/physics rig |

## Install

**To use them** — install the plugin:

```
/plugin marketplace add LucianoAdonis/neorgon-forge
/plugin install neorgon-forge@neorgon-forge
```

Refresh with `/plugin update neorgon-forge`.

**To author them** — clone and symlink, so edits are live with no sync step:

```bash
git clone https://github.com/LucianoAdonis/neorgon-forge
cd neorgon-forge
make install          # symlinks into ~/.claude/skills
```

Then restart Claude Code. `install.sh` prints the slash command for every skill it linked.

Install into one project instead of globally:

```bash
bash bin/install.sh --project ~/code/my-repo
```

`install.sh` refuses to overwrite a real directory that shares a name with one of ours; pass
`--force` to move it aside with a timestamped backup.

## Commands

```bash
make install      # symlink skills into ~/.claude/skills
make refresh      # pull, re-link, report drift, validate
make validate     # check every skill against the house standard
make new NAME=my-skill PURPOSE="what it does"
make status       # what is installed, and from where
```

## The shared brief

`task` maintains `.forge/brief.md` in the repo being worked on:

```
## Problem     what was wrong before — the symptom, not the absence of a fix
## Approach    what you are doing
## Rejected    the alternative that lost, and why
## Decisions   appended as they happen, timestamped
## Measured    numbers actually observed, with how
## Open        deferred work, defects that shipped, decisions left to the user
```

Maintained through a script so the mechanical parts are not the model's problem:

```bash
FORGE=~/.claude/skills   # or wherever the skills are installed
bash "$FORGE/task/scripts/brief.sh" init "modal is unreadable on dark backgrounds"
bash "$FORGE/task/scripts/brief.sh" note "rejected raising opacity — the token is shared with 6 sites"
bash "$FORGE/task/scripts/brief.sh" stream add "audit tokens" "find every 3% surface use"
bash "$FORGE/task/scripts/brief.sh" stream done "audit tokens" "9 sites; 2 were intentional"
bash "$FORGE/task/scripts/brief.sh" status
bash "$FORGE/task/scripts/brief.sh" close
```

Why it exists: the three things a deck or post most needs — the symptom before the fix, the
alternative that lost, the number actually measured — are the three things a diff cannot show and
a long session reliably forgets. `close` refuses to quietly drop unfinished workstreams; they
belong under `## Open`.

Add `.forge/` to the worked repo's `.gitignore` if you would rather not commit briefs. Committing
them is also reasonable — a brief is a decision record, and that is the kind of thing worth
keeping.

## Scopes, in `task`

Chosen per task and stated out loud, because ceremony on a small task wastes time and a campaign
run as a quick fix produces half a migration.

| Scope | Fits | Delegates |
|---|---|---|
| `quick` | One file, known cause, under ~30 lines | No |
| `standard` | A few files, one subsystem | Research only |
| `campaign` | Many files or subsystems, or spanning sessions | Yes, per workstream |

Campaign delegation has one non-negotiable: **verify against the diff, not the report.** A
subagent reporting success is evidence, not proof. `skills/task/reference/delegation.md` has the
prompt contract and the verification table.

## Authoring new skills

```bash
make new NAME=my-skill PURPOSE="one-line purpose"
```

Scaffolds the directory, frontmatter, and the section headings that make a skill good — with
`TODO`s rather than plausible filler, because filler gets shipped and questions do not.

**`docs/authoring.md`** is the tutorial: when a skill is the right shape at all, how to write the
description (the part that decides whether it ever fires), progressive disclosure across the four
tiers, and how to test that it fires when it should and not when it should not.

## The other two

**`voicecheck`** loads a voice before judging one. A per-project `VOICE.md` overrides a checkable
baseline; with neither, an audit is just an opinion about someone else's writing. `audit` reports
`file:line` and never writes, `align` applies the fixes, `detox` strips only the AI tells, and
`diff` compares two projects — the one command that can see drift, since drift is invisible from
inside a single repo.

**`mascot-forge`** is two halves that fail differently. Generation fails by *drifting*, so frames
stop layering; animation fails by looking *pasted on*. Its scripts run from the target project's
root and write into `./images/mascot/`, so one install serves every project. Art generation needs
`GEMINI_API_KEY`; `keys.py` is the only place that reads a key, and it never prints one.

## Portability

Portable core, overlay for local convention. Each `SKILL.md` works in any repo; anything true
only of the Neorgon monorepo — the `slides-site` deck player, the brand palette, the suite chrome
strings — sits in `reference/neorgon.md` behind a detection step. `debrief` emits slides YAML when
`slides-site/` exists and falls back to Marp or Markdown when it does not; `voicecheck` prints its
overlay only when it actually detects the suite.

## Layout

```
neorgon-forge/
├── .claude-plugin/marketplace.json     # so /plugin marketplace add works
├── plugins/neorgon-forge/
│   ├── .claude-plugin/plugin.json
│   └── skills/
│       ├── task/         SKILL.md, scripts/brief.sh, reference/delegation.md
│       ├── debrief/      SKILL.md, scripts/collect-changes.sh, reference/
│       ├── writeup/      SKILL.md, scripts/{check-writeup.sh,diagram-kit.mjs,rasterize.mjs}
│       ├── voicecheck/   SKILL.md, scripts/load-voice.sh, reference/voice-defaults.md
│       └── mascot-forge/ SKILL.md, scripts/*.py, assets/, reference/prompts/
├── bin/{install,refresh,validate,new}.sh
├── docs/authoring.md
└── Makefile
```

## License

MIT
