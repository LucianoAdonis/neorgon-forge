---
name: atlas
description: "Use when an app needs documentation that stays true — architecture docs, a dependency map, diagrams of how the pieces fit, or an MkDocs site to answer questions from later. Extracts a dependency model from the source, generates Mermaid diagrams and MkDocs pages from that model, then answers questions against it: what breaks if I change this, what does this depend on, where is change expensive, is the doc still current. Triggers on: 'document this app', 'diagram the architecture', 'map the dependencies', 'set up mkdocs', 'what depends on this file', 'what breaks if I change this', 'is this doc still accurate'. Not for Mermaid syntax questions (use mermaid-diagrams), not for choosing a C4 level (use c4-architecture), not for finding where a ticket's change goes (use wayfind)."
argument-hint: "[scan|build|ask|render] [target]"
user-invocable: true
license: MIT
---

# atlas — an app's dependencies as a model, a doc site, and a thing you can ask

Extracts a dependency model from the source, then generates every diagram and doc
page *from that model* rather than beside it. The failure mode it exists to
prevent: architecture docs that were true once. A hand-drawn diagram goes stale
silently — it keeps looking authoritative, and the first reader who trusts it
after a refactor is misled with no warning. A generated one goes stale loudly,
because the model records the commit it was built from and `ask stale` compares
that against the tree.

Everything here reads one file. Diagrams, pages, and answers all derive from
`docs/.atlas/model.json`, so they cannot disagree with each other — only,
together and visibly, with the code.

## Step 1 — build the model

```bash
FORGE=~/.claude/skills
cd <the project>
python3 "$FORGE/atlas/scripts/scan.py"
```

Scans `.js/.mjs/.jsx/.ts/.tsx/.py` and writes `docs/.atlas/model.json`: modules
with a role and an area, internal import edges each carrying the `file:line` the
import was found on, and external packages with their importers.

Read the summary it prints before going on. Three lines there change what you do
next:

| It says | It means | Do |
|---|---|---|
| `areas from wayfind` | `.forge/map-areas.tsv` exists | Nothing — areas are already in the user's words |
| `areas from directory tree` | Areas were derived from containing directories | Consider running `wayfind` first, or accept directory names |
| `working tree is dirty` | Provenance will name a commit the pages don't match | Fine while iterating; commit before publishing |
| `no git commit` | Staleness cannot be measured at all | Say so — the corpus has no way to warn a future reader |

**If the areas are directory names, the area diagram is a picture of the folder
layout.** That is worth something but it is not architecture. `wayfind` names
areas the way the people working there name them, and `scan.py` picks those up
automatically; the two skills are designed to compose in that order.

## Step 2 — look at the model before publishing anything

```bash
python3 "$FORGE/atlas/scripts/ask.py" risk
```

Read this yourself first. It reports hubs, import cycles, and modules nothing
imports — and those are findings, not decoration. A cycle you did not know about
changes the architecture description you were about to write. An orphan list with
six entries means either dead code or a scan that missed an entry point, and
publishing before deciding which bakes the wrong answer into a doc.

**Do not describe the app to the user from the model alone.** The model knows
imports; it does not know what the app is *for*. `docs/index.md` is left
hand-written for exactly that reason.

## Step 3 — generate the corpus

```bash
python3 "$FORGE/atlas/scripts/build.py" --scaffold
```

Writes into `docs/reference/`: `architecture.md`, `dependencies.md`,
`modules.md`, and one `area-*.md` per area. With `--scaffold` it also writes
`mkdocs.yml` and a `docs/index.md` stub — and it never overwrites either if they
exist.

The `docs/reference/` boundary is the whole discipline:

| Location | Owner | Rule |
|---|---|---|
| `docs/reference/*` | `atlas` | Never edit. Rerun `build.py`. Every page says so in an admonition |
| `docs/index.md`, everything else in `docs/` | You | `atlas` never touches it |
| `docs/.atlas/model.json` | `scan.py` | The single source every page derives from |

Without that split the corpus becomes a place where some pages are current and
some are stale with nothing to tell them apart, which is worse than having no
corpus — a reader trusts it either way.

Verify it builds, if MkDocs is available:

```bash
mkdocs build --strict    # or: python3 -m mkdocs build --strict
```

**MkDocs may not be installed, and that is not a failure.** The Markdown is
valid either way. Say plainly that the corpus was generated but not built, and
offer `pip install mkdocs-material` — do not report a working docs site you never
rendered.

## Step 4 — answer questions from the model

```bash
python3 "$FORGE/atlas/scripts/ask.py" impact schema     # what breaks if I change this
python3 "$FORGE/atlas/scripts/ask.py" needs render      # what I must understand first
python3 "$FORGE/atlas/scripts/ask.py" where card        # which modules match a term
python3 "$FORGE/atlas/scripts/ask.py" layers            # distance from an entry point
python3 "$FORGE/atlas/scripts/ask.py" areas             # sizes and coupling
python3 "$FORGE/atlas/scripts/ask.py" stale             # does the model still hold
```

Query the model, not the generated pages. The pages are prose *about* the model
and prose loses the structure: "what depends on `schema.js` transitively" is one
lookup here and a reading-comprehension exercise there.

`impact` and `needs` print the `file:line` of each direct import, so any claim in
the answer can be checked in seconds. Quote those locations when you answer —
an unlocated dependency claim is indistinguishable from a guess.

