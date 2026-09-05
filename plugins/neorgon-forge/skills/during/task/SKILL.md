---
name: task
description: "Use when the user brings a problem to solve rather than an edit to make, anything phrased as a goal instead of a diff. Triggers on: 'implement X', 'add support for Y', 'refactor Z', 'migrate A to B', 'build me a', 'I want to build', 'fix the bug in X, the cause is known', 'take on this whole thing', 'this is a big one'. Fits a feature, a refactor, a migration, or a bug whose cause is already established. Scopes the work before writing code, splits large work into workstreams that can be delegated to subagents and verified against the diff rather than the report, and keeps a brief on disk that debrief and writeup read afterwards. Not for a one-line change you already know how to make, not for reviewing existing code (use code-review), not when the plan needs arguing with (use grill), and not for 'figure out why W is broken' when nobody has established the cause (use untangle first)."
argument-hint: "[problem] [--scope quick|standard|campaign] [--resume]"
user-invocable: true
license: MIT
---

# task: scope it, size it, then do it

Most bad outcomes on a large task are decided before any code is written: the wrong problem
gets solved, or the right problem gets solved in twelve places when it lives in one. This skill
front-loads the two questions that prevent both, then picks an execution mode proportional to
the work.

It also leaves a **brief** at `.forge/brief.md`: the problem, the decisions, what was tried
and rejected, what is still open. That file is the reason `debrief` and `writeup` can report
what happened instead of reconstructing it from a diff. Written during, not after: a decision
recalled at the end of a long session has already lost the alternative it beat.

## Step 0: Size the work

Pick the mode from the work in front of you, and say which one you picked and why in one line.
Getting this wrong in either direction is the most common failure: ceremony on a small task
wastes the user's time, and a campaign run as a quick fix produces half a migration.

| Mode | Fits | Costs | Delegates |
|---|---|---|---|
| `quick` | One file, cause already known, under ~30 lines | No brief, no plan | No |
| `standard` | A few files, one subsystem, cause needs confirming | Brief + inline plan | Only for research |
| `campaign` | Many files or subsystems, or work spanning sessions | Brief + tracked workstreams | Yes, per workstream |
| `refine` | A **working** thing that should be better, with no defect to fix and no feature to add | Brief + a baseline nobody argues with | Yes, and verification costs more than the research |

Escalate mid-flight when a `standard` task turns out to touch nine files, say so and start the
brief rather than pressing on. Never silently downgrade a `campaign`; if it is smaller than it
looked, say that too.

**Escalate by kind, not only by size.** Mode is about how big the work is; it has nothing to
say about a fix that is not converging. After **three** attempts at the same failure that each
produce a new theory rather than new evidence, stop and hand it to `/untangle`. That is not a
bigger task, it is a different one: the cause was never actually known, and `/task` was the
wrong skill from the first attempt. The count is deliberate. An agent inside a fix loop is the
worst-placed observer of it, and "am I going in circles" asked as a judgment call is answered
"no" every time.

One environment check before any mode: if the working tree lives inside a cloud-sync
folder: iCloud's `Mobile Documents`, Dropbox, OneDrive, Google Drive, stop and say so
before editing anything. Sync daemons fork concurrently-written files into silent
`name 2.ext` copies; a session that ignored this lost an entire source tree. `brief.sh
init` warns when it sees such a path. This and the other ways an environment destroys
finished work: rebase-abort deletions, stale artifacts posing as results, a shell that
drops PATH in loops: live in `reference/hazards.md`; read it when any of its symptoms
appears.

`quick` skips to Step 3. The rest of this applies to `standard`, `campaign` and `refine`.

**`refine` is a campaign pointed at something that already works**, which changes what can go
wrong. There is no failing test to anchor on, so the work drifts toward whatever is easiest to
have an opinion about. Five rules keep it honest, and they come from a real refinement run
where seven subagents and outside research produced roughly forty findings:

1. **Establish a baseline nobody argues with first**: what exists, what already passes, and the
   command that proves it. Without it, every later claim is a matter of taste.
