# atlas

Documentation and diagrams generated from a real dependency model, so they can be asked
questions and can go stale loudly.

## What it does

`atlas` extracts a dependency model from a project's JavaScript, Python, HTML and CSS, then
generates the Mermaid diagrams and MkDocs pages **from that model** rather than beside it. It
answers questions against the model with `file:line` citations.

The defining constraint is that every claim is citable and therefore disprovable. A dependency
answer that cannot be traced to a line is a guess, and the diagram that cannot be regenerated
from the model is a picture of what was true once.

It also gets a static site's entry point right: for a page-based project that is `index.html`,
not whichever module looked most central.

## When to reach for it

Type `/atlas`, or the agent reaches for it when asked to document an app, diagram its
architecture, or work out what breaks if a file changes.

Reach for it when the question is about the app itself. For where one specific change goes, use
[wayfind](wayfind.md). For Mermaid syntax questions, this is not the tool.

## Generated means generated

Nothing under `docs/atlas/` is ever hand-edited: it is overwritten on the next build, so an
edit there is a fact that exists until someone reruns. `stale` asks git rather than the
filesystem, because a file touched but not changed has a new mtime and identical content, and a
staleness check that fires on nothing gets ignored within a week.

Where `.forge/context.md` exists, it also reports where the code's names and the project's own
language have drifted apart, and reports it rather than fixing it. Renaming a module to match a
glossary is a code change, which is [task](task.md)'s job.

## It's working if

- An answer arrives with a `file:line` you can open and check.
- `stale` reports nothing after a run with no source changes, and reports something after one
  with changes.
- A diagram changes when the code changes, without anyone editing the diagram.
