---
name: tabletop
description: "Use when a tabletop game also runs as software and the two halves must agree: a card game with a browser engine, a print-and-play, a boss rush, a facilitator's deck. Triggers on: 'add a card', 'balance this game', 'the game is too hard', 'make a print-and-play', 'simulate the game', 'is this card worth playing', 'add a mechanic', 'write the rulebook', 'the printed card came out blank'. Covers the build order (rulebook, data, engine, screen), the single-source rule that stops a printed component count drifting from the data, how to measure a balance claim instead of arguing it, and the breaks code review misses: a card the simulator cannot see, a rule the printer drops, an option strictly worse than a free one. Not for a purely physical game with no code (use board-game-design), not for a video-game loop with nothing printed, not for a card face's visual design alone (use impeccable)."
argument-hint: "[what you are adding or changing] [--balance] [--audit]"
user-invocable: true
license: MIT
---

# tabletop: the game is the data, the engine is a reading of it

A tabletop game that also runs in a browser is two products sharing one source. The
printed deck is the thing people own; the screen is a preview and a referee. Almost every
expensive bug in this fleet came from letting those two disagree, or from letting the
prose disagree with the data both of them read.

This skill is the order to build in, the invariants that keep the two halves honest, and
the failure modes that ordinary code review does not catch, because the tests can be
green while the printed card is blank.

Two games in this fleet are built this way and both are worth reading before you start:
`projects/enjeu-site` (a solo boss rush: `data/cards.json`, `js/game/engine.js`, a
simulator, a print sheet) and `projects/rush-q-cards-site` (a facilitation deck: 235
cards, `js/simulation/engine.js`, a balance page). Their shapes are the same because the
shape is forced by the problem, not chosen.

## Step 0: which half are you touching

| You are changing | Start at | Because |
|---|---|---|
| What a card DOES | the rulebook | the engine is a reading of the rules, not their home |
| How many of something there are | the data file | every count in every document is derived from it |
| Whether the game is fair | the simulator | a balance claim without a run log is a guess |
| What a card LOOKS like | the renderer | the printed artifact is the product |
| How it is explained | the rulebook, then the tutorial | two sources of prose drift, always |

If the answer is "several", do them in the order below and do not skip ahead. The order is
not ceremony: every time it was violated in this fleet it produced a specific bug, and
those are named in `reference/failure-modes.md`.

## Step 1: the rulebook first, always

**Write the rule in the rulebook before the engine implements it.** The rulebook is the
canonical statement; the engine is one reading of it. When the engine decides something
the rulebook does not say, that is a gap in the rulebook, not a feature of the code.

Keep a list, in the engine's own header, of every ruling the code makes that the prose
does not. Review it whenever you touch the rules. In `enjeu-site` that list ran to eleven
entries before anybody noticed the rulebook had been silent for months on which cards
break first under Rage, whether a Knight's free guard survives it, and whether damage past
a minion's last card spills to the boss. All three decide whether a player lives.

**The test of a rule is whether two readers play it the same way.** Not whether it is
technically unambiguous. Read it aloud.

## Step 2: one source for components, and derive every count

Put the components in one data file. Then **never retype a number that file already
knows**. Every count in the rulebook, the README, the site copy, the print button and the
tutorial is derived or checked, never remembered.

This is the single most reliable defect in a game project. In `enjeu-site` the component
table said 89 when the data said 90, then 93 under a stated 94, then 104 under a stated
105. Same table, three times, and twice the missing row was the same card. The rulebook
claimed in its own prose that the table was machine-checked. Nothing checked it until a
test did.

```
Write the check, then break the data on purpose and watch it fail.
A guard nobody has seen fail is not a guard.
```

## Step 3: the engine, with rolls from outside

**The engine never generates randomness.** A roll arrives as an argument, from a human's
die or from a seeded stream. This is what makes a fight reproducible, a test possible and
a simulator honest. An engine that rolls internally cannot be measured.

**Every new component must reach the engine by derivation, not by a list.** The most
repeated bug in this fleet: a hand, a deck or an attack set built from a hardcoded array
that someone forgets to extend. In `enjeu-site` a hardcoded trio silently left Bubble out
of every simulated hand when it was added; the comment recording that incident was sitting
directly above the code that then did the same thing to Run.

