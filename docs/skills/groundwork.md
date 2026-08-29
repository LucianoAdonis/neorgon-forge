# groundwork

What a service actually requires, found out and dated, before a tutorial promises it.

## What it does

`groundwork` investigates prerequisites, credential acquisition, versions, costs, rate limits,
quotas, and free-tier boundaries, then produces a dated requirements doc where **every claim
carries a label**: verified, documented, or inferred.

The defining constraint is that labels are earned, never inherited. A step you did not walk is
`documented`, not narrated as though you had. That distinction is the entire value of the
document, and it is the first thing that erodes.

## When to reach for it

Type `/groundwork`, or the agent reaches for it when asked what is needed to set something up,
whether a free tier is enough, or what an API's limits are.

Reach for it before writing a tutorial, not during. For writing the tutorial itself, use
[penname](penname.md)'s tutorial persona. For generating the walkthrough script a human runs,
use [wizard](wizard.md).

## Undated limits do not ship

Every limit carries a value, a scope, a source, and a date. A rate limit with no date is a
number that was true once, and the reader has no way to tell how long ago. `stale.sh` expires
them; `docrun.sh` executes the document's own commands to prove them.

Dead ends ship verbatim. The path that did not work is the most reusable output of the whole
investigation, and it is the one thing the next person cannot regenerate.

## It's working if

- You can tell, per claim, whether someone actually did it.
- A claim expires and the doc says so, rather than quietly aging.
- The document contains a failed approach, written out in full.
- No real credential material appears anywhere in it, only same-shape synthetic placeholders.
