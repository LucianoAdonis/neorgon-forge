---
name: task
description: "Use when the user brings a problem to solve rather than an edit to make — anything phrased as a goal instead of a diff. Triggers on: 'implement X', 'add support for Y', 'refactor Z', 'migrate A to B', 'build me a', 'I want to build', 'figure out why W is broken', 'take on this whole thing', 'this is a big one'. Fits a feature, a refactor, a migration, or a bug with an unclear cause. Scopes the work before writing code, splits large work into workstreams that can be delegated to subagents and verified against the diff rather than the report, and keeps a brief on disk so the reasoning survives the session — which is what debrief and writeup read afterwards. Not for a one-line change you already know how to make, not for reviewing existing code (use code-review), and not when the shape of the problem is still unknown (use untangle first)."
argument-hint: "[problem] [--scope quick|standard|campaign] [--resume]"
user-invocable: true
license: MIT
---

# task — scope it, size it, then do it

Most bad outcomes on a large task are decided before any code is written: the wrong problem
gets solved, or the right problem gets solved in twelve places when it lives in one. This skill
front-loads the two questions that prevent both, then picks an execution mode proportional to
the work.

It also leaves a **brief** at `.forge/brief.md` — the problem, the decisions, what was tried
and rejected, what is still open. That file is the reason `debrief` and `writeup` can report
what happened instead of reconstructing it from a diff. Written during, not after: a decision
recalled at the end of a long session has already lost the alternative it beat.

## Step 0 — Size the work

Pick the mode from the work in front of you, and say which one you picked and why in one line.
Getting this wrong in either direction is the most common failure: ceremony on a small task
wastes the user's time, and a campaign run as a quick fix produces half a migration.

| Mode | Fits | Costs | Delegates |
|---|---|---|---|
| `quick` | One file, cause already known, under ~30 lines | No brief, no plan | No |
| `standard` | A few files, one subsystem, cause needs confirming | Brief + inline plan | Only for research |
| `campaign` | Many files or subsystems, or work spanning sessions | Brief + tracked workstreams | Yes, per workstream |

Escalate mid-flight when a `standard` task turns out to touch nine files — say so and start the
brief rather than pressing on. Never silently downgrade a `campaign`; if it is smaller than it
looked, say that too.

One environment check before any mode: if the working tree lives inside a cloud-sync
folder — iCloud's `Mobile Documents`, Dropbox, OneDrive, Google Drive — stop and say so
before editing anything. Sync daemons fork concurrently-written files into silent
`name 2.ext` copies; a session that ignored this lost an entire source tree. `brief.sh
init` warns when it sees such a path. This and the other ways an environment destroys
finished work — rebase-abort deletions, stale artifacts posing as results, a shell that
drops PATH in loops — live in `reference/hazards.md`; read it when any of its symptoms
appears.

`quick` skips to Step 3. The rest of this applies to `standard` and `campaign`.

## Step 1 — Resolve ambiguity, once

Ask about the things where two readings produce materially different work. Use `AskUserQuestion`,
batch every question into **one** round, and make each option a real fork with its consequence
stated.

Ask about:

- **Scope boundaries** — is the adjacent broken thing in or out
- **Forks with no default** — new dependency vs hand-roll, migrate vs dual-write
- **The definition of done** — tests pass, or deployed and verified
- **Constraints you cannot infer** — deadlines, systems that must not be touched

Do not ask about anything you can find out yourself. Reading the file is faster than asking
what is in it, and a question whose answer is in the repo reads as not having looked. If the
task is unambiguous, skip this step entirely rather than manufacturing questions — a forced
round of obvious questions is worse than none.

Answer these yourself, from the code, before proposing anything:

- Where does this behaviour live now, and is there one home for it or several
- What already exists that does part of this
- What will break, and what covers it

## Step 2 — State the approach before building it

Two paragraphs, not a document: what you are going to do, and the one alternative you
considered and why you did not take it. Then write the brief.

```bash
bash "$FORGE/skills/task/scripts/brief.sh" init "<one-line problem>"
```

Fill in the approach and the rejected alternative while both are still in your head. For
`campaign`, also register the workstreams:

```bash
bash "$FORGE/skills/task/scripts/brief.sh" stream add "css tokens" "audit every hardcoded colour"
bash "$FORGE/skills/task/scripts/brief.sh" stream start "css tokens"
bash "$FORGE/skills/task/scripts/brief.sh" stream done "css tokens" "34 sites, 3 needed manual review"
```

The mechanical part of the brief — file, status, timestamps — is the script's job. The
judgment goes in prose under each heading, and prose is the part worth your attention.

## Step 3 — Build

Work the plan. The invariants:

- **Root cause, not symptom.** If a value arrives wrong, fix where it is produced. A guard at
  the point of use leaves the bug live for the next caller.
- **Follow what is there.** Match the surrounding naming, error handling, and file layout even
  where you would have chosen differently. A file with two conventions is worse than a file
  with the convention you dislike.
- **Self-documenting over commented.** Rename the variable rather than explaining it. Keep
  comments for *why*, where the reason is not recoverable from the code.
- **No compatibility shims, no defensive fallbacks** unless asked. A fallback that masks a
  failure converts a loud bug into a silent one.
- **Record decisions as they happen.** `brief.sh note "…"` when you reject an approach, hit a
  constraint, or discover the problem is not what it looked like. This is the material the
  downstream skills cannot get anywhere else.