**Run `stale` before answering anything consequential**, and lead with what it
says. An answer from a stale model reads exactly like an answer from a current
one, which is the specific way this kind of tool does damage.

## Step 5 — diagrams, and which target they need

This is the one thing about Mermaid-in-MkDocs that is easy to get wrong, and it
is not a syntax question — it is a theming one.

| Target | Where it goes | Theme | Why |
|---|---|---|---|
| `page` | A fence inside a Markdown page | **None emitted** | Material injects theme variables from the active palette. A baked theme wins and the diagram then stays dark on the light scheme |
| `export` | A standalone `.mmd` rendered to SVG/PNG | Baked in | Nothing else supplies one |

```bash
D="$FORGE/atlas/scripts/diagram.py"
python3 "$D" areas   --target page                       # fences: build.py embeds these
python3 "$D" flow    --target export --out docs/diagrams/flow.mmd
python3 "$D" focus   --focus state --target export --out docs/diagrams/state.mmd
bash "$FORGE/atlas/scripts/render.sh" docs/diagrams --png
```

`build.py` already embeds the page-target fences, so generate `export` diagrams
only for things that leave the site: a slide, a README, a post.

Kinds: `areas` (coupling between areas, arrows labelled with the import count),
`flow` (the dependency spine), `area-detail --area NAME`, `focus --focus PATH`
(one module's importers above and dependencies below), `externals`.

### The visual patterns, and why each one

Worth understanding rather than copying, because these are the decisions that
separate a diagram someone reads from one they scroll past:

**Shape carries role; colour only emphasises.** Rounded is an entry point,
cylinder a store, hexagon config, parallelogram data. A shape survives a palette
switch, greyscale printing, and a colourblind reader; a legend mapping six hex
values to six roles survives none of them. Colour is used for exactly three
things — the way in, the hubs, and anything structurally wrong.

**The spine, not every edge.** A real app has roughly twice as many imports as
modules. Drawing all of them produces a plate of spaghetti that renders, looks
impressive, and answers nothing — rendering a 19-module project with all 41 edges
was genuinely unreadable, and the same model as a spine was not. So `flow` draws
one arrow per module (how an entry point reaches it) plus the edges that close an
import cycle, because a cycle is the one fact a tree cannot express.

**Every reduction is stated.** Elided edges and omitted modules are counted in a
`%%` comment inside the diagram. A silently truncated diagram claims completeness
it does not have.

**Left-to-right for anything with fan-out.** A top-down spine puts every
depth-1 module on one row, and a diagram wider than the content column gets
scaled down to fit — a legible SVG becomes an unreadable thumbnail. Vertical
overflow costs a scroll; horizontal overflow costs the diagram.

**`<br/>` for line breaks, never `\n`.** Mermaid 11 renders labels through an
HTML `foreignObject`, where a literal backslash-n is two characters of text.
`render.sh` refuses a file containing one rather than emitting a diagram that
looks subtly broken. This is a live regression, not a hypothetical — see
`reference/mkdocs.md`.

**Arrow labels carry counts.** Two areas joined by one import and two joined by
thirty are different facts; an unlabelled arrow reports them identically.

For Mermaid *syntax* — sequence diagrams, class diagrams, participant
declarations — use the `mermaid-diagrams` skill. For choosing a C4 level, use
`c4-architecture`. Note that Material auto-themes only flowchart, sequence,
class, state and ER; **C4 diagrams are not auto-themed**, so a C4 diagram in a
page fence needs its own styling or belongs in `export`.

Configuration details, the verified Material contract, and what breaks with each
extension missing are in `reference/mkdocs.md`. Read it when scaffolding
`mkdocs.yml` by hand or when a fence renders as a code block.

## Step 6 — keep it honest over time

```bash
python3 "$FORGE/atlas/scripts/ask.py" stale
python3 "$FORGE/atlas/scripts/scan.py" && python3 "$FORGE/atlas/scripts/build.py"
```

`stale` asks git, not the filesystem — a file touched but not changed has a new
mtime and identical content, and an mtime check that reports drift which does not
exist gets ignored within a week. It also ignores changes under `docs/` and
`site/`, since those are this skill's own output and counting them would make the
check fire on every single run.

## Where this sits

| Situation | Skill |
|---|---|
| You do not know where a change goes | `wayfind` |
| You need areas named the way the team names them | `wayfind`, then `atlas` |
| The app needs documentation that can be checked | `atlas` |
| You need to know what a change will break | `atlas ask impact` |
| How do I write this particular Mermaid diagram | `mermaid-diagrams` |
| Which C4 level fits this audience | `c4-architecture` |
| Explaining work you just did, to people | `debrief` / `writeup` |

`atlas` documents the app as it *is*. `writeup` explains a change that was made.
Pointing `atlas` at a diff, or `writeup` at an architecture, produces something
that is neither.

## Invariants

- **Never hand-edit a file under `docs/reference/`.** It is overwritten on the
  next build, and an edit there is a fact that exists only until someone reruns.
- **Never point mermaid-cli at a Markdown page.** It rewrites the file in place,
  replacing every fence with an image link. Only ever `.mmd`.
- **No theme frontmatter in a page fence, always one in an export.** Getting this
  backwards is invisible until someone switches palette.
- **Quote the `file:line` for any dependency claim.** The model records it
  precisely so the answer can be disproved.
- **Report `stale` before answering from the model**, and never present a corpus
  as built unless `mkdocs build` actually ran.
