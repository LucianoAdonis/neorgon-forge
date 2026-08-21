---
name: groundwork
description: "Use before writing a tutorial, guide, or integration that promises steps, investigate what a service or tool actually requires: account and credential acquisition, prerequisites, versions, costs, rate limits, quotas, free-tier boundaries. Triggers on: 'what do I need to set up X', 'investigate the prerequisites for', 'find the limits of this API', 'can the free tier do this', 'what credentials does this need', 'how long until a first successful call'. Produces a dated requirements doc where every claim is labeled verified/documented/inferred. Not for writing the tutorial itself (penname's tutorial persona), not for security auditing (secret-safe-reporting), though it follows that skill's credential hygiene."
argument-hint: "[service or tool] [what the tutorial will promise]"
user-invocable: true
license: MIT
---

# groundwork: investigate before the tutorial promises

Investigates what a service actually requires and produces a requirements document a
tutorial can be built on. The failure mode it exists to prevent: a tutorial that
promises an unverified prerequisite fails its reader at step 1. The free tier that
quietly needs a credit card, the API key that takes a day of approval, the rate limit
that makes the example unusable. The writer paid those costs once and forgot them; the
reader pays them again, plus the trust.

## Step 1: Scope the promise

One paragraph before investigating anything: what will the tutorial claim the reader
can do at the end, starting from what baseline (OS, accounts they already have, budget,
skill level)? The promise decides what needs verifying, "send one test SMS" and "run
an SMS campaign" have different credential tiers, different limits that matter, and
different costs. An investigation without a promise collects everything and answers
nothing.

## Step 2: Walk the acquisition path yourself

For every account, credential, and tool the promise needs, walk the path the reader
will walk: sign-up → verification → credential creation → **first successful call**.
Record what you actually saw:

- Each decision point with its options ("scope: read-only vs full. The tutorial needs
  read-only"), because the reader stalls at every fork you don't pre-answer.
- Every wait: email verification, manual approval, KYC, "provisioning". These dominate
  time-to-first-success and are the thing writers forget first.
- The exact first call that proves the credential works, with its expected response
  shape.

Where you cannot walk it (payment required, KYC, region lock), say so and label the
whole branch `documented` with the source. Never invent the middle of a path you only
read about.

## Step 3: Find the limits before the reader does

Hunt the boundaries the tutorial's promise will hit: rate limits, quotas, size caps,
expiry windows, free-tier walls, region and version constraints. For each, record four
things: **value, scope, source, date checked**, in the template's limits table.
Prefer *provoking* a limit over reading about it: send request N+1, watch the 429, and
quote its body verbatim. A provoked limit is `verified`; a pricing-page limit is
`documented` and gets re-checked at publish time, because pricing pages drift faster
than docs.

## Step 4: Keep the dead ends

Every error you hit during the walk goes in the doc verbatim, with what caused it and
what fixed it. Dead ends are not investigation waste; they are the tutorial's Gotchas
section, pre-written, and they are searchable in a way paraphrases are not.

## Step 5: Emit the requirements doc

Fill `reference/requirements-template.md`. The doc's job is to be *consumable by the
tutorial writer* (possibly a later session with none of this context): every claim
labeled, every limit dated, time-to-first-success stated honestly including the waits,
and a named re-verification trigger.

## The doc proves itself: docrun and stale

Two scripts keep a requirements doc honest after it ships:

```bash
bash "$FORGE/skills/groundwork/scripts/docrun.sh" <doc.md>          # list the runnable blocks
bash "$FORGE/skills/groundwork/scripts/docrun.sh" <doc.md> --run    # execute them, in order, in one shell
bash "$FORGE/skills/groundwork/scripts/stale.sh" <dir> --days 90    # dated claims past the threshold
```

`docrun` executes the doc's fenced bash blocks in a single shell (exports and `cd`
carry across blocks, as they do for a reader) and reports the first failing block
with its doc line: the mechanical upgrade from `documented` to `verified`. It is
safe by default: listing is the default mode, ` ```bash norun ` marks blocks that
must never execute, and `--run` runs with *your* shell privileges in a scratch
workdir, so read the doc before running one you did not write. `stale` reports every
dated claim older than the threshold as `file:line`. The enforcement half of "a
limit without a date is a rumor". Both exit 0/1/2, and 2 means nothing was checked.

## The label ladder: the judgment that makes the doc trustworthy

| Label | Means | Earned by |
|---|---|---|
| `verified` | You did it and saw the result | Running it, on a named setup, this investigation |
| `documented` | An authoritative source says so | Official docs/pricing, with URL and date |
| `inferred` | You concluded it from adjacent facts | Stated reasoning, and it says "inferred" |

Labels never move up without re-doing the work: quoting a `documented` claim in three
docs does not make it `verified`. A limit without a date is a rumor with formatting.
And time-to-first-success is the number that matters most, measure it as the reader's
clock (including sign-up waits), not as your clock resuming a half-configured account.

## Credential hygiene

The investigation handles real credentials; the document never does. Placeholders are
synthetic and the right *shape* (`AKIAFAKEFAKEFAKEFAKE`, `act_0000000000000000`), never
a real value and never a truncated real value, truncation is not redaction. If the
investigation's scratch files touched real secrets, they stay out of the doc and out of
git; `secret-safe-reporting`'s sweep covers the repo before any first push.

## Invariants

- **Every limit carries value, scope, source, and date.** Undated limits do not ship.
- **Labels are earned, never inherited.** Re-verify or keep the lower label.
- **Walked paths only.** The middle of a path you didn't walk is `documented`, not
  narrated as if you did.
- **Dead ends ship verbatim.** They are the most reusable output of the investigation.
- **No real credential material in the doc, ever**: synthetic same-shape placeholders
  only.
