---
name: forge
description: Ask which forge skill fits the situation. A router over the eighteen, and the flows that connect them.
user-invocable: true
disable-model-invocation: true
license: MIT
---

# forge: which one of these do I want

Eighteen skills is more than anyone holds in their head, and the ones you reach for least are
the ones you most need reminding of. Ask instead.

They sit in four buckets by **where in the work you are**, not by topic.

| | |
|---|---|
| **`before/`** | You have not started: you do not know which skill, where the change goes, what the problem is, or whether the plan holds |
| **`during/`** | The work is happening |
| **`after/`** | It is done and someone has to hear about it |
| **`craft/`** | Standing quality of the fleet. Reached for at any point, on their own schedule |

## The main flow: a problem arrives, code ships, someone is told

The route most work travels. Not every step every time; the middle one is the only one that is
always there.

1. **`/wayfind`** when you do not know where the change goes. Produces `.forge/map.md`: areas,
   path rules, exceptions. Skip it in a repo you already know.
2. **`/grill`** when the plan needs arguing with before anyone builds it. A round of questions
   at a time, each with a recommended answer, until the frontier is empty. In a repo it leaves
   `.forge/context.md` and numbered decision records.
3. **`/task`** does the work. It picks a mode from the size (`quick`, `standard`, `campaign`),
   splits a campaign into workstreams it can delegate, and keeps `.forge/brief.md` **while the
   work happens**: the symptom before the fix, the alternative that lost, the number actually
   measured. That file is the reason step 4 reports rather than reconstructs.
4. **`/debrief`** for a deck, **`/writeup`** for a post. Both read the brief. Ask for one and
   you usually want both.

**The brief is the spine.** Steps 2, 3 and 4 all read or write `.forge/`, which is what stops
the account of the work being a flattering summary of a diff. Everything else in this repo is
optional; skipping the brief is what makes the last step bad.

## On-ramps: how work arrives

- **Something is broken and the cause is not obvious** goes to **`/untangle`** first, not
  `/task`. It refuses to theorise before it has evidence, and produces either a reproduction,
  a scored decision, or a coverage map. When the cause is known, that is a `/task`, and when
  the finding is that the module is the wrong shape, `/task` reads its deep-module reference.
- **A Pathfinder canvas, brief, or link arrives, or finished work must return to one**, goes to
  **`/pathfinder`**: it obeys the brief's Situation and mode, and hands back a canvas that
  provably loads instead of JSON that silently drops blocks on import.
- **A question about the app itself, rather than one change to it**, goes to **`/atlas`**. It
  extracts a dependency model and generates the MkDocs pages and Mermaid diagrams *from* it, so
  they can be asked questions and can report their own staleness. Where `.forge/context.md`
  exists it also reports where the code's names and the project's language have drifted.
- **A step only a human can take** (a dashboard, a DNS record, an API key, a cutover) goes to
  **`/wizard`**, which generates the bash script that walks them through it. Reach for it the
  moment you hit a wall you cannot pass yourself, and never for something you could just do.
- **A tutorial about to promise steps** goes to **`/groundwork`** before a word is written. It
  finds what the service actually requires, dates every claim, and labels each one verified,
  documented, or inferred.

## At a session boundary

- **`/handoff`** when the work moves: a new window, a new machine, a new harness, a colleague.
  It writes `.forge/handoff-<slug>.md`, reads the brief rather than restating it, and names the
  skills the next agent should call.
- **`/repitch`** mid-conversation, inside any other skill, when an answer did not land. The
  agent re-pitches with the context you were missing, in plain language, using the project's
  own vocabulary.

## The craft bucket: what a fleet drifts on

These run on their own schedule and belong to no flow.

- **`/voicecheck`** audits copy that already exists: `file:line`, against the project's
  `VOICE.md`, or across projects, because voice drift is invisible from inside one repo.
- **`/penname`** drafts new prose that has to sound like the author, English or Spanish, under a
  persona whose register rules are checkable rather than adjectival, with a ledger of the
  corrections the author actually accepted.
- **`/deckcraft`** is for the deck that did **not** come from a diff: written from an idea, or
  already written and saying nothing. Its bar is that every heading makes a claim someone could
  dispute.
- **`/quizmaster`** turns source material into a validated Proctor-format exam.
- **`/mascot-forge`** generates a character, cuts it out, aligns the frames, and rigs it.
- **`/secret-safe-reporting`** sits across everything: any pipeline, report, or test suite that
  reads sensitive data and produces output other people will see. Run its sweep before a repo's
  first push to a new remote, where a find is a squash rather than a rotation.

## When two of them look the same

The overlaps, resolved. This table is the reason to open this skill rather than the list above.

| You are about to reach for | Reach for this instead when |
|---|---|
| `untangle` | The cause is already known: that is `/task`. The plan is the doubt, not the cause: that is `/grill` |
| `grill` | The shape of the problem is unknown, not the plan's soundness: `/untangle` first |
| `task` | The change is one line you already know how to make: just make it, no skill |
| `wayfind` | The question is how the whole app fits together rather than where one change goes: `/atlas` |
| `pathfinder` | The plan itself needs arguing with rather than encoding: `/grill`. The work in the middle is the ask: `/task`, then come back for the write-back |
| `debrief` | It is a post, not a deck: `/writeup`. It did not come from a diff: `/deckcraft` |
| `writeup` | It is README or docs prose: that is ordinary writing, or `/penname` for voice |
| `deckcraft` | The deck should report what actually changed in the code: `/debrief` reads the diff |
| `voicecheck` | The copy does not exist yet: `/penname` writes, `voicecheck` audits |
| `groundwork` | The tutorial is written and the question is how it reads: `/voicecheck` |
| `wizard` | You could do the step yourself: then do it |
| `handoff` | The context is fine and the work is not moving: keep going, or compact |

## The rule underneath all of it

**A skill is worth invoking when it prevents a specific failure, and not otherwise.** Each one
in this repo names its failure in its own first two sentences. If you cannot say which failure
you are buying protection from, you probably want to just do the work.

## Setting them up

Nothing here needs a setup step. Every skill runs in any repo. The parts that are true only of
the Neorgon monorepo sit behind a detection step inside the skill that needs them, so a skill
run anywhere else degrades to its portable path rather than erroring.

The one thing worth knowing: `.forge/` is where they all write. `context.md`, `decisions/` and
`map.md` are standing descriptions of the repo and get more useful the longer they are kept.
`brief.md`, `evidence.md` and `handoff-*.md` are about one piece of work and are disposable.
Gitignore the directory, or commit the standing half; both are reasonable, and mixing them
without deciding is not.
