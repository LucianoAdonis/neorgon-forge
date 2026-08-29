#!/usr/bin/env bash
# Prove a Pathfinder canvas loads before handing it over.
#
# Uses the app's published validator, which wraps the app's own normalize.js:
# what it accepts is exactly what the canvas accepts. Prefers a local checkout
# when one is nearby; otherwise fetches the published copy once per run.
#
# Usage: validate-canvas.sh <canvas.json | - | '#s=...' | share-url>
set -euo pipefail
TARGET="${1:?usage: validate-canvas.sh <canvas.json | - | '#s=...'>}"

for local in \
  "./validate.mjs" \
  "./projects/pathfinder-site/validate.mjs" \
  "$HOME/dev/Personal/projects/pathfinder-site/validate.mjs"; do
  if [ -f "$local" ]; then exec node "$local" "$TARGET"; fi
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsS https://pathfinder.neorgon.com/validate.mjs -o "$TMP/validate.mjs"
node "$TMP/validate.mjs" "$TARGET"
