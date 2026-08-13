# Deriving a persona from a corpus

How the shipped personas were built, and the method for adding one. A persona derived
from adjectives ("casual, witty, direct") reproduces nobody; a persona derived from a
corpus reproduces its author. The difference is that a corpus forces you to separate
what the author *always does* from what they *sometimes do*, and to put a number on
"sometimes".

## The method

1. **Sample across registers, finals only.** Pick 4–6 finished, published pieces —
   drafts teach the wrong lessons. Deliberately include different content types (a
   tutorial, an opinion piece, a troubleshooting story): what survives across all of
   them is identity; what appears in only one is register.

2. **Collect markers, not impressions.** For each piece, write down the mechanical
   facts: how it opens (first 3 sentences), how sections transition, how it closes,
   sentence-length rhythm, punctuation habits (em dashes? ellipses? exclamations per
   1000 words?), how humor is *constructed* (contrast? wordplay? references?), what the
   author does with uncertainty and failure, recurring sentence shapes ("Why?
   Security.").

3. **Split identity from saturation.** Identity: the mechanics present everywhere
   (directness, contrast humor, honest costs, no em dashes). Saturation: the tokens
   whose *frequency* varies ("lol", elongated vowels, pop-culture references). Identity
   becomes prose rules; saturation becomes **budgets with numbers**. This split is the
   whole fix for drift: imitations fail by treating saturation tokens as identity and
   stacking them.

4. **Write the lint block from observed drift.** Every `ban` should name a failure you
   have actually seen (an AI-tell the author never uses, a formalization that killed
   the voice); every `cap` puts a number on "sparingly". A rule that could never fire
   on a plausible draft is decoration — delete it.

5. **Calibrate with a pair.** Render the *same base fact* twice: once in persona, once
   over-cooked. The over-cooked example is the more valuable half; it shows the
   failure mode the budgets exist to prevent. Without it, the next session reads the
   keep-list and saturates.

6. **Trip the lint.** Run `persona-lint.sh` against the over-cooked example (put it in
   a scratch file — the persona file's own examples are not linted). If the lint block
   passes the bad example, the rules are decoration; fix them before shipping the
   persona.

## Persona file shape

Every persona file carries, in order: identity line + use/not-for · register knobs
table · sentence mechanics · vocabulary (prefer/avoid) · structure defaults ·
calibration pair · ```lint block. Keep the whole file loadable in one read; a persona
that needs its own reference directory is two personas.

## Provenance of the shipped personas

`ironic` was derived in 2026-08 from the author's published Medium finals (19 posts
across technical tutorials, troubleshooting stories, hobby tier-lists, and AI
experiment logs), then **toned down**: the full-strength corpus voice allows elongated
vowels, more internet-speak, and NSFW-adjacent asides that the portable persona bans.
Inside the author's own writing repos, a local `VOICE.md` documents full strength and
outranks the persona's vocabulary rules. `briefing`, `fieldnote`, and `tutorial` keep
that corpus's identity layer (directness, honest costs, plain verbs, no em dashes) and
swap the register layer for their audiences.
