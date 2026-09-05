---
name: secret-safe-reporting
description: "Use when building anything that reads sensitive data and produces output others will see, and before a repo's first push to a new remote. A secrets/credentials scanner, a compliance dashboard, a PII audit, an error reporter that touches user content, an LLM trace viewer, tests written against real observed data. Triggers on: 'report on secrets', 'scan for credentials', 'sweep this repo before I push', 'check the history for secrets', 'don't leak PII into the report', 'write tests for the classifier'. Covers the boundary architecture that makes leaks structurally impossible, classifier ordering, synthetic fixtures, canary enforcement, and the pre-publish history sweep. Not for rotating an already-leaked credential (that is incident response, rotation comes first). It designs the pipeline gitleaks and trufflehog double-check in CI, and owns the pre-push sweep they run too late to catch."
argument-hint: "[design|fixtures|enforce|sweep] [target]"
user-invocable: true
license: MIT
---

# secret-safe-reporting: reports about sensitive data that cannot leak it

Any pipeline that classifies sensitive data and reports on it will, by default, leak the
data into the report: in fixtures, in "sample value" tables, in error messages, in git
history. The failure mode is specific and observed: a session that spent the day writing
*rules against leaking secrets* also hard-coded nine live production credentials into test
fixtures and put 22-character prefixes of six more into a baseline document. Understanding
the rule does not prevent the violation; only structure and mechanical checks do.

The rule, once: **classify at the trust boundary and propagate the verdict, never the
input.** Everything below is that rule applied to four places a value tries to escape.

## Step 1: Design the boundary so the leak has nowhere to live

At the point where sensitive data enters, classify it and hand downstream a type that
**has no field the sensitive value could occupy**:

```
classify(key, value) -> { sensitive, shape, matchedBy, length }
```

The verdict never echoes the input. Downstream code cannot leak what it was never given,
there is no redaction step because nothing needs redacting.

Why this beats sanitize-on-output: stripping sensitive fields before emitting fails the
first time someone adds a field and forgets, and it fails silently. Narrowing at the
boundary makes the safe state the default; introducing a leak then requires deliberately
threading a value through every layer, which is visible in review.

Make the downstream contract explicit: an **allow-list of fields**, asserted in a test, so
a new field fails the build even when its first fixture is benign.

## Step 2: Order the classifier so exclusions cannot shadow detections

In any classifier mixing "this is sensitive" patterns with "this is benign" exclusions,
**ordering is load-bearing and the natural order is wrong.** Two observed instances of the
same bug: a monitoring-family exclusion `/^dd_/` checked first preserved `DD_API_KEY`,
2,746 occurrences of a live 32-char hex key, in the clear; and a common-word value list
containing `test` made `isSensitive('passwd', 'test')` return false.

| May run before the sensitive check | Must run after |
|---|---|
| Value shapes that **structurally prove** non-secrecy: ARN, boolean, port number, region name, enum from a closed set | Key-family prefixes (`^dd_`, `^aws_`). A family tells you the vendor, not the sensitivity |
| | Common-word value lists: an English word can be a password |
| | Anything heuristic ("looks like a config flag") |

The rule to encode: **deny-by-name outranks allow-by-family**, and an allow may precede a
deny only when the allow is a structural proof rather than a heuristic. A port cannot be a
credential whatever its key is named; that is what "structural" means, and nothing weaker
qualifies.

## Step 3: Fixtures and documents never carry the observed value

When writing tests or docs against real observed data:

- **Never inline the observed value.** Synthesize a same-shape substitute:
  `00000000feed0000face0000cafe0000` is a valid hex-32 and reads as obviously synthetic at
  a glance: that legibility is the point. `reference/shapes.md` gives a substitute recipe
  per shape.
- **Truncation is not redaction.** A ≥12-character fragment of a high-entropy value is a
  partial disclosure: 22 chars of a 32-char hex key leaves ~40 bits, which is
  brute-forceable. A "Sample Sensitive Values" table of prefixes is a leak that reads as
  caution.
- **A high-entropy literal in a test is a finding by default**, hex-32/40/64, base64
  blobs, JWT shape, connection strings with credentials. If it is genuinely synthetic,
  make it *look* synthetic.

## Step 4: Enforce with a canary, not with review

A fuzz test across the whole pipeline: inject values of every shape at the boundary,
assert none reaches the output. Two details make this real rather than theatre, and both
are non-negotiable:

1. **A negative control.** One case plants a canary directly in the output and asserts the
   detector *sees* it. Without this, a broken detector passes everything and the suite is
   green forever.
2. **An entity-decode pass.** HTML escaping hides a leaked value from a raw substring
   match: decode the output before searching, or the leak ships encoded and renders
   decoded.

## Step 5: Sweep before anything is published

```bash
bash "$FORGE/skills/secret-safe-reporting/scripts/sweep.sh" [dir]           # working tree + index
bash "$FORGE/skills/secret-safe-reporting/scripts/sweep.sh" [dir] --history # every commit, before a first push
```

`.gitignore` does nothing for an already-tracked file, and a value deleted in a later
commit is still in history. Before a repo's **first** push to a new remote, sweep history,
not just the tree: after that first push, history is public and unrecoverable. Two of
twenty commits in the observed session carried live AWS keys and a MongoDB URI; caught
pre-push, it was a squash. Post-push it would have been a rotation.

If the sweep fires on history that was already pushed, the value is burned: **rotate it**,
then clean history. Cleaning without rotating is theatre.

## The same rule, other vocabularies

The architecture generalizes past secrets; only the shape vocabulary changes.

| Domain | The value that must not reach the report |
|---|---|
| Analytics | PII: emails, names, addresses |
| Error reporting | User content in messages and stack locals |
| LLM operations | Prompt/response text in traces and evals |

## Honest limits

State these in whatever you build, because a reader will otherwise assume more than is
true: the classifying process still reads plaintext. This protects the *output*, not the
process. Key *names* pass through unguarded, and a name can itself disclose ("STRIPE_
PROD_KEY" says a Stripe prod key exists). Retained `length` is a small, real disclosure,
keep it only if something downstream uses it.

## Invariants

- **The verdict propagates; the input does not.** No downstream type has a field the
  sensitive value could occupy.
- **Deny-by-name outranks allow-by-family.** Only structural proofs may run before the
  sensitive check.
- **No observed value in a fixture or document, whole or truncated.** Synthesize
  same-shape substitutes that look synthetic.
- **The canary suite has a negative control and an entity-decode pass.** Without both it
  is theatre.
- **History is swept before a first push; a pushed secret is rotated, not just removed.**
