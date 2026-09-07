# quiz-set

Material turned into a small game round that explains itself when you get it
wrong.

## What it does

`quiz-set` picks the game the material can actually explain, writes one
`neo-quiz-set/1` document, validates it with the Quiz engine's own validator, and
hands back the iframe snippet plus the Runcible exercise spec.

The defining constraint is that an item's id is a foreign key. `quiz:answer`
carries it as `itemId`, and a host stores that string as the evidence a chapter
goal is gated on, so an id derived from a row number is a set that will one day
be rebuilt in a different order, validate perfectly, play identically, and throw
away every attempt anybody ever made on it. Ids come from the material or the
build refuses to run, and the validator will read the previous version and prove
that no id vanished or changed hands.

## When to reach for it

Type `/quiz-set`, or the agent reaches for it when asked to turn a list, a table
or a set of lines into a game for quiz.neorgon.com.

| The ask | The skill |
|---|---|
| Drill it in short rounds, with a reason shown on a miss | `quiz-set` |
| Schedule it over weeks with spaced repetition | [`rappel-deck`](rappel-deck.md) |
| Grade it once, as a test | [`quizmaster`](quizmaster.md) |
| Build the chapters and goals the round sits inside | [`runcible-book`](runcible-book.md) |

One case sends it away before it starts: material already inside a corpus that
has a generator. Runcible's Japanese sets are derived from its own data by a
build step, and adding one there is a row in a selection file, not a second
hand-written document that will drift from the first.

## The round owes a reason

Four games ship, and the choice between them is not a matter of taste. Each one
owes the learner an explanation after a wrong answer, and the explanation is
built from the material itself: beats cuts the written form into tiles and names
the rule, sound draws the symbol's own row out of the set's siblings, pairs shows
the two sides together, order marks the first misplaced piece in the correct
line. A game whose `why` the material cannot fill is the wrong game for it.

The same idea running the other way is what keeps a round honest: the prompt
never contains the answer. The reading, the romaji, the gloss and the translation
are all feedback, held back until the answer is in. That is the half a round is
for, and putting any of it on the prompt turns the question into a free point.

## It's working if

- Rebuilding the set after editing the list keeps every item id, and the
  validator says so by name.
- The set comes back with the iframe snippet, and with the `data[]` line when it
  is going into a Book.
- Every wrong answer has something to show: an explain line, a row, a note, a
  gloss.
- A `CC-BY` source arrives with its wording quoted rather than paraphrased, and
  it renders under the round.
- The validator names the file it checked against, so it is clear the engine's
  own rules were the ones applied.
