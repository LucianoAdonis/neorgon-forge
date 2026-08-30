# docket

Opens a session by turning "what should I do now?" into a numbered slate the session can
actually finish.

## What it does

`docket` builds the candidate list from ledgers rather than from memory: the prompt queue with
each item's **age and line count**, every `.forge/brief.md` Open section, every workstream still
`pending` or `active`, the harness ledger's open runs, and uncommitted or unpushed git state.
The collector is read-only, so producing a docket closes nothing.

It then sorts into four lanes by a test rather than a feeling. `small` is one repo, no decision
pending, done condition statable in one line. `question` is an item whose blocker is an answer
rather than work. `campaign` is real work that will not fit in a sitting. `blocked` needs
something outside this session, and is listed but never offered.

The order is deliberate and is not the order of importance: small first, then questions, then
campaigns named separately, then blockers. It recommends at most five small items plus every
question, lists what it left out, and one reply approves the slate.

## The failure modes it prevents

An unaided answer to "what's next" comes from recollection, so the work chosen is whatever was
discussed most recently. The queue this was built against held fifteen one-line items, four of
them 174 days old: none of them hard, none of them ever remembered. The opposite failure is
worse. A session that opens on its blockers never starts, because a blocker cannot be closed in
the session that discovers it.

There is a third, quieter one. A ledger entry is a claim, not a fact. The first real run found
seven workstreams marked `pending` whose work was plainly finished on disk, and offering
finished work as the next thing to do discredits the whole slate.

## When to reach for it

At the start of a session, or the moment a piece of work lands and the next one is unchosen.

The pairing with `/closeout` is worth holding: closeout's list is **debt already incurred**, so
silence means close it. Docket's list is a **menu nobody has committed to**, so silence means
leave it alone. Reach for closeout when work has landed and something is left over; reach for
docket when nothing is in progress and something must be picked.

Not for doing a task already chosen (`/task`), not for arguing with a plan before building it
(`/grill`), not for landing what already exists (`/closeout`).

## It's working if

- The slate names where every item came from, and you can open that ledger and see it.
- The items you close are ones you had forgotten, not the one you walked in thinking about.
- The blockers are visible and none of them was attempted.
- The queue is shorter at the end of the session than at the start, because Step 6 wrote the
  closes back rather than leaving them in the transcript.
