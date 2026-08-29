---
name: deckcraft
description: "Use when writing, fixing or critiquing a slide deck for slides-site (Presentation Sage), from an idea or from existing YAML. Triggers on: 'write me a deck about', 'turn this into slides', 'review my deck', 'these slides are boring', 'my headings are weak', 'make this deck land', 'prep me for the board', 'tighten this before the talk', 'use deckcraft'. Fixes the failure this tool cannot see: a deck that passes the density audit and still says nothing, because every heading names a topic instead of stating a claim. Covers heading rewrites, argument order for the room, slide-type choice, speaker notes, and the export traps that silently drop content. Not for turning finished work into a deck from a git diff (use debrief), not for a blog post (use writeup), and not for the words on a marketing page (use voicecheck)."
argument-hint: "[deck.yaml | topic] [--audience exec|eng|mixed|customer|learner] [--minutes N] [--room desk|meeting|hall]"
user-invocable: true
license: MIT
---

# deckcraft: decks that argue, not decks that list

Writes and repairs decks for `projects/slides-site`, where the mechanical audit already enforces
density and cannot enforce meaning.

The failure mode this exists to prevent: **a deck that passes `validate.mjs` cleanly and still
tells the audience nothing.** Measured on that project's own twelve example decks by three
independent passes, 2 of 48 content headings state a claim. The other 46 name a subject. A deck
whose headings read "Problem / Rollout / Actions / Next Steps" is a filing system with a theme.

## Step 0: Refuse to start on nothing

Before writing a slide, you need three answers. Two come from the user; the third you decide.

| | Why it changes the deck |
|---|---|
| **Audience** | Decides the order, not just the tone. See "Order for the room" |
| **Outcome** | inform · convince · approve · teach. An approval deck that never asks is a failure |
| **The one sentence** | What the room repeats afterwards. If you cannot write it, there is no deck yet |

If the user brought a topic and no facts, **say so and stop.** A deck of `[placeholder]` bullets
is worse than no deck: it looks like progress and cannot be presented. Ask for the numbers, the
before/after, or the decision being requested. This is the one step where refusing beats
producing.

## Step 1: Read the ground truth

```bash
bash "$FORGE/skills/deckcraft/scripts/deck-lint.sh" <deck.yaml>
```

Reports what `validate.mjs` structurally cannot: topic-label headings, promises of links that do
not exist, unlabelled comparison columns, missing alt text, and slides whose heading asserts a
number the slide never shows. Run it on an existing deck before critiquing it, and on your own
output before handing it over.

Then read the project's `CLAUDE.md` for the schema and the density table. **Do not restate those
limits here or re-derive them.** They are enforced; your job starts where they stop.

## Step 2: Write the headings first

Write every heading before any bullet. The heading carries the argument; the body is evidence for
it. This inverts the usual order deliberately: bullets written first produce a heading that
summarises them, which is how topic labels get made.

**The test:** a heading is an assertion if you could disagree with it.

| Topic label | Assertion |
|---|---|
| "Rollout" | "Nothing switches in week one" |
| "The Problem" | "Polling costs 200k requests a day" |
| "Spend against plan" | "Compute came in 20% under, storage 10% over" |
| "What you get" | "Subscribe in one line, replay a week" |
| "Timeline" | "A 14:02 deploy was not rolled back until 14:26" |

Three rules that follow:

- **The claim usually already exists one field lower.** In nine of twelve real decks the assertion
  was sitting in `subtitle:`, `caption:`, `action:` or `note:`, rendered smaller than the label
  above it. Promote it. This is a rewrite, not new writing.
- **Never invent a number to make a heading sharper.** If the slide does not contain the fact,
  the heading cannot claim it. `deck-lint.sh` flags a heading whose numeral appears nowhere in
  its own slide.
- **Dividers and the CTA are headings too.** They are the most-skipped and the most-read. A
  `divider` reading "The Solution" wastes the one slide everyone looks up for.

Exception, and it is real: a **calendar or curriculum spine** ("Day One", "Days Two to Four")
should stay a label. The reader needs a position, not a claim.

## Step 3: Order for the room

The order is not a house style. It is a function of who is deciding.

| Audience | Order | Cut first |
|---|---|---|
| **Executive / approval** | **Answer first.** Recommendation on slide 2, evidence behind it, ask restated at the end | Method, alternatives you rejected early, anything requiring a mental model |
| **Engineering / peer review** | Problem, cost of the status quo, design, **failure modes**, rollout | Business framing, org context, anything they can read in the RFC |
| **Customer / QBR** | What they got, measured against what was promised, then what is next | Your roadmap for its own sake, internal architecture |
| **Conference / teaching** | Hook, tension, **resolution held to the end**, one thing to take home | Everything not serving the single takeaway |
| **Mixed / all-hands** | Numbers with baselines, what shipped and what slipped, who to ask | Acronyms, and any ask most of the room cannot act on |

Two of these actively conflict, and that is the point. A conference talk holds its resolution;
an executive deck that holds its recommendation until slide 9 has failed. When someone hands you
"problem → solution → proof → ask" for a board, **that ordering is wrong for that room.**

