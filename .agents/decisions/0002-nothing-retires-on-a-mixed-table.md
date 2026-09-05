# 0002: Nothing retires on a mixed table

**Date:** 2026-09-05
**Status:** accepted

## Context

A reach measurement found 17 of 26 skills had never been invoked once across 2,212
transcripts, with `/task` holding 151. A description audit then proposed five skills for
merging or retirement rather than rewording, on the strength of that number.

Two facts make acting on it wrong today.

The first is that the number was measured against a table that is not this repo. Eleven
skills are loaded twice, once from `~/.claude/skills` symlinked here and once from a plugin
cache frozen at v1.9.0, serving descriptions that had already drifted. `bin/check-install.py`
now fails on that state. Until it passes, a zero cannot distinguish "nobody needed this" from
"the router read a different description".

The second is that sixteen description edits landed the same day, and four of them were
precisely the collisions that would suppress a skill's reach. Measuring before those edits
have had a chance to route anything would be measuring the thing we just fixed.

## Decision

**No skill is retired or merged on this evidence.** Each candidate was checked against the
filesystem rather than against the audit's summary, and the checks disagreed with it twice.

| Candidate | Argument made | What the filesystem says | Decision |
|---|---|---|---|
| `quizmaster`, fold into `rappel-deck` | "one hand-authored exam in 24 days" | **Three** exams in `proctor-site/data`, dated 2026-08-10, 08-10 and 08-14. And `rappel-deck` already defers to it one-way: flashcards are not a graded exam | **Keep.** The premise is wrong and the boundary is already written |
| `pathfinder`, retire unless the canvas workflow is revived | "the cleanest case in the set" | `pathfinder-site` is `lifecycle: live` at pathfinder.neorgon.com with commits on 2026-09-01 and 09-02 | **Keep.** The workflow it serves is not dormant |
| `grill` and `untangle`, merge the design halves | Both handle an undecided design | Real overlap, but they enter from opposite ends: `untangle` picks *between* options against criteria written first, `grill` stress-tests *one* plan already chosen | **Keep separate.** Today's edits made that boundary explicit in both descriptions, which is the cheaper fix |
| `deckcraft`, merge into `debrief` if still zero | Zero reach | The audit itself said re-measure in a month | **Defer**, and the clock starts when `check-install` passes, not today |
| The set as a whole, 26 slots | The loaded routing table holds roughly 400 skills, so the forge's 26 do not compete with each other | True and unrefuted | **Standing question**, owner's call, not an agent's |

## Consequences

The order is fixed and matters: clear the cache, confirm with `make check-install`, let the
sixteen edits route for a while, then `make reach`. A retirement decided before that is
decided on noise.

Two of five arguments in a carefully verified audit did not survive a filesystem check. That
is the argument for this record existing: the next session will find the audit and should find
this next to it.
