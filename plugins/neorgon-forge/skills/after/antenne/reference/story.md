# The story: shape, caps, and the one command that sends it

Read this when you are about to write the JSON, and only then.

**The monorepo's `.claude/commands/newsroom.md` is canonical.** When the repo you are in sits
under a checkout that has it, open it and follow it: its hard rules 1 to 3, its kinds, its copy
rules and its schema are the rule set three enforcers already agree on. What is below is the
same thing written down for the case where that file is not beside you, plus the parts this
skill owns: one story instead of a sweep, and the exact runner.

## Schema, one JSON file per story

```json
{
  "id": "YYYY-MM-DD-kebab-slug",
  "date": "YYYY-MM-DD",
  "kind": "launch | feature | fix | note",
  "site": "project-id, or null for fleet-wide",
  "title": "Short, concrete, news-style",
  "summary": "One or two sentences that stand alone",
  "body": ["paragraph", "paragraph"],
  "links": [{ "label": "Open X", "url": "https://x.neorgon.com/" }],
  "tags": ["kebab", "tags"]
}
```

## Caps, checked in submit mode before anything is sent

| Field | Rule |
|---|---|
| `id` | `a-z`, `0-9` and hyphens, 1 to 80. It starts with the story's own `date` and a hyphen |
| `date` | A real calendar date, between 60 days ago and tomorrow, counted in UTC by the server |
| `kind` | One of `launch`, `feature`, `fix`, `note` |
| `site` | The registry id, or `null` for fleet-wide |
| `title` | 1 to 100 characters, one line |
| `summary` | 1 to 320 characters, one line, and it has to carry the story on its own |
| `body` | At most 5 paragraphs of at most 900 characters |
| `links` | At most 6, labels of at most 40 characters |
| `url` | `https://` on `neorgon.com`, a `*.neorgon.com` host, or `github.com/energon-a-secas/`. Any other host refuses the story |
| `tags` | At most 8 unique tags of `a-z`, `0-9` and hyphens, up to 32 characters |
| Every field | No em dash, no control character, and nothing that looks like a token or a key |

Copy rules: no em dashes, no powerful, seamless, leverages, robust or utilize, active verbs,
short sentences. Tone is the feed's own: factual, with a wink. Body is one to three short
paragraphs. The summary is what an embed shows on its own, so it has to work without the body.

## Where the file goes

A scratch directory **outside every repo**, because the Antenne repo is public and so is every
site repo beside it. The session's scratchpad when the harness names one, otherwise:

```bash
bash "$FORGE/skills/antenne/scripts/submit.sh" scratch
```

Each story is `<scratch>/<id>.json`. Never write one under the Antenne checkout.

## The runner, exactly

Both commands go through the root's trust wrapper, never at the client directly, because the
Antenne repo is public and more than the owner can push to its main branch:

```bash
python3 scripts/antenne_trust.py run projects/dispatch-site scripts/submit-drafts.py --dry-run <scratch>/<id>.json
python3 scripts/antenne_trust.py run projects/dispatch-site scripts/submit-drafts.py <scratch>/<id>.json
```

`submit.sh check` and `submit.sh send` run exactly these, with the project folder resolved as
`projects/antenne-site` when the rename has landed and `projects/dispatch-site` while it has
not. Use the wrapper rather than typing these by hand: it refuses a story file that lives
inside a repo, it stops a send that has no key before the client is reached, and it turns each
exit code into a sentence.

## Outcomes, per id

| Outcome | Meaning |
|---|---|
| `created` | A new draft is waiting at the desk |
| `updated` | It replaced a pending draft nobody had touched |
| `unchanged` | Already queued with the same text |
| `kept-human-edits` | A reviewer had already edited it, and their copy stands |
| `already-decided`, `published` | Past review, nothing changed |
| `invalid` | The server refused it. Fix that story and submit it again |
| `queue-full` | The queue holds as many machine drafts as it allows. Stop, and ask the operator to work through the desk first |

Exit 0 means every story landed. Any other exit comes with one line on stderr: report it and
stop. Never retry in a loop, and never run the pin command to get past a refusal.
