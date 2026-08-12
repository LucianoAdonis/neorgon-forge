#!/usr/bin/env bash
# Sweep a repo for credential-shaped content before it is published.
#
# Why the skill needs it: .gitignore does nothing for an already-tracked file,
# and a value deleted in a later commit is still in every clone's history. The
# default scan covers the working tree and the index — what a commit made now
# would contain. --history scans every reachable blob, which is the check that
# matters before a repo's FIRST push: after that push, history is public.
#
# This is a pre-publish tripwire, not a substitute for gitleaks/trufflehog in
# CI. It reports file and line, never the matched value itself — a sweep whose
# own output leaks the secret would be the joke writing itself.
#
# Reads only. Nothing here writes to the surveyed repo.
#
# Usage: sweep.sh [dir] [--history]
set -uo pipefail

DIR="."
HISTORY=0
for arg in "$@"; do
  case "$arg" in
    --history) HISTORY=1 ;;
    *) DIR="$arg" ;;
  esac
done
[ -d "$DIR" ] || { printf 'no such directory: %s\n' "$DIR" >&2; exit 1; }
cd "$DIR" || exit 1

head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }

# One pattern per shape, alternated. Fixed provider prefixes are the strongest
# signals; bare hex runs are word-bounded to cut noise from minified assets.
PATTERN='AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36}|xox[baprs]-[A-Za-z0-9-]{10}|sk-[A-Za-z0-9_-]{20}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|[a-z+]+://[^/:[:space:]]+:[^@[:space:]]+@|[^0-9a-fA-F][0-9a-fA-F]{32}([^0-9a-fA-F]|$)'

findings=0

report() { # <where> <grep output lines "path:line:content" or "sha:content">
  local where="$1" hits="$2"
  [ -n "$hits" ] || return 0
  red "  $where"
  # File and line only — printing the matched value would make this script the leak.
  printf '%s\n' "$hits" | cut -d: -f1-2 | sort -u | sed 's/^/    /' | head -40
  findings=$((findings + $(printf '%s\n' "$hits" | wc -l | tr -d ' ')))
}

head_ "Working tree"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  report "tracked files" "$(git grep -nIE "$PATTERN" -- . 2>/dev/null || true)"
  head_ "Index (what a commit right now would contain)"
  report "staged content" "$(git grep -nIE --cached "$PATTERN" -- . 2>/dev/null || true)"

  # .env-class files tracked at all is its own finding, match or no match.
  head_ "Tracked env files"
  envs=$(git ls-files | grep -E '(^|/)\.env(\.|$)' | grep -vE '\.(example|sample|template)$' || true)
  if [ -n "$envs" ]; then
    red "  tracked — .gitignore does not untrack a file already committed:"
    printf '%s\n' "$envs" | sed 's/^/    /'
    findings=$((findings + 1))
    dim "    fix: git rm --cached <file>, and the value it held is in history — see --history"
  else
    dim "  none tracked"
  fi

  if [ "$HISTORY" -eq 1 ]; then
    head_ "History (every reachable blob)"
    dim "  slow on large repos; the check that matters before a FIRST push"
    hist=$(git rev-list --all 2>/dev/null | while IFS= read -r c; do
      git grep -lIE "$PATTERN" "$c" -- . 2>/dev/null
    done | sort -u | head -60)
    if [ -n "$hist" ]; then
      red "  credential-shaped content in committed history:"
      printf '%s\n' "$hist" | sed 's/^/    /'
      findings=$((findings + 1))
      dim "    unpushed: squash to a clean root (and warn that old clones must hard-reset, not pull)"
      dim "    pushed:   the value is burned — rotate it first, then clean"
    else
      dim "  clean"
    fi
  fi
else
  report "files (not a git repo)" "$(grep -rnIE --exclude-dir=node_modules --exclude-dir=.git "$PATTERN" . 2>/dev/null | head -60 || true)"
fi

head_ "Verdict"
if [ "$findings" -gt 0 ]; then
  red "  $findings hit(s) — inspect each before publishing anything"
  dim "  a hit in a test fixture is still a hit: synthesize a same-shape substitute"
  dim "  (reference/shapes.md) rather than shipping the observed value"
  exit 1
fi
dim "  nothing credential-shaped found (this narrows the risk; it does not prove absence)"
exit 0
