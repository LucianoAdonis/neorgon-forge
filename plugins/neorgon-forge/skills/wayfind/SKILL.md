---
name: wayfind
description: "Use when working in an application whose layout you do not yet know, or when a ticket has to be resolved to actual files before anything can be changed. Triggers on: 'where does this go', 'where is this handled', 'I don't know this codebase', 'which file owns the checkout total', 'what are the conventions here', 'I keep guessing wrong about where things live'. Builds a durable map in .forge/map.md, navigable areas in the user's words, path rules saying where each kind of file belongs and how that was established, and the exceptions practice turns up, then resolves a ticket's vocabulary to candidate files and the rules governing them. A submodule hub or multi-repo workspace gets one map per child plus a cross-repo index that flags concerns two repos share. Not for finding one known symbol (grep it), not for diagnosing a bug (use untangle), not for executing the change once the location is known (use task)."
argument-hint: "[ticket or question] [--map] [--check]"
user-invocable: true
license: MIT
---

# wayfind: where things live, and how you know

Two questions cost more time in an unfamiliar codebase than the work itself: *where does a change
of this kind go*, and *which files does this ticket actually touch*. Both get answered from
scratch every session, by grepping, by inference from whichever file was opened first, and the
answer is written down nowhere when the session ends.

The failure mode this prevents is **a convention asserted from two files**. "Components live in
`src/components`" is true of most repos and false in the one that matters. The assertion is
plausible, so nobody challenges it, and the correction arrives after the change is written. This
skill makes every claim about the codebase carry the basis it was established on, so that a guess
and a census are never mistaken for each other.

The map is one file, `.forge/map.md`, and it earns its keep through the exceptions. Rules can be
re-derived from a census any time; that `Modal.tsx` is a portal host rather than a component is
only learned by being wrong about it once.

## Step 1: Orient before claiming anything

```bash
bash "$FORGE/skills/wayfind/scripts/orient.sh" [dir]
```

Reports the routing model, the entry points, an extension census per directory, and the naming
patterns with their counts. Counts, not conclusions: forty `.tsx` files in one directory are
evidence for a rule, and one is not.

It also enumerates **infra manifests**: SAM/CloudFormation `template.yaml`,
`serverless.yml`, Terraform. In an infra-heavy repo the real entry points and the
real topology live there, not in the code census: Step Functions, cron schedules, queues,
and functions with no obvious handler file are all invisible to a file count. Reconcile
the manifest's function list against the handler files; the function that exists only in
the manifest is the one that slips review.

Then read the convention documents it found. **A stated convention outranks a census.** If
`CONTRIBUTING.md` says tests go beside the source and the census shows a `tests/` directory, that
is a finding: the repo is mid-migration, not a licence to pick whichever you prefer.

```bash
bash "$FORGE/skills/wayfind/scripts/map.sh" init "<application>"
```

## Step 2: Record areas in the user's words

An **area** is a region of the application as a person describes it: `checkout`, `admin settings`,
`the public marketing pages`. Areas are what a ticket names; directories are what a rule names,
and the translation between the two is most of what a newcomer lacks.

```bash
bash "$FORGE/skills/wayfind/scripts/map.sh" area checkout src/pages/checkout,src/lib/cart,tests/checkout \
  "cart, totals, discounts, the payment step"
```

Three to eight areas. Twenty means you have mapped directories and called them areas, which
answers nothing an `ls` would not.

## Step 3: Write path rules, with their basis

A rule is a glob, a kind, and **how it was established**. The third part is not optional; the
script refuses a rule without it.

```bash
bash "$FORGE/skills/wayfind/scripts/map.sh" rule 'src/components/*.tsx' component \
  'census: 41 files, no exceptions'
bash "$FORGE/skills/wayfind/scripts/map.sh" rule 'tests/*.spec.ts' test \
  'CONTRIBUTING.md states it; census agrees, 38 files'
```

### What counts as a basis

| Basis | Strength | What it licenses |
|---|---|---|
| The user said so | Strongest | Follow it, including where it contradicts the census |
| A stated convention in `CLAUDE.md` / `CONTRIBUTING.md` | Strong | Follow it; note where the census disagrees |
| A census with no exceptions | Strong | Follow it |
| A census with a few exceptions | Usable | Follow it, and record the exceptions as lessons |
| Two files that happened to look alike | None | Not a rule. Run the census. |
| "It's the standard for this framework" | None | A prior, not a fact about this repo |

The last two are the ones that feel like knowledge. A framework's convention tells you what the
authors probably intended, which is a different claim from what they did.

Two refinements on stated conventions. First, proximity: a repo's **own** `CLAUDE.md` is
stronger evidence than a generic one at a parent or hub root. It is practically the
authors telling you this repo's layout, where the parent file describes the family. When
they disagree, the nearer file wins. Second, staleness: a stated convention is strong
evidence of *intent*, and intent goes stale without the file changing. Before betting on
a claim like "PRs target `develop`", spend the thirty seconds of corroboration, where
`origin/HEAD` points, relative commit counts, whether the file you are changing even
exists on the claimed branch. A `develop` that is 47 commits behind `main` is a doc bug
to report, not a convention to follow.

