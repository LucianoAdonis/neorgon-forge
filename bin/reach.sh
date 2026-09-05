#!/usr/bin/env bash
# Which skills actually fire, counted from local transcripts.
#
# A description is the whole routing decision, and nothing in this repo could
# tell you whether a description ever won one. The first run of this, on
# 2026-09-05, found 17 of 26 skills had never been invoked once across 2,126
# transcripts, and that /task alone held 148 of them. Six routing collisions and
# a stale duplicate install came out of chasing that number.
#
# Counts only two signals, both structural: a Skill tool_use, matched on the
# whole `"name":"Skill","input":{"skill":"..."` shape, and the harness's
# command-name block. A bare `"skill": "x"` key is NOT enough and was the first
# version's bug: any transcript that merely discusses skills in JSON, including
# an audit of these very descriptions, writes that key and inflated every count.
# Measured on this machine: the loose pattern matched 259 times, the structural
# one 112. Over-counting cannot invent a zero, so it never faked a quiet skill,
# but it did flatter the busy ones. A bare "/name" in prose is noisier still and
# is not counted at all, so this UNDER-reports rather than flattering.
#
# Usage: bash bin/reach.sh [--projects DIR] [--zero-only]
# Exit: 0 always. This reports, it does not judge: a skill can be correctly at
# zero because its situation has not arisen, and only you can say which.
set -uo pipefail

PROJECTS="${HOME}/.claude/projects"
ZERO_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --projects) PROJECTS="$2"; shift 2 ;;
    --zero-only) ZERO_ONLY=1; shift ;;
    *) printf 'usage: reach.sh [--projects DIR] [--zero-only]\n' >&2; exit 2 ;;
  esac
done

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO/plugins/neorgon-forge/skills"
[ -d "$PROJECTS" ] || { printf 'no transcripts at %s\n' "$PROJECTS" >&2; exit 2; }

tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
PAT_TOOL='"name":"Skill","input":\{"skill":"[a-z][a-z0-9:-]*"'
PAT_CMD='<command-name>/?[a-z][a-z0-9:-]*</command-name>'
if command -v rg >/dev/null 2>&1; then
  rg -oI --no-filename -e "$PAT_TOOL" -e "$PAT_CMD" "$PROJECTS" 2>/dev/null > "$tmp" || true
else
  grep -rhoIE "$PAT_TOOL|$PAT_CMD" "$PROJECTS" 2>/dev/null > "$tmp" || true
fi

# The plugin registers some skills a second time as neorgon-forge:<name>, so the
# prefix is stripped and both registrations count as one skill.
sed -E 's/.*"skill":"([^"]+)".*/\1/; s#<command-name>/?([^<]+)</command-name>#\1#' "$tmp" \
  | sed 's#^neorgon-forge:##' | sort | uniq -c | sort -rn > "$tmp.counts"

files=$(find "$PROJECTS" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
printf '\n\033[1m== Skill reach, from %s transcripts\033[0m\n\n' "$files"

rows=$(mktemp); trap 'rm -f "$tmp" "$tmp.counts" "$rows"' EXIT
for d in "$SRC"/*/*/; do
  name=$(basename "$d"); bucket=$(basename "$(dirname "$d")")
  n=$(awk -v s="$name" '$2 == s { t += $1 } END { print t + 0 }' "$tmp.counts")
  printf '%s\t%s\t%s\n' "$n" "$name" "$bucket" >> "$rows"
done

total=$(wc -l < "$rows" | tr -d ' ')
zero=$(awk -F'\t' '$1 == 0' "$rows" | wc -l | tr -d ' ')
sort -rn "$rows" | while IFS=$'\t' read -r n name bucket; do
  [ "$ZERO_ONLY" -eq 1 ] && [ "$n" -gt 0 ] && continue
  colour=32; [ "$n" -eq 0 ] && colour=31
  printf '  \033[%sm%5s\033[0m  %-24s %s/\n' "$colour" "$n" "$name" "$bucket"
done

printf '\n  %s of %s skills have never been invoked.\n' "$zero" "$total"
printf '  Zero is not automatically a defect: a skill whose situation has not arisen is\n'
printf '  correctly quiet. It is a defect when the situation DID arise and something else\n'
printf '  won the routing, which is what bin/check-install.py and the router overlap table\n'
printf '  exist to catch.\n\n'
