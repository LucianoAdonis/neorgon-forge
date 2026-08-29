# penname

Prose that sounds like the author rather than like a model, in English or Spanish.

## What it does

`penname` picks one persona from `personas/` (ironic, medium-es, briefing, fieldnote, tutorial),
loads its **checkable register rules** plus any accumulated feedback ledger, drafts
content-first, then lints the result against the persona's ban and cap lists.

The defining constraint is that the register rules are checkable rather than adjectival. "Warm
but professional" cannot be verified by anyone; a cap on sentence length, a banned phrase list,
and a required ratio can. That is what makes the lint mean something.

## When to reach for it

Type `/penname`, or the agent reaches for it when you ask for something written in your style,
drafted for your manager, or produced in Spanish.

Reach for it for blog and Medium posts, README prose, announcements, exec updates, tutorials,
and long-form docs: documents a person signs. For auditing copy that already exists, use
[voicecheck](voicecheck.md). For UI microcopy, neither.

## The ledger outranks the persona

Corrections the author actually accepted accumulate in `feedback/`, and they win over the
persona file. A persona is a model of how someone writes; the ledger is evidence of it. When
they disagree, the evidence is right.

Content pass comes before register pass, always. A voice-first draft hides content holes behind
fluent sentences, and the fluency makes them harder to spot, not easier.

## It's working if

- The lint exits non-zero on a draft you thought was fine.
- One persona per document, named before the first sentence.
- The rewrite changes how a sentence reads and never what it claims.
- A correction you made last month shows up applied without you asking.
