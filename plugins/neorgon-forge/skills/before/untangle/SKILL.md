---
name: untangle
description: "Use when a problem resists a plan and starting work would be guessing. Triggers on: 'I have no idea why', 'this makes no sense', 'we tried everything', 'it works locally but not in prod', 'intermittent', 'flaky', 'which approach should we take', 'weigh the options', 'trade-offs', 'I keep going in circles', 'this is a hard one'. Fits an unclear cause, contradictory evidence, several theories that all fit, a fix that keeps not working, or a design with three defensible answers where choosing wrong is expensive. Classifies the difficulty first (unknown cause / undecided design / too large to hold), then runs the branch for it: competing hypotheses each carrying the observation that would kill it, options scored against criteria written before the options, or a coverage map before any edit. Not for work whose shape is already known (use task) and not for reviewing finished code."
argument-hint: "[problem] [--kind cause|design|scale] [--resume]"
user-invocable: true
license: MIT
---

# untangle: for the problems that resist a plan

`task` assumes you know the shape of the work and need to execute it well. This is for when you
do not: the symptom does not point at the source, or three architectures are each defensible, or
the work is too large to hold in one head at once.

The failure mode it exists to prevent is **confident motion in the wrong direction**. Hard
problems punish the instinct that serves easy ones. You form a theory, the theory feels right,
and every subsequent observation gets read as support. Hours later the bug is still there and the
theory has never once been tested against something that could have killed it.

## Step 0: Classify the difficulty

Say which kind this is, in one line, before anything else. The three branches share almost no
technique, and running the wrong one is the expensive mistake.

| Kind | The tell | What the work actually is |
|---|---|---|
| `cause` | A symptom exists; nobody knows why | Narrowing, by refutation |
| `design` | Several answers work; the cost of wrong is high | Comparing, against stated criteria |
| `scale` | The answer is known; holding it all is not | Mapping coverage before editing |

Two honest complications:

- **A problem can change kind.** A `cause` investigation that finds the bug is architectural
  becomes a `design` problem. Say so and switch branch; do not keep debugging a decision.
- **`scale` masquerades as the others.** "Why is the build slow" across 40 packages is a
  coverage problem wearing a cause problem's clothes. If the answer is *probably many small
  things*, it is `scale`.

Open the brief now, whichever branch. Hard problems span sessions by nature, and a session that
ends with the reasoning only in the transcript starts over tomorrow.

```bash
bash "$FORGE/skills/task/scripts/brief.sh" init "<the symptom, or the decision>"
```

## Branch `cause`: narrow by refutation

### Establish the observation before theorising

```bash
bash "$FORGE/skills/untangle/scripts/evidence.sh" init "<the symptom>"
```

Write down what is actually observed, separated from what it is assumed to mean. The two get
conflated within minutes, and everything downstream inherits the confusion.

Then answer, from the system rather than from memory:

- **What exactly happens, and what exactly was expected?** "It breaks" is not an observation.
- **When did it start, and what changed then?** `git log` around the boundary is often the
  entire investigation.
- **Where is the boundary?** The smallest input that fails, the largest that works.
- **Is it deterministic?** A flake and a bug are different problems with different methods.

### Hold at least two hypotheses at once

One hypothesis is not an investigation, it is a hunch with a to-do list. Register competing
theories and, for each, **the observation that would kill it**:

```bash
bash "$FORGE/skills/untangle/scripts/evidence.sh" hypothesis "cache key omits the locale" \
  "then a locale-free request would also fail, check one"
bash "$FORGE/skills/untangle/scripts/evidence.sh" observe "locale-free request succeeds" --refutes 1
```

A hypothesis with no refuting observation attached is not testable, and an untestable hypothesis
cannot be crossed off: it lingers and gets re-litigated. **Design the cheap discriminating
test**: prefer one observation that splits the field over three that each confirm one theory.

### When the evidence contradicts itself

Contradiction means an assumption is wrong, and it is nearly always one of these:

| Suspect | Check |
|---|---|
| Not the same code | The deployed commit, the installed version, a stale build artefact |
| Not the same input | Log the actual value at the boundary, do not infer it |
| Not the same environment | Env vars, timezone, locale, filesystem case sensitivity |
| Not one bug | Two failures with one symptom; separate them before fixing either |
| Not the layer you think | Instrument the layer below before theorising about it |

`reference/hypotheses.md` has worked examples of each, and the shape of the mistake that produced
them.

### Stop condition

You are done when you can **make the bug appear and disappear on demand**. Anything less is a
correlation, and a fix built on a correlation comes back. If a change makes the symptom go away
and you cannot say why, that is not a fix, record it as open and say so plainly.

## Branch `design`: compare, do not rationalise

### State the criteria before the options

Criteria chosen after the options are criteria fitted to the preferred option. Write them first,
with weights if they differ, and get them confirmed if the user is available. A decision made
against the wrong criteria is worse than a coin flip, because it arrives with a justification.

### Two or three real options, honestly built

Each needs: how it works in a paragraph, what it costs, what it forecloses, and **what would
have to be true for this to be the right answer**. That last question exposes options nobody
actually believes in: a strawman cannot answer it.

Then score against the criteria in a table, and say which wins and by how much. A narrow win is
worth saying out loud: it means the decision is roughly reversible and not worth more analysis.

### Prototype only to resolve a specific uncertainty

If the deciding factor is unknowable from reading, throughput, an API's real behaviour, whether
a library handles your edge case: build the smallest thing that answers *that one question*.
Timebox it and record the number in the brief. A prototype that drifts into an implementation
has stopped being an experiment.

### Stop condition

Someone who disagrees with your choice can see, from what you wrote, exactly which criterion
they weigh differently. That is what makes a design decision reviewable rather than a matter of
taste, and `## Rejected` in the brief is where it lands.

## Branch `scale`: map before you touch

This branch's job is the map. Once it exists, hand execution to `task --scope campaign`; the map
is the part that gets skipped, not the editing.

### Enumerate mechanically, never from memory

```bash
bash "$FORGE/skills/untangle/scripts/survey.sh" <pattern> [dir]
```

Get the full population before deciding how to handle it. Every call site, every package, every
file matching the shape. A count from a script and a count from recollection differ, and the
difference is what ships broken.

### Sample before generalising

Read three or four instances *chosen to be different*. The oldest, the newest, the one everyone
warns about. The pattern inferred from the first two will be wrong in a way only the outlier
reveals, and finding that out after 30 mechanical edits is the expensive path.

### Partition into independent slices

Slices that share a file are not independent and cannot run in parallel. Register each as a
workstream on the brief, then delegate.

## When you are stuck, say so

A real stop condition, not a failure state. After roughly three refuted hypotheses with no new
information, or two fixes that did not hold: **stop and report**. State what is known, what was
ruled out and how, and the two or three things you would try next with what each would cost.

Continuing past this point produces the pattern everyone recognises: a long transcript, many
edits, no progress, and a codebase noisier than when it started. The user can often unstick it in
one sentence, but only if asked.

Revert speculative changes before reporting. A stuck investigation that leaves debug logging and
half-fixes behind has made the next attempt harder, including your own.

## Invariants

- **Classify first, and say which branch.** The techniques do not transfer.
- **Every hypothesis carries the observation that would kill it.** Otherwise it is a hunch.
- **Observation and interpretation stay separate**, in writing.
- **A fix you cannot explain is not a fix.** Record it as open and say so.
- **Stuck is a report, not a state to persist in.** Three refuted theories, then escalate.
