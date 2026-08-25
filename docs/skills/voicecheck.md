# voicecheck

Copy that already exists, audited against the voice it is supposed to have.

## What it does

`voicecheck` loads a project's `VOICE.md` before judging anything, falls back to a checkable
baseline where there is none, and reports findings as `file:line`. It also compares projects
against each other.

The defining constraint is that it loads the voice first. An audit against a remembered voice is
an opinion, and an opinion about someone's copy is the least actionable thing you can hand
them.

## When to reach for it

Type `/voicecheck`, or the agent reaches for it when you say copy reads like AI wrote it, ask
for a tone audit, or ask whether something is on-brand.

Reach for it for headlines, meta descriptions, button labels, empty states, error messages,
onboarding copy, README prose. For writing new copy from a brief, use
[penname](penname.md): voicecheck audits, penname writes.

## Cross-project comparison is the part you cannot do yourself

Voice drift is invisible from inside one repo. Every individual decision looked reasonable at
the time, and the divergence only exists in the comparison. Running it across projects is what
surfaces it.

`audit` never writes. Keeping the report separate from the rewrite is what makes it safe to run
on copy that is not yours.

## It's working if

- Every finding has a `file:line` you can jump to.
- It cites the project's own `VOICE.md` rule, not a general principle.
- Running it across two sites finds a divergence neither site could see.
- A rewrite changes the reading and not the claim.
