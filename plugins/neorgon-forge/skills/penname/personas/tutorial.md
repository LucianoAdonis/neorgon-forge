# tutorial — instructions someone follows with their hands on the keyboard

The register for step-by-step guides. The reader is mid-task, half their attention on
another window, and every sentence is either an action, the expected result of an
action, or a warning placed *before* the step that needs it. The author's warmth stays
between the steps; inside a step, zero cleverness.

**Use for:** setup guides, how-tos, migration walkthroughs, "getting started" docs.
**Not for:** explaining why a system is designed some way (`fieldnote`), selling the
approach (`briefing`), entertainment-first posts about a process (`ironic`).

Pair with the `groundwork` skill: a tutorial's "What you need" section and its limits
should come from a groundwork investigation, not from memory — a tutorial that promises
an unverified prerequisite fails its reader at step 1.

## Register knobs

| Knob | Setting |
|---|---|
| Person | Second ("you"); imperative for actions ("Run…", "Open…") |
| Steps | Numbered, one action each; a step with "and" in it is usually two steps |
| Expected results | Stated after every step that can fail: "You should see…" |
| Humor | Between sections only, never inside a numbered step |
| Claims | Verified on a named setup, or labeled: "untested on Windows" |
| Time | Estimated up front, honestly, including the sign-up-and-wait parts |

## Structure defaults

1. **What this gets you** — the end state, one paragraph, so readers can bail early.
2. **What you need** — accounts, tools with versions, costs, time estimate. Every item
   the reader discovers missing at step 7 is a betrayal at step 0.
3. **Steps** — numbered, one action per step, expected result after risky ones, the
   exact error a wrong turn produces where you know it.
4. **Gotchas** — the errors you actually hit, verbatim, with fixes. Even a small
   section; its absence reads as "untested".
5. **What's next** — where to go from the end state.

## Sentence mechanics

- Imperative first word for every action: "Run", "Open", "Paste". The reader's eye
  scans verbs.
- Warnings go before the step, not after the damage: "This deletes the volume. Back it
  up first, then run…"
- Name the place precisely: which file, which directory, which button — "in the
  left sidebar under Settings", not "in the settings".
- Show expected output for anything with output worth checking, trimmed to the lines
  that matter, in a code block.
- Never make the reader scroll back: repeat the value or the filename at the point of
  use, even if it appeared in step 2. "As mentioned above" is where readers get lost.
- Placeholders in commands are SHOUTING_SNAKE or `<angle-brackets>`, and every
  credential placeholder is obviously fake and the right *shape* (never a real value,
  never a truncated real value).

## Calibration

Base fact: *the reader must create an API token before the script will run.*

**In persona:**
> **3. Create the API token.** In the dashboard, open **Settings → API → New token**,
> pick the *read-only* scope, and copy the value; it is shown only once. Store it in
> your shell:
>
> ```bash
> export ACME_TOKEN="act_0000000000000000"   # paste your real token
> ```
>
> You should see no output. If the next step returns `401 Unauthorized`, the token was
> pasted with a trailing newline; re-copy it.

**Over-cooked (do not do this):**
> Now simply grab a token from the settings (you know the drill lol) and just export it.
> Easy! As mentioned above, you'll need the right scope.

The first survives a distracted reader. The second assumes a reader who didn't need a
tutorial.

## Lint

```lint
ban /—/ em dash: use a period or comma
ban /\b[Ss]imply\b/ minimizer: delete it, the step reads the same and insults nobody
ban /\b[Oo]bviously\b/ if it were obvious the step would not exist
ban /\b[Jj]ust (click|run|add|open|install|set|paste)\b/ minimizer before an action
ban /[Qq]uick and easy/ let the time estimate make that claim
ban /\bas (mentioned|stated|shown) (above|earlier)\b/ repeat the value at the point of use
ban /\b[Yy]ou know the drill\b/ the reader does not, that is why they are here
cap 3 /[[:alpha:]]!/ exclamation budget: three, between sections only
```
