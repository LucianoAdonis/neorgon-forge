# Requirements template

Copy into the project as `groundwork-<topic>.md` (or directly as a topic folder's
`CONTEXT.md`: see the mapping note at the end). Delete sections that genuinely don't
apply; a deleted section reads as "not applicable", an empty one reads as "not
investigated".

```markdown
# Groundwork: <service/tool>, <the tutorial's promise>

**Investigated:** YYYY-MM-DD on <OS/setup> · **Investigator's clock:** <total hands-on time>
**Time-to-first-success (reader's clock):** <estimate, including sign-up and approval waits>
**Re-verify when:** <the trigger: a version bump, a pricing-page change, a date>

## The promise

<One paragraph: what the reader can do at the end, from what baseline.>

## What you need

| Item | Version/tier | Cost | Label |
|---|---|---|---|
| <account> | <free tier / paid plan> | <$ or free> | verified/documented |
| <tool> | <pinned version> | none | verified |

## Credential acquisition: the walked path

1. <step, with the exact screen/menu names>: *<wait time if any>*
   - Decision point: <the fork and which option the promise needs>
2. …
N. First successful call:
   ```bash
   <the exact command, with synthetic same-shape placeholders only>
   ```
   Expected response: <shape/status>

<For any branch not walked: "Not walked (<reason>); per <source URL, YYYY-MM-DD>: …">

## Limits that matter to the promise

| Limit | Value | Scope | Source | Checked | Label |
|---|---|---|---|---|---|
| <rate limit> | <n/min> | <per key/per account> | <URL or "provoked, response below"> | YYYY-MM-DD | verified |
| <free-tier wall> | <n/month> | <per account> | <pricing URL> | YYYY-MM-DD | documented |

## Gotchas (dead ends, verbatim)

### <what you were trying>
```
<the exact error>
```
Cause: <…> · Fix: <…>

## What NOT to do

- <the tempting wrong turn and why it costs the reader>

## Sources

- <URL>: <what it backs>, accessed YYYY-MM-DD

## Open / unverified

- <the claim you could not verify, its label, and what verifying it would take>
```

## Mapping to a writing repo's CONTEXT.md

Repos using a per-topic `CONTEXT.md` for AI-assisted editing consume this directly:
"What you need" covers *Technical Specifications/Versions*, "Gotchas" covers *Common
Pitfalls*, "What NOT to do" maps by name, and the promise paragraph covers *Target
audience*. Keep the labels and dates when converting. They are the part a plain
CONTEXT.md lacks, and the reason the tutorial can say when it was last true.
