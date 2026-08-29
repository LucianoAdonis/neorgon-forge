# Failure modes

Every one of these happened, most of them in `projects/enjeu-site`, several of them
twice. Each entry is the symptom, why the tests did not see it, and the check that does.

---

## 1. The hardcoded list that drops a new component

**Symptom.** You add a card. It never appears in a hand, a deck, a simulation or a sheet,
and nothing errors.

**Why tests miss it.** The tests were written against the same hardcoded list, so they
assert the old set and pass.

**Happened twice, in the same file.** `run.js` carried a comment recording that a
hardcoded trio had silently left Bubble out of every hand when Bubble was added. Directly
below that comment, `sim.js` built its attack list from constants and ignored `data.attack`
entirely, so when Run was added the simulator could not see it either.

**The check.** Derive every set from the data, then assert the derivation against the data
rather than against a literal:

```js
const dealt = attacksFor(run, data).map((c) => c.id).sort();
assert.deepEqual(dealt, data.attack.map((c) => c.id).sort());
```

That assertion names the missing card in its failure message, which is the difference
between a useful test and a red light.

---

## 2. Data before engine: a field nothing reads

**Symptom.** A card is in the data with a new field. It resolves as though the field were
absent, which usually means it falls through to the most generic path in the code.

**The real one.** `{"id": "run", "hides": true, "damage": 0}` went into the deck before
the engine knew what `hides` meant. `attack()` fell through to the ordinary hit path;
because the card had no element it inherited the hero's, so it collected affinity, biome
and relic bonuses and dealt up to 75 damage for one action and no cards. It strictly beat
the card it was supposed to sit beside. **All 124 tests passed**, because no test asserted
that a card with no damage deals none.

**The check.** For every component with a behaviour flag, assert the behaviour, not the
flag. And assert the negative: a card that deals nothing must deal nothing.

---

## 3. The guard that does not run

**Symptom.** A comment, a docstring or a rulebook sentence says a check exists. It does
not, or it checks the wrong half.

**Two real ones.**
- `js/strings.js` stated in its header that a key present in one language and missing in the other "renders the literal `[some.key]` on the page, which `tests/content.test.mjs` is there to catch." Both tests in that file walked the English table. Nothing ever read the Spanish one.
- The rulebook's component table said `tools/lint_cards.py` counted the deck "so this table is checkable rather than remembered." The linter printed a count and never opened the rulebook.

**Why it is worse than no guard.** A stated guard gets quoted. People stop checking the
thing by hand because they believe something else is.

**The check.** After writing any guard, **break the thing it guards and watch it fail**,
in every direction it claims to cover. A parity check gets tripped twice: once by removing
a key from each side.

---

## 4. The effect the printer drops

**Symptom.** Correct on screen, wrong or blank on paper. No test sees it because the
markup is right and only the rasteriser is not.

**The real one.** Card art was recoloured with an SVG filter. Chromium drops SVG filters
when rasterising for print and PDF, so every recoloured picture printed in the source
file's black. Mostly that was merely wrong. On the boss life card, a gold crown on a
near-black face, it printed black on black: a blank card, from a deck whose entire purpose
is to be printed.

**The check.** Render the actual print path to PDF and look at the pages. Then forbid the
class of thing in a test:

```js
assert.ok(!svg.includes('<filter') && !svg.includes('filter="url('),
  'no filter may reach a card face');
```

**Related.** Percentage max-heights, container queries, blend modes, `backdrop-filter` and
anything relying on a stacking context are all suspect in a print pipeline.

---

## 5. The new option that is strictly worse than a free one

**Symptom.** A card nobody would ever play, that reads fine in the rulebook.

**The real one.** A card was designed to cost one action and grant a defensive state. The
game already granted that same state **free**, as a rider on an existing attack that also
dealt damage. So the new card was one action for strictly less. Measured, playing it cost
10.5 points of run completion against simply not playing it. The rulebook had recorded
this exact defect once before, about a different card, and it happened again because
nobody re-read what the player already gets for nothing.

**The check.** Before pricing anything, enumerate what the player can already do **for
free** or for the same cost. Write the comparison down. If the new thing is not better in
some identifiable state, it is not a card.

