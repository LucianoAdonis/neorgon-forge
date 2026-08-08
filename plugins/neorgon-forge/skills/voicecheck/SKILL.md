---
name: voicecheck
description: "Use when the user wants to write, audit, align, critique, or fix the VOICE, TONE, or COPY of a site, app, or doc. Covers headlines, meta descriptions, header subtitles, button labels, empty states, error messages, onboarding copy, README prose, and marketing text. Keeps voice consistent across many projects by reading a per-project VOICE.md, falling back to a checkable baseline when there is none. Triggers on: 'does this sound on-brand?', 'audit the copy', 'align this to our voice', 'strip AI-isms', 'rewrite this headline', 'is our tone consistent across sites?', 'this reads like ChatGPT wrote it'. Not for visual or layout work, and not for deciding what a feature does — only how it reads."
argument-hint: "[audit|align|teach|detox|diff] [target]"
user-invocable: true
license: MIT
---

# voicecheck — voice and copy consistency

Owns *how it reads*. It never guesses the voice: it loads a context file, applies rules
that can actually be checked, and reports `file:line` rather than impressions.

The failure mode it exists to prevent is drift. Copy written one screen at a time by
different sessions converges on the same generic register, and forty products stop
sounding like one product. Nobody notices from inside a single file.

## Step 1 — Load the voice (always first)

```bash
bash "$FORGE/skills/voicecheck/scripts/load-voice.sh" <project-dir>
```

Prints, in precedence order: the project's `VOICE.md` if one exists, then the baseline in
`reference/voice-defaults.md`, which always applies. Consume the whole output. If the
loader output is already in this session's history, do not re-run it.

A missing `VOICE.md` is not a blocker — the baseline *is* the standard every project must
meet. Only run `teach` when a project genuinely deviates: bilingual copy, a themed
register, a different audience.

**Then check for a local overlay.** `reference/neorgon.md` holds the suite chrome rules
that are true of the Neorgon monorepo and nowhere else. Read it when working there; skip
it entirely otherwise, and treat the baseline as complete.

## Step 2 — Pick the command

Default with no command is `audit`.

### `audit <target>`

Read-only. Report every violation as `file:line` · the offending text · the rule it
breaks · the fix, without applying it. Group by severity:

| Severity | What lands here |
|---|---|
| **blocker** | Banned words, em dashes, a broken chrome invariant |
| **warning** | Passive lead, over-length meta description or subtitle |
| **nit** | Weak verb, hype-adjacent phrasing, hedging |

End with one line: `on-voice` / `needs-alignment` / `off-voice`. An audit that finds
nothing is a result too — say so rather than padding the list with nits.

### `align <target>`

Apply what `audit` would report. Rewrite in place, preserving meaning and the author's
intent, and show a before/after per change. Preserving intent is the constraint that
matters: a rewrite that reads better and says something different is a defect, not a fix.

### `teach <project-dir>`

Interview to author a project `VOICE.md`. **One question at a time** — audience, register,
banned and blessed words beyond the baseline, bilingual needs, one example on-voice
sentence. Write it using `reference/voice-md-template.md`.

### `detox <target>`

Strip AI-writing tells only, and nothing else: em and en dashes, rule-of-three cadence,
inflated symbolism, hedging, "it's not just X, it's Y". Narrower than `align` on purpose —
it is the command for copy that is factually fine but reads synthetic.

### `diff <projectA> <projectB>`

Compare two projects' user-facing copy — headlines, subtitles, empty states, CTAs. Report
where they drift and which is closer to the baseline. This is the only command that can
catch fleet-wide drift, because drift is invisible from inside one project.

## Delegate the rewriting when a specialist is installed

voicecheck orchestrates. When a rewrite needs a specialist and one is available, hand it
the text **plus the loaded voice constraints**, then re-audit the result before accepting
it — a general rewriter does not know the banned-word list.

| Need | Delegate to |
|---|---|
| Remove AI-isms | `avoid-ai-writing` |
| Strip AI cadence, inflated symbolism | `humanizer` |
| Grammar and clarity, voice preserved | `professional-proofreader` |
| Tighten wordy prose | `writing-clearly-and-concisely` |
| UI microcopy | `ux-copy` |

None of these are required. If a skill is not installed, do the rewrite here against the
same rules — the rules live in `reference/voice-defaults.md`, not in the delegate.

## Invariants

- **Load context before judging.** An audit against a remembered voice is an opinion.
- **Report `file:line`.** A finding nobody can locate does not get fixed.
- **Project `VOICE.md` wins over the baseline** — except for chrome invariants an overlay
  declares non-overridable, which are global by definition.
- **`audit` never writes.** Separating the report from the rewrite is what makes it safe
  to run on copy that is not yours.
- **Preserve meaning.** Voice work changes how a sentence reads, never what it claims.
