# Question patterns — the craft the validator cannot check

The validator proves the exam loads and grades. Whether it *teaches* is decided
here. These patterns come from building and drilling real certification banks: the
useful question has a tell in the stem, one winning option shape, and distractors
drawn from genuine misconceptions.

## Stem patterns that work

| Pattern | Shape | Tests |
|---|---|---|
| Discriminator | "Which flag makes X happen?" | One fact, cleanly |
| Boundary | "Up to what size / how many / until when does X hold?" | Limits — where real mistakes live |
| Misconception check | truefalse on the thing everyone gets wrong | The specific wrong belief |
| Applied judgment | A one-paragraph scenario, then "what do you do first?" | Transfer, not recall |
| Output prediction | A fenced code/config block, "what does this print/do?" | Reading comprehension of the artifact |
| Cold recall | fill: "the command that does X is ___" | Names that must be known without a lookup |

## Distractor shapes

A distractor earns its place by being the answer of someone who *almost*
understands. The reliable sources:

- **The adjacent concept** — the sibling flag, the similar-sounding term, the other
  mode. (For "what does `**` do in Python": `^` — the operator from another
  language.)
- **The right answer to a different question** — true in general, wrong for this
  stem's specific condition.
- **The stale answer** — what used to be true in an older version, when the source
  material itself flags a change.
- **The plausible magnitude** — for boundary questions, the neighboring order of
  magnitude, not a random number.

Never: joke options, options of visibly different length or grammar than the key
(test-wise students pick the longest, most-qualified option), "all of the above".

## Explanations that teach

The explanation is study mode's entire value. It must name the discriminator and
kill the strongest distractor: "B — `--ack-mode explicit` is what persists the
cursor; `--sync` (A) only flushes the buffer, which is why events still vanished
after a crash." One sentence for why the key is right, one for why the best wrong
answer is wrong. A bare "see section 4" wastes the miss.

## Weighting and ensure

- Weight categories by *cost of ignorance*, not by page count — the topic that
  breaks production outweighs the topic with the most paragraphs.
- `ensure: true` marks the questions a random draw must never skip: safety rules,
  irreversible operations, the one command everyone must know cold. If more than a
  third of the exam is `ensure`, the exam is too small.
- `points` above 1 is for questions whose miss should fail the exam on its own —
  use rarely, and say so in the stem ("worth 3 points").
