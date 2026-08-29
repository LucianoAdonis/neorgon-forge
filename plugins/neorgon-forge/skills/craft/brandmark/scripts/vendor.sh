#!/bin/bash
# vendor.sh <outdir> <slug...>: vendor Simple Icons brand SVGs.
# Keeps only responses that are actually SVG (a CDN 404 page saved under an
# .svg name renders as a broken square and lies in git forever), reports
# misses by name, exits non-zero if any slug failed.
set -uo pipefail

[ $# -ge 2 ] || { echo "usage: vendor.sh <outdir> <slug...>" >&2; exit 2; }
out="$1"; shift
mkdir -p "$out"

ok=0; miss=()
for slug in "$@"; do
  f="$out/$slug.svg"
  if curl -fsS --max-time 10 "https://cdn.simpleicons.org/$slug" -o "$f" 2>/dev/null \
     && head -c 200 "$f" | grep -q "<svg"; then
    ok=$((ok+1))
  else
    rm -f "$f"; miss+=("$slug")
  fi
done

echo "vendored $ok icon(s) into $out"
if [ ${#miss[@]} -gt 0 ]; then
  echo "no icon for: ${miss[*]} (trademark removals or wrong slug; plan a fallback)" >&2
  exit 1
fi