**Room and export detail** lives in `reference/rooms-and-exports.md`: minimum legible sizes by
viewing distance, dark-versus-light by room, and exactly what each export path drops. Read it
when the deck has to survive a named room, or when someone will be handed the file rather than
shown it.

**Length:** budget at least one minute per slide, and count only the main deck. Twenty-five slides
in a twenty-minute slot is forty-eight seconds each, which is a reading exercise. Move the
overflow behind `type: appendix`, where the density rules stop applying and the page count resets.

## Step 4: Pick the type by the question it answers

The audit can only coach a deck whose types carry intent. Choosing `bullets` for everything
throws that away.

| The question the slide answers | Type |
|---|---|
| Which option should we take? | `matrix`: criteria down, options across |
| What are the numbers? | `table` for reading across, `stats` for three that carry the argument |
| Where are we in a sequence? | `timeline` |
| What is the state of our commitments? | `checklist`: done, doing, blocked |
| What does it look like, and what should I notice? | `media`: the image with 2 to 5 lines beside it |
| Two pictures that only mean something together | `compare` |
| Two or three parallel ideas that are not a sequence | `grid` |
| Who are these people? | `people` |
| A principle worth pausing on | `quote` |

**Tables are the reliability floor.** They fill their width, never clip horizontally, and survive
every export path intact. When a layout is fighting you, a table is the answer that always works.

**Do not reach for a diagram.** The tool has no diagram type, and that is a decision, not a gap:
Mermaid renders blank in the engines that tried it, Marp has no built-in support, PPTX would need
a raster and lose editable text, and its parser breaks on accented characters, which matters
directly for Spanish decks. Use `table`, or an SVG through `image`.

## Step 5: Write the notes, and know they may not travel

`note:` is where the sentence you actually say lives. Shape it as **a delivery cue, then the
talking points**:

```yaml
note: "[Slow down here.] The 31% is against plan, not against last quarter. If someone asks
       about storage, it is the one line that went over."
```

**The trap, and you must tell the user about it:** speaker notes reach the in-app presenter and
nothing else. They are dropped by the PPTX export, by Marp, and by the standalone HTML, and the
Reveal export writes them into markup that has no plugin registered to open them. Anyone
presenting from an exported file has no notes. Until that is fixed, put anything you cannot
afford to lose on the slide or in the appendix.

## Step 6: Check what the audit cannot

Run `deck-lint.sh` again, then read the deck the way an audience meets it:

1. **Read only the headings, in order.** Do they make an argument? This is the whole test.
2. **Does anything promise what the deck does not contain?** "The link is on the last slide"
   with no URL anywhere is a real defect that shipped in a curated example.
3. **Does any slide contradict itself?** "None" and "Need help with: [blocker]" as two bullets
   on one slide is a real defect that shipped too.
4. **Does the ask name a person and a date?** "Approve the rebuild" names neither. Nine of nine
   real decks failed this.
5. **Does every image caption match the image?** Alt text is never validated, so a caption can
   describe a picture that is not there.
6. **Open it in the player and click through.** The audit checks density, not geometry: content
   past the slide box is clipped silently, with no warning anywhere.
7. **Hand the deck over as a link, not only a file.** Base64url-encode the YAML (UTF-8 bytes,
   `+`→`-`, `/`→`_`, no padding) and give
   `https://slides.neorgon.com/?via=agent#d=<payload>`: opening it loads the deck in the
   player, nothing is uploaded anywhere. Over ~8 KB of payload, host the YAML instead and give
   `https://slides.neorgon.com/?src=<https url>&via=agent`. The `via=agent` marker stays in
   the query string (never inside `#d=`); it is counted, not displayed. Full contract:
   https://slides.neorgon.com/llms.txt

## Judgment: what to cut when it will not fit

In order. Stop as soon as it fits.

1. **The agenda**, if the deck has fewer than three sections. Announcing two sections costs a
   slide and tells nobody anything.
2. **Any slide whose heading you could not turn into an assertion.** If there is no claim, there
   was no slide.
3. **The second gradient.** Backgrounds stop reading as emphasis after the first one, and every
   preset is dark, so on a light theme they make text unreadable.
4. **Detail into the appendix**, not into the bin. Backup slides are allowed to be dense; that is
   what the marker is for.
5. **A pause you cannot justify.** A `qa` slide the presenter will walk straight past teaches the
   room that pauses are decorative.

Never cut: the ask, the baseline on a number, or the one slide that states the disagreement.

## Judgment: honest signals a deck is not ready

- Every bullet is a full sentence. The presenter is reading, and the room is reading ahead.
- A number appears with no baseline. "31% lower" than what?
- Two decks share a number and only one says what it measures.
- The deck ends on a summary. A summary is the audience's job; the last slide is the ask.
- No slide states a trade-off. A deck with no cost is a brochure, and the room knows it.

## Invariants

- **Write the headings before the bullets, and make every one a claim someone could dispute.**
- **Never invent a fact to sharpen a heading.** If the slide does not show it, the heading cannot
  say it.
- **Order by audience, not by habit.** An approval deck leads with the answer; a talk holds it.
- **Refuse to build a deck out of placeholders.** Ask for the facts instead.
- **Tell the user that exported speaker notes are lost**, every time notes matter to them.
