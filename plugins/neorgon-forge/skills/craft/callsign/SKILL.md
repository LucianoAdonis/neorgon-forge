---
name: callsign
description: "Use when a project, service, repo, worker, feature flag or release needs a codename in Armored Core VI part grammar, or someone asks for Callsign by name. Triggers on: 'give me a codename for', 'name this service', 'callsign for this repo', 'what should I call this project', 'AC6 style name', 'a three-letter acronym for this', 'name the whole system as one build'. Runs the Callsign site's own command line, so every name matches what callsign.neorgon.com shows for the same words, and hands back candidates with the designation, the 3- and 4-letter acronyms, what the letters read as, the grammar version and a link that reopens the plate. Not for brand copy or a tagline, use penname; not for a site's icon, use sigil; not for names inside code such as variables or functions."
argument-hint: "[what you are naming] [--slot <id>] [--house <id>]"
user-invocable: true
license: MIT
---

# callsign: a codename with rules behind it

Names projects, services and tools the way Armored Core VI names its parts,
using the engine behind https://callsign.neorgon.com. A name offered here is the
name the site shows for the same input, because it is the same code. Callsign is
an unofficial fan tool; say so when the name is headed somewhere public.

## Step 1: Find the engine, or say you could not

The engine is the site repo's command line, `tools/callsign.mjs`, and it needs
Node 22 LTS or later. Run this skill's script by its full path and stay in the
user's own directory, because that is where the search starts. It looks at
`--site` alone when given, otherwise in the working directory and each parent,
and in `projects/callsign-site` and `callsign-site` under each of them, which
covers the monorepo and a standalone clone:

```bash
FORGE=~/.claude   # the directory containing skills/: ~/.claude after bin/install.sh, plugins/neorgon-forge in this repo
node --disable-warning=MODULE_TYPELESS_PACKAGE_JSON "$FORGE/skills/callsign/scripts/callsign.mjs" houses
```

Exit 2 means nothing was generated: no checkout ("no Callsign checkout found"),
one from before the command line ("git pull there"), or a Node too old to load
it. Do not invent a name in its place: offer to clone
`https://github.com/energon-a-secas/callsign-site`, or send the user to the site.

## Step 2: Pick the slot from what is being named

| Being named | Slot | Answers to |
|---|---|---|
| A frontend, dashboard or client | `head` | an acronym |
| The main service or API | `core` | an acronym |
| Integrations, SDKs, adapters | `arms` | an acronym |
| Infrastructure, hosting, runtime | `legs` | an acronym |
| CI/CD, deploys, release automation | `booster` | an acronym |
| Monitoring, alerting, analytics | `fcs` | an acronym |
| A database, queue or event bus | `generator` | an acronym |
| Failover, kill switch, backups | `expansion` | an acronym |
| One tool or service with one job | a weapon class; `slots` lists what each names | a name |

Ask only when the thing could honestly sit in two slots. The house is taste:
leave it unset unless the user named one or the build already has a frame house.

## Step 3: Forge three candidates

```bash
node --disable-warning=MODULE_TYPELESS_PACKAGE_JSON "$FORGE/skills/callsign/scripts/callsign.mjs" \
  forge "<the user's own description>" --slot <slot> --count 3 --via agent --json
```

Pass the user's words, not a summary: the acronym is built from them, so
"release automation daemon" gives RAD. Only the first 120 characters count,
because that is what a link carries; the script says so on stderr when it cuts. Three or four capitals on their own
(`RAD`) are taken as the acronym itself. `--count 3` with no house picks three
different houses, and `--roll <n>` moves to the next candidates. Seven of the
22 houses (`apojove`, `umklapp`, `vastitas`, `quadnil`, `peristome`, `siboga`,
`protyle`) are Callsign's own, not in the game, with words from real science
that reads like science fiction; `houses` marks them as Callsign originals.

## Step 4: Hand them back

For each candidate give the designation, the callsign, the other acronyms, what
the letters read as, and the link; state the grammar version once. `--badge`
prints a README badge and `--md` a wiki line for the same plates.

A whole system is `identity "<system name>"` for the build's own acronym, and the
site's Garage for the rest. `garage <link>` reads a build someone shared.
`lookup "<designation or word>"` says which house and word family a name comes
from (ask it before explaining what a name means; do not guess), and `families`
lists every family with its houses and word counts.

## Step 5: Inside the Neorgon monorepo

When a `PROJECTS.md` sits in the working directory or a parent and the codename
feeds `/new-project`, read `reference/neorgon.md`: only the plain acronyms can
become a subdomain, and only when the registry does not already hold them.

## Invariants

- **The engine is the site's, never a copy.** Vendoring it into this skill
  would fork the names the first time the site's grammar moves.
- **The grammar version is part of the name.** A plate reproduces under its
  grammar number; when a name must never change, keep the designation text as
  well as the link.
- **Exit 2 is a stop.** An unknown house or slot, or no checkout, means nothing
  was generated, and the answer must not pretend otherwise.
- **Never present real in-game part names as output.** Callsign leaves them out
  of its word pools and rerolls any exact collision; do not add them back.