- **When a recorded note turns out wrong, supersede it — never leave it standing.**
  `brief.sh correct "<fragment of the wrong note>" "<what is actually true>"` strikes the old
  claim where it stands and appends the correction. Being wrong then right is the normal shape
  of a long campaign; a reader going top to bottom must not meet the wrong claim first and
  stop there.

When you find a second problem mid-task: finish the first, then name the second. Do not
silently expand scope, and do not silently drop what you found.

## Step 4 — Delegate, for campaigns

Delegate a workstream when it is **independent** (no shared files with another live stream),
**bounded** (you can state its done condition in a sentence), and **verifiable** (you can check
the result without redoing it). If it fails any of the three, keep it inline — a subagent
handed vague work returns confident, wrong work, and checking it costs more than doing it.

Good candidates: per-site or per-package sweeps, "find every call site of X", independent
research, applying one decided pattern in many places.

Bad candidates: anything where stream B needs stream A's design decision, anything touching a
file another stream is editing, and the core design work itself. Do not delegate the thinking
that determines the shape of the result.

Each subagent prompt must carry, because it inherits none of your context:

1. The goal, as a done condition
2. The constraints — conventions to follow, files not to touch
3. The return contract — what to report back, in what shape
4. Explicitly: **report what you could not do**, rather than working around it

A session- or project-level rule about subagents outranks this step: if the environment says
not to spawn, do the work inline and say so — the skill suggests delegation, it does not
license overriding a standing instruction.

Run independent streams concurrently in one message. Then **verify on return** — this is the
step that makes delegation safe, and skipping it is what gives delegation its bad reputation.
Both halves of this arrangement have earned their place in a single run: one review subagent
found a live credential leak the author had missed and had already reported as fixed — and the
same review also proposed, with equal confidence, a pattern change that production data showed
would have redacted ordinary config blobs. The subagent sees what you cannot; its output still
needs verifying, not applying. Neither half is a formality:

- Read the actual diff, not the summary. A subagent reporting success is evidence, not proof.
- Spot-check the claim. If it says 34 files, count them.
- Look for the thing it did not mention. Silence about a hard case usually means it was skipped.
- Reconcile against the convention. Independent streams drift apart; a stream that invented its
  own naming needs fixing before the next one copies it.

Record each stream's outcome with `stream done` **including what it got wrong**. A campaign's
value at the end is largely in knowing which parts were verified and which were taken on trust.

## Step 5 — Verify, then report honestly

Run whatever the project actually has — tests, linter, build, the page in a browser. State what
you ran and what it said. "Should work" is not verification, and neither is a passing test for
code you did not exercise.

**If you added a guard, a check, or a refusal, write the test that trips it.** A guard you
cannot make fail is not a guard — and one that always says "fine" is worse than none, because
it gets quoted. Two shipped in a single session, both freshly written to make things safer: a
retry classifier whose regex did not match the abort message it existed to catch, and a
coverage check comparing against a field that did not exist, so every merge reported full
coverage. Both passed review and tests; only tripping them would have caught either. This
includes retry classifiers, coverage checks, and validation that runs in a dry-run path.

Two more verification rules that sound pedantic until they catch something:

- **Never report a test count without a run log.** A suite that was written but never
  executed is not coverage; quote the runner's own output, and check a new test file's
  path actually matches the project's test glob before writing it.
- **A test count that decreases is a defect, not a green result.** "28 passed, 0 failed"
  after a run that said 29 means something deleted a test — and if you did not, a file
  has been truncated or forked under you (`reference/hazards.md`).

And when a number goes in the brief's Measured section, **name the unit of value before
measuring**. "Per item returned" and "per item that mattered" can point in opposite
directions: a filter that is slower per batch was 4.4× faster per useful document, and
nearly got reported as a regression.

If the task ends with a repo's **first push to a new remote**, run the
`secret-safe-reporting` sweep over history first:

```bash
bash "$FORGE/skills/secret-safe-reporting/scripts/sweep.sh" . --history
```

A credential found in an unpushed history is a squash; found after the push, it is a
rotation. The thirty seconds are cheap against that asymmetry.

Then close the brief:

```bash
bash "$FORGE/skills/task/scripts/brief.sh" close
```

Report in this shape:

1. **What changed** — by theme, with paths
2. **What was verified, and how** — the command and its result
3. **What is still open** — deferred work, known defects that shipped, decisions left to the user

The third item is not optional and not a formality. Reporting a task as complete when part of
it is not is the one error that destroys trust in every prior report, and the user finds out
either way. If genuinely nothing is open, say that in one line.

## Resuming

`--resume` reads `.forge/brief.md` and picks up from stream state. A campaign spanning sessions
is the case the brief was built for: read it before touching anything, and trust it over your
recollection where they disagree.

## Handing off to debrief and writeup

Both read `.forge/brief.md` when it exists. What makes their output good is the material only
this skill can capture: the symptom before the fix, the alternative that lost, the number that
was actually measured. Write those down as they occur and the deck writes itself; leave them
implicit and the deck becomes a flattering summary of a diff.

## Invariants

- **Mode matches the work.** Say which one you picked. Escalate out loud, never downgrade silently.
- **One round of questions, only where the answer changes the work.**
- **The brief is written during the work, not reconstructed at the end.**
- **Delegated work is verified against the diff, not the report.**
- **Open items are always stated.**
