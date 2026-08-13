---
name: penname
description: "Use when writing prose that must sound like the author, not like a model — blog and Medium posts, README prose, announcements, exec and stakeholder updates, tutorials, long-form docs. Triggers on: 'write this in my style', 'draft a post about', 'make this sound like me', 'rewrite this for my manager', 'explain this for non-technical people', 'tone this down but keep it me'. Picks one persona from personas/ (ironic, briefing, fieldnote, tutorial), loads its checkable register rules, drafts content-first, then lints the result against the persona's ban/cap list. Not for auditing existing copy (voicecheck), not for slide decks (debrief), not for UI microcopy — only documents a person signs."
argument-hint: "[draft|rewrite|lint|personas] [target]"
user-invocable: true
license: MIT
---

# penname — write under a named persona

Drafts and rewrites prose under one of the author's personas, each defined as a set of
rules that can actually be checked. The failure mode it exists to prevent is **register
drift**: prose written one session at a time slides toward a generic model voice, or —
the opposite failure — imitates the author's tics so hard that every paragraph has a
joke, and ten documents later nothing sounds like the same person twice. A style guide
that says "be casual and witty" cannot catch either; a ban/cap list can.

## Step 1 — Pick the persona, out loud

One persona per document. Say which one and why in a single line before writing.

| Situation | Persona |
|---|---|
| Blog/Medium post, personal README, anything with the author's name and sense of humor on it | `ironic` |
| Update for a manager, exec, or non-technical stakeholder — they decide, they don't build | `briefing` |
| Engineer-to-engineer: incident narrative, "how I debugged this", technical writeup | `fieldnote` |
| Step-by-step instructions someone will follow with their hands on a keyboard | `tutorial` |

If two personas genuinely fit, ask one question about the audience — never blend. A
document that opens in `ironic` and closes in `briefing` reads as two authors, which is
the exact defect this skill exists to prevent.

## Step 2 — Load the persona file, wholly

Read `$FORGE/skills/penname/personas/<name>.md` top to bottom before writing a word.
Every persona file has the same shape: when to use it, register knobs, vocabulary,
structure defaults, calibration examples (the same base paragraph rendered correctly and
over-cooked), and a machine-readable lint block.

**Precedence:** a project's own `VOICE.md` outranks the persona's vocabulary rules where
they conflict — the persona still supplies structure and mechanics. This matters in the
author's own writing repos, where the local voice runs stronger than the portable,
toned-down persona.

## Step 3 — Content first, register second

Draft in two passes, in this order:

1. **Ugly draft.** Get the substance down — the steps, the argument, the numbers — with
   no attention to voice. Structure it with the persona's defaults (opener pattern,
   section flow, closer).
2. **Persona pass.** Rewrite sentence mechanics to the register: sentence length,
   contractions, the persona's transitions and asides, humor *where the content earns
   it*.

Never the reverse. A draft written voice-first optimizes for sounding right over being
right, and the register pass cannot fix a content hole.

## Step 4 — Lint before delivering

```bash
bash "$FORGE/skills/penname/scripts/persona-lint.sh" <doc.md> --persona <name>
```

Reports every `ban` violation as `file:line` and every blown `cap` budget with its
count. Exit 0 clean · 1 violations · 2 the run itself failed (missing persona or lint
block — never report that as clean). Fix what it finds, then deliver. If a violation is
genuinely intentional — a quoted phrase, a banned word used *as* the example — say so in
one line rather than silently shipping it.

Fenced code blocks are excluded from linting automatically; inline `code` spans are not,
so a flagged token inside backticks is the one case to overrule by hand.

## Identity vs. saturation — the judgment call

The author's voice is **contrast and honesty**, not tokens. What makes it recognizable:
an elevated setup undercut by a blunt admission; the failed attempt left in the
narrative; the cost stated in real currency; the aside in parentheses. What made past
imitations drift: treating the *tokens* — "lol", elongated vowels, a pop-culture
reference per section — as the voice and stacking them until the register collapsed.

- Tokens are seasoning with a budget. The caps in each persona's lint block are that
  budget, in numbers.
- A joke must carry information (an analogy that explains, an admission that calibrates
  trust). The same joke structure twice in one document counts as zero jokes.
- When in doubt, cut the flourish and keep the honesty. An under-seasoned document in
  this voice still sounds like the author; an over-seasoned one sounds like a parody.

## Adding a persona

Follow `reference/extraction.md` — derive it from a real corpus (markers, budgets, lint
rules, calibration pair), never from adjectives. A persona whose lint block has no rules
that could fire on a plausible draft is a preference, not a persona.

## Invariants

- **One persona per document, named before writing.** Blending registers is the defect,
  not a compromise.
- **The persona file is read wholly before drafting.** Writing from a remembered persona
  is how drift starts.
- **Content pass precedes register pass.** Voice-first drafts hide content holes.
- **Lint runs before delivery, and exit 2 is a failure, not a pass.**
- **Meaning survives the rewrite.** Register changes how a sentence reads, never what it
  claims — same contract as voicecheck.
