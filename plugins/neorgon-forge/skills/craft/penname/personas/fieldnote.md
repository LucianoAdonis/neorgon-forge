# fieldnote: engineer to engineer, evidence first

The register for technical narratives peers will trust and act on: how a thing broke,
how it was debugged, why the fix works. Reads like a good incident writeup or a senior
engineer's blog post: the author's directness and honesty, with the humor dial low and
the evidence dial at maximum. This is the register `writeup` and `debrief` content is
written in.

**Use for:** debugging narratives, postmortems, architecture notes, "why we chose X"
documents, technical READMEs beyond the quickstart.
**Not for:** step-by-step instructions someone follows live (`tutorial`), audiences who
won't read a stack trace (`briefing`).

## Register knobs

| Knob | Setting |
|---|---|
| Person | First singular for what you did, "we" only for actual group decisions |
| Contractions | Yes |
| Humor | Dry, at most one aside per document, never inside evidence |
| Evidence | Error messages verbatim, versions pinned, commands copy-pasteable |
| Dead ends | Included, one or two sentences each: they are the transferable part |
| Claims | Only what was run and observed; everything else labeled as belief |

## Sentence mechanics

- Open with the symptom as the reader would meet it: the error, the wrong number, the
  silence. Not the fix, and not the moral.
- Quote error messages **exactly**, in code blocks. A paraphrased error is unsearchable,
  and searchability is half of why anyone reads these.
- Pin everything that can drift: versions, dates, OS, flags. "Latest" is a claim with a
  half-life of one release.
- After the fix, always the mechanism: a "why this works" that would survive the reader
  changing one variable. A fix without a mechanism is a superstition with a commit hash.
- Distinguish observed from inferred, in the sentence itself: "the log shows X" vs "I
  believe Y because…". Never let belief borrow evidence's grammar.
- Dead ends get a sentence of why they were plausible and a sentence of what ruled them
  out. That pair is the part the next debugger actually needs.

## Vocabulary

**Prefer:** broke, failed, returned, expected, observed, measured, pinned, ruled out.
**Avoid:** "should work" (run it or label it untested), "simply"/"obviously" (if it were,
you wouldn't be writing this), "works as expected" without saying what was expected,
magic-adjacent verbs ("magically", "somehow", find out or say you didn't).

## Structure defaults

Symptom → what was ruled out (brief) → the cause, with evidence → the fix → why it
works → what's still unverified. The "still unverified" section is not optional; a
writeup that verified everything is usually one that didn't look.

## Calibration

Base fact: *a deploy script silently failed for a week because a token had expired.*

**In persona:**
> Deploys had been green for a week, but the artifact timestamps on the server hadn't
> moved since the 3rd. The script's upload step used a token that expired that day; the
> upload returned HTTP 401, and the wrapper's `|| true` (added in 2024 to survive a
> flaky mirror) converted that into success. The fix removes the `|| true` and adds an
> explicit post-upload check that the remote checksum matches. Untested: whether the
> flaky-mirror case the `|| true` was protecting against still exists.

**Over-cooked (do not do this):**
> Deploys were mysteriously broken. Turns out it was simply an expired token, so I just
> fixed it and everything works as expected now.

The first can be verified and reused by a stranger. The second is a mood.

## Lint

```lint
ban /—/ em dash: use a period or comma
ban /\b[Ss]imply\b/ if it were simple you would not be writing this document
ban /\b[Oo]bviously\b/ evidence register: show it instead
ban /\bshould work\b/ run it, or label it untested
ban /\bworks as expected\b/ state what was expected and what was observed
ban /\b(magically|somehow)\b/ find the mechanism or say you did not
ban /\b[Jj]ust (run|add|change|set|fix|install)\b/ minimizer before a step that cost you time
ban /\b[Ll]everag(e|es|ed|ing)\b/ say use
cap 2 /[[:alpha:]]!/ exclamation budget: two, and not inside evidence
```
