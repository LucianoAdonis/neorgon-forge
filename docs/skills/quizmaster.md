# quizmaster

Source material turned into a validated exam.

## What it does

`quizmaster` builds a coverage map of the source, writes questions against it, and validates the
result into Proctor-format JSON.

The defining constraint is the order: **coverage map before questions**. An exam written
straight from the source tests what was memorable to whoever wrote it, which correlates with
what was vivid rather than with what matters.

## When to reach for it

Type `/quizmaster`, or the agent reaches for it when asked to turn material into a quiz, an
exam, or a set of practice questions.

Reach for it when the material exists and the exam does not. It is a producer, not a tutor.

## Distractors are the craft

A wrong option that nobody would pick is a free point, and an exam of free points measures
nothing. Distractors are believable mistakes: the thing a learner who half-understands would
actually choose.

Every question carries a category and an explanation. No diagnostic value and no teaching value
means no question. Answers are verified against the source rather than against recollection,
because a wrong answer key is worse than no exam: it teaches the error with authority.

## It's working if

- The validator runs before delivery, and exit 2 is treated as a failure.
- You get a question wrong and the explanation tells you why your answer was tempting.
- The coverage map shows a section of the source with no questions, and that is a decision
  rather than an oversight.
