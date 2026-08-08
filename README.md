# neorgon-forge

[![skills.sh](https://skills.sh/b/LucianoAdonis/neorgon-forge)](https://skills.sh/LucianoAdonis/neorgon-forge)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Skills for finding your way into hard work, taking it on, then explaining it, then keeping the
result consistent.

They follow the arc of a piece of work. `wayfind` and `untangle` come first, for the two things
that stall a start: not knowing where anything lives, and not knowing the shape of the problem
yet. `atlas` sits alongside them when the question is about the app itself rather than one change
— it extracts a dependency model and generates the docs and diagrams from it, so they can be
asked questions and can report their own staleness. `task` then scopes the work, splits it into
workstreams that can be delegated, and keeps a brief on disk while the work happens. `debrief`
and `writeup` read that brief afterwards — so the account of the work comes from a record written
at the time rather than reconstructed from a diff at the end. The last two are about what a fleet
of projects drifts on: how the copy reads, and how the art holds together.

| Skill | Use it when | Produces |
|---|---|---|
| **`wayfind`** | You do not know where a change goes | `.forge/map.md` — areas, path rules, exceptions |
| **`untangle`** | The problem resists a plan | Evidence, or a scored decision, or a coverage map |
| **`atlas`** | An app needs docs that can be checked | A dependency model, an MkDocs corpus, and answers |
| **`task`** | A problem to solve, not an edit to make | Working code, plus `.forge/brief.md` |
| **`debrief`** | You need to present what changed | A deck (slides YAML, Marp, or Markdown) |
| **`writeup`** | You need to publish what changed | `post/POST.md` plus diagrams that cannot drift |
| **`voicecheck`** | Copy needs auditing, aligning, or de-AI-ing | A `file:line` report, or the rewrite |
| **`mascot-forge`** | A character to generate, cut out, and rig | Aligned frames plus a CSS/physics rig |

## Install

Three routes, and which one you want depends on what you are doing rather than on preference.

**As a Claude Code plugin** — the whole set, updated as a unit:

```
/plugin marketplace add LucianoAdonis/neorgon-forge
/plugin install neorgon-forge@neorgon-forge
```

Refresh with `/plugin update neorgon-forge`.

**With the skills CLI** — for one skill, or for an agent other than Claude Code:

```bash
npx skills add LucianoAdonis/neorgon-forge           # all eight
npx skills add LucianoAdonis/neorgon-forge -s atlas   # just one
npx skills add LucianoAdonis/neorgon-forge -l         # list without installing
```

Pass `-g` for user-level rather than project-level. `npx skills` also targets Cursor, Codex and
others, so this is the route that does not assume Claude Code — but it installs skills
individually, so the group is no longer updated as one thing.

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

**Do not mix the author route with the other two on the same machine.** `make install` symlinks
`~/.claude/skills/<name>` back into this working tree, and both the plugin and `npx skills add`
place their own copy at that name. Whichever lands second wins, and the failure is silent: you
edit the clone and run the copy. Pick one route per machine.

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

`.forge/` is shared: `untangle` writes `evidence.md` beside the brief and `wayfind` writes
`map.md`. Add the directory to the worked repo's `.gitignore` if you would rather not commit any of
it. Committing is also reasonable, and the two are worth separating — a brief is a decision record
about one piece of work, while a map is a standing description of the repo that gets more useful
the longer it is kept.

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

## Documenting the app — `atlas`

Generates every diagram and doc page from one extracted model rather than beside it, because a
hand-drawn architecture diagram goes stale *silently* — it keeps looking authoritative, and the
first reader to trust it after a refactor gets no warning. `scan.py` records the commit it read
and the `file:line` of every import, so `ask impact <file>` answers "what breaks if I change
this" with citations that can be disproved, and `ask stale` compares the model against git rather
than against mtimes.

The generated pages live under `docs/reference/` and say so in an admonition; everything else in
`docs/` is hand-owned and never touched. Diagrams follow one rule worth stating on its own:
**shape carries role, colour only emphasises**, and the dependency flowchart draws a spine rather
than every edge — a real app has about twice as many imports as modules, and drawing all of them
produces something that renders, looks impressive, and answers nothing. `reference/mkdocs.md`
holds the verified Material contract, including the two silent failures: a missing
`custom_fences` entry renders a diagram as a code block with no warning at all, and a literal
`\n` in a Mermaid 11 label renders as two characters of text.

## Before the work — `wayfind` and `untangle`

Both exist because the expensive mistakes happen before any code is written: confident motion in
the wrong direction, and a convention asserted from two files.

**`untangle`** classifies the difficulty first, because the three kinds share almost no technique.
`cause` narrows by refutation — every hypothesis registered with `evidence.sh` must carry the
observation that would kill it, since a theory nothing could disprove cannot be crossed off and
quietly becomes the assumption everything else rests on. `design` scores real options against
criteria written *before* the options. `scale` builds a coverage map with `survey.sh` and hands
execution to `task --scope campaign`. It also has a stop condition: three refuted hypotheses with
nothing confirmed is a report, not a state to persist in.

**`wayfind`** makes every claim about a codebase carry its basis. `map.sh rule` refuses a rule
without one, because "it seems standard" and "census: 41 files, no exceptions" read identically
next session and only one of them is true. `ticket` resolves a ticket's vocabulary to ranked
candidate files, `resolve` reports which rules and recorded exceptions govern a path, and `check`
flags rules whose glob now matches nothing — a dead rule is worse than a missing one, because a
missing rule prompts a question and a dead one answers it wrongly.

## After the work — `voicecheck` and `mascot-forge`

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
│       ├── wayfind/      SKILL.md, scripts/{orient.sh,map.sh}, reference/tickets.md
│       ├── untangle/     SKILL.md, scripts/{evidence.sh,survey.sh}, reference/hypotheses.md
│       ├── atlas/        SKILL.md, scripts/{scan,atlas_model,diagram,build,ask}.py + render.sh
│       │                 reference/mkdocs.md
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
