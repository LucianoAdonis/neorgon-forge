#!/usr/bin/env bash
# shipcheck.sh — the "ship it" checklist for a post, mechanized.
#
# Structure: title heading, a hook paragraph before the first section, section
# headings on long posts, one concrete example, a gotchas section on technical
# posts, and an ending. Rot: every http(s) link answers < 400, every local
# image path exists. persona-lint covers voice; this covers structure and rot.
#
# Usage:
#   shipcheck.sh <post.md> [--no-network] [--timeout N]
#
# Exit codes: 0 ships · 1 findings · 2 the run itself failed (unreadable file).
# Exit 2 must never be read as a pass.
set -uo pipefail

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }

POST="" NETWORK=1 TIMEOUT=10
while [ $# -gt 0 ]; do
  case "$1" in
    --no-network) NETWORK=0; shift ;;
    --timeout)    TIMEOUT="${2:-10}"; shift 2 ;;
    -*) red "unknown option: $1" >&2; exit 2 ;;
    *)  POST="$1"; shift ;;
  esac
done
[ -n "$POST" ] && [ -r "$POST" ] || { red "usage: shipcheck.sh <post.md> [--no-network]" >&2; exit 2; }

POSTDIR="$(cd "$(dirname "$POST")" && pwd)"
findings=0
note() { printf '%s\n' "$1"; findings=$((findings + 1)); }

# Prose view: fenced code blocks and HTML comments blanked, line numbers kept.
PROSE="$(awk '
  /^```/            { fence = !fence; print ""; next }
  fence             { print ""; next }
  /<!--/ && /-->/   { print ""; next }
  /<!--/            { comment = 1; print ""; next }
  comment           { if (/-->/) comment = 0; print ""; next }
  { print }
' "$POST")"

# ── Structure ────────────────────────────────────────────────────────────────

printf '%s\n' "$PROSE" | awk 'NF { exit !($0 ~ /^# /) }' \
  || note "$POST:1: no title — the first content line should be a single # heading"

# A hook: at least one prose paragraph (not a heading/image/blockquote) before
# the first ## section. Skimmers decide here.
hook="$(printf '%s\n' "$PROSE" | awk '
  /^## /                       { exit }
  /^# /                        { next }
  /^!\[/ || /^> / || /^---/    { next }
  NF                           { found = 1; exit }
  END                          { print found + 0 }
')"
[ "$hook" = "1" ] || note "$POST: no hook paragraph before the first section — say what the reader gets"

words="$(printf '%s\n' "$PROSE" | wc -w | tr -d ' ')"
sections="$(printf '%s\n' "$PROSE" | grep -c '^## ' || true)"
if [ "$words" -gt 600 ] && [ "$sections" -lt 2 ]; then
  note "$POST: $words words with $sections section heading(s) — skimmers need ## headings"
fi

if ! grep -qE '^```|!\[' "$POST"; then
  note "$POST: no concrete example — no code block and no image in the whole post"
fi

# Technical tell: a fenced code block. Technical posts owe the reader a gotchas
# or still-figuring-out section; hobby posts are exempt.
if grep -q '^```' "$POST"; then
  printf '%s\n' "$PROSE" | grep -qiE '^#{2,4} .*(gotcha|common mistake|troubleshoot|what went wrong|figuring out|known issue|caveat)' \
    || note "$POST: technical post with no gotchas section — even a small one signals it was tested"
fi

printf '%s\n' "$PROSE" | tail -20 | grep -qiE "TL;?DR|and that'?s it|peace!|resources|what'?s next|final thoughts|closing thoughts|let me know" \
  || note "$POST: no ending — close with a TL;DR, sign-off, resources, or a feedback ask"

# ── Rot ──────────────────────────────────────────────────────────────────────

# Local images (skip URLs and the repo's <!-- Image Source --> mirrors).
while IFS=: read -r ln path; do
  [ -n "$path" ] || continue
  case "$path" in http*|data:*) continue ;; esac
  [ -e "$POSTDIR/$path" ] || note "$POST:$ln: image not found: $path"
done < <(grep -n '!\[' "$POST" | sed -E 's/^([0-9]+):.*!\[[^]]*\]\(([^) ]+)[^)]*\).*/\1:\2/' | grep -E '^[0-9]+:')

if [ "$NETWORK" -eq 1 ]; then
  checked=""
  while IFS=: read -r ln url; do
    [ -n "$url" ] || continue
    case "$checked" in *"|$url|"*) continue ;; esac
    checked="$checked|$url|"
    code="$(curl -sL -o /dev/null -m "$TIMEOUT" -A "Mozilla/5.0 (shipcheck)" -w '%{http_code}' "$url" 2>/dev/null)"
    case "$code" in
      2*|3*) : ;;
      000)   note "$POST:$ln: link did not answer within ${TIMEOUT}s: $url" ;;
      *)     note "$POST:$ln: link answers $code: $url" ;;
    esac
  done < <(grep -noE '\]\(https?://[^) ]+\)' "$POST" | sed -E 's/^([0-9]+):\]\((.*)\)$/\1:\2/')
else
  printf '%s\n' "(link probes skipped: --no-network)"
fi

# ── Verdict ──────────────────────────────────────────────────────────────────

if [ "$findings" -gt 0 ]; then
  red "$findings finding(s) — not ready to ship"
  exit 1
fi
green "ships"
exit 0
