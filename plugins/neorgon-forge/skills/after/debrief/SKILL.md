---
name: debrief
description: "Use at the END of a piece of work for a deck, slides, or a presentation of what changed and why. Triggers on: 'make a deck about this', 'slides for the demo', 'presentation of what we did', 'build me a readout', 'deck for the sprint review', 'I need to present these changes', 'use debrief', 'debrief and writeup', 'overview deck of this project', 'explain this platform to managers'. Fits a demo, standup, sprint review, stakeholder update, retro, or a plain overview of what a project is and who it is for. Reads the git diff and the task brief so the deck reports facts, not flattery, then builds the PDF rather than explaining how to. Offer it unprompted after a large multi-file change lands. Not for a blog post alone (use writeup), not for a commit message (use commit-work), and not for a deck whose subject is not a codebase, or one that already exists and needs repair (use deckcraft)."
argument-hint: "[project] [--audience eng|stakeholder|mixed] [--since <ref>] [--format auto|yaml|marp|md] [--theme <name>]"
user-invocable: true
license: MIT
---

# debrief: the work, as a deck someone can sit through

Turns finished work into a presentation that explains what changed and, more importantly, why.

The failure mode this skill exists to avoid: a deck assembled from what the model *remembers*
doing, which drifts toward flattery and omits the parts that did not work. Every claim here
starts from the diff or from the brief written while the work happened.

## Step 1: Collect the facts

**First, decide which of the two decks this is**, because it changes where the facts come from:

- **A change readout**: what shifted in this body of work. The default, and the rest of this
  step applies.
- **An overview**: what a project *is*, what it does, who it is for. No diff sits behind it.
  Skip the collector; it has nothing to say about a system that did not just change. Get the
  facts from the README, the schema or data model, the entry points, and the user. Then jump to
  the overview spine in Step 3.

Asking for "an overview of X" is not a malformed change readout, and running the collector
anyway produces a deck about last month's commits when someone wanted to know what the product
does. If the request names no timeframe and no change, it is an overview.

For a change readout:

```bash
bash "$FORGE/skills/debrief/scripts/collect-changes.sh" <project> [--since <ref>]
```

Prints changed files grouped by area, insertions/deletions, commits in range, new and deleted
files, and any docs or instruction files touched. Read all of it before writing a slide.

**Then read `.forge/brief.md` if it exists.** The `task` skill writes it during the work, and it
holds exactly what the diff cannot: the symptom before the fix, the alternative that was
rejected, the numbers actually measured, and what is still open. A brief turns three of the
slides below from guesswork into transcription.

Without a brief, get the same four things from the session or by asking:

- **What was wrong before.** A deck that opens with the solution leaves the audience unable to
  judge whether it was worth doing.
- **What was measured.** Real numbers only: page height, error count, response time, test
  results. If a number was never measured, it does not go on a slide.
- **What was decided and rejected.** The alternative you did not take is usually the most
  interesting slide in the deck.
- **What is still open.** Non-negotiable; see Step 5.

## Step 2: Pick the audience

The same work makes three different decks. Ask if it is not obvious.

| Audience | Leads with | Include | Cut |
|---|---|---|---|
| `eng` | The technical problem | Code slides, trade-offs, invariants, failure modes | Business framing |
| `stakeholder` | The user-visible symptom | Before/after, measured impact, what it unblocks | Implementation detail, file names |
| `mixed` | The symptom, then one layer of mechanism | Before/after plus one honest technical slide | Deep code |

For `stakeholder`, translate every technical fact into a consequence. "Changed the container to
a fixed height" is not a slide; "the chart and its readout now fit on one screen, so nobody
scrolls to see the result of their own click" is.

## Step 3: Structure the narrative

The spine that works for a change readout:

```
title
→ what was wrong        (the symptom, in the audience's language)
→ what we found         (the cause, often more interesting than the fix)
→ what changed          (grouped by theme, not by file)
→ proof                 (measured before/after; stats or split)
→ what it cost          (trade-offs, what got harder)
→ what is still open    (honest, named, with an owner if there is one)
→ cta                   (the decision or next step you want)
```

For an **overview**, the change-readout spine does not apply. There is no "before" to open on.
Use this instead, and keep it short. An overview that runs long stops being an overview:

```
title
→ what it is            (one sentence someone can repeat, not a feature list)
→ who it is for         (and, as sharply, who it is not for)
→ the problem it solves (the manual, expensive thing it replaces)
→ what it does          (3 to 5 capabilities, one grid or checklist slide, not one slide each)
→ how it works          (one layer of mechanism, only enough to make the value credible)
→ what is next          (or the ask, if there is one)
```

Six or seven slides. The failure mode is a feature inventory: every capability gets its own
slide, and the room leaves knowing the parts but not the point. If two capabilities serve the
same outcome, they are one slide.

Group by **theme, not by file**. Nobody wants a slide per changed file. Three or four themes
with the files as supporting detail is the right density; if you cannot name the themes, you
have not understood the change well enough to present it.

Two structural notes:

- **The cause slide is usually the best one.** "The dialog used a 3%-opacity surface token over
  a blurred backdrop" is a better slide than "fixed modal transparency", because it teaches
  something and makes the fix obvious rather than magic.
- **Put a divider before each theme.** Printed headings alone should tell the story.

## Step 4: Write the deck

