# writeup

Finished work turned into a published post, with diagrams that cannot silently go stale.

## What it does

`writeup` finds the argument in the code, drafts it in the author's voice, generates SVG
diagrams that **import the project's own model**, rasterizes them for platforms that reject
SVG, runs an AI-writing detox that leaves the voice intact, and optionally produces a neutral
Spanish version.

The defining constraint is that diagram generators import rather than restate. A hardcoded
number in a generator is a second source of truth that goes stale the first time the model
changes, and nothing reports it.

## When to reach for it

Type `/writeup`, or the agent reaches for it when you ask to write something up, publish a
post, or produce an article with diagrams.

Reach for it for a Medium post, a blog post, an announcement, or a launch post. For README or
docs prose, this is ordinary writing. For a deck, use [debrief](debrief.md); asking for docs
about finished work without naming a format usually means you want both.

## The detox is not a style pass

The author's voice is not an AI pattern. The detox removes machine tells: throat-clearing,
empty hedges, "not just X but Y", triads of near-synonyms, em-dash pileups. It leaves slang,
first-person asides, deliberate fragments, and the one or two hedges that read as a person
thinking.

Guessing wrong toward "remove it" produces prose that passes every checker and sounds like
nobody, which is the failure mode worth being afraid of.

## It's working if

- A number in the post can be produced by calling a function you can point at.
- Rebuilding after a model change updates the diagrams without anyone editing an SVG.
- Your own turns of phrase survive the detox.
- Asked to make it shorter, it names the section it would cut rather than quietly shipping
  something 10% shorter.
