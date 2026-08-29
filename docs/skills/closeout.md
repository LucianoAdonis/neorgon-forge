# closeout

Ends a body of work by turning "anything else pending?" into a numbered contract.

## What it does

`closeout` inventories the pending items from sources that cannot lie: git state (including
repos with no remote), the site registry's `ready` entries, hub cards still marked Soon,
`.forge/brief.md` Open sections, the harness ledger, and the prompt queue. It presents them as
a numbered list where every item carries what closing it takes and a lane: `do`, `yours`
(credentials and decisions only the user can make), or `parked` (someone else's in-progress
work, listed but not offered).

The user answers once. That answer is the authorisation: every `do` item proceeds except the
ones it denies by name or number. Publishing is always its own line item, so "wrap up" can
never imply making a repo public. Execution runs in blast-radius order (local closes, commits,
verification gates, pushes, publishes) and the final report uses the same numbers the user
answered to, each with its proof.

## The failure modes it prevents

A wrap-up enumerated from memory misses exactly the items only git knows about: the repo that
was never pushed anywhere, the generated file nobody committed, the zone backup sitting dirty.
And an agent told to "finish everything" without a list first will close things the user never
saw offered. The numbered list is the consent boundary in both directions.

## When to reach for it

At the end of a session or a campaign, when the user asks what is left or asks for everything
to land. Not for choosing new work (that is the prompt queue and `/task`), not for the readout
(`/debrief`), not for reviewing what shipped (`/code-review`).