**The second-order check.** Ask what the new option does to the *reserve* the game's
tension depends on. A card that makes a mandatory precaution optional can be power-neutral
and still ruin the game.

---

## 6. The undiscoverable free rule

**Symptom.** A real mechanic exists that the owner does not know about, because it is one
clause inside a paragraph about something else.

**The real one.** Hiding was free, available every turn, as a bullet under the Strike card.
It never appeared in the UI, never on a card, and the game's own author did not know it was
there when asking for a card that would do the same thing.

**The check.** Every mechanic a player can use should be reachable from a component they
can hold or a control they can see. A rule that exists only in prose is a rule that exists
only for whoever wrote it. Ask: *what would show me this exists mid-game?*

---

## 7. Prose that drifts from data

**Symptom.** A count, a percentage or a statline stated in a document disagrees with the
source, or with the same claim elsewhere.

**The real ones.** 89 vs 90 cards. 93 vs 94. 104 vs 105, twice missing the same row. A
rulebook claiming a card lifted completion from 6.4% to 8.3% when the harness it cited
measured 6.1% to 28.9%, an error of more than twenty points that had been faithfully
translated into a second language.

**The check.** Parse the document and compare it to the source:

```js
const rows = [...table.matchAll(/^\| (?!\*\*Total)([^|]+?) \| (\d+) \|$/gm)];
const sum = rows.reduce((a, r) => a + Number(r[2]), 0);
assert.equal(sum, Number(statedTotal));
assert.equal(sum, data.physical.length);
```

For a translated document, compare numeric multisets locale-blind, so `4,000` and `4.000`
match but a changed value does not.

---

## 8. Sizing from the window instead of the container

**Symptom.** At one common laptop size, content is cropped, and it is painted underneath an
opaque neighbour rather than merely hidden.

**The real one.** Card sizes were `vh`-based. The action panel and the arena both measured
the window; the panel was content-sized so it took what it wanted first, and the arena
absorbed the whole deficit. At 1280x720 with a plan queued it was given 101px for content
needing 133px. `document.elementFromPoint` on the player's own life cards returned the
panel: not hidden, unclickable.

**The check.** Measure, at every size you claim to support:

```js
{ clip: el.scrollHeight - el.clientHeight,
  below: max(child.bottom) - el.bottom,
  pageScrolls: document.documentElement.scrollHeight > innerHeight + 1 }
```

Container query units on the band that owns the height, plus a floor on its grid row, is
the fix. And when three promises cannot hold at once (no page scroll, control reachable,
nothing cropped), release the least important one deliberately rather than cropping.

---

## 9. The measurement that was blind

**Symptom.** A balance number that does not move when it should, or moves for the wrong
reason.

**Two ways it happens.** The simulator cannot see the new component (failure 1), or no
strategy ever uses it. Both were true at once when Run was measured: the attack list was
hardcoded and no strategy had ever called `hide`.

**The check.** Before trusting a measurement, confirm the thing being measured is reachable:
assert the component appears in the simulated hand, and that at least one strategy plays it
in a run. If you cannot make a bot use it well, say so, and label the result a floor or a
ceiling rather than an estimate.

---

## 10. Colour as the only channel

**Symptom.** A component is unreadable to a colour-blind player or a photocopier.

**The rule.** Every meaning carried by colour is also carried by a shape, a count or a
sigil. A red card with no fire glyph fails. A risk ramp from green to red is only
acceptable because the pip *count* says the same thing independently.

**The check.** Assert the redundancy, and assert that two values never share the redundant
channel:

```js
const counts = [...seen.values()];
assert.equal(new Set(counts).size, counts.length,
  'two steps sharing a pip count would leave colour alone');
```

---

## 11. Two renderers for one component

**Symptom.** The same card looks different in two places, and one of them is the wrong one.

**The rule.** One function renders a component, everywhere: the browser, the print sheet
and the play runner. A second renderer written for the screen will drift, and it will be
the one that never gets printed, so it will be wrong for years without anybody noticing.
When a view needs a variant, it passes an option; it does not draw its own.
