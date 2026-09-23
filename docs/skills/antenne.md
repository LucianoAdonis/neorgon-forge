# antenne

Judges whether the work that just finished is news the fleet wants, and submits at most one
story to the private desk queue.

## What it does

`antenne` runs inside one repo, about the work that just landed in it. It reads the record
rather than the recollection: the commits since the newest already-published story, the files
that window touched, the brief the work kept, and the registry row that decides whether the
site may be called open at all. From that it decides whether a fleet reader would notice
anything happened, drafts at most one story, and submits it to a queue.

Most runs submit nothing, and that is the design rather than a shortfall. A feed that fills
with kit syncs, renames and refactors is a feed people stop opening, so an honest no is a
finished run here: the skill names what it looked at, says why it does not clear the bar, and
stops.

Nothing on this path is public. Submitting puts a draft in front of a reviewer, who approves or
spikes it at the desk, and publishing runs itself only after that approval. The skill never
approves, never writes the feed, and never commits or pushes.

## The window, the narrowing, and the verdict

Three words carry the whole run.

The **window** is everything since the newest published story, read from the Antenne checkout
rather than chosen, so the same ground is not retold and a bot's publishing commit upstream does
not read as this clone being behind.

The **narrowing** sorts the window's commits into candidate, quiet and unclear from their
subjects alone. It is deliberately not the judgement. A candidate is a commit whose diff is
worth reading, and the diff is the only evidence a sentence may rest on: a claim nothing in the
log or the working tree supports does not go in, however true it sounds.

The **verdict** is the part that can be no. When nothing survives the narrowing, the collector
says so in as many words and the run ends there.

Two rules are mechanical rather than advisory, because both have a failure that no amount of
care prevents reliably. A site may be called open only when the registry says `lifecycle: live`,
which is read every run and never recalled. And three repos carry employer and private context:
naming one of them refuses the collection outright, so a refusal gathers nothing at all instead
of gathering it and warning.

## When to reach for it

Type `/antenne`, or the agent reaches for it when a task fits: at the end of a piece of work, in
any Neorgon repo, when what landed might be worth telling the fleet.

| You are about to reach for it, but | Reach for this instead |
|---|---|
| The sweep is the whole fleet since the last published story, and may produce several stories | The monorepo's `/newsroom` command, which does exactly that and ends at the same queue |
| The question is what is still unlanded rather than what is worth telling | [`closeout`](closeout.md), whose undrafted-news item submits through the same queue |
| The audience is a room | [`debrief`](debrief.md) |
| The audience is a reader, at article length | [`writeup`](writeup.md) |
| A story is queued and someone has to approve it | The desk. No skill approves a story |

The boundary against `/newsroom` is scope and count: `newsroom` sweeps the fleet and may write
several, `antenne` runs in one repo about the work in front of it and writes at most one.

## It's working if

- Most runs end without a submission, and each one names what it looked at.
- Every sentence in a submitted story can be traced to a commit or a file in the window.
- No story calls a site open unless the registry row printed during the run said `live`.
- The operator sees the story as a reader would see it, next to the dry run's verdict, before
  anything is sent.
- Running it inside `cartograph-site`, `metrics` or `o11y-harness` prints a refusal and nothing
  about those repos at all.
- Nothing in the repo changed: no commit, no push, no edit to the feed.
