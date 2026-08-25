# deckcraft

The deck that did not come from a diff: written from an idea, or already written and saying
nothing.

## What it does

`deckcraft` writes, repairs, and critiques slide decks. It rewrites headings, orders the
argument for the room, chooses slide types, drafts speaker notes, and lints the result.

The defining constraint is the bar it holds every heading to: **a claim someone could dispute**.
A heading that names a topic ("Performance", "Next steps") cannot be disagreed with, and
therefore cannot carry an argument. That is the failure the density audit cannot see, and it is
why a deck can pass every check and still say nothing.

## When to reach for it

Type `/deckcraft`, or the agent reaches for it when you ask to write a deck about an idea, or
say an existing deck is boring or unfocused.

Reach for it when the deck comes from a topic rather than from work that happened. When it
should report what actually changed in the code, [debrief](debrief.md) reads the diff and the
brief instead.

## Headings before bullets

The order is the method. Writing the bullets first produces headings that summarise them, which
is how you end up with fourteen topic labels. Writing the claims first tells you which slides
have no evidence behind them, and those are the slides to cut.

It will not build a deck out of placeholders. Where the facts are missing it asks, because a
heading invented to sound sharp is a claim the slide cannot support and the room will test it.

## It's working if

- You can disagree with every heading, in principle.
- The order changes when you change the audience: an approval deck leads with the answer, a
  talk holds it.
- It refuses to proceed on placeholder facts.
- It warns you that exported speaker notes are lost, before you find out.
