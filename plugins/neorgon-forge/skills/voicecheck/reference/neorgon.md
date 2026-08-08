# Neorgon overlay — voicecheck

Read this only when working inside the Neorgon monorepo (`Documents/Projects/Personal`).
Everything here is local convention, not part of the portable skill.

## Detecting the overlay

```bash
[ -f PROJECTS.md ] && [ -d neorgon-site ] && echo "Neorgon monorepo"
```

If that is false, the baseline in `voice-defaults.md` is complete and nothing below applies.

## Chrome invariants (blocker, non-overridable)

These must read identically on all 40+ sites. A project's `VOICE.md` cannot override them.

| Invariant | Value |
|---|---|
| `og:site_name` | `Neorgon` — never `Energon` |
| Browser `<title>` | `Tool Name \| Descriptor` — pipe, never a dash |
| Footer attribution | `Part of Neorgon`, linking `https://neorgon.com/` |

The pipe is not only an anti-AI-tell: it also reads cleaner in search results, where the
title is truncated and a dash looks like a broken sentence.

## Source of truth

`PROJECTS.md` §3 (Brand Guide) and §6 (Copy Style Guide) are canonical for the suite voice.
`voice-defaults.md` restates those rules in checkable form. **If `PROJECTS.md` changes, update
`voice-defaults.md` to match** — the drift runs in that direction, and a stale baseline
silently passes copy that the brand guide now forbids.

## Projects that legitimately deviate

No project has a `VOICE.md` yet, so today the baseline is applied everywhere. These are the
sites whose register genuinely differs — an audit that flags their flavour as off-voice is
wrong, and each is a candidate for `teach`:

- **Themed:** `guild-hall-site` (Monster Hunter quest board), `questline-site` (NieR console),
  `resume-forge-site` (game stats), `minimap-site` (parody ARPG)
- **Bilingual:** `playbook-site`, `safeguard-site`, `parla-site`, `pieza-site` (ES + EN)

## Companion skill

`impeccable` owns *how it looks* and tracks design through a per-project `DESIGN.md`.
voicecheck is the same shape for copy. A finding about contrast, spacing or layout belongs
there, not in a voice audit.