`reference/deck-skeleton.yaml` is the annotated skeleton: copy it, fill it, delete what does
not apply. Its comments explain what each slide is *for*, which is the part that decides whether
a slide earns its place.

**Where the target player publishes finished example decks, start from the closest one instead.**
A deck that already validates and renders beats a stub, and it shows you the slide types in use
rather than describing them. For slides-site that is the deck library; `reference/neorgon.md`
maps each debrief occasion to the deck to fetch. Read the player's own agent index first
(`llms.txt` for slides-site) rather than working from the file list in any skill, this one
included: the player gains features on its own schedule, and a list kept here goes stale
silently.

Pick the output format from what the project actually has. `--format auto` means: use the first
of these that applies.

| Format | When | Output |
|---|---|---|
| `yaml` | A deck player expects it (see `reference/neorgon.md` for slides-site) | `docs/debrief-<YYYY-MM>.yaml` |
| `marp` | The repo has Marp, or the user wants PDF/PPTX export | `docs/debrief-<YYYY-MM>.md` |
| `md` | Neither: plain Markdown, one `##` per slide, `---` between | `docs/debrief-<YYYY-MM>.md` |

If the format supports a deck-level look (a `theme:` key, a Marp theme), set it only when a
preference exists: `--theme` wins, else a deck theme the project's own docs state, else leave it
unset and the player's default applies. Valid names live in the player's docs, not here. Theme
names are **colors, never clients or companies**. The value ships inside the deck file, and a
deck that names a customer in its metadata cannot be reshared outside that room.

Density rules hold in every format, and they are the difference between a deck and a document:

- **One idea per slide.** Two ideas is two slides; the deck being longer is not the problem.
- **At most 5 bullets, at most ~10 words each.** A bullet that wraps is a paragraph.
- **Code under 15 lines.** Show the point, not the file.
- **Sentence case headings**, and a heading that makes a claim beats one that names a topic.

Slide types worth reaching for in a change deck:

| Use | For |
|---|---|
| split | Before/after: the workhorse of a change deck |
| stats | Measured numbers, up to 4. Only measured ones |
| code | The one diff hunk that makes the point |
| timeline | Rollout or migration phases |
| image | A screenshot of the change, or a generated diagram |
| quote | A user complaint or a review finding, verbatim |
| divider | Between themes |

**If the change is visible in a browser, show it. A screenshot demo beats describing a UI.**
When the work touched something a page renders, capture it and put it on `image` slides:

- Launch the project's own preview and screenshot the changed feature in its real state, not a
  mockup. For a new feature, one shot of it working; for a visual change, before/after on a
  `split`-adjacent pair of `image` slides: the old state is usually still reachable via the
  live site or the previous commit.
- **Reuse assets that already exist before capturing new ones.** A verification screenshot
  from the session that built the change, an OG image, generated art, if the work produced
  an asset worth sharing, the deck is where it gets seen.
- Skip it honestly when the work is not visual: a screenshot of a terminal proves less than
  the `code` slide showing the diff hunk, and a decorative screenshot dilutes the deck.

Reference images by relative path from the deck file, or by public URL when the deck will
travel. Confirm each one resolves.

Put the detail you cut from a slide into its speaker note. File paths, exact numbers, and the
caveat you would say out loud belong there. It keeps slides sparse without losing the
information, and it means the user can present without re-deriving what each slide was about.

## Step 5: The honest slide

Every debrief gets a "what is still open" slide, and it is the one that earns the rest of the
deck its credibility. Include:

- Work explicitly deferred, and why
- Known defects that shipped anyway, and the reasoning
- Decisions the user still has to make
- Anything verified only partially, stated as such

If the brief has an `## Open` section, this slide is mostly transcription. If a campaign had
blocked streams, they go here by name.

Presenting a change as complete when part of it is not is the single fastest way to lose an
audience's trust, and they always find out. If the work genuinely has no open items, say so in
one line rather than dropping the slide: an audience reads a missing caveats slide as an
omission, not as an absence of caveats.

## Step 6: Audit

Two questions, both worth answering out loud before handing the deck over:

- Does slide 1 establish the **problem** rather than announce the topic?
- Does the last slide say what **happens next**?

Then check it renders, in whatever player applies, and confirm no slide overflows. A slide that
scrolls is a slide with two ideas on it.

## Step 7: Hand over a file, not a source

A deck YAML is an input to a player. Most of the people a debrief is written for will never open
one, so **build the shareable artifact and give them the path**, do not close by explaining
which buttons to press.

PDF is the default: it survives email, Slack, and a phone. Add PPTX when the audience will edit
or re-present it. Build both when unsure, it costs one flag. The per-player commands live in the
overlay (`reference/neorgon.md` for slides-site, one `render-deck.mjs` invocation); where no
build path exists, say plainly that the format ships as source and what opens it.

Report the file you produced, its slide count, and which checks actually ran against it.

## Invariants

- **Facts come from the diff and the brief, not from memory.** Run the collector first on any
  change readout. An overview has no diff behind it: get its facts from the code and the user,
  and say which.
- **Read the player's own index before writing for it.** A file list copied into this skill is
  stale the moment the player ships anything.
- **Build the artifact.** A debrief ends in a PDF someone can open, not in instructions for
  producing one.
- **Only measured numbers reach a slide.** An estimate presented as a measurement is the one
  error an audience can catch and never forgets.
- **Group by theme, not by file.**
- **The open-items slide is not optional.**
- **One idea per slide.**
