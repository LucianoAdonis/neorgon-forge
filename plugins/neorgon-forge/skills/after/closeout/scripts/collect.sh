#!/usr/bin/env bash
# Gather the pending-item inventory from the places that cannot lie:
# git state, the registry, the hub, the harness ledger. The skill's whole
# claim is that the enumeration comes from here, not from what the session
# remembers doing, so every section below degrades to silence rather than
# guessing when its source is absent.
#
# Usage: bash collect.sh [monorepo-root] [--fleet] [project ...]
#   default: the fast sources only (root git, registry, hub, briefs, harness, queue)
#   --fleet: also sweep every repo for dirty/unpushed state (slow: one git per repo)
#   project: also check the named project repos' git state (fast, targeted)
set -uo pipefail

ROOT="."
ROOT_SET=0
FLEET=0
PROJECTS=()
for a in "$@"; do
  case "$a" in
    --fleet) FLEET=1 ;;
    *) if [ -d "projects/$a/.git" ]; then
         PROJECTS+=("$a")
       elif [ -d "$a" ]; then
         # Only the first directory-like argument is the root. A second one used
         # to overwrite it silently, so naming a sibling repo redirected the
         # whole collection and every section then reported on the wrong tree.
         if [ "$ROOT_SET" -eq 1 ]; then
           printf '\033[31mtwo roots given: "%s" and "%s". Pass one root; projects go under it.\033[0m\n' \
             "$ROOT" "$a" >&2
           exit 2
         fi
         ROOT="$a"; ROOT_SET=1
       else
         PROJECTS+=("$a")
       fi ;;
  esac
done
cd "$ROOT" 2>/dev/null || { echo "no such directory: $ROOT"; exit 1; }

head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

if [ "$FLEET" -eq 1 ] && [ -x scripts/fleet.sh ]; then
  head_ "Dirty repos (uncommitted work, fleet-wide)"
  ./scripts/fleet.sh names --dirty 2>/dev/null | sed 's/^/  /' || echo "  (fleet.sh failed)"
  head_ "Unpushed repos (fleet-wide)"
  ./scripts/fleet.sh names --unpushed 2>/dev/null | sed 's/^/  /' || echo "  (fleet.sh failed)"
fi

for p in "${PROJECTS[@]+"${PROJECTS[@]}"}"; do
  dir="$p"; [ -d "projects/$p/.git" ] && dir="projects/$p"
  head_ "$p: git state"
  # "Not here" and "has no remote" are different facts and used to print the
  # same alarming line. A repo whose source exists nowhere but this disk is a
  # real finding; a typo is not, and a false one teaches you to skim the rest.
  if [ ! -d "$dir/.git" ]; then
    printf '  not a git repo under %s: nothing collected for it\n' "$(pwd)"
    continue
  fi
  git -C "$dir" status --porcelain 2>/dev/null | head -10 | sed 's/^/  /'
  git -C "$dir" log --oneline "@{u}..HEAD" 2>/dev/null | head -5 | sed 's/^/  unpushed: /'
  git -C "$dir" remote get-url origin >/dev/null 2>&1 || echo "  NO REMOTE: never pushed anywhere"
done

head_ "Root repo: uncommitted and unpushed"
git status --porcelain 2>/dev/null | head -12 | sed 's/^/  /'
git status --porcelain 2>/dev/null | wc -l | sed 's/^ */  uncommitted files: /'
git log --oneline "@{u}..HEAD" 2>/dev/null | wc -l | sed 's/^ */  unpushed commits: /'

head_ "Registry: sites with a domain and no repo (lifecycle ready)"
if [ -f docs/site-registry.json ]; then
  python3 - <<'PY' 2>/dev/null || echo "  (could not read registry)"
import json
d = json.load(open('docs/site-registry.json'))
sites = d['sites'] if isinstance(d, dict) and 'sites' in d else d
for s in sites:
    if isinstance(s, dict) and s.get('lifecycle') == 'ready':
        print(f"  {s['id']}  ({s.get('domain')})")
PY
else
  echo "  (no registry here)"
fi

head_ "Hub: cards still marked Soon"
grep -h "Currently Soon" .claude/HUB_REGISTRY.md 2>/dev/null | sed 's/^/  /' || echo "  (no hub registry here)"

head_ "Dispatch: undrafted news (newest story vs newest hub ship date)"
# Ship dates live on the hub cards (data-added); stories live in the news
# site's committed feed. A ship date newer than the newest story is landed
# work nobody announced. /newsroom only writes gitignored drafts, so the
# close is reversible; publication stays at the desk.
if [ -f projects/dispatch-site/data/posts.json ] && [ -f projects/neorgon-site/index.html ]; then
  python3 - <<'PY' 2>/dev/null || echo "  (could not compare feed and hub)"
import json, re
posts = json.load(open('projects/dispatch-site/data/posts.json')).get('posts', [])
story = max((p.get('date', '') for p in posts), default='')
added = re.findall(r'data-added="(\d{4}-\d{2}-\d{2})"', open('projects/neorgon-site/index.html').read())
ship = max(added, default='')
if ship > story:
    print(f"  STALE: newest story {story or 'none'}, newest hub ship date {ship}")
    print("  default close: /newsroom drafts the missing stories; the desk approves")
else:
    print(f"  current: newest story {story or 'none'}, newest hub ship date {ship or 'n/a'}")
PY
else
  echo "  (no dispatch here)"
fi

head_ "Briefs with an Open section (.forge/brief.md)"
found=0
for f in .forge/brief.md projects/*/.forge/brief.md; do
  [ -f "$f" ] || continue
  if grep -q '^## Open' "$f" 2>/dev/null; then
    found=1
    echo "  $f:"
    # The last Open section, not the first. A brief accumulates one per run, and
    # reading the first reports a campaign that closed weeks ago as the open work.
    start=$(grep -n '^## Open' "$f" | tail -1 | cut -d: -f1)
    awk -v s="$start" 'NR > s { if (/^## / || /^---$/) exit; print }' "$f" \
      | grep -v '^[[:space:]]*$' | head -10 | sed 's/^/    /'
  fi
done
[ "$found" -eq 0 ] && echo "  (none found)"

head_ "Harness ledger"
if [ -f neorgon-harness/bin/sweep.py ]; then
  python3 neorgon-harness/bin/sweep.py run --dry-run 2>/dev/null | head -8 | sed 's/^/  /' || echo "  (sweep dry-run failed)"
else
  echo "  (no harness here)"
fi

head_ "Prompt queue (parked backlog, ambient: not this skill's to close)"
if [ -f docs/prompt-queue.md ]; then
  grep -c '^\s*#[0-9]' docs/prompt-queue.md 2>/dev/null | sed 's/^/  open items: /' || true
  grep -m1 'open' docs/prompt-queue.md 2>/dev/null | sed 's/^/  /' || true
else
  echo "  (no queue here)"
fi
