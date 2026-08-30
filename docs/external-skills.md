# Skills named here that do not live here

A `SKILL.md` description earns its keep by saying what the skill is **not** for, and the
sharpest way to say that is to name the skill that is. Eight of those names point outside this
plugin. That is legitimate: the fleet has skills beyond the forge, and a reader who has them
is better served by the name than by a vague gesture.

What is not legitimate is the reader who does **not** have them, who follows a name into
nothing. So every external name is declared here, `bin/coverage.py` fails on one that is not,
and the same check catches the real hazard the declaration exists to distinguish from: a
description still routing to a forge skill that was renamed.

| Name | What it is | Named by |
|---|---|---|
| `code-review` | A monorepo slash command at `.claude/commands/code-review.md`, not a skill | closeout, grill, task |
| `impeccable` | A separate user skill for visual design review | tabletop |
| `favicon` | A separate user skill that resizes art into icon files | brandmark |
| `mermaid-diagrams` | A separate user skill for diagram syntax | atlas |
| `c4-architecture` | A separate user skill for C4 model diagrams | atlas |
| `commit-work` | A separate user skill for commit hygiene | debrief |
| `copywriting` | A separate user skill for marketing copy | voicecheck |
| `crafting-effective-readmes` | A separate user skill for README structure | writeup |

Adding a row is the cheap half. Before you do, check the harder question: a name only belongs
in a description when a reader is genuinely better off knowing it. If the skill is obscure, or
only you have it, say what the boundary is instead of who owns it.
