---
name: wizard
description: "Use when a procedure has steps only a human can take: clicking through a third-party dashboard, provisioning a domain or DNS record, generating an API key, setting a CI secret, or running a one-off cutover. Generates an interactive bash script that opens each URL, says exactly what to click, captures each value, writes it into .env and GitHub secrets, confirms before anything irreversible, and shows how many stages are left. Triggers on: 'walk me through setting up', 'I need to configure X in the dashboard', 'set up the credentials for', 'script the DNS steps', 'a checklist I can actually run', 'make this setup repeatable'. Not for steps the agent can perform itself, which it should just perform, and not for investigating what a service requires in the first place (use groundwork)."
argument-hint: "[the procedure] [--commit]"
user-invocable: true
license: MIT
---

# wizard: a script for the steps only a person can take

Some procedures cannot be automated because the blocker is not capability, it is a browser
session, a two-factor prompt, or a dashboard nobody has an API for. Those steps get done by
hand, badly, at intervals long enough that the person has forgotten them, and re-explained to
an agent every single time.

A **wizard** is a bash script that walks the human through exactly those steps: one screen at a
time, opening each URL, saying what to click, capturing what comes back, and writing it where
it belongs. The knowledge stops living in a chat log.

**Do not generate one for work you can do yourself.** An agent that writes a wizard for
something it could have run is handing the user a chore. The test is whether a human is
genuinely in the loop.

## The library is not yours to edit

`scripts/template.sh` already solves the part that is tedious and easy to get wrong: stage
progress, confirmation gates, cross-platform URL opening including WSL, hidden entry for
secrets, idempotent `.env` upserts, `gh secret` and `gh variable` writes, and a closing summary.

Everything above the `# ---- STAGES ----` marker is identical in every wizard. That sameness is
the point: a reviewer reads the stages and trusts the rest. **Never hand-edit the library.**
Your job is to scope the procedure and author its stages.

## Step 1: Scope it from the repo, not from the user

Read before you ask. Asking a user to list their own setup steps produces the steps they
remember, which are the ones they did not need a wizard for.

- **For setup**: `.env`, `.env.example`, `.env.*`, the README, `docker-compose*`, framework
  config, and `.github/workflows/*`. Every `secrets.*` and `vars.*` reference in a workflow is
  a value this wizard has to produce.
- **For a migration or cutover**: the current state, the target state, and every irreversible
  action between them. The irreversible ones decide where the confirmation gates go.
- **In this fleet specifically**: `docs/operations/publishing.md` is the canonical ordering for
  a repo, Pages, and DNS publish, and `tooling/dns/` holds the Namecheap records. A wizard for
  publishing follows that runbook rather than a remembered command.

Then show the user the ordered stages and the value each produces, and let them add, drop, or
reorder before you write a line.

**Done when** every stage is named in order, and for each captured value you know where the
human gets it, where it is written (`.env`, a GitHub secret, both, or nowhere), and whether it
is secret.

## Step 2: Trace each stage to a real path

Write the exact journey: which URL, what to do there, where the value is shown, which variable
it fills. "Dashboard, then Developers, then API keys, then Reveal test key, then copy."

Where you do not know the current UI, **say so and check**. An invented menu path is worse than
no wizard: the user follows it, does not find the button, and now distrusts every other stage.
`groundwork` is the skill for finding out what a service actually requires, and its dated
requirements doc is the right input to this step.

**Done when** every stage traces to instructions a stranger could follow.

## Step 3: Author the stages

Copy the template, replace the example stage with one `stage` per step in dependency order, and
set `TOTAL_STAGES`.

```bash
cp "$FORGE/skills/wizard/scripts/template.sh" scripts/setup-<thing>.sh
```

Helpers, and the bar each one sets:

| Helper | Use it for | The rule |
|---|---|---|
| `stage "<title>"` | Each step | Clears the screen. One focused task per stage, so nothing scrolls away |
| `say` / `step` | Instructions | The literal click path, not a summary of it |
| `open_url <url>` | Every URL | Open it **before** asking for the value it produces |
| `ask` / `ask_secret` | Capturing input | `ask_secret` for anything that must not land in scrollback |
| `write_env K V` | Persisting | Every value the project needs at runtime |
| `set_secret` / `set_var` | CI | Only the values CI actually reads |
| `confirm "<what>"` | Before irreversible actions | Deleting, cutting over, publishing, spending money |

## Step 4: Verify statically, then hand off

**Do not run it end to end.** It opens browsers and blocks on human input; an agent driving it
either hangs or answers the prompts itself, which proves nothing.

```bash
bash -n scripts/setup-<thing>.sh && shellcheck scripts/setup-<thing>.sh
chmod +x scripts/setup-<thing>.sh
```

Then trace it on paper: every value from step 1 is captured, lands where step 1 said it would,
and every `set_secret` name matches a `secrets.*` reference in CI **exactly**. A near-miss on a
secret name is the defect this check exists for, because CI reports it as an empty string
rather than an error.

A wizard is **ephemeral by default**: built for one run, written to `scripts/`, deleted when
the job is done. Commit it only when the procedure recurs, and then link it from the README so
the next person runs the script instead of asking an agent.

## Invariants

- **Never generate a wizard for work the agent can do.** A human in the loop is the entry
  condition, not a style choice.
- **Never edit the library above the marker.** Stages are yours; the machinery is not.
- **Open the URL before asking for its value.** The other order makes the user hunt.
- **`confirm` before anything irreversible**, and name what is about to happen in the prompt.
- **Never invent a menu path.** Check it, or ask, or say the step is unverified in the script
  itself.
