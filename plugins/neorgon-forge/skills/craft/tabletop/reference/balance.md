# Measuring a game instead of arguing about it

A balance claim is a measurement or it is an opinion. This is how to take the measurement,
what to protect, and where the measurement stops being able to help.

---

## The harness

Small, ugly, checked in, and named after the question it answers. In `enjeu-site` these
live in `tools/checks/*.mjs` and each is thirty lines:

```js
import { readFileSync } from 'node:fs';
import { useCards } from '../../js/data/cards.js';
import { runCell } from '../../js/game/sim.js';
import { STYLES } from '../../js/game/strategies.js';

const data = useCards(JSON.parse(readFileSync('data/cards.json', 'utf8')));
const T = Number(process.env.T || 6000);

for (const [label, opts] of [['without', { noRun: true }], ['with', {}]]) {
  console.log(`\n${label}  (${T.toLocaleString()} fights per cell)`);
  const total = Object.fromEntries(STYLES.map((s) => [s, 1]));
  for (let L = 1; L <= 5; L++) {
    const row = STYLES.map((st) => {
      const c = runCell(data, { level: L, style: st, ...opts }, T);
      total[st] *= c.win / 100;
      return c.win.toFixed(1).padStart(8) + '%';
    });
    console.log(` ${L}  ${row.join('')}`);
  }
  console.log('  full run: ' + STYLES.map((s) => `${s} ${(total[s] * 100).toFixed(2)}%`).join('  '));
}
```

Three properties make it worth keeping:

1. **It takes the variant as data**, so the comparison runs without editing the game.
2. **It prints the baseline beside the change**, so nobody has to remember last week's numbers.
3. **It is deterministic.** Seed the stream. A balance harness that gives a different answer each run cannot settle an argument.

Commit the harness with the document that cites it. A `BALANCE.md` naming a script nobody
else has is worse than one naming no script at all.

---

## Sample size

Win rates converge fast and then stop moving. Measured on a five-level boss rush:

| Trials per cell | What it is good for |
|---|---|
| 500 | a smoke test that the harness runs |
| 3,000 | the shape: which line is best, whether a strategy is dead |
| 6,000 to 8,000 | a decision between two variants, if they differ by more than about 2 points |
| 20,000 | a number you are going to print in a document |

Below about 3,000 the noise is wider than most design changes. Above 20,000 you are buying
decimal places nobody will act on. **State the trial count with the number, always**, and
state the seed if the harness takes one.

---

## Protect properties, not numbers

A win rate is a fact about a build. A property is a fact about the design, and it is what
you actually care about.

The properties worth naming, in rough order of how much damage their loss does:

- **Skill is rewarded.** The careful line beats the reckless line. If a change raises everybody's win rate and inverts this, the change made the game worse.
- **The boring line loses.** The most passive possible strategy (never bet, never risk, wait it out) must fail. If it wins, the game has no clock.
- **The intended progression is monotone.** A later, more expensive component is actually better per unit of cost. This is worth checking directly: an early version of `enjeu-site` had its tier 1 card as the most efficient in the game, so every level-up was a downgrade under careful play.
- **No dominant option.** No component is the right answer in every state.
- **No dead option.** Every component is the right answer in some state. If you cannot name that state, cut the card.

Write the property into the harness output so it is checked rather than remembered:

```js
const ok = tot.adaptive > tot.safe && tot.adaptive > tot.gamble && tot.adaptive > tot.turtle;
console.log(`adaptive best over a full run? ${ok ? 'YES' : 'NO'}`);
```

---

## The order of a balance change

1. **Baseline.** Measure the game as shipped. Keep the output in the brief.
2. **Name the property** the change must not break, before you look at any number.
3. **Build the variants as data.** Add the dial to the data file rather than editing the engine per run. When `enjeu-site` made every boss life card worth 100, the question was how many cards a Summon moves; making that a data field turned an argument into three harness runs.
4. **Measure all variants at one trial count.** Print them together.
5. **Check the property.** Then the numbers.
6. **Record both in the brief**, with the trial count. The number you did not write down is a number you will re-derive badly in a month.

A worked example, from the uniform-100 change:

| Variant | L1 | L2 | L3 | L4 | L5 | full run |
|---|---|---|---|---|---|---|
| baseline (mixed card values) | 75.6 | 68.1 | 51.8 | 43.4 | 44.8 | 5.18% |
| uniform, Summon moves 1 card | 75.6 | 67.8 | 48.1 | 43.2 | 44.5 | 4.74% |
| **uniform, Summon moves 2 cards** | **77.6** | **68.1** | **51.8** | **44.9** | **44.3** | **5.43%** |

The third row is within noise of the baseline everywhere, so the ergonomic win (a child
turns one card over per 100 damage and never divides) cost no balance at all. That is a
conclusion; the two rows above it are why anyone should believe it.

---

## When the bots are the problem

A simulator measures the game its strategies can play. Two ways that goes wrong:

- **The component is unreachable.** The strategy list, the hand, or the deck is hardcoded and the new thing is not in it. See `failure-modes.md`, entry 1.
- **No strategy uses it well.** The bots have no logic for the new mechanic, so the measurement shows a floor, not a value.

When you add a mechanic, add the heuristic that uses it, and make the heuristic *narrow*
rather than eager. A bot that plays a defensive option whenever it looks scary measured
**10 points worse** than one that plays it only under three conditions: only when the
defence cannot be got for free, only when it actually closes the gap, and only when there
is no likely kill available instead. Those three conditions are a design finding, not a
bot detail: they are when the card is worth its cost, and they belong in the rulebook's
explanation of the card.

If you cannot make a bot play it well, say so and label the result:

- a **floor** (naive play), or
- a **ceiling** (the effect always on, free)

and never call either an estimate.

---

## What a simulator cannot answer

Write these down and take them to a table. They are the only questions that matter for a
game a person actually plays, and no amount of trials touches them.

1. **Is the central tension felt?** The simulator can prove the guard line binds. It cannot tell you whether the player notices they are choosing.
2. **Is a turn too long?** Count real minutes and real arithmetic. If a round takes six minutes of adding up, the design is wrong whatever the win rate says.
3. **Does the table state fit on a table?** Piles, markers, and the space they need.
4. **Is the iconography guessed, not worked out?** Show a component to somebody who has never played, for three seconds. If they cannot guess, redesign it. If any playtester asks what an icon means, that icon is wrong.
5. **Does anybody use the interesting card?** A component with a good win rate that nobody reaches for has failed.
6. **Does losing feel survivable?** For a game played by a child, this decides whether there is a second session.

Record the answers with dates in a playtest log, and treat that log as a record rather than
a document to tidy: when a later change supersedes an entry, append the correction, do not
rewrite the entry.

---

## Calibrating to the audience

The number that matters is not "is this balanced" but "is this the right difficulty for the
person playing it". A five-level completion rate around 5% is roguelike territory and is
almost certainly wrong for a child. Before tuning the whole game to fix that, check what
the optional safety mechanics already buy: in `enjeu-site` the gentle-mode card lifted
completion from 6.1% to 28.9%, which reframes the question from "is the game too hard" to
"should the safety net be on by default".
