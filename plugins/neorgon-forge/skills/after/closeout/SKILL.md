---
name: closeout
description: "Use when the work has landed and the question is what is left: 'anything else pending?', 'what's still open?', 'wrap up', 'close out', 'land everything', 'finish the leftovers and publish'. Inventories the pending items from sources that cannot lie (git state, the registry, the hub, briefs, the harness ledger), enumerates them numbered with a per-item default, then treats the user's single reply as the authorisation: every listed item is closed except the ones the reply denies, publishing included when it was listed. Triggers on: 'anything else pending', 'what is pending', 'close out', 'wrap this up', 'land and publish everything'. Not for choosing new work (the prompt queue is the backlog: use task), not for reviewing what shipped (use code-review), not for the readout deck (use debrief)."
argument-hint: "[project ...] [--fleet]"
user-invocable: true
license: MIT
---

# closeout: enumerate what is pending, then close what the answer authorises

Ends a body of work by turning "anything else?" into a numbered contract: the inventory comes
from the repos and registries rather than from memory, the user answers once, and everything
enumerated gets closed except what that answer denies. The failure mode this exists to prevent
has two halves: a wrap-up listed from recollection that misses the items only git knows about
(the repo with no remote, the generated file nobody committed), and its opposite, an agent that
"finishes up" by doing things that were never put in front of the user as a list.

## Step 1: Collect, from sources that cannot lie

```bash
bash "$FORGE/skills/closeout/scripts/collect.sh" [root] [project ...] [--fleet]
```

Name the project repos the session touched; add `--fleet` only when the question is fleet-wide
(it runs one git per repo and is slow). The script reports: git state of the root and each named
project (dirty files, unpushed commits, **no-remote repos**), registry sites at `lifecycle:
ready` (a domain reserved with nothing served), hub cards still marked Soon, `.forge/brief.md`
`## Open` sections, the harness ledger's pending sweeps, whether the fleet news feed is behind
the newest hub ship date (landed work nobody announced), and the prompt-queue count.

Then add what only the session knows: items deferred out loud during the work, checks that ran
partially ("validated but never clicked through"), and anything a report of yours promised.
Label each of those with where it came from, because they are the only entries not backed by
the script's output.

## Step 2: Enumerate, with a default per item

Present a numbered list. Every item carries three things:

1. **What it is**, in one line, with the path or resource that proves it.
2. **What closing it takes**: the command, the edit, or the runbook.
3. **A lane**: `do` (will be done unless denied), `yours` (needs a credential, a dashboard, or
   a decision only the user can make: never attempted), or `parked` (belongs to the backlog,
   listed so its omission is visible, not offered for action).

Publishing is always its own numbered item when it applies, never folded into another one:
"push" and "publish a site to a public repo" are different magnitudes of irreversible and the
user must be able to deny one without the other. An undrafted-news item is the opposite case
and defaults to `do`: `/newsroom` writes only gitignored drafts, and the stories themselves
publish at the desk, never as part of a closeout. Ambient items from other efforts (another
session's campaign, the queue) are `parked` by default: closing someone else's in-progress work
is how two sessions corrupt each other.

## Step 3: Read the answer as the authorisation

The user replies once. Interpret it as: **every `do` item proceeds except those the reply
denies**, by number or by name. "Go, but skip the DNS" closes everything but the DNS item. A
reply that only adds items ("also run the sweep") extends the list and authorises the rest. A
reply that is a question is not an authorisation: answer it and re-offer the list.

Two hard edges:

- **The list is the ceiling.** Work discovered mid-execution that was not enumerated gets
  reported at the end, not silently done. If it blocks a listed item, say so and stop that item.
- **`yours` stays yours.** A stale credential or an IP whitelist does not become yours to fix
  because the user said "do everything". Report it with the exact step they must take.

## Step 4: Execute in blast-radius order

Cheapest and most reversible first, so a failure late in the run strands as little as possible:

| Order | Items |
|---|---|
| 1 | Local file closes: generated artifacts, doc updates, config entries |
| 2 | Commits, per repo, only the files each item names |
| 3 | Verification gates: the project's tests, `make smoke`, validators |
| 4 | Pushes to existing remotes |
| 5 | Publishes: new public repos, Pages, DNS, per the operations runbook, never from memory |

Row 5 has one precondition it must not skip. A site repo has to be **public** for Pages on the
free plan, so publishing publishes the source. Before a first push to a new remote:

```bash
bash "$FORGE/skills/secret-safe-reporting/scripts/sweep.sh" . --history
```

A credential found in an unpushed history is a squash; found after the push, it is a rotation.
`/task` requires this at the same boundary, and this is where publishing actually happens, so
it has to be required in both places rather than remembered in one.

A failed gate at row 3 stops rows 4 and 5 for that repo and is reported as the reason. Never
reorder a publish above its verification.

## Step 5: Report per item, by number

Close the loop with the same numbers the user answered to: `done` (with the proof: the commit,
the URL, the exit code), `denied` (by them), `blocked` (with what broke and what would unblock
it), `yours` (with the exact step). An item reported `done` without its proof is the flattering
summary this repo exists to prevent.

## Invariants

- **The inventory comes from the collector, not from memory.** Session-known items are
  additions on top, labelled as such: never the base.
- **Nothing executes before the enumeration is answered.** The numbered list is the consent
  boundary; work outside it is a new conversation.
- **Publishing is its own line item.** It is never implied by "wrap up".
- **`yours` items are never attempted.** Credentials, dashboards, whitelists, destructive
  choices: reported with the step, left alone.
- **Report by the same numbers.** The user checked boxes; the report must be checkable against
  them.
