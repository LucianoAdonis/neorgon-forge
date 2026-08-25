# repitch

That did not land. Say it again, differently.

## What it does

`repitch` makes the agent re-explain its last answer: the missing context first, then the point
again in plain language, using the project's own vocabulary.

The defining constraint is the diagnosis it starts from. It assumes the gap was **missing
context**, not missing intelligence, so it leads with the one or two facts the agent was
standing on that you were not, rather than restating the same thing more slowly.

## When to reach for it

You type `/repitch`; the agent cannot reach for it on its own, and should not. An agent that
decides its own last message did not land is guessing at your comprehension.

Reach for it mid-conversation, inside any other skill, the moment an answer slid past you. It
is cheap. Reaching for it early is better than reading the same paragraph four times.

## What a re-pitch is not

It is not the same explanation with softer wording. A re-pitch that repeats the original has
not diagnosed anything, and the skill says so: where it cannot find another angle it names the
part it thinks is the sticking point and asks, rather than paraphrasing.

It also leads with the conclusion and then the reasoning, because the first version almost
always did the reverse.

## It's working if

- The second version is shorter than the first.
- It opens with a fact, not an apology.
- It uses a word you already know in place of one you did not.
- It sometimes comes back with a question instead of an explanation.
