---
name: antenne
description: "Use at the END of a piece of work in any Neorgon repo, when what just landed might be worth telling the fleet: 'submit this to Antenne', 'is this worth a story?', 'put this on the news feed', 'tell the fleet what we shipped', 'file a dispatch for this change', 'add this to the feed'. Reads the repo's own diff, log, brief and registry row, decides whether a reader would actually care (a site opening, a feature they can use, a fix they noticed, a lifecycle change), says so and stops when the answer is no, then drafts one story, validates it through Antenne's pinned client, shows you the verdict, and submits to the private desk queue only after you say so. Triggers on: 'submit this to antenne', 'is this news', 'file it to the feed', 'tell the fleet', 'antenne this'. Not for sweeping many repos into several stories at once, which is the monorepo's /newsroom command; not for a readout deck (use debrief); not for an article (use writeup); and never for approving or publishing, which happen at the desk."
argument-hint: "[repo] [--since YYYY-MM-DD]"
user-invocable: true
license: MIT
---

# antenne: one story about the work you just did, or an honest no

Turns a finished piece of work into at most one story in the fleet's news archive, drafted from
the diff rather than from what the session remembers doing, and submitted to a private queue
where a human still decides. Two failure modes make this worth a skill. An agent asked to
"write it up" writes something either way, so the feed fills with kit syncs and refactors until
readers stop opening it; and an agent drafting from recollection writes a sentence the diff does
not support, which on a public, permanent archive is not a rough edge but a false claim.

The archive is public. Nothing here makes it so: this path ends at a queue.

## Step 1: Collect, from sources that cannot lie

```bash
bash "$FORGE/skills/antenne/scripts/collect.sh" [repo] [--since YYYY-MM-DD]
```

Read-only. It prints where it is running, the window (the newest published story, so the same
ground is not retold), this session's commits narrowed into candidates and not-news, the files
the window touched, the brief's problem and open lines, the registry row for the project, the
stories already published about it, and the ids already waiting at the desk.

Three of those deserve a note:

- **The narrowing is not the judgement.** A candidate is a commit whose diff is worth reading.
  You read it. The diff is the only evidence a sentence may rest on.
- **The registry row decides how you may speak.** `lifecycle: live` is the only state in which a
  story may call a site open or carry its link. `ready` means a domain is reserved and nothing is
  served, so the story is coming-soon phrasing with no link. Anything else gets neither.
- **It refuses some repos outright** and gathers nothing at all: `o11y-harness`, `metrics` and
  `cartograph-site` carry employer and private context that must never reach a public feed
  (exit 3). `assistant` and `fine-loop` stop it the same way, for a milder reason: they are
  outside the fleet's scope, so the verdict is in and there is nothing left to read (exit 4).
  Either way, report the one line it printed and stop.

The monorepo's `.claude/commands/newsroom.md` is canonical for what counts and for the story
schema. Read it when it is beside you; `reference/story.md` is the fallback when it is not, and
says so.

## Step 2: Decide whether it is news, and be willing to say no

This is the step the skill exists for. A fleet reader is not your colleague: they do not care
that the code is tidier, they care whether anything changed for them.

| It is news when | It is not news when |
|---|---|
| A site opened: the registry says `live` and it did not before | A refactor, a rename, a file split, an extraction |
| Someone can now do something they could not do | A kit sync, a vendored copy refreshed, a regeneration |
| Something they noticed being broken works again | Docs, a README, a CLAUDE.md, a comment, a typo |
| A lifecycle changed: to `live`, or to `ready` from anything but `live` | A chore, a bump, a lockfile, a lint pass, a test added |
| A tool changed how the fleet is run, described from the outside | A site arriving `internal` or `unpublished`, or a live site dropping back to `ready` |

Four exclusions are not judgement calls and never become news whatever the diff shows: work in
`assistant` or `fine-loop`, any change to `cartograph-site`, and any repo whose origin is not one
of the owner's accounts. That is somebody else's work.

**When the answer is no, say so and stop.** Name what you looked at and why it does not clear
the bar, in two sentences, and submit nothing. Filler is the expensive outcome here: a reviewer
has to read and spike it, and a reader who finds one learns the feed is not worth opening. An
honest no is a finished run, not a failed one.

