# untangle

A problem whose shape is not known yet: worked until it has one.

## What it does

`untangle` handles the case before a plan is possible. It classifies the problem first (a cause
to find, a design to choose, a limit to characterise), says which branch it took, and then runs
that branch's technique, because the techniques do not transfer.

The defining constraint is that it **refuses to theorise before it has evidence**. Every
hypothesis it writes down carries the observation that would kill it. A hypothesis with no
disproof attached is a hunch wearing a hypothesis's clothes, and it will survive the whole
investigation because nothing can end it.

## When to reach for it

Type `/untangle`, or the agent reaches for it when something is reported broken, slow, or
intermittent and the cause is not obvious.

Reach for it when the first look did not explain it. If the cause is already known, this is a
[task](task.md), not an investigation. If the doubt is about a plan rather than a behaviour, it
is a [grill](grill.md).

## Observation and interpretation stay apart

The discipline the whole skill turns on: what was observed is written separately from what it
means. They collapse into each other within minutes otherwise, and once collapsed, an
interpretation is defended as if it were an observation.

Being stuck is a report, not a state to sit in. After three refuted theories it escalates rather
than generating a fourth.

## It's working if

- It says which branch it is on, in the first message.
- It kills its own hypotheses, including yours.
- A fix it cannot explain gets recorded as open rather than declared done.
- You get a reproduction, a scored decision, or a coverage map. Not a paragraph of maybes.
