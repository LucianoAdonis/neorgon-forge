#!/usr/bin/env bash
# closeout's whole claim is that its inventory comes from sources that cannot
# lie. Its collector lied twice in one session: it reported six repos that all
# have remotes as "NO REMOTE: never pushed anywhere", and it read the first
# "## Open" section of a multi-run brief, showing a campaign that closed weeks
# earlier as the open work. Neither is visible from the output, which looks
# plausible either way. This is the test that trips both.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
COLLECT="$REPO/plugins/neorgon-forge/skills/after/closeout/scripts/collect.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
fail=0

red()   { printf '\033[31m  FAIL %s\033[0m\n' "$1"; fail=1; }
green() { printf '\033[32m  ok   %s\033[0m\n' "$1"; }

printf '\n\033[1m== closeout/collect.sh\033[0m\n'

# A root holding one real project repo, and a brief with two runs.
mkdir -p "$WORK/root/projects/real-site" "$WORK/root/.forge"
git -C "$WORK/root/projects/real-site" init -q
git -C "$WORK/root/projects/real-site" remote add origin git@example.com:x/real-site.git
cat > "$WORK/root/.forge/brief.md" <<'MD'
# Brief: first run

## Open

- FIRST_RUN_ITEM, belongs to a campaign that closed weeks ago

---

## Run: 2026-08-29 12:00

## Open

- SECOND_RUN_ITEM, the work actually open now
MD

out=$(cd "$WORK/root" && bash "$COLLECT" . real-site 2>&1)

# 1. The open work is the current run's, not the first run's.
if grep -q 'SECOND_RUN_ITEM' <<<"$out"; then
  green "reads the current run's Open section"
else
  red "read the wrong Open section: a closed campaign reported as open work"
fi
grep -q 'FIRST_RUN_ITEM' <<<"$out" \
  && red "also printed an earlier run's Open items" \
  || green "leaves earlier runs' Open items alone"

# 2. A repo that is present and has a remote is never called remoteless.
grep -q 'NO REMOTE' <<<"$out" \
  && red "claimed NO REMOTE for a repo that has one" \
  || green "does not invent a missing remote"

# 3. A name that is not a repo under the root says so, rather than claiming
#    its source exists nowhere but this disk.
out2=$(cd "$WORK/root" && bash "$COLLECT" . not-a-real-project 2>&1)
if grep -q 'not a git repo under' <<<"$out2"; then
  green "distinguishes 'not here' from 'has no remote'"
else
  red "a name that is not a repo here was reported as having no remote"
fi

# 4. A genuinely remoteless repo is still reported, because that one matters.
mkdir -p "$WORK/root/projects/orphan-site"
git -C "$WORK/root/projects/orphan-site" init -q
out3=$(cd "$WORK/root" && bash "$COLLECT" . orphan-site 2>&1)
grep -q 'NO REMOTE' <<<"$out3" \
  && green "still reports a repo whose source exists nowhere else" \
  || red "stopped reporting a genuinely remoteless repo"

# 5. Two roots is ambiguous and must not silently pick one.
(cd "$WORK/root" && bash "$COLLECT" . projects >/dev/null 2>&1)
[ "$?" -eq 2 ] && green "refuses two roots instead of silently picking one" \
               || red "accepted two roots and picked one silently"

printf '\n'
[ "$fail" -eq 0 ] && { printf '\033[32mcollect.sh checks passed.\033[0m\n'; exit 0; }
printf '\033[31mcollect.sh checks failed.\033[0m\n'; exit 1
