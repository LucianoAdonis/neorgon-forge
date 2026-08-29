# wizard

A bash script that walks a human through the steps only a human can take.

## What it does

`wizard` generates an interactive script for a manual procedure: it opens each URL, says
exactly what to click, captures each value, writes it into `.env` and GitHub secrets, confirms
before anything irreversible, and shows how many stages are left.

The defining constraint is the entry condition: a human must be genuinely in the loop. An agent
that generates a wizard for something it could have run has handed the user a chore.

## When to reach for it

Type `/wizard`, or the agent reaches for it when it hits a wall only you can pass: a dashboard
with no API, a two-factor prompt, a DNS record, a one-off cutover.

Reach for it when the procedure recurs at intervals long enough that you have forgotten it, and
you have re-explained it to an agent more than once. For finding out what a service requires in
the first place, use [groundwork](groundwork.md).

## The library is fixed, the stages are yours

Everything above the `STAGES` marker in `template.sh` is identical in every wizard: stage
progress, confirmation gates, cross-platform URL opening including WSL, hidden secret entry,
idempotent `.env` upserts, `gh secret` writes, a closing summary. That sameness is what lets a
reviewer read the stages and trust the rest.

The idempotent upsert matters more than it sounds: it is what makes a half-finished run
recoverable. Re-running replaces a value rather than appending a second line for the same key.

## It is verified on paper, not by running it

It opens browsers and blocks on human input, so an agent driving it either hangs or answers its
own prompts, which proves nothing. Verification is `bash -n`, `shellcheck`, and a static trace:
every value captured lands where the scope said it would, and every secret name matches its
`secrets.*` reference in CI **exactly**. CI reports a mismatched name as an empty string, never
as an error.

## It's working if

- One screen at a time, and nothing you need has scrolled away.
- The URL opens before you are asked for the value it produces.
- Re-running it after a failure at stage four does not make you retype stages one to three.
- It refuses to write itself for something the agent could have just done.
