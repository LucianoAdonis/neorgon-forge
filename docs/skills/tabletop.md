# tabletop

A tabletop game built as software, without letting the printed deck and the running engine disagree.

## What it does

`tabletop` covers the whole loop of a game that is both a thing you print and a thing that
runs: the rulebook, the component data, the engine that reads it, the simulator that measures
it, and the sheet that prints it.

The defining constraint is that the components live in exactly one file and every count
anywhere else is derived from it. A card total retyped into a rulebook, a README and a print
button is three numbers that will disagree, and in practice they do: the same component table
in this fleet has been wrong three separate times, twice missing the same row, while claiming
in its own prose to be machine-checked.

## When to reach for it

Type `/tabletop`, or the agent reaches for it when a task is about a game's rules,
components or balance.

Reach for it when the game has a printed artifact and a running one, and a change has to
land in both. For the visual design of a card face on its own, use `impeccable`, which lives outside
this plugin;
for the rulebook's prose once the rules are settled, use [penname](penname.md) or
[voicecheck](voicecheck.md). A pure screen loop with nothing to print is not this skill.

## The order is the skill

Rulebook, then data, then engine, then screen. Every inversion of that order has a bug
attached to it, and the skill names them.

Writing the engine first produces rulings the prose never makes, and they accumulate
silently: one engine header in this fleet listed eleven, including which cards break first
under the game's endgame mechanic, which decides whether a player lives.

Adding a card to the data first produces a component the code cannot see. One shipped as a
no-cost attack dealing up to 75 damage because its behaviour flag meant nothing to the
engine, and the whole suite stayed green, because no test asserted that a card with no
damage deals none.

## Measure the property, not the win rate

A balance claim without a trial count is an opinion. But the number to protect is rarely a
win rate: it is a property, like *the careful line beats the reckless line at every level*.
A change that lifts everybody's win rate and inverts that has made the game worse, and the
delta alone will not tell you.

The skill carries the harness shape, the sample sizes past which you are buying decimal
places nobody acts on, and the questions no simulator answers: whether a turn takes six
minutes of arithmetic, whether anyone reaches for the interesting card, whether losing
feels survivable enough for a second session.

## It's working if

- Every count in every document is derived or checked, and the check has been watched to fail.
- A new component reaches the hand, the sheet and the simulator without anybody editing a list.
- Balance changes arrive as a table of variants at one trial count, with the baseline beside them.
- The printed sheet is looked at, as a PDF, before anyone believes it.
- The rulebook says what the engine does, and the list of rulings only the code makes gets shorter.