**Data before engine is the wrong order.** A card added to the data with a field nothing
reads does not sit inert: it falls through to the default path. Run shipped for an hour as
a one-action, no-bet attack dealing up to 75 damage, because `hides: true` meant nothing to
the code and the attack path did not care. All 124 tests passed. Nothing asserted that a
card with no damage deals none.

## Step 4: measure the balance, do not argue it

Name the property that must hold **before** you measure, and make it a property, not a
number. In `enjeu-site` the property is *the careful line beats the reckless line at every
level*, and it is worth more than any particular win rate.

The loop:

1. **Baseline first.** Measure the game as it is, and keep the output.
2. **Change one thing.** Build the variants as data where you can, so the harness runs them without an edit.
3. **Measure every variant at the same trial count**, and print them side by side.
4. **Check the property, not just the delta.** A change that raises the win rate and inverts the skill ordering has made the game worse.
5. **Record the numbers in the brief**, with the trial count and the seed.

`reference/balance.md` has the harness shape, the sample sizes that stop mattering, and
the three questions a simulator cannot answer.

**The bots must know about the new thing.** A strategy that never plays a card measures a
game nobody is playing. When Run was added, the simulator's attack list was hardcoded AND
no strategy had ever called `hide`, so the first measurement was blind twice over.

**A degenerate line must lose.** Find the most boring possible strategy (never bet, never
risk, wait) and confirm it fails. If it wins, the clock is missing.

## Step 5: the printed artifact is the product

The screen is a preview. Every rule below was learned by printing something wrong.

- **Nothing on a card face may depend on a filter, a blend mode or a CSS effect.** Chromium drops SVG filters when it rasterises for print. A gold crown recoloured by a filter printed black on a black card: invisible in every browser, blank on paper, and no test saw it because the markup was correct. Paint with plain fills.
- **Colour is never the only channel.** Every component that means something by its colour also means it by a shape, a count or a sigil. This is the colour-blind rule and it is also the photocopier rule.
- **Size in millimetres, not in zoom.** A card is 63 x 88 mm. Set that, and let the sheet paginate.
- **An overflow must print visibly wrong.** Never `overflow: hidden` a print cell: a silent crop is worse than an obvious one.
- **Count the ink.** A solid field is real money on a home printer. Offer a light-ink variant for anything large and dark, and say what it costs.
- **Print it before you believe it.** Headless PDF, then look at the pages.

## Step 6: the screen is a referee, and it has its own traps

- **Size from the container that owns the height, not from the window.** Two panels that both measure the viewport will fight, and the loser crops. In `enjeu-site` the fight board was handed 101px for content needing 133px, and painted the difference under an opaque panel where it could not even be clicked.
- **Never claim a keyboard shortcut unconditionally.** Enter belongs to whatever is focused.
- **A state the player cannot see is a rule they will not learn.** If the engine tracks it, draw it.
- **Do not draw slots a mode can never fill.** Five dimmed boxes promising mechanics the current mode does not have is worse than four fewer boxes.

## Step 7: the words

A rulebook is read aloud, usually by an adult to a child, usually once, usually while
someone is impatient to start. That is a harsher constraint than technical writing.

- **Define a term before you use it.** Check the distance from first use to definition; in `enjeu-site` one card was explained in terms of a mechanic 143 lines away, and a component was named 266 lines before its own section.
- **Read every rule out loud.** Buried verbs, stacked clauses and a subject that changes halfway are invisible on screen and obvious in the mouth.
- **Use the game's own verbs.** If nothing is ever discarded, do not write "discard".
- **No typesetting marks.** A section symbol means nothing to a child.
- **A translated rulebook must carry identical numbers.** Compare the two files' numeric multisets, locale-blind, as a check.

## Invariants

- **Rulebook, then data, then engine, then screen.** Escalate out loud when you find yourself going backwards.
- **No count is ever retyped.** Derived, or checked by a test that has been seen to fail.
- **The engine does not roll.**
- **No component reaches the game through a hardcoded list.**
- **A balance claim ships with its trial count and its seed, or it does not ship.**
- **A new option that is strictly worse than a free existing one is not a card, it is a bug.** Check what the player already gets for nothing before you price anything.
- **Nothing on a printed face depends on an effect the printer can drop.**

## Reference

- `reference/failure-modes.md`: the specific bugs, with the evidence and the check that catches each one. Read it before adding a component or changing a rule.
- `reference/balance.md`: the harness, the sample sizes, the properties worth protecting, and the questions only a human at a table can answer.
