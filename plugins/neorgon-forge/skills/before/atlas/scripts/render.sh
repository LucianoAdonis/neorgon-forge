#!/usr/bin/env bash
# Render export-target .mmd files to SVG and PNG with mermaid-cli.
#
# Only for diagrams that leave the docs site: a slide, a README, a post. Diagrams
# inside MkDocs pages stay as fences and are rendered by Material in the browser,
# because a fence re-themes with the palette and an image does not.
#
# Two facts this exists to enforce, both learned by getting them wrong:
#   - mermaid-cli EDITS a Markdown input file in place, replacing every fence with
#     an image link. It is only ever pointed at .mmd here, never at a docs page.
#   - a label containing a literal \n renders as the two characters backslash-n
#     under Mermaid 11's HTML labels. This refuses to render a file containing one
#     rather than producing a diagram that looks subtly broken.
#
# Usage: render.sh [DIR] [--png] [--scale N]
#   DIR defaults to docs/atlas/diagrams. Writes beside each .mmd.

set -uo pipefail

DIR="docs/atlas/diagrams"
WANT_PNG=0
SCALE=2
BG="#040714"
MMDC_VERSION="@mermaid-js/mermaid-cli@11.12.0"

while [ $# -gt 0 ]; do
  case "$1" in
    --png) WANT_PNG=1 ;;
    --scale) SCALE="${2:?--scale needs a number}"; shift ;;
    --bg) BG="${2:?--bg needs a colour}"; shift ;;
    -*) printf 'unknown flag: %s\n' "$1" >&2; exit 2 ;;
    *) DIR="$1" ;;
  esac
  shift
done

red() { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
dim() { printf '\033[2m%s\033[0m\n' "$1"; }

if [ ! -d "$DIR" ]; then
  red "no directory $DIR"
  dim "generate export diagrams first:"
  dim "  python3 scripts/diagram.py flow --target export --out $DIR/flow.mmd"
  exit 1
fi

sources=()
while IFS= read -r f; do sources+=("$f"); done < <(find "$DIR" -name '*.mmd' | sort)

if [ ${#sources[@]} -eq 0 ]; then
  red "no .mmd files under $DIR"
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  red "npx not found: mermaid-cli needs Node"
  dim "the .mmd files are still valid; render them anywhere, or paste into"
  dim "https://mermaid.live to check them by eye"
  exit 1
fi

fail=0
rendered=0

for src in "${sources[@]}"; do
  base="${src%.mmd}"

  if grep -q '\\n' "$src"; then
    red "  SKIP $src: contains a literal \\n in a label"
    dim "        Mermaid 11 renders that as two characters, not a line break."
    dim "        Use <br/> instead. Regenerate with diagram.py, which does."
    fail=1
    continue
  fi

  if ! grep -qE '^(flowchart|graph|sequenceDiagram|classDiagram|stateDiagram|erDiagram)' "$src"; then
    red "  SKIP $src: no diagram declaration found"
    dim "        Material auto-themes only flowchart, sequence, class, state and ER."
    fail=1
    continue
  fi

  if npx -y "$MMDC_VERSION" -i "$src" -o "$base.svg" -b transparent >"$base.log" 2>&1; then
    green "  $base.svg"
    rendered=$((rendered + 1))
    rm -f "$base.log"
  else
    red "  FAIL $src"
    # mermaid-cli reports the line number relative to the diagram body, not the
    # file, so the number in this log is offset by the frontmatter block above it.
    sed 's/^/        /' "$base.log" | tail -8
    fail=1
    continue
  fi

  if [ "$WANT_PNG" -eq 1 ]; then
    # Flattened onto the plate colour rather than left transparent: these land in
    # slides and posts, and both composite an alpha PNG onto white, which turns
    # light text on a dark diagram into light text on white.
    if npx -y "$MMDC_VERSION" -i "$src" -o "$base.png" -s "$SCALE" -b "$BG" \
        >"$base.log" 2>&1; then
      green "  $base.png (${SCALE}x on $BG)"
      rm -f "$base.log"
    else
      red "  FAIL $base.png"
      sed 's/^/        /' "$base.log" | tail -6
      fail=1
    fi
  fi
done

echo
if [ "$rendered" -eq 1 ]; then
  dim "1 diagram rendered from $DIR"
else
  dim "$rendered diagrams rendered from $DIR"
fi

if [ "$fail" -ne 0 ]; then
  red "some diagrams did not render: the model is fine, the diagram source is not"
  exit 1
fi
