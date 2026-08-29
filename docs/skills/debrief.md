# debrief

Finished work turned into a deck, built from the diff and the brief rather than from memory.

## What it does

`debrief` reads the actual git diff and `.forge/brief.md`, then produces a deck in whichever
format the project supports (slides YAML, Marp, or plain Markdown) and **builds the PDF**.

The defining constraint is where the facts come from. A deck written from recollection is a
flattering summary of what happened; one written from the diff and a brief kept during the work
is a report. Only measured numbers reach a slide, because an estimate presented as a
measurement is the one error an audience catches and never forgets.

## When to reach for it

Type `/debrief`, or the agent reaches for it when you ask for slides, a readout, or a
presentation of what changed. It is also worth offering unprompted after a large multi-file
change lands.

Reach for it for a demo, a standup, a sprint review, a stakeholder update, a retro, or a plain
overview of what a project is. For a post instead of a deck, use [writeup](writeup.md); the two
are usually wanted together. For a deck that did not come from a diff, use
[deckcraft](deckcraft.md).

## It ends in an artifact

A debrief that ends in instructions for producing a PDF has not finished. The output is a file
someone can open.

Two structural rules that decide whether the deck reads: group by theme rather than by file,
because nobody cares which files changed, and one idea per slide. The open-items slide is not
optional, and it is the slide that earns trust for all the others.

## It's working if

- Every number on a slide can be traced to something that was run.
- The slides are grouped by what changed conceptually, not by directory.
- There is a slide naming what is still broken.
- You get a PDF, not a build command.
