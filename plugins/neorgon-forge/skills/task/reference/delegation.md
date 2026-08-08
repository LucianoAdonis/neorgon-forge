# Delegating a workstream

Read when a `campaign` task has streams to hand off. The short version lives in SKILL.md
Step 4; this is the detail that makes the difference between delegation saving time and
delegation costing more than doing the work inline.

## The three tests, and why each one fails

A stream is safe to delegate only if it is independent, bounded, and verifiable.

**Independent.** No file is touched by two live streams. Two subagents editing the same file
produce a last-writer-wins result, and neither reports a conflict because neither saw one. If
two streams must touch one file, either serialise them or pull that file out into a third
stream you run yourself.

**Bounded.** You can state the done condition in a sentence. "Audit the CSS" is not bounded —
the agent decides when to stop, and it stops early. "List every hardcoded hex colour in
`css/*.css` with its file and line" is bounded, and you can tell at a glance whether it
finished.

**Verifiable.** You can check the result without redoing the work. Counting files, running a
grep, or reading a diff is verification. Re-reasoning through the design decision the agent
made is not — it costs what the delegation saved.

## What to delegate

Work that is wide and shallow:

- Per-site, per-package, or per-file sweeps of a pattern you have already decided
- "Find every call site of X" across a large tree
- Independent research — reading docs, comparing library options
- Mechanical migrations where the transformation is settled

## What to keep

Work that is narrow and deep:

- The design decision that determines the shape of everything else
- Anything downstream of another live stream's unfinished decision
- Any file another stream is editing
- The judgment call the user would want you personally to have made

Delegating the core design is the mistake that produces a campaign of individually-reasonable
changes that do not add up to a coherent whole.

## The prompt contract

A subagent inherits none of your context. Every prompt carries four things, and omitting any
one of them produces a predictable failure:

```
GOAL (as a done condition)
  Replace every hardcoded hex colour in <site>/css/*.css with the matching
  token from css/parts/tokens.css. Done when no hex literal remains outside
  tokens.css.

CONSTRAINTS
  - Do not touch vendored files: neorgon-header.css, neorgon-footer.css, viz.css
  - If no token matches a colour, leave it and report it — do not invent a token
  - Match the existing var(--name) formatting

RETURN
  - Files changed, with a count of replacements per file
  - Every colour you could NOT map, with file and line
  - Anything you skipped and why

REPORT WHAT YOU COULD NOT DO rather than working around it.
```

Omit the goal-as-done-condition and it stops early. Omit constraints and it edits vendored
files. Omit the return contract and you get prose you have to re-read the diff to check. Omit
the last line and it invents a token rather than admitting the gap — the failure that is
hardest to catch, because the output looks complete.

## Verifying on return

The step that makes delegation safe. A subagent's report is evidence, not proof; it is a claim
made by the party with an interest in the claim.

| Check | How | Catches |
|---|---|---|
| Read the diff | `git diff --stat`, then the hunks | Work that was reported but not done |
| Count the claim | It said 34 files — count them | Rounded-up or invented totals |
| Look for the silence | What hard case went unmentioned? | Skipped edge cases |
| Reconcile conventions | Compare two streams' output | Drift between parallel streams |
| Re-run the check | The grep whose emptiness means done | Partial completion |

Convention drift is specific to parallel delegation and worth naming: two streams given the
same instruction will pick different names for the same new thing. Fix it after the first two
streams return, before the rest copy the divergence.

## Recording the outcome

```bash
brief.sh stream done "css tokens" "34 sites; 3 needed manual review; 2 colours had no token"
```

Include what the stream got wrong. At the end of a campaign the useful question is not what was
done but **which parts were verified and which were taken on trust** — and only the record
answers that, because by then everything looks equally finished.
