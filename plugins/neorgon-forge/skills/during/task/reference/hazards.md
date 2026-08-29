# Environment hazards: where the work gets destroyed by something that is not the work

Every entry here cost a real session real losses. None of them announce themselves: the
failure is silent at the moment it happens and surfaces later as a symptom that looks
unrelated. Read this when starting a campaign in an environment you did not set up, and
whenever one of the symptoms below appears.

## A git tree inside a cloud-sync folder loses work silently

iCloud Drive, Dropbox, OneDrive and Google Drive all assume they own the directory. So
does git. They do not compose: concurrent writes make the sync daemon **fork files**,
putting each set of changes into a separate copy named `name 2.ext`, and nothing reports
that it happened. One session lost, separately: six tests from a suite (visible only as a
pass count dropping 29 → 28), two npm scripts, a 292-line document, and an entire `src/`
tree of 19 files.

Detect it before making dozens of edits: the path tells you:

```
Mobile Documents/     (iCloud Drive)
Dropbox/
OneDrive/
Google Drive/  ·  My Drive/
```

`brief.sh init` checks for these and warns. The right response to the warning is to move
the repo out (`~/Projects`, anything unsynced) before continuing, not to proceed
carefully: carefulness does not help against a daemon writing concurrently with you.

If the tree has already been bitten: conflict copies must be ignored with patterns that
**anchor on the space** the sync daemon inserts:

```gitignore
* [0-9]
* [0-9].*
```

`*[0-9].md`: no space, matches any file ending in a digit, and will silently swallow
`notes-2026.md` and `runbook-v2.md`. An over-broad ignore is worse than none, because it
fails silently in the direction of losing work.

## `git rebase --abort` deletes staged-but-uncommitted files

The abort performs a hard reset, which removes files present in the index but absent
from the target commit. If `git add` ran before the rebase, the content still exists as
blobs in the object store even though no commit references it. Recovery:

```bash
git cat-file --batch-all-objects --batch-check | awk '$2=="blob"{print $1}' > /tmp/blobs
# match a marker unique to the lost file
while read -r b; do git cat-file -p "$b" | grep -q "UNIQUE_MARKER" && echo "$b"; done < /tmp/blobs
git cat-file -p <sha> > path/to/restore.ext
```

Two caveats, both observed:

- **Use `--batch-all-objects`, not `git fsck --lost-found`.** fsck reported 15 dangling
  blobs and none of the lost content; the batch listing found all of it.
- **A marker can match the wrong file.** Two 113-line docs shared a marker and one was
  restored over the other. After recovery, verify line counts and headings, not just
  existence.

## An orphan-branch squash breaks every existing clone

`git checkout --orphan` + commit produces a history with **no common ancestor** to the
original. It is a legitimate way to publish without a leaked `.env` in history, but any
machine holding the old history can no longer pull: `git pull --rebase` replays every old
commit onto the unrelated root, conflicts on every file, and leaves conflict markers
inside files where the breakage then looks like an unrelated bug. If you squash for a
clean publish, say in the same breath: **other clones must hard-reset to the new remote,
never pull.**

## A dropping test count is a data-loss signal, not noise

"28 passed, 0 failed" reads as green. If the previous run said 29, something deleted a
test, and if you did not delete one deliberately, a file has been truncated, forked, or
reverted under you. Compare counts across runs; a decrease you cannot attribute is a
defect to chase now, because it is the only visible symptom of the quiet failures above.

## Stale artifacts on disk impersonate fresh results

A sharded run exited 0 and printed "all shards complete" while every shard had died
instantly on an unset variable: the aggregate looked plausible because it was reading
the *previous* run's reports still on disk. Any script that aggregates from files must
clear its output directory before starting and exit non-zero when it produced nothing.
"Produced nothing" and "found last run's output" must be distinguishable, and by default
they are not.

## A query that buffers everything yields nothing on timeout

Three successive attempts at a large database read produced no output at all: the client
buffered the entire result (`.toArray()` on a 300k-document cursor) before any processing,
so hitting the tool timeout discarded everything rather than yielding partial results. The
same query streamed (`for await`) with per-batch checkpointing completed. When a read is
large enough that a timeout is plausible, structure it so a timeout loses a batch, not the
run. Related trap, same database: sampling more than ~5% of a collection (`$sample` at
15%) silently abandons the random-cursor optimization and becomes a full scan plus sort.

## The harness shell can drop PATH inside loops

Under some harness shells (observed: zsh via Claude Code on macOS), `for`-loop bodies
and some `eval`'d compound commands lose `PATH`, `command not found: git`, then
`basename`/`sed` failing once git is made absolute. If that symptom appears: prefix the
command with `export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin`, and prefer
explicit per-item invocations over loops for anything that must succeed. Scripts invoked
directly (like this skill's) are unaffected; the trap is in ad-hoc loop one-liners.
