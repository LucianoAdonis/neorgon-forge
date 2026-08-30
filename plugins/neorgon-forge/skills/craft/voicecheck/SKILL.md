---
name: voicecheck
description: "Use when the words need work, headlines, meta descriptions, subtitles, button labels, empty states, error messages, onboarding copy, README prose, marketing text. Triggers on: 'audit the copy', 'ai slop', 'run ai-detox on this', 'this reads like ChatGPT wrote it', 'review the tone and style across the site', 'does this sound on-brand?', 'rewrite this headline', 'strip the AI-isms', 'is our tone consistent across sites?', 'keep the style and tone in the translation'. Loads a per-project VOICE.md before judging anything, falls back to a checkable baseline when there is none, and reports file:line rather than impressions. Also compares projects, since voice drift is invisible from inside one repo. Wraps ai-writing-detox and humanizer rather than replacing them. It loads the voice they do not know about, then delegates. Not for writing new marketing copy from a brief (use copywriting), not for visual or layout work, and not for deciding what a feature does, only how it reads."
argument-hint: "[audit|align|teach|detox|diff] [target]"
user-invocable: true
license: MIT
---

# voicecheck: voice and copy consistency

Owns *how it reads*. It never guesses the voice: it loads a context file, applies rules
that can actually be checked, and reports `file:line` rather than impressions.

The failure mode it exists to prevent is drift. Copy written one screen at a time by
different sessions converges on the same generic register, and forty products stop
sounding like one product. Nobody notices from inside a single file.

## Step 1: Load the voice (always first)

```bash
bash "$FORGE/skills/voicecheck/scripts/load-voice.sh" <project-dir>
```

Prints, in precedence order: the project's `VOICE.md` if one exists, then the baseline in
`reference/voice-defaults.md`, which always applies. Consume the whole output. If the
loader output is already in this session's history, do not re-run it.

A missing `VOICE.md` is not a blocker: the baseline *is* the standard every project must
meet. Only run `teach` when a project genuinely deviates: bilingual copy, a themed
register, a different audience.

**Then check for a local overlay.** `reference/neorgon.md` holds the suite chrome rules
that are true of the Neorgon monorepo and nowhere else. Read it when working there; skip
it entirely otherwise, and treat the baseline as complete.

## Step 2: Pick the command

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
nothing is a result too: say so rather than padding the list with nits.

### `align <target>`

Apply what `audit` would report. Rewrite in place, preserving meaning and the author's
intent, and show a before/after per change. Preserving intent is the constraint that
matters: a rewrite that reads better and says something different is a defect, not a fix.

Its only stated scope was semantic ("user-facing copy"), which is a judgment the rewrite
makes about itself. The byte-level version, because a banned-word substitution inside an
`href` or a class name breaks a live site while the audit report shows nothing:

- **The text surface**, which `align` and `detox` may rewrite: visible text nodes, the
  `content=` of description / `og:` / `twitter:` metas, the text of `<title>`, the values of
  `alt` / `aria-label` / `placeholder` / `title`, and user-visible string literals in JS.
- **Not the text surface**, ever: attribute *names*, `class` / `id` / `data-*` values,
  `href` / `src` / `srcset`, anything inside `<script>` or `<style>`, fenced and inline code
  in Markdown, version and date stamps, and JSON or YAML *keys* and i18n message ids.
- **File type decides nothing.** A large share of this fleet's user-facing copy lives in
  `.yaml` and `.json`: slides decks, Proctor exams, Resume Forge documents. The rule is the
  surface, not the extension.

### `teach <project-dir>`

Interview to author a project `VOICE.md`. **One question at a time**, audience, register,
banned and blessed words beyond the baseline, bilingual needs, one example on-voice
sentence. Write it using `reference/voice-md-template.md`.

### `detox <target>`

Strip AI-writing tells only, and nothing else: em and en dashes, rule-of-three cadence,
inflated symbolism, hedging, "it's not just X, it's Y". Narrower than `align` on purpose,
it is the command for copy that is factually fine but reads synthetic.

### `diff <projectA> <projectB>`

Compare two projects' user-facing copy: headlines, subtitles, empty states, CTAs. Report
where they drift and which is closer to the baseline. This is the only command that can
catch fleet-wide drift, because drift is invisible from inside one project.

## Delegate the rewriting when a specialist is installed

voicecheck orchestrates. When a rewrite needs a specialist and one is available, hand it
the text **plus the loaded voice constraints**, then re-audit the result before accepting
it: a general rewriter does not know the banned-word list.

| Need | Delegate to |
|---|---|
| Remove AI-isms | `avoid-ai-writing` |
| Strip AI cadence, inflated symbolism | `humanizer` |
| Grammar and clarity, voice preserved | `professional-proofreader` |
| Tighten wordy prose | `writing-clearly-and-concisely` |
| UI microcopy | `ux-copy` |

None of these are required. If a skill is not installed, do the rewrite here against the
same rules: the rules live in `reference/voice-defaults.md`, not in the delegate.

## Invariants

- **`align` and `detox` rewrite prose, never structure.** A rewrite that changes a byte
  outside the text surface is a defect even when the copy improved. This applies to a
  rewrite you delegate and to one you make yourself; re-audit either before accepting it.
- **Load context before judging.** An audit against a remembered voice is an opinion.
- **Report `file:line`.** A finding nobody can locate does not get fixed.
- **Project `VOICE.md` wins over the baseline**: except for chrome invariants an overlay
  declares non-overridable, which are global by definition.
- **`audit` never writes.** Separating the report from the rewrite is what makes it safe
  to run on copy that is not yours.
- **Preserve meaning.** Voice work changes how a sentence reads, never what it claims.
