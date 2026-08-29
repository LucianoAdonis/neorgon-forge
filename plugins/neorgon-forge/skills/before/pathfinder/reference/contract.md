# The canvas contract, condensed

The authoritative copy is https://pathfinder.neorgon.com/llms.txt; this crib
carries what emitting a canvas needs. When the two disagree, llms.txt wins.

## Shape

```json
{
  "blocks": [
    {
      "id": "b1", "type": "goal", "title": "Short imperative phrase",
      "description": "One or two sentences.", "notes": "",
      "x": 0, "y": 0,
      "actions": ["validate"],
      "questions": [{ "text": "Open question?", "answer": "" }],
      "criteria": ["short definition-of-done strings"],
      "rationale": "decisions only: why, and what was rejected",
      "priority": "high", "status": "in-progress"
    }
  ],
  "arrows": [
    { "id": "a1", "from": "b1", "to": "b2", "label": "depends on", "style": "routed" }
  ],
  "groups": [{ "id": "g1", "label": "Phase 1" }],
  "meta": {
    "title": "Canvas title",
    "contextBrief": "One or two lines of framing",
    "prompt": { "mode": "investigate", "tone": "auto", "detail": "standard", "pre": [] },
    "situation": {
      "codebase": "current", "runtime": "code", "firstMove": "read",
      "repoHint": "org/repo", "constraints": "One boundary per line"
    }
  }
}
```

Only `id`, `type`, `title`, `x`, `y` are required per block; `from`/`to` per
arrow. Unknown fields and enum values are dropped on import, not rejected.
Rough positions are fine; the app's Tidy lays the graph out.

## Enums

- `type`: `goal` `problem` `requirement` `assumption` `risk` `decision`
  `question` `resource` `output` `process` `terminator` `context` `custom`
- `actions`: `resolve` `prepare` `recollect` `reinforce` `validate`
- `priority`: `high` `medium` `low` · `status`: `not-started` `in-progress`
  `done` `blocked`
- `arrows[].style`: `routed` (default) `curved` `straight` `elbow` `dashed`
  `dotted`
- `meta.prompt.mode`: `plan` `investigate` `explore` `build` `clarify`
- `meta.prompt.tone`: `auto` `formal` `casual` `technical` ·
  `detail`: `standard` `brief` `detailed` ·
  `pre`: `tasks` `edge` `errors` `docs` `security` `typescript`
- `meta.situation.codebase`: `none` `current` `other` `greenfield` ·
  `runtime`: `chat` `code` `ide` · `firstMove`: `read` `ask` `plan` `act`

## Semantics that matter

- `assumption` = acted on without checking; `question` = known unknown. The
  export pressure-tests the first and answers the second.
- `criteria` belong on `requirement` / `goal` / `output`; `rationale` on
  `decision`. They feed the prompt, tasks.md and the EARS export.
- Do not encode meaning in `highlight`; it is presentation only.

## The patch (writing results back)

End a reply to an exported brief with a fenced block; the app previews and
applies it as one undo step. Address blocks by the ids the prompt lists.

```pathfinder-patch
{
  "format": "pathfinder-patch",
  "version": 1,
  "note": "one line the human sees first",
  "answers":  [{ "block": "b3", "question": 0, "answer": "..." }],
  "verify":   [{ "block": "b5", "verdict": "verified|refuted", "evidence": "required" }],
  "status":   [{ "block": "b2", "status": "done" }],
  "criteria": [{ "block": "b4", "add": ["..."] }],
  "notes":    [{ "block": "b2", "note": "appends to block notes, prefixed Review:" }],
  "blocks":   [{ "id": "n1", "type": "problem", "title": "..." }],
  "arrows":   [{ "from": "n1", "to": "b2", "label": "explains" }]
}
```

A `verify` turns the assumption into a decision in place (arrows survive);
evidence is required. Never patch in answers you do not have; an empty patch
is a valid reply.

## Links

- Share link: `https://pathfinder.neorgon.com/?via=<name>#s=` +
  `btoa(encodeURIComponent(JSON.stringify(payload)))`
- By URL: `?src=<https url>` (GitHub raw/gist or the site itself)
