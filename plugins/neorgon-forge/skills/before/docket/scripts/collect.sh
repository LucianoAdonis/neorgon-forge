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

# ── Landed work nobody announced, and the desk queue ──────────────────
head_ "Dispatch: undrafted news and the desk queue"
# A ship date newer than the newest story is landed work nobody announced:
# a natural small-lane item, since /newsroom submits to a private queue,
# nothing publishes without a reviewer, and the done condition is one line (a
# story is queued per ship date). The newest story is read from origin/main
# when the clone has it: the publish workflow commits upstream as a bot, and
# a clone that fetched but did not pull is not behind.
if [ -f projects/dispatch-site/data/posts.json ] && [ -f projects/neorgon-site/index.html ]; then
  python3 - <<'PY' 2>/dev/null || echo "  (could not compare feed and hub)"
import json, os, re, subprocess
doc, source = None, 'origin/main'
if os.path.exists('projects/dispatch-site/.git'):
    try:
        p = subprocess.run(['git', '-C', 'projects/dispatch-site', 'show', 'origin/main:data/posts.json'],
                           stdin=subprocess.DEVNULL, capture_output=True, timeout=5,
                           env=dict(os.environ, GIT_OPTIONAL_LOCKS='0'))
        doc = json.loads(p.stdout.decode('utf-8')) if p.returncode == 0 else None
    except (OSError, subprocess.SubprocessError, ValueError):
        doc = None
if not isinstance(doc, dict):
    doc, source = json.load(open('projects/dispatch-site/data/posts.json')), 'working copy'
posts = doc.get('posts', [])
story = max((p.get('date', '') for p in posts), default='')
added = re.findall(r'data-added="(\d{4}-\d{2}-\d{2})"', open('projects/neorgon-site/index.html').read())
ship = max(added, default='')
if ship > story:
    print(f"  STALE: newest story {story or 'none'} ({source}), newest hub ship date {ship}")
else:
    print(f"  current: newest story {story or 'none'} ({source}), newest hub ship date {ship or 'n/a'}")
PY
else
  echo "  (no dispatch here)"
fi
# One line from the desk queue, and only when a submit key exists (ANTENNE_KEY
# or ~/.config/antenne/submit-key). Fail-soft inside a 5 s budget: a backend
# that is down or not set up yet costs one line, never the docket. Counts and
# ages only; the queue's ids and every story's text stay out of it.
# dispatch-site's client runs only through the root's scripts/antenne_trust.py,
# which first checks it against the owner's reviewed pins: others can push to
# dispatch-site main, and this runs beside every credential on the machine.
# When the check fails, the one line says the scripts changed since review and
# names the pin command, and nothing from dispatch-site runs.
if [ -f projects/dispatch-site/scripts/submit-drafts.py ]; then
  python3 - <<'PY' 2>/dev/null || echo "  (could not read the desk queue)"
import json, os, subprocess, sys, time
if not (os.environ.get('ANTENNE_KEY', '').strip()
        or os.path.isfile(os.path.expanduser('~/.config/antenne/submit-key'))):
    raise SystemExit(0)
trust, site = 'scripts/antenne_trust.py', 'projects/dispatch-site'
if not os.path.isfile(trust):
    print(f"  desk queue: not read, there is no {trust} here to check dispatch-site's scripts against their review")
    raise SystemExit(0)
start = time.monotonic()
# 4.5 s for the check and the request, so the line, every interpreter's start included, fits in 5 s.
try:
    c = subprocess.run([sys.executable, trust, 'check', site], stdin=subprocess.DEVNULL,
                       capture_output=True, text=True, timeout=2)
    if c.returncode != 0:
        why = (c.stderr.strip().splitlines() or ['the check failed'])[-1]
        why = why.replace('antenne_trust: ', '', 1).replace('refused: ', '', 1)
        print(f"  desk queue: not read, {why.replace(os.path.expanduser('~'), '~')[:400]}")
        raise SystemExit(0)
    p = subprocess.run([sys.executable, trust, 'run', site, 'scripts/submit-drafts.py', '--status'],
                       stdin=subprocess.DEVNULL, capture_output=True, text=True,
                       timeout=max(0.5, 4.5 - (time.monotonic() - start)))
except subprocess.TimeoutExpired:
    print('  desk queue: no answer within 5 s')
    raise SystemExit(0)
if p.returncode != 0:
    why = (p.stderr.strip().splitlines() or ['no reason given'])[-1].replace('submit-drafts: ', '', 1)
    why = why.replace(os.path.expanduser('~'), '~').split('; ')[0]
    print(f'  desk queue: unavailable, {why[:160]}')
    raise SystemExit(0)
s = json.loads(p.stdout)
counts = s.get('counts') or {}
run = s.get('lastRun') if isinstance(s.get('lastRun'), dict) else {}
ages = [q['ageMs'] for q in s.get('queue') or []
        if isinstance(q, dict) and q.get('status') == 'pending' and isinstance(q.get('ageMs'), int)]
def age(ms):
    m = ms // 60000
    return f'{m // 1440}d {m % 1440 // 60}h' if m >= 1440 else f'{m // 60}h {m % 60}m' if m >= 60 else f'{m}m'
oldest = f' (oldest {age(max(ages))})' if ages else ''
print(f"  desk queue: {counts.get('pending', 0)} pending{oldest}, {counts.get('approved', 0)} approved waiting,"
      f" last run {run.get('state') or 'none'}")
PY
fi

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
