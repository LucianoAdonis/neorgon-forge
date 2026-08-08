# Resolving a ticket to files

Read this when `map.sh ticket` returned nothing useful, or when the ticket is written in a
vocabulary the codebase does not share.

The core problem: a ticket is written by whoever noticed the symptom, in the words of the interface
they were looking at. The code is written in the words of whoever built it. Those two vocabularies
overlap by accident, not by design, and the gap between them is where "I searched and found
nothing" comes from.

## The three failure shapes

**The ticket names the surface, the code names the mechanism.** "The date is wrong on the receipt"
→ the code has no `receipt`; it has `OrderConfirmationTemplate` and a `formatIssuedAt` helper. The
translation is one hop and a grep for `date` finds four hundred files.

**The ticket names an outcome, not a location.** "Users can't log in" is a whole subsystem: the
form, the session, the token, the redirect, the rate limiter. Nothing is wrong with the ticket —
the reporter cannot see which of those failed. Resolving it means narrowing to a stage first,
which is `untangle --kind cause`, not a search problem at all.

**The ticket names something that no longer exists.** "Fix the sidebar filter" in a repo where the
sidebar became a drawer two quarters ago. Grep finds the dead code, which is the worst possible
result: it looks like the answer.

## Getting from words to files

In order of cost, cheapest first. Stop as soon as one works.

**1. The user-visible string.** If the ticket quotes text the user sees — a label, an error
message, a button — grep the literal string. This is by far the highest-yield move and it is
routinely skipped in favour of grepping the concept.

```bash
grep -rn --exclude-dir=node_modules "Order confirmed" .
```

For an interpolated or translated string, grep the stable fragment or the translation key rather
than the rendered sentence.

**2. The area, from the map.** `map.sh ticket` shows which mapped areas use the ticket's
vocabulary. An area narrows the search space by an order of magnitude before any grep runs, which
is the whole reason areas are recorded in the user's words.

**3. The route.** If the ticket names a screen or a URL, resolve the route to its handler, then
read outward from there. `orient.sh` reports where routes are declared; the path from route to
component to helper is short and it is reliable.

**4. The git history of the feature.** When the ticket describes a regression, the commit that
introduced it names the files.

```bash
git log --oneline -S 'formatIssuedAt' -- .
git log --oneline --since='3 months ago' --grep='receipt' -i
```

`-S` searches for commits that changed the number of occurrences of a string — it finds the commit
that *introduced* a term, which no grep of the current tree can do.

**5. Ask.** One sentence — "which screen is this on?" — beats twenty minutes of synonym search, and
the answer is worth recording as a lesson because the same translation will be needed again.

## What to record afterwards

Every resolution that took more than one hop taught you a vocabulary mapping, and that mapping is
the reusable part.

```bash
bash "$FORGE/skills/wayfind/scripts/map.sh" learn \
  "tickets say 'receipt'; the code calls it OrderConfirmation throughout" \
  --rule 'src/emails/*'
```

Do this even when the resolution felt obvious in hindsight. It felt obvious because you had just
built the mapping; nobody arriving tomorrow has it, including you.

## When the ranking is flat

`map.sh ticket` ranks by distinct terms matched. If every candidate matched exactly one term, the
list is alphabetical noise dressed as a ranking, and the script says so. Two ways out:

- **Add a term the code would actually use.** Re-run with your own translation of the ticket:
  `map.sh ticket "OrderConfirmation issuedAt timezone"`. You are now searching the code's
  vocabulary instead of the reporter's.
- **Narrow to an area first**, then search inside it. A flat ranking across the whole repo often
  becomes decisive inside one directory.

## The check before you edit

Whatever route you took, say it out loud before changing anything:

> This is the `checkout` area. I expect to change `src/lib/cart/total.ts` and its test, because
> the currency is resolved there rather than at render time.

Two things happen when that sentence exists. A wrong guess gets corrected in one line instead of
after a diff. And when the change turns out to touch six files instead of two, the discrepancy is
visible — which usually means the ticket was a `scale` problem or a design question in disguise,
and the right move is to stop and reclassify rather than keep editing.
