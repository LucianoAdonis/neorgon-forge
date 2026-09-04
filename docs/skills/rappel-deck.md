# rappel-deck

A word list turned into a spaced repetition deck someone can actually study.

## What it does

`rappel-deck` reads a list, decides which templates the material earns, writes
one `neo-deck/1` document, and validates it with the Rappel engine's own
validator.

The defining constraint is that a card is `noteId + ":" + templateId`, and that
string is the foreign key of the review ledger. Everything else follows from it.
Note ids are assigned once and never reassigned, extending a deck keeps every id
that already exists, and the validator will read the previous version of the
deck and prove no id vanished or changed hands. A deck rebuilt with renumbered
notes validates perfectly, looks identical on screen, and silently sets every
card in it back to new.

## When to reach for it

Type `/rappel-deck`, or the agent reaches for it when asked to turn terms,
vocabulary or a glossary into flashcards.

Reach for it when the material exists and the deck does not. For a graded test
rather than a study aid, use [`quizmaster`](quizmaster.md). For the chapters and
goals a deck sits inside, use [`runcible-book`](runcible-book.md).

## Templates are the cost, not the feature

A deck's size is not its note count. Three templates over fifty notes is a
hundred and fifty cards, which is about a month of daily reviews out of one
paste, and the person studying pays that bill.

So each template is added because the skill is genuinely different. Recognition
is seeing an item and knowing what it is. Recall is producing it, which is a
harder and separate thing. A multiple choice template is worth adding only where
the deck has enough same tag siblings to make a wrong option tempting, because
a distractor drawn at random from the whole deck is not a discriminator, and an
option nobody would pick is a free point.

The other standing decision is the licence. Material that is not the user's own
carries the exact wording its source requires on screen, quoted rather than
paraphrased, and the validator refuses a `CC-BY` deck that lacks it.

## It's working if

- Rebuilding the deck after editing the list keeps every note id, and the
  validator says so by name.
- The deck comes back with the iframe snippet and the reason that delivery was
  chosen over the other two.
- Each template can be justified in one sentence about the skill it drills.
- A `CC-BY` source arrives with its attribution sentence quoted, and it renders.
- The validator names the file it checked against, so it is clear that the
  engine's rules were the ones applied.
