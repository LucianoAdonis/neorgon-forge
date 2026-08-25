# 0001. Skills are bucketed by arc position, not by topic

Date: 2026-08-22
Status: accepted

## Context

The set reached eighteen skills in one flat directory. At that size the directory listing stops
being a menu and becomes a wall: the skills reached for least are the ones most needing a
reminder, and a flat list gives the reader no way to narrow.

The obvious grouping is by topic, and it is what comparable repos do (`engineering/`,
`productivity/`, `misc/`). Applied here it puts eleven of the eighteen in one bucket, because
most of this set is writing, documentation, and explanation work.

## Decision

Four buckets named for **where in the work you are**: `before/`, `during/`, `after/`, `craft/`.
The bucket answers "when would I reach for this", which is the question a person browsing
actually has.

The bucket is repo organisation only. Skills install flat, so nothing downstream sees it and a
cross-skill path in prose never carries a bucket.

## Rejected

**Topic buckets.** Distribution is the whole argument: 11/3/2/2 against 5/5/3/5. A bucket
holding two thirds of the set has not grouped anything.

**Staying flat.** Cheapest, and it leaves the actual problem: at eighteen the reader needs
narrowing before they need detail.

## Consequences

- `plugin.json` now needs an explicit `skills` array, since the default scan only sees one level.
  `validate.sh` fails when that array and the tree disagree, which the default scan could never
  get wrong.
- Every tool walking the tree walks two levels. `validate.sh` gained `skill_dir()` to resolve a
  bare name, because prose still addresses the flat installed layout.
- A skill whose arc position is genuinely ambiguous has no obvious home. `secret-safe-reporting`
  is the live case: it applies across the whole arc, and sits in `during/` because that is where
  the leak would happen.
