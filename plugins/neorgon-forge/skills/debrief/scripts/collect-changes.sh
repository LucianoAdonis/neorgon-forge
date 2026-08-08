#!/usr/bin/env bash
# Gather the facts a change deck should be built from, so the slides
# report the diff rather than a recollection of it.
#
# Usage: bash collect-changes.sh [project-dir] [--since <ref>]
#
# Default range is uncommitted work (staged + unstaged + untracked).
# Pass --since <ref> to cover a branch, a tag, or the last N commits
# (e.g. --since HEAD~5, --since main, --since v1.2.0).
set -uo pipefail

DIR="."
SINCE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE="${2:-}"; shift 2 ;;
    *) DIR="$1"; shift ;;
  esac
done

cd "$DIR" 2>/dev/null || { echo "no such directory: $DIR"; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: $DIR"; exit 1; }

head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

if [ -n "$SINCE" ]; then
  RANGE="$SINCE..HEAD"
  DIFF_ARGS="$SINCE"
  printf '\033[1mScope:\033[0m commits in %s (%s)\n' "$RANGE" "$(pwd)"
else
  RANGE=""
  DIFF_ARGS="HEAD"
  printf '\033[1mScope:\033[0m uncommitted work in %s\n' "$(pwd)"
fi

head_ "Volume"
git diff --shortstat $DIFF_ARGS 2>/dev/null | sed 's/^/  /' || echo "  (none)"
if [ -z "$SINCE" ]; then
  untracked=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')
  [ "$untracked" != "0" ] && echo "  $untracked untracked file(s)"
fi

head_ "Changed files by area"
{
  git diff --name-only $DIFF_ARGS 2>/dev/null
  [ -z "$SINCE" ] && git ls-files --others --exclude-standard
} | sort -u | awk -F/ '
  { area = (NF > 1) ? $1 : "(root)"; count[area]++; files[area] = files[area] "\n      " $0 }
  END { for (a in count) printf "  %s (%d)%s\n", a, count[a], files[a] }
' | sed '/^$/d'

head_ "New files"
if [ -n "$SINCE" ]; then
  git diff --diff-filter=A --name-only $DIFF_ARGS 2>/dev/null | sed 's/^/  + /'
else
  git diff --diff-filter=A --name-only HEAD 2>/dev/null | sed 's/^/  + /'
  git ls-files --others --exclude-standard | sed 's/^/  + /'
fi
head_ "Deleted files"
git diff --diff-filter=D --name-only $DIFF_ARGS 2>/dev/null | sed 's/^/  - /' || true

if [ -n "$SINCE" ]; then
  head_ "Commits in range"
  git log --oneline --no-merges "$RANGE" 2>/dev/null | sed 's/^/  /'
fi

head_ "Docs and instructions touched"
# These usually contain the reasoning already written down in prose,
# which is the fastest route to the "why" slides.
{
  git diff --name-only $DIFF_ARGS 2>/dev/null
  [ -z "$SINCE" ] && git ls-files --others --exclude-standard
} | sort -u | grep -iE '(CLAUDE\.md|README\.md|docs/.*\.md|\.agents/)' | sed 's/^/  /' \
  || echo "  (none — the reasoning is only in the diff and the session)"

head_ "Biggest single-file changes"
git diff --numstat $DIFF_ARGS 2>/dev/null \
  | awk '{ printf "  %6s +  %6s -   %s\n", $1, $2, $3 }' \
  | sort -rn | head -12

head_ "Generated or vendored files in the diff"
# Worth knowing before presenting: these inflate the volume numbers
# and are not the work.
{
  git diff --name-only $DIFF_ARGS 2>/dev/null
  [ -z "$SINCE" ] && git ls-files --others --exclude-standard
} | sort -u | grep -iE '(neorgon-(header|footer|themes)\.(css|js)|/png/|\.svg$|package-lock|site-registry\.(json|yml|md))' \
  | sed 's/^/  /' || echo "  (none)"

printf '\n\033[1mNext:\033[0m the diff shows what changed. Before writing slides, establish\n'
printf 'what was wrong before, what was measured, and what is still open — none of\n'
printf 'those are in here.\n'
