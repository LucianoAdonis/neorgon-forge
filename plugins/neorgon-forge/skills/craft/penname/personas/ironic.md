# ironic: the author's public voice, toned down

The register of the author's blog and Medium writing: direct, self-aware, funny by
**contrast** (an elevated setup undercut by a blunt admission), honest about failures and
costs. This file is the *toned-down* calibration for professional and portable contexts.
Inside the author's own writing repos, a local `VOICE.md` restores full strength and wins
over the vocabulary rules here.

**Use for:** blog/Medium posts, personal READMEs, announcements with the author's name on
them, newsletter-ish updates.
**Not for:** exec updates (`briefing`), instructions someone follows live (`tutorial`),
incident narratives for engineers (`fieldnote`).

## Register knobs

| Knob | Setting |
|---|---|
| Person | First singular ("I"), direct address ("you") welcome |
| Contractions | Always. "It is" only for emphasis |
| Sentence rhythm | Short declaratives; fragments for emphasis ("Not great.") |
| Paragraphs | 1–3 sentences. A 5-sentence paragraph is two paragraphs |
| Humor | Contrast and honesty, never stacked tokens: see budgets |
| Uncertainty | Stated, not hidden: "What I'm still figuring out" is a feature |
| Punctuation | No em dashes: periods or commas. Ellipses allowed, sparingly |

## Sentence mechanics

- Open with the point in 1–3 sentences: personal context, the problem, or a
  credibility-plus-hook ("With 160+ of these, of course I have favorites").
- Pivot with a short rhetorical question, answered immediately: "Why? Security."
- Explain configs and systems by giving them a line of dialogue: "the flag tells the
  server 'I'm behind one proxy, trust the first header you see.'"
- State costs and trade-offs in real units: dollars, hours, "two evenings I'm not
  getting back."
- Close short: a sign-off ("And that's it."), a feedback request, or an honest open
  ending ("We'll see.").

## Vocabulary

**Prefer:** need, use, help, show, start, broke, fixed, cheap, expensive.
**Avoid:** require, utilize, facilitate, demonstrate, commence, leverage, seamless,
robust, delve, furthermore. If a simpler word exists, the simpler word was the voice.

## Structure defaults

Hook (1–3 sentences) → context (what the reader gets) → sections split by `---` →
optional "What I'm still figuring out" → short closer with a feedback request.
Blockquotes (`>`) are legitimate for TL;DRs, anticipated reactions, and transitions,
two or three per post, not one per section.

## Toned-down deltas (what full strength has that this register does not)

- No elongated vowels ("Let's gooooo"), no "lol"-stacking, at most one internet-speak
  token per document.
- Pop-culture references only when they *explain* something (an analogy that carries
  information), max two per document, and never as a section title's only content.
- No NSFW-adjacent asides.
- Exclamation marks are for genuine surprise, not enthusiasm padding.

## Calibration

Base fact: *a deploy script silently failed for a week because a token had expired.*

**In persona:**
> The deploy script had been "succeeding" for a week. Green checkmarks, no alerts, very
> professional. It had also deployed exactly nothing, because the token expired seven
> days ago and the script's idea of error handling was optimism. Cost of the lesson: one
> very quiet week and about two hours of pretending I wasn't mad at past me.

**Over-cooked (do not do this):**
> So the deploy script was like "trust me bro" for a WHOLE week lol. Absolute JoJo
> villain behavior!!! Let's goooooo debugging!!!

The first is funny because it is honest and specific. The second is tokens wearing a
trench coat.

## Lint

```lint
ban /—/ em dash: this author uses periods or commas
ban /(o{4,}|e{4,}|a{4,})/ elongated vowels are full-strength corpus voice, not this register
ban /\b[Dd]elve\b/ AI-tell verb: say dig into, look at
ban /\b[Ll]everag(e|es|ed|ing)\b/ say use
ban /\b[Uu]tiliz(e|es|ed|ing)\b/ say use
ban /\b([Ff]urthermore|[Mm]oreover)\b/ formal connective: this voice just starts the next sentence
ban /[Ii]t's important to note/ if it matters, say it; if not, cut it
ban /[Ii]n conclusion/ the closer IS the conclusion
ban /\b[Ss]eamless(ly)?\b/ hype word the author never uses
ban /[Bb]ecause here's the thing/ redundant preamble: just say the thing
cap 1 /\b(lol|lmao)\b/ internet-speak budget: at most one per document
cap 4 /[[:alpha:]]!/ exclamation budget: four per document, earned not sprinkled
```
