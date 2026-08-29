# handoff

This session, compacted into something the next agent can start from cold.

## What it does

`handoff` writes `.forge/handoff-<slug>.md`: where the work is, the single next action, the
landmines, and which skills the next session should call.

The defining constraint is that artifacts are **referenced, never copied**. If the brief already
records the rejected approach, the handoff points at it. That is what keeps it short, and it is
what stops two copies of a decision drifting until the reader cannot tell which is current.

## When to reach for it

You type `/handoff`; the agent will not reach for it on its own. Compacting a session is a
judgment about the session, and that is yours.

Reach for it when the work moves: a new context window, a new machine, a new harness, a
colleague, or forking a side task mid-phase. If the context is fine and nothing is moving, keep
going or compact instead.

## Landmines are the reason it beats reading the diff

A diff shows what worked. It cannot show the approach that was tried for two hours and
abandoned, the thing that looks safe and is not, or the environment fact that cost an
afternoon. That section is the whole value, and it is stated even when it is unflattering: an
omitted failed approach gets retried by the next agent at full cost.

## Sizing

If the handoff is longer than the brief it references, it is transcribing rather than
compacting. Cut in this order: conversation narrative, restated file contents, options
considered and dropped without changing anything, and reasoning about steps already finished.
A good one is usually under a page.

Everything sensitive is redacted before it lands, because a handoff is a file that gets pasted
into another session and forgotten in a temp directory.

## It's working if

- The next agent starts working instead of asking what is going on.
- It is shorter than the conversation by an order of magnitude.
- It names one next action, not a plan.
- Something in the landmines section is faintly embarrassing.