Only one story. If the window holds two real stories, say so and offer the second separately
rather than welding them into one paragraph that is about neither.

## Step 3: Draft it in the archive's voice

Kinds are `launch`, `feature`, `fix`, `note`. The shape, the caps and where the file goes are in
`reference/story.md`: read it before writing the JSON, not after the first refusal.

What the rules will not catch for you:

- **Write what the diff shows and nothing more.** No motive you inferred, no scale you did not
  measure, no benefit nobody can check. If you cannot point at the change that makes a sentence
  true, cut the sentence.
- **Privacy is not a style rule.** A brief, a review, a plan and a workstream row are private
  working notes: summarize them in your own words, never quote them, and never carry a person's
  name, an email address, an employer or an internal path into a field.
- **The summary stands alone**, because an embed shows it without the body.
- Write each story to a scratch directory **outside every repo**. These repos are public, and
  `submit.sh scratch` will mint one. The wrapper refuses a story file that sits in a work tree,
  which is the accident it is there to prevent.

## Step 4: Check it, and show the operator both halves

```bash
bash "$FORGE/skills/antenne/scripts/submit.sh" check <scratch>/<id>.json
```

This validates in submit mode through the client Antenne itself uses, reached only through the
root's `./scripts/antenne_trust.py`, which runs it only while it matches the sha256 the owner
pinned after reading it. Nothing is sent. One invalid story refuses the whole run, so fix the
file and check again until it exits 0.

Then put two things in front of the operator, together: **the story as a reader would see it**
(title, summary, body, links, tags) and **the dry run's verdict**. A story shown without its
verdict asks for approval of something unvalidated; a verdict shown without the story asks them
to approve JSON. Then ask.

## Step 5: Submit only on a yes, then report per id

```bash
bash "$FORGE/skills/antenne/scripts/submit.sh" send <scratch>/<id>.json
```

Report each id with the outcome the client gave it: `created`, `updated`, `unchanged`,
`kept-human-edits`, `already-decided`, `published`, `invalid` or `queue-full`. Say what each one
means for that story rather than printing the word alone. `queue-full` stops the run: the desk
has as many machine drafts as it allows, and the answer is a reviewer, not a retry.

Then hand off: a reviewer approves or spikes each story at `https://dispatch.neorgon.com/desk.html`,
and publishing runs itself after approval. There is nothing to build, commit or clean up here.

## When something fails, one sentence and a stop

Every one of these ends the run. None of them is retried in a loop, and none is worked around.

| What happened | What it means, and the one thing to do |
|---|---|
| No submit key | Nothing can be submitted from this machine. Say so and point at `./scripts/setup-antenne.sh`. Never read or print the key |
| The trust check refused (exit 3) | Antenne's client changed since the owner read it. Report the line, stop, and never run the pin command yourself: pinning is the owner's review of that diff |
| The desk backend is not set up (exit 2) | The deployment or the key is not configured yet. Report the client's line and stop; do not fall back to writing drafts into a repo |
| `queue-full` | The queue is at its cap for machine drafts. Ask the operator to work through the desk first |
| `invalid` from the server | It judges the date by its own UTC day. Fix that story and submit it again |
| An id is already taken | `unchanged`, `kept-human-edits`, `already-decided` or `published` all mean the desk already has it. Leave it alone and say which |
| No Antenne checkout, or no monorepo root | The client cannot be reached from here. Say where you looked and stop |

## Invariants

- **The story comes from the diff.** A sentence that no change in the log or the working tree
  supports does not go in, however true it sounds.
- **An honest no is the expected outcome most days.** Refactors, kit syncs, docs and chores are
  not news; say what you looked at and stop rather than submitting filler.
- **`lifecycle: live` is the only licence to call a site open**, and the only one that earns a
  link. It is read from the registry, never from memory.
- **The client runs only through the root's trust wrapper**, and a refusal is reported, never
  pinned past.
- **Nothing here approves, publishes, writes the feed, commits or pushes.** This path ends at a
  private queue, and the desk is where a human decides.
- **The operator's yes is per story.** Checking is not consent to send, and one story's yes is
  not the next one's.
