# secret-safe-reporting

Pipelines that read sensitive data and produce output other people will see, designed so the
output cannot carry the input.

## What it does

`secret-safe-reporting` covers the design, the fixtures, the enforcement, and a pre-push sweep
for any scanner, report, or test suite that touches secrets, credentials, or personal data.

The defining constraint is structural rather than procedural: **the verdict propagates, the
input does not**. No type downstream of the check has a field the sensitive value could occupy.
Redaction applied at the point of output is a filter that can be forgotten; a type with nowhere
to put the value cannot.

## When to reach for it

Type `/secret-safe-reporting`, or the agent reaches for it when a design involves scanning,
logging, or reporting on data that must not leak.

Reach for it before the pipeline is written, and again before a repo's first push to a new
remote. That asymmetry is the whole argument for the sweep: a credential found in unpushed
history is a squash, and found after the push it is a rotation.

## Fixtures are where it usually goes wrong

No observed value appears in a fixture or a document, whole or truncated. A truncated secret is
still a secret, and a real value in a test file is a real value in the repository forever.
Substitutes are synthesized to the same shape and made to look synthetic.

The canary suite needs a negative control and an entity-decode pass. Without the negative
control you cannot tell a working detector from one that says "clean" unconditionally, which is
worse than none because it gets quoted.

## It's working if

- The type signatures make the leak impossible, rather than a comment asking you not to.
- The canary suite fails when you deliberately break the detector.
- A fixture reads as obviously fake at a glance.
- The sweep runs before the first push, not after someone asks about it.
