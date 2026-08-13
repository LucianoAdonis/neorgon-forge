#!/usr/bin/env bash
# docrun.sh — a tutorial that proves itself. Extract the fenced bash blocks
# from a doc and execute them in order, in ONE shell, so exports and cd carry
# across blocks the way they do for a reader. The first failing block is
# reported as `block N (doc line L)` with the tail of its output.
#
# Safe by default: with no mode flag it only LISTS what would run. There is no
# sandbox — --run executes the doc's commands with your shell privileges in a
# scratch workdir. Read the doc first; the tool's job is upgrading a tutorial
# from `documented` to `verified`, not protecting you from a doc you trust
# blindly.
#
# Blocks fenced as ```bash norun are skipped (for illustrative or destructive
# snippets the doc shows but a runner must not execute).
#
# Usage:
#   docrun.sh <doc.md>                 # list blocks (default)
#   docrun.sh <doc.md> --run           # execute in a scratch dir
#   docrun.sh <doc.md> --run --workdir DIR
#
# Exit codes: 0 all blocks passed (or listed) · 1 a block failed ·
# 2 no runnable bash blocks (nothing was checked — never a pass).
set -uo pipefail

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }

DOC="" MODE=list WORKDIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --run)     MODE=run; shift ;;
    --list)    MODE=list; shift ;;
    --workdir) WORKDIR="${2:-}"; shift 2 ;;
    -*) red "unknown option: $1" >&2; exit 2 ;;
    *)  DOC="$1"; shift ;;
  esac
done
[ -n "$DOC" ] && [ -r "$DOC" ] || { red "usage: docrun.sh <doc.md> [--run]" >&2; exit 2; }
DOCABS="$(cd "$(dirname "$DOC")" && pwd)/$(basename "$DOC")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Extract blocks: TMP/block-N.sh plus TMP/lines (block number → doc line of
# the fence). ```bash and ```sh run; ```bash norun is listed but skipped.
awk -v out="$TMP" '
  /^```(bash|sh)([[:space:]]|$)/ && !fence {
    fence = 1; n += 1
    skip = ($0 ~ /norun/) ? 1 : 0
    printf "%d %d %d\n", n, NR, skip >> (out "/lines")
    next
  }
  /^```/ && fence { fence = 0; next }
  fence && !skip  { print >> (out "/block-" n ".sh") }
' "$DOC"

[ -s "$TMP/lines" ] || { red "no fenced bash blocks in $DOC (nothing was checked)" >&2; exit 2; }

total=0 runnable=0
while read -r n ln skip; do
  total=$((total + 1))
  first="$( [ "$skip" = 1 ] || head -1 "$TMP/block-$n.sh" 2>/dev/null )"
  if [ "$skip" = 1 ]; then
    dim "block $n (line $ln): SKIPPED (norun)"
  else
    runnable=$((runnable + 1))
    printf 'block %s (line %s): %s\n' "$n" "$ln" "${first:-<empty>}"
  fi
done < "$TMP/lines"
[ "$runnable" -gt 0 ] || { red "every bash block is norun (nothing to run)" >&2; exit 2; }

if [ "$MODE" = "list" ]; then
  dim "$runnable runnable block(s) of $total. Execute with: docrun.sh $DOC --run"
  exit 0
fi

if [ -z "$WORKDIR" ]; then
  WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/docrun.XXXXXX")"
fi
mkdir -p "$WORKDIR"

# One runner, one shell: markers between blocks tell us how far it got.
RUNNER="$TMP/runner.sh"
{
  echo 'set -e'
  while read -r n ln skip; do
    [ "$skip" = 1 ] && continue
    printf 'echo "::docrun::%s::%s"\n' "$n" "$ln"
    cat "$TMP/block-$n.sh"
  done < "$TMP/lines"
  echo 'echo "::docrun::done"'
} > "$RUNNER"

LOG="$TMP/run.log"
( cd "$WORKDIR" && bash "$RUNNER" ) > "$LOG" 2>&1
status=$?

last="$(grep -n '^::docrun::' "$LOG" | tail -1)"
if [ "$status" -eq 0 ] && printf '%s' "$last" | grep -q '::done'; then
  green "all $runnable block(s) passed (workdir: $WORKDIR)"
  exit 0
fi

marker="${last#*:}"                       # ::docrun::N::L
n="$(printf '%s' "$marker" | cut -d: -f5)"
ln="$(printf '%s' "$marker" | cut -d: -f7)"
red "$DOCABS: block ${n:-?} (doc line ${ln:-?}) failed with exit $status"
dim "-- output tail --"
markerline="${last%%:*}"
tail -n "+$((markerline + 1))" "$LOG" | tail -15
dim "-- workdir kept for inspection: $WORKDIR --"
exit 1