One boundary worth naming: **intent, history, and ownership are not repo-derivable.** A
census reads current structure; it cannot see that a migration is mid-flight, which team
owns what, or the impact level of a dependency. When a question is of that kind, say so
and ask for the document that holds it: a map that guesses at intent is fiction with a
basis column.

### When the census disagrees with itself

Split the rule rather than averaging it. Two globs with narrower scopes and honest counts beat one
rule that is 70% true: a rule that is *usually* right is the expensive kind, because it is
trusted and then wrong without warning.

If neither pattern dominates and no document settles it, that is an open question, not a rule.
Record it under `## Open questions` and ask. One sentence from the user replaces an hour of
archaeology, and the answer becomes the strongest basis there is.

## Step 4: Resolve a ticket to files

```bash
bash "$FORGE/skills/wayfind/scripts/map.sh" ticket "Checkout total shows the wrong currency when the cart has a discount"
```

Extracts the ticket's terms, ranks files by how many *distinct* terms each mentions, and shows
which mapped areas use that vocabulary. Then resolve the top candidates to get the rules and
exceptions that apply:

```bash
bash "$FORGE/skills/wayfind/scripts/map.sh" resolve src/lib/cart/total.ts
```

**Ranked candidates are a starting set, not an answer.** One shared term is coincidence. Read the
top of the list, then say which files you expect to change and why *before* editing. That
sentence is what makes a wrong guess cheap to correct.

Two results mean *stop and ask* rather than *proceed carefully*:

- **Nothing matched.** The ticket's vocabulary is not the code's. Ask which feature it means; do
  not go hunting for a synonym and hope. `reference/tickets.md` covers this translation problem.
- **No rule covers the file you are about to change.** Either it is a new kind of file, in which
  case the rule is a decision to state, or a rule is missing. Do not invent one silently.

## Step 5: Record what practice taught

The step that makes the map worth keeping rather than regenerating. After doing the work, write
down what the census could not have told you:

```bash
bash "$FORGE/skills/wayfind/scripts/map.sh" learn \
  "portal host, not a component: it imports from pages and cannot be moved" \
  --rule 'src/components/Modal.tsx'
```

`resolve` surfaces a lesson whenever its glob matches, so the next session meets the exception
before repeating the mistake. A lesson attached to nothing is a note nobody reads at the moment it
would have mattered.

| Record | Skip |
|---|---|
| A file that looks like its neighbours and behaves differently | What a file does. That is what reading it is for |
| A rule that holds everywhere except one place, and why | A restatement of a rule already recorded |
| Two directories that look interchangeable and are not | Anything true of the framework generally |
| The term the codebase uses for what the ticket calls something else | A bug you found. That belongs in the brief |

Then re-read your rules. If a lesson contradicts one, **correct the rule too**: the map is read as
current, so a stale rule sitting above its own exception gets believed.

## Submodule hubs: one map per repo, one index over them

A hub of submodules (or a monorepo of independent repos) gets a map per child, which is
right, and structurally blind. The same collection, field, or concern touched by two
repos is invisible when each map is read alone, and that blindness is exactly where a
duplicated job hides: two repos both marking `isStale` on the same collection look fine
from inside either one.

```bash
bash "$FORGE/skills/wayfind/scripts/map.sh" index          # from the hub root
```

Aggregates every child `.forge/map.md` into the parent's `.forge/map-index.md` and flags
**shared concerns**: vocabulary that two or more child maps both use, drawn from their
areas and lessons. Each flagged term is a question, not a verdict: same concern seen from
two sides, or the same job done twice? Resolving that still takes reading, but the index
turns what used to be an unaskable question into a listed one.

The index is only as good as the child maps feed it. A child with no areas and no
lessons contributes nothing; map the children first, index second.

## Step 6: Check for drift

```bash
bash "$FORGE/skills/wayfind/scripts/map.sh" check
```

Run this before trusting a map you did not write this session. It re-counts every rule's glob and
flags three states: `DEAD` (matched files when recorded, matches none now. The code moved),
`EMPTY` (never matched anything, so the rule was wrong on arrival), and `GREW` (more than doubled,
so the convention may have split and needs re-sampling).

A dead rule is worse than a missing one. A missing rule prompts a question; a dead rule answers it
wrongly, with full confidence.

## Where this sits

| Situation | Skill |
|---|---|
| You do not know where the change goes | **wayfind** |
| You know where it goes, and need it done well | `task` |
| You know where it is and not why it breaks | `untangle` |
| The population of files is the problem, not the layout | `untangle --kind scale` |
| "What breaks if I change this" / data-flow between modules | `atlas` |

The map records where things live; it does not model dependencies. Questions like "which
job writes this collection and who reads it" are `atlas`'s ground. Its model carries the
`file:line` of every edge, which a map's prose cannot.

`wayfind` and `untangle --kind scale` both enumerate; the difference is what the output is for.
`survey.sh` builds a population to edit once. `map.sh` builds a map to consult repeatedly. On a
migration into an unfamiliar repo, use both: map first, then survey inside the areas the map
identified.

## Invariants

- **Every rule carries its basis.** A census, a document, or the user, never "it seems standard".
- **A convention asserted from two files is a guess.** Run the count before writing the rule.
- **Ranked candidates are a starting set.** State the files you expect to change, before editing.
- **An exception found is an exception recorded.** That is the part that cannot be regenerated.
- **`check` before trusting a map you did not just build.** A dead rule is confidently wrong.
