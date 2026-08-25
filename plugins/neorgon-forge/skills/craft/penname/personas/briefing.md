# briefing: technical work for people who decide, not build

The register for managers, executives, and non-technical stakeholders. The reader will
spend ninety seconds, decides something at the end, and must never feel quizzed on
vocabulary. The voice is still the author's, plain, honest about costs, no hype, with
the humor dial near zero and the jargon dial at zero.

**Use for:** status updates, proposals, incident summaries for leadership, "what does
this mean for us" documents, budget or headcount asks.
**Not for:** anything a peer engineer will act on technically (`fieldnote`), documents
meant to entertain (`ironic`).

## Register knobs

| Knob | Setting |
|---|---|
| Person | First plural for the team ("we shipped"), second for the ask ("you decide") |
| Contractions | Yes: plain is not stiff |
| Sentence length | ≤ ~22 words average; one idea per sentence |
| Humor | Optional, dry, at most one aside; never in the ask or the numbers |
| Jargon | None without an immediate plain-word gloss; prefer the plain word alone |
| Numbers | Always with context: "40% fewer support tickets" not "significantly reduced" |
| Code | Never, unless explicitly requested |

## The reader's question ladder

Answer these, in this order, in the first three paragraphs. The reader stops when
their question is answered, so put theirs first, not yours:

1. **What happened?** One sentence, outcome not activity ("customers can now X", not
   "we refactored the Y service").
2. **Does it affect me?** Who is impacted, in their terms: customers, revenue, risk,
   timeline.
3. **What do you need from me?** The decision or resource, stated once, plainly, with
   a date. If nothing is needed, say "no action needed". An update without an ask
   should say so.

Detail, history, and method go *below* the ask, for readers who keep going.

## Sentence mechanics

- Lead every section with its conclusion; evidence follows.
- Translate scale into felt terms: "every user who logs in on a Monday" beats "~14% of
  weekly sessions".
- Name cost, time, and risk explicitly, even when unflattering. Trust in the numbers is
  this register's entire value; one inflated figure spends all of it.
- Never anthropomorphize systems here ("the service decided…" reads as evasion of
  responsibility to this audience).
- One everyday-domain analogy maximum, and only if it shortens the explanation.

## Vocabulary

**Prefer:** cost, saves, risk, delay, works, broke, needs, decision, by <date>.
**Avoid:** synergy, streamline, leverage, utilize, robust, scalable (as praise),
"aligned", "circle back", "low-hanging fruit", unexplained acronyms, hedging stacks
("might potentially").

## Calibration

Base fact: *a deploy script silently failed for a week because a token had expired.*

**In persona:**
> Our release system stopped delivering updates for the past week, and its own status
> reports hid the failure. No customer data was affected; the cost was seven days of
> shipped fixes not reaching users. It is fixed as of Tuesday, and we added a check
> that alerts us within an hour if it happens again. No action needed from you; this is
> an FYI for the ops review.

**Over-cooked (do not do this):**
> Due to an expired OAuth token, the CD pipeline's exit codes were swallowed by the CI
> wrapper, potentially leading to suboptimal deployment cadence. We will leverage
> improved observability going forward.

The first tells the reader what it cost and whether they must act. The second quizzes
them on vocabulary and hides the week.

## Lint

```lint
ban /—/ em dash: use a period or comma
ban /\b[Ss]ynerg(y|ies|istic)\b/ buzzword: name the actual benefit
ban /\b[Ss]treamlin(e|ed|es|ing)\b/ buzzword: say what got faster or cheaper
ban /\b[Ll]everag(e|es|ed|ing)\b/ say use
ban /\b[Uu]tiliz(e|es|ed|ing)\b/ say use
ban /\b[Rr]obust\b/ praise-jargon: state the failure it survives instead
ban /\b[Cc]ircle back\b/ say when you will follow up
ban /low.hanging fruit/ name the actual item and its cost
ban /\b(might potentially|could possibly|potentially may)\b/ hedging stack: pick one qualifier or state it plainly
ban /[Ii]t's important to note/ if it matters, say it; if not, cut it
cap 1 /[[:alpha:]]!/ exclamation budget: one, if any
```
