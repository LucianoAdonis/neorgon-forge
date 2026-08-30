---
name: docket
description: "Use when the work in front of you is finished and the next thing is unchosen, which is usually a session's first question. Builds the slate from ledgers rather than memory: the prompt queue with each item's age and size, every brief's Open section and unfinished workstreams, the harness ledger, and dirty or unpushed git state. Orders it small items first, then the questions only you can answer, then the blockers, because a session that opens on its blockers never starts. Recommends a capped slate and one reply approves it: small items run inline, anything larger goes to task. Triggers on: 'what's next', 'what should I work on', 'what is pending', 'give me the next steps', 'what is in the backlog', 'anything small first'. Not for landing work that already exists (closeout), not for doing a task already chosen (task), not for arguing with a plan (grill)."
argument-hint: "[project ...] [--fleet]"
user-invocable: true
license: MIT
---

# docket: what is next, smallest first, approved in one reply

Opens a session by turning "what should I do now?" into a numbered slate drawn from the
ledgers, ordered so the session can actually finish something. Two failure modes make this
worth a skill rather than a habit.

The first is that an unaided answer comes from recollection, so the work chosen is whatever
was most recently discussed. The queue in front of this one had fifteen one-line items, four
of them 174 days old: none of them is hard, and none of them was ever the thing anybody
remembered. The second is the opposite, and worse: a session that opens on its blockers never
starts. A blocker cannot be closed in the session that discovers it, so leading with it costs
the session its momentum and buys nothing.

## Step 1: Collect, from ledgers rather than memory

```bash
bash "$FORGE/skills/docket/scripts/collect.sh" [root] [project ...] [--fleet]
```

Read-only: it closes nothing and writes nothing. It reports the prompt queue with each item's
**age and line count**, every `.forge/brief.md` `## Open` section, every `streams.tsv` entry
still `pending` or `active`, the harness ledger's open runs, and uncommitted or unpushed git
state. Add `--fleet` only when the question is fleet-wide; it runs one git per repo.

Outside a monorepo the queue and the harness are absent and the script says so rather than
inventing a substitute. Briefs and git state alone still make a usable docket.

Then add what only the session knows: work deferred out loud, a check that ran partially, a
promise a report of yours made. Label those with where they came from, because they are the
only entries the script cannot back.

**A ledger entry is a claim, not a fact.** Verify the cheap ones before offering them: this
skill's own first run found seven workstreams marked `pending` whose work was plainly finished
on disk, left stale because the session that did them closed the brief without closing the
rows. Offering finished work as the next thing to do is the fastest way to make the whole slate
untrustworthy.

## Step 2: Sort into lanes, by a test rather than a feeling

| Lane | The test it has to pass | Why it sits here |
|---|---|---|
| `small` | One repo, no decision pending, and you can state the done condition in one line | The only lane a session reliably finishes |
| `question` | The blocker is an **answer**, not work: one reply from the user unblocks it | Costs a sentence, and converts the item into `small` for next time |
| `campaign` | Real work, well understood, but more than one sitting | Choosing one should be deliberate, never accidental |
| `blocked` | Needs something outside this session: a credential, a dashboard, an upstream fix, another campaign to land first | Listed so its absence is visible. Never offered |

The queue gives you the size signal for free. A one-line item is a `small` candidate; an item
that runs to paragraphs has already told you it is a `campaign`, whatever its bullet suggests.

The order is the point, and it is not the order of importance. Small first, because momentum is
what the session has to buy. Questions second, because they are the cheapest thing the user can
do and they pay out later. Campaigns named but not sorted among the small work, because a
campaign is a decision, not an item. Blockers last, and only as a list.

## Step 3: Recommend a slate, do not hand over the backlog

Recommend **at most five** `small` items plus every `question`. A list of twenty is a backlog,
and a backlog gets skimmed rather than answered, which is the failure this skill was built to
end rather than to reproduce in a nicer format.

Everything not recommended still gets listed, under a heading that says it is not being
offered. The omission has to be visible: a slate that quietly drops fifteen items is the same
lie as a router that omits a skill.

Each recommended item carries four things:

1. **What it is**, in one line.
2. **Where it came from**: `#41`, `projects/x/.forge/brief.md`, `git status`. Every item is
   traceable to a ledger or labelled as session-known.
3. **What closing it takes**: the command, the file, the edit.
4. **Its lane**, and for a `question`, the recommended answer. A question offered without a
   recommendation makes the user do the thinking twice.

## Step 4: One reply, and it means less than closeout's does

The user answers once. The contract:

- The **recommended slate is default-yes**: "go" runs all of it, "go, not 3" runs it minus 3.
- Everything below the slate is **default-no**: it runs only if the reply names it.
- A reply that is a question is not an approval. Answer it and re-offer the slate.
- Answering a `question` item authorises the answer to be **recorded**, not the work it
  unblocks. Say which items moved to `small` because of it, and stop there.

This is the opposite default to `/closeout`, and the difference is not stylistic. Closeout's
list is debt already incurred, so silence means close it. This list is a menu of work nobody
has committed to, so silence means leave it alone.

## Step 5: Do the small ones, hand the rest over

Small items run inline, cheapest and most reversible first, so a late failure strands as
little as possible: local edits, then commits, then whatever gate the project has, then pushes.
A failed gate stops the push for that repo and is reported as the reason.

Anything sized `campaign` is **not started here**. It goes to `/task`, which opens with its own
sizing and question round, and that round is the thing a docket entry cannot substitute for.
Hand over the item text and its ledger id; do not pre-decide its approach.

The list is the ceiling. Work discovered mid-run that was not on it gets reported at the end,
not silently done.

## Step 6: Write the answer back, or this is a treadmill

An item closed here is closed **in the ledger it came from**, in the same run:

| Source | How it closes |
|---|---|
| Prompt queue | `./scripts/prompt.sh done <id>` |
| Brief `## Open` | Strike the line, or `brief.sh correct` when it turned out wrong |
| `streams.tsv` | `brief.sh stream done "<name>" "<what it got wrong>"` |
| Harness ledger | `run.py close --run <id> --status ...` |
| A question the user answered | `./scripts/prompt.sh add "<what was decided>"`, or a decision record under `.forge/decisions/` |

Skip this and the same twenty items come back next session, which is the state that made the
skill necessary in the first place. The asymmetry is worth naming: three skills read the prompt
queue and, until this step, nothing wrote to it, so a queue only ever grew.

## Invariants

- **The list comes from the collector.** Session-known items are additions on top, labelled.
- **A ledger entry is checked before it is offered.** Stale `pending` rows are real and common.
- **Small first, questions second, blockers last and never offered.**
- **The slate is capped and what was left out is named.**
- **Default-yes stops at the slate.** Nothing below it runs unnamed.
- **A campaign goes through `/task`'s sizing round**, never straight off the docket.
- **An item closed here is closed in its ledger**, in the same run.
