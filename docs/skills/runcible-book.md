# runcible-book

A subject turned into a Book the Runcible shell can load.

## What it does

`runcible-book` plans a ladder of chapters, writes the manifest and one chapter
file each, and validates the result with the site's own validator.

The defining constraint is that the shell must stay ignorant of the subject.
Adding a Book is one entry in the catalog plus a directory, and no file under
`js/` changes. Everything the skill does follows from that: the drills come from
the nine generic exercise types rather than from code the Book ships, the
corpora are declared as pointers rather than embedded, and a subject that seems
to need a shell change is reported as a finding instead of quietly getting one.

## When to reach for it

Type `/runcible-book`, or the agent reaches for it when asked to add a subject,
a syllabus or a set of chapters to Runcible.

Reach for it when the subject exists and the Book does not. For the flashcard
deck a chapter embeds, use [`rappel-deck`](rappel-deck.md), which is a different
format with a different validator.

## The ladder is the design

A Book is a sequence where each chapter is the prerequisite of the next, and
that sequence carries the whole teaching decision. Pages are filling; the ladder
is the argument.

Two things hold it up. A **goal** stated as something the learner can be seen to
do, never as a topic: "name any interval by ear", not "intervals". And
**evidence**, the accuracy and the count over a window of attempts that decides
when the chapter is passed. A goal with no evidence cannot gate the chapter
after it, and evidence naming a skill no exercise in the Book produces is a gate
nobody can ever open. That second one looks perfect on screen, which is why the
validator treats it as an error rather than a note.

Where good teachers disagree about ordering, the disagreement becomes a track
the reader picks rather than an order the Book imposes, and every locked chapter
keeps a manual override. A gate a self taught adult cannot open is a wall.

## It's working if

- Adding the Book touched the catalog and one directory, and nothing else.
- Every chapter goal is a sentence you could verify by watching someone.
- The validator exits 0, and it says which file it checked against.
- A chapter that is not built shows up as a planned entry with a note, rather
  than as a gap you have to notice.
- Any corpus the Book needs is named as a file a human must produce, with its
  licence, instead of being written from memory.
