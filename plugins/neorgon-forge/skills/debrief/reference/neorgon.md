# Neorgon overlay — debrief

Read this only when working inside the Neorgon monorepo (`Documents/Projects/Personal`).
Everything here is a local convention, not part of the portable skill.

## Detecting the overlay

The overlay applies when the `slides-site` player is reachable. Check before assuming it:

```bash
{ [ -d projects/slides-site ] || [ -d slides-site ]; } && echo "slides-site available"
```

Both paths, deliberately. The monorepo keeps its sites under `projects/`, but this skill also
runs from inside a single project and ships to repos that have no `projects/` at all — so a test
for one path only is a test that silently stops matching the day the layout changes. It did:
the earlier `[ -d slides-site ]` went dead when the sites moved, and because the gate fails
closed, `debrief` quietly dropped to plain Markdown and stopped emitting YAML entirely. Nothing
errored, which is why it went unnoticed. Prefer a gate that names every layout it supports.

If neither is there, fall back to `--format marp` or `--format md`. Emitting slides-site YAML
into a repo with no player produces a file nobody can open.

## Format

`--format yaml` targets **`slides-site`**, the deck player in the monorepo. The canonical schema,
every slide type, the density rules and the flow audit checklist live in **`slides-site/CLAUDE.md`**.
Read it before writing YAML — it is the source of truth, and duplicating it here would fork it.

Save to `<project>/docs/debrief-<YYYY-MM>.yaml`.

## Preview

```bash
make serve P=slides-site     # http://localhost:8806
```

Load the YAML in the player, click through, confirm no slide overflows.

## Backgrounds

`stats` and `divider` slides accept a `background` — `ocean` is the safe default for a measured-
numbers slide. Check `slides-site/CLAUDE.md` for the current set rather than guessing a name;
an unknown background renders as the default and the mistake is invisible in the YAML.

## What the collector already knows about this repo

`scripts/collect-changes.sh` has a Neorgon-specific section: it flags vendored and generated
files (`neorgon-header.css`, `neorgon-footer.css`, `viz.css`, `png/`, `site-registry.*`) because
these inflate the diff volume without being the work. Read that section before quoting a line
count on a slide — a 4,000-line diff that is 3,600 lines of regenerated registry is a
misleading stat, and it is the kind an engineering audience checks.

## Per-project context

A project's own `CLAUDE.md` auto-loads inside it and usually states the invariants the work was
meant to preserve. Those invariants make good "what it cost" material: the trade-off you
accepted is often the one the invariant forced.
