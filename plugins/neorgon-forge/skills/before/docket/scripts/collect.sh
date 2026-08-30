#!/usr/bin/env bash
# Build the candidate list from ledgers that cannot lie: the prompt queue, the
# Open section of every brief, the harness ledger, and git state. The skill's
# claim is that the session's slate comes from here rather than from what was
# most recently discussed, so every section degrades to a stated absence rather
# than to a guess.
#
# Read-only. It writes nothing and closes nothing.
#
# Usage: bash collect.sh [root] [project ...] [--fleet]
#   default: the fast sources (queue, briefs under the root, harness, root git)
#   --fleet: also ask fleet.sh which repos are dirty or unpushed (slow)
#   project: also read the named project repos' git state and briefs
set -uo pipefail

ROOT="."
FLEET=0
PROJECTS=()
for a in "$@"; do
  case "$a" in
    --fleet) FLEET=1 ;;
    *) if [ -d "projects/$a/.git" ]; then PROJECTS+=("$a"); elif [ -d "$a" ]; then ROOT="$a"; else PROJECTS+=("$a"); fi ;;
  esac
done
cd "$ROOT" 2>/dev/null || { echo "no such directory: $ROOT"; exit 1; }

head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
TODAY=$(date +%Y-%m-%d)

# ── The backlog proper ────────────────────────────────────────────────
# Every item with its id, its age, and its own length. Length is the size
# signal that matters: a one-line item is a candidate for this session, and an
# item that runs to paragraphs is a campaign wearing a bullet's clothes.
head_ "Prompt queue"
if [ -f docs/prompt-queue.md ]; then
  TODAY="$TODAY" python3 - <<'PY' 2>/dev/null || echo "  (could not parse the queue)"
import os, re, datetime
today = datetime.date.fromisoformat(os.environ["TODAY"])
lines = open("docs/prompt-queue.md").read().splitlines()
try:
    start = lines.index("## Queue") + 1
except ValueError:
    print("  (no ## Queue section)"); raise SystemExit
items, cur = [], None
for line in lines[start:]:
    if line.startswith("## "):
        break
    m = re.match(r"- `#(\d+)` \u00b7 (\d{4}-\d{2}-\d{2}) \u00b7 (.*)", line)
    if m:
        cur = {"id": m.group(1), "date": m.group(2), "text": m.group(3), "lines": 1}
        items.append(cur)
    elif cur is not None and line.strip():
        cur["lines"] += 1
if not items:
    print("  (queue is empty)")
for it in items:
    age = (today - datetime.date.fromisoformat(it["date"])).days
    size = "one-liner" if it["lines"] == 1 else f"{it['lines']} lines"
    print(f"  #{it['id']}  {age:>3}d old  [{size}]  {it['text'][:96]}")
print(f"\n  {len(items)} open, {sum(1 for i in items if i['lines'] == 1)} of them one-liners")
PY
else
  echo "  (no docs/prompt-queue.md here: this repo has no queue)"
fi

# ── What past work left behind ────────────────────────────────────────
head_ "Briefs with an Open section"
found=0
for f in .forge/brief.md */.forge/brief.md projects/*/.forge/brief.md; do
  [ -f "$f" ] || continue
  grep -q '^## Open' "$f" 2>/dev/null || continue
  body=$(sed -n '/^## Open/,/^## /p' "$f" | sed '1d;$d' | grep -v '^\s*$' | head -6)
  [ -n "$body" ] || continue
  found=1
  echo "  $f:"
  printf '%s\n' "$body" | cut -c1-100 | sed 's/^/    /'
done
[ "$found" -eq 0 ] && echo "  (no brief has an Open section)"

head_ "Briefs with unfinished workstreams"
found=0
for f in .forge/streams.tsv */.forge/streams.tsv projects/*/.forge/streams.tsv; do
  [ -f "$f" ] || continue
  open=$(awk -F'\t' '$2=="pending" || $2=="active" {print "    " $2 "\t" $1}' "$f")
  [ -n "$open" ] || continue
  found=1
  echo "  $f:"
  printf '%s\n' "$open"
done
[ "$found" -eq 0 ] && echo "  (no unfinished workstreams)"

# ── The harness, where a run left open is a result nobody read ────────
head_ "Harness ledger"
if [ -f neorgon-harness/bin/run.py ]; then
  # A run left open is a result nobody read. --table because the default
  # envelope is JSON meant for the loops, not for a person.
  python3 neorgon-harness/bin/run.py list --status open --table 2>/dev/null \
    | head -8 | sed 's/^/  /' || echo "  (could not list open runs)"
  python3 neorgon-harness/bin/sweep.py run --dry-run 2>/dev/null \
    | grep -E '"(pending|no_commit_recorded)"' | tr -d ' ,"' | sed 's/^/  sweep /' \
    || echo "  (sweep dry-run failed)"
else
  echo "  (no harness here)"
fi

# ── Work already started, which outranks anything on the backlog ──────
head_ "Root repo: uncommitted and unpushed"
git status --porcelain 2>/dev/null | head -12 | sed 's/^/  /'
git status --porcelain 2>/dev/null | wc -l | sed 's/^ */  uncommitted files: /'
git log --oneline "@{u}..HEAD" 2>/dev/null | wc -l | sed 's/^ */  unpushed commits: /'

for p in ${PROJECTS[@]+"${PROJECTS[@]}"}; do
  dir="$p"; [ -d "projects/$p/.git" ] && dir="projects/$p"
  head_ "$p: git state"
  git -C "$dir" status --porcelain 2>/dev/null | head -8 | sed 's/^/  /'
  git -C "$dir" log --oneline "@{u}..HEAD" 2>/dev/null | head -5 | sed 's/^/  unpushed: /'
  git -C "$dir" remote get-url origin >/dev/null 2>&1 || echo "  NO REMOTE: never pushed anywhere"
done

if [ "$FLEET" -eq 1 ] && [ -x scripts/fleet.sh ]; then
  head_ "Dirty repos (fleet-wide)"
  ./scripts/fleet.sh names --dirty 2>/dev/null | sed 's/^/  /' || echo "  (fleet.sh failed)"
  head_ "Unpushed repos (fleet-wide)"
  ./scripts/fleet.sh names --unpushed 2>/dev/null | sed 's/^/  /' || echo "  (fleet.sh failed)"
fi

printf '\n\033[1m== Not collected\033[0m\n'
echo "  Code TODOs and open issues are deliberately not swept: they are mostly"
echo "  old, and they would swamp the lane this skill exists to surface."