2. **Label every claim** `verified` (measured in this repo), `cited` (a primary source was read),
   or `inferred` (someone's reasoning). Ask each research stream for a ranked **do not build**
   list with the evidence against, which is often where the value turns out to be.
3. **Verify every claim before acting.** About one in five did not survive checking in that run,
   including a confident "this is dead code" about code that was live, and a report that cited
   the wrong file while describing the right defect.
4. **Fix in severity order**, blockers before polish.
5. **Leave a mechanical check** for each class of defect, so it cannot come back.

And check the **artifact**, not only the source. The worst defects of that run were invisible in
the browser and obvious in the export: images that were SVG bytes under a `.png` name, an author's
home directory in an alt-text field, a canvas a third too wide.

The honest answer is sometimes that the thing is already good enough. Say that rather than
manufacturing forty findings to justify the run.

## Step 1: Resolve ambiguity, once

Ask about the things where two readings produce materially different work. Use `AskUserQuestion`,
batch every question into **one** round, and make each option a real fork with its consequence
stated.

Ask about:

- **Scope boundaries**: is the adjacent broken thing in or out
- **Forks with no default**: new dependency vs hand-roll, migrate vs dual-write
- **The definition of done**: tests pass, or deployed and verified
- **Constraints you cannot infer**: deadlines, systems that must not be touched

Do not ask about anything you can find out yourself. Reading the file is faster than asking
what is in it, and a question whose answer is in the repo reads as not having looked. If the
task is unambiguous, skip this step entirely rather than manufacturing questions. A forced
round of obvious questions is worse than none.

Answer these yourself, from the code, before proposing anything:

- Where does this behaviour live now, and is there one home for it or several
- What already exists that does part of this
- What will break, and what covers it

## Step 2: State the approach before building it

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

The mechanical part of the brief: file, status, timestamps, is the script's job. The
judgment goes in prose under each heading, and prose is the part worth your attention.

## Step 3: Build

Work the plan. The invariants:

- **Root cause, not symptom.** If a value arrives wrong, fix where it is produced. A guard at
  the point of use leaves the bug live for the next caller.
- **When the shape is the problem, name it as the shape.** A task that turns out to be about a
  module's interface rather than its behaviour needs vocabulary the surrounding prose does not
  have: depth, seam, adapter, leverage, locality. `reference/deep-modules.md` holds it, plus the
  four questions to ask of an interface and the two places the argument translates badly to a
  fleet of static sites. Read it before proposing a split; most proposed splits are shallow.
- **Follow what is there.** Match the surrounding naming, error handling, and file layout even
  where you would have chosen differently. A file with two conventions is worse than a file
  with the convention you dislike.
- **Self-documenting over commented.** Rename the variable rather than explaining it. Keep
  comments for *why*, where the reason is not recoverable from the code.
- **No compatibility shims, no defensive fallbacks** unless asked. A fallback that masks a
  failure converts a loud bug into a silent one.
- **A step you cannot take is not a step to narrate.** When the work needs a browser session, a two-factor prompt, or a dashboard with no API, stop and call the Skill tool with "wizard" to generate the script that walks the human through it. Click paths typed into chat are followed once and then lost.
- **Record decisions as they happen.** `brief.sh note "…"` when you reject an approach, hit a
  constraint, or discover the problem is not what it looked like. This is the material the
  downstream skills cannot get anywhere else.
- **When a recorded note turns out wrong, supersede it: never leave it standing.**
  `brief.sh correct "<fragment of the wrong note>" "<what is actually true>"` strikes the old
  claim where it stands and appends the correction. Being wrong then right is the normal shape
  of a long campaign; a reader going top to bottom must not meet the wrong claim first and
  stop there.

When you find a second problem mid-task: finish the first, then name the second. Do not
silently expand scope, and do not silently drop what you found.

## Step 4: Delegate, for campaigns

Delegate a workstream when it is **independent** (no shared files with another live stream),
**bounded** (you can state its done condition in a sentence), and **verifiable** (you can check
the result without redoing it). If it fails any of the three, keep it inline. A subagent
handed vague work returns confident, wrong work, and checking it costs more than doing it.

Good candidates: per-site or per-package sweeps, "find every call site of X", independent
research, applying one decided pattern in many places.

Bad candidates: anything where stream B needs stream A's design decision, anything touching a
file another stream is editing, and the core design work itself. Do not delegate the thinking
that determines the shape of the result.

Each subagent prompt must carry, because it inherits none of your context:

1. The goal, as a done condition, **and the cheap way to satisfy it, forbidden by name**.
   Every done condition worth stating is a mechanical check: an empty grep, a passing suite, a
   count. Each one is satisfiable by changing what is checked rather than what is wrong, by
   widening an ignore rule, moving the offending values into an exempted file, or deleting the
   failing case. Say which of those is off the table, because a subagent optimising for a green
   check is not being dishonest, it is being literal
2. The constraints: conventions to follow, files not to touch
3. The return contract: what to report back, in what shape
4. Explicitly: **report what you could not do**, rather than working around it

A session- or project-level rule about subagents outranks this step: if the environment says
not to spawn, do the work inline and say so. The skill suggests delegation, it does not
license overriding a standing instruction.

Run independent streams concurrently in one message. Then **verify on return**. This is the
step that makes delegation safe, and skipping it is what gives delegation its bad reputation.
Both halves of this arrangement have earned their place in a single run: one review subagent
found a live credential leak the author had missed and had already reported as fixed, and the
same review also proposed, with equal confidence, a pattern change that production data showed
would have redacted ordinary config blobs. The subagent sees what you cannot; its output still
needs verifying, not applying. Neither half is a formality:

- Read the actual diff, not the summary. A subagent reporting success is evidence, not proof.
- Spot-check the claim. If it says 34 files, count them.
- Look for the thing it did not mention. Silence about a hard case usually means it was skipped.
- Reconcile against the convention. Independent streams drift apart; a stream that invented its
  own naming needs fixing before the next one copies it.
- **Check what was added, not only what was missed.** Every check above hunts a deficit: what
  was skipped, what went unmentioned, what count was rounded up. None of them fires on a file
  the stream created that nobody asked for, a dependency it introduced, or a second problem it
  fixed on the way past. Read the diff for additions with the same suspicion as omissions. A
  subagent with a bounded task and spare capacity will widen the task, and it will report that
  as thoroughness.

Record each stream's outcome with `stream done` **including what it got wrong**. A campaign's
value at the end is largely in knowing which parts were verified and which were taken on trust.

## Step 5: Verify, then report honestly

Run whatever the project actually has: tests, linter, build, the page in a browser. State what
you ran and what it said.

**"The page in a browser" is the fleet's dominant case and needs its own bar**, because roughly
70 zero-build static sites have no suite at all. Loading it is not verification. The check is:
the page renders, the browser console has **zero errors**, the network tab shows no failed
request, and you exercised the specific control the change touched and saw the specific thing
it was supposed to do. Report those four, the way you would report a runner's output. "Looks
right" from a screenshot is the visual equivalent of a test that was written and never run. "Should work" is not verification, and neither is a passing test for
code you did not exercise.

**If you added a guard, a check, or a refusal, write the test that trips it.** A guard you
cannot make fail is not a guard, and one that always says "fine" is worse than none, because
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
  after a run that said 29 means something deleted a test, and if you did not, a file
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

1. **What changed**: by theme, with paths
2. **What was verified, and how**: the command and its result
3. **What is still open**: deferred work, known defects that shipped, decisions left to the user

The third item is not optional and not a formality. Reporting a task as complete when part of
it is not is the one error that destroys trust in every prior report, and the user finds out
either way. If genuinely nothing is open, say that in one line.

## Resuming

Before re-deciding something that smells familiar, check whether a past campaign
already decided it: `brief.sh index <root>` collects every repo's brief under a root
into `<root>/.forge/brief-index.md`: problems, decisions, and open items, one
grep-able file. Cheaper than recollection and immune to it.

`--resume` reads `.forge/brief.md` and picks up from stream state. A campaign spanning sessions
is the case the brief was built for: read it before touching anything, and trust it over your
recollection where they disagree.

When the window is about to end with the work half-finished, tell the user to run `/handoff` before it closes. It writes `.forge/handoff-<slug>.md` beside the brief and carries the three things the brief does not: what is half-done right now, the single next action, and the landmines already paid for. Never call it yourself: it is user-invoked. Say the command and let them run it.

## Handing off to debrief, writeup and the newsroom

Debrief and writeup both read `.forge/brief.md` when it exists. What makes their output good is
the material only this skill can capture: the symptom before the fix, the alternative that
lost, the number that was actually measured. Write those down as they occur and the deck writes
itself; leave them implicit and the deck becomes a flattering summary of a diff.

One more hand-off, conditional: when the finished work shipped something a visitor can see on a
live site (a launch, a feature, a fix worth telling) and the `/newsroom` command exists in the
repo, offer it alongside the other two. It drafts a Dispatch story from the same brief and git
history into the news site's gitignored drafts; nothing publishes until the desk approves.
Internal tooling, refactors, and work on unpublished sites get no story.

## Invariants

- **Mode matches the work.** Say which one you picked. Escalate out loud, never downgrade silently.
- **One round of questions, only where the answer changes the work.**
- **The brief is written during the work, not reconstructed at the end.**
- **Delegated work is verified against the diff, not the report.**
- **Open items are always stated.**
