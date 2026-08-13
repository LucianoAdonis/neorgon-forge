#!/usr/bin/env bash
# stale.sh — a limit without a fresh date is a rumor. Scan groundwork
# requirements docs for dated claims older than the threshold and report each
# one as file:line, plus every re-verify trigger so it can be judged by eye.
#
# A file counts as a groundwork doc if it carries a "# Groundwork:" title or an
# "**Investigated:**" stamp — the two things the template guarantees.
#
# Usage:
#   stale.sh <dir-or-file> [--days N]     # default 90
#
# Exit codes: 0 all fresh · 1 stale claims found · 2 no groundwork docs scanned
# (exit 2 is a failure to check, never a pass).
set -uo pipefail

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }

TARGET="" DAYS=90
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="${2:-90}"; shift 2 ;;
    -*) red "unknown option: $1" >&2; exit 2 ;;
    *)  TARGET="$1"; shift ;;
  esac
done
[ -n "$TARGET" ] && [ -e "$TARGET" ] || { red "usage: stale.sh <dir-or-file> [--days N]" >&2; exit 2; }

# YYYY-MM-DD compares correctly as a string, so one threshold date is enough.
THRESHOLD="$(date -v-"${DAYS}"d +%F 2>/dev/null || date -d "-${DAYS} days" +%F)"
[ -n "$THRESHOLD" ] || { red "could not compute threshold date" >&2; exit 2; }

if [ -d "$TARGET" ]; then
  DOCS="$(grep -rlE '^# Groundwork:|\*\*Investigated:\*\*' --include='*.md' "$TARGET" 2>/dev/null)"
else
  DOCS="$(grep -lE '^# Groundwork:|\*\*Investigated:\*\*' "$TARGET" 2>/dev/null)"
fi
[ -n "$DOCS" ] || { red "no groundwork docs under $TARGET (nothing was checked)" >&2; exit 2; }

stale=0
while IFS= read -r doc; do
  # Every dated claim in the doc: table "Checked" cells, Investigated stamps,
  # "accessed" source lines. One report per dated line.
  while IFS= read -r hit; do
    ln="${hit%%:*}"
    line="${hit#*:}"
    d="$(printf '%s\n' "$line" | grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' | head -1)"
    [ -n "$d" ] || continue
    if [[ "$d" < "$THRESHOLD" ]]; then
      excerpt="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//' | cut -c1-100)"
      printf '%s:%s: %s is older than %s days (threshold %s): %s\n' \
        "$doc" "$ln" "$d" "$DAYS" "$THRESHOLD" "$excerpt"
      stale=$((stale + 1))
    fi
  done < <(grep -nE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' "$doc")

  # Context, not verdicts: the doc's own re-verification triggers.
  grep -nE '\*\*Re-verify when:\*\*' "$doc" | sed "s|^|$doc:|" | sed 's/\*\*//g'
done <<< "$DOCS"

if [ "$stale" -gt 0 ]; then
  red "$stale dated claim(s) past the ${DAYS}-day threshold — re-verify or relabel as rumor"
  exit 1
fi
green "all dated claims within ${DAYS} days"
exit 0
