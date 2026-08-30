# Submitting neorgon-forge to the Claude plugin directory

The plugin directory (community-driven, surfaced in Claude Code as the official
`claude-plugins-official` marketplace and in Cowork) is the one distribution
surface an individual author can reach without a paid Team or Enterprise org.
This file records how to submit and what was verified, so a resubmission or an
audit does not start from scratch. Source of truth for the process:
https://claude.com/docs/plugins/submit

## Readiness, verified 2026-08-29

| Requirement | State |
|---|---|
| Public repo (closed-source is rejected) | yes: https://github.com/LucianoAdonis/neorgon-forge |
| `claude plugin validate . --strict` (marketplace manifest) | passes |
| `make validate` (house standard, 23 skills, set-level coverage included) | passes |
| `npx skills@latest add . -l` (the skills CLI reads the bucket layout) | lists 23 |
| License | MIT |
| Every skill has a `SKILL.md`, an `agents/openai.yaml` and a docs page | 23 of 23 |
| Bundled MCP connectors (extra review, more user warnings) | none |
| Version | 2.2.0 |

Previously verified 2026-08-21 at 13 skills, before the arc-position buckets,
the `forge` router and the README map existed.

The plugin bundles skills only, no MCP connectors, so it avoids the connector
review path entirely. `secret-safe-reporting` is about not leaking sensitive
data in reports; it reads nothing on its own.

## How to submit (one time, needs you)

The submission is a signed-in form; it cannot be done from a coding session.
As an individual author (no Team/Enterprise org), use the Console form:

1. Sign in at https://platform.claude.com (a Developer, Admin or Owner role on a
   Console org; individual authors sign up there).
2. Open https://platform.claude.com/plugins/submit
3. Paste the repo link: https://github.com/LucianoAdonis/neorgon-forge
4. Submit. **Push first**, always: the directory reads the public repo, so
   submitting ahead of a push lists a version nobody can install. Review times vary with queue volume; basic automated review runs
   first, and an "Anthropic Verified" badge, if it ever comes, is a separate,
   additional review with no guarantee.

The claude.ai form (https://claude.ai/admin-settings/directory/submissions/plugins/new)
is the other door, but it needs a Team or Enterprise org, so it does not apply here.

## After it publishes

Updates pushed to `main` are picked up automatically: CI mirrors changes to the
public marketplace and re-screens on each update. There is no need to resubmit
the form when a skill changes or a new one lands. That is also why the manifests
must stay accurate: `.claude-plugin/marketplace.json` and
`plugins/neorgon-forge/.claude-plugin/plugin.json` are what the listing renders
from, not this file and not the GitHub description.

## Terms

Directory plugins must comply with the Anthropic Software Directory Terms and
Policy (linked from the submission doc above). This plugin ships instructions and
scripts, no telemetry and no bundled third-party software.
