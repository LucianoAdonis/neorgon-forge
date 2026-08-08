#!/usr/bin/env bash
# Mechanical checks for a post directory, so attention goes to the
# judgment calls instead of the greppable stuff.
#
# Usage: bash check-writeup.sh <project>/post
set -uo pipefail

DIR="${1:-post}"
[ -d "$DIR" ] || { echo "no such directory: $DIR"; exit 1; }

red()  { printf '\033[31m%s\033[0m\n' "$1"; }
green(){ printf '\033[32m%s\033[0m\n' "$1"; }
head_(){ printf '\n\033[1m== %s\033[0m\n' "$1"; }

fail=0

head_ "Length"
for f in "$DIR"/POST*.md; do
  [ -f "$f" ] || continue
  n=$(grep -v '^!\[' "$f" | grep -v '^\*Alt\|^\*Títulos' | sed 's/[#*_`]//g' | wc -w | tr -d ' ')
  printf '  %-16s %5s words  (~%s min read)\n' "$(basename "$f")" "$n" "$(( (n + 199) / 200 ))"
done

head_ "AI writing patterns (English)"
# Kept in sync with the ai-writing-detox skill; that skill is the
# canonical list, this is the fast grep for the mechanical subset.
PAT='\b(delve|realm|tapestry|landscape|leverage|utilize|robust|seamless|comprehensive|cutting-edge|holistic|synergy|paradigm|empower|innovative|transformative|game-changer)\b'
PAT+="|it'?s (important|worth) (to note|noting|mentioning)|without further ado|as we all know"
PAT+='|at the end of the day|when it comes to|in terms of|with respect to|moving forward'
PAT+='|in order to|due to the fact|prior to|has the ability to|is(n.t)? just a|more than just'
if grep -HniE "$PAT" "$DIR"/POST.md 2>/dev/null; then fail=1; else green "  clean"; fi

head_ "Sentence-start tics"
if grep -HnoE '(^|[.!?"] )(Well|Now|Look|Listen|Basically|Essentially|Moreover|Furthermore|Additionally|Ultimately), ' "$DIR"/POST.md 2>/dev/null; then
  echo "  (check these are voice, not filler — 'So,' is often deliberate)"
else green "  clean"; fi

head_ "Heading case (should be sentence case)"
if grep -hE '^#{1,3} ' "$DIR"/POST*.md 2>/dev/null \
   | grep -E '^#{1,3} ([A-Z][a-z]+ ){2,}[A-Z][a-z]+\s*$'; then fail=1; else green "  clean"; fi

head_ "Spanish regionalisms"
if [ -f "$DIR/POST.es.md" ]; then
  ES='\b(cachar|cacha|cachai|altiro|po|weon|guagua|arriendo|pololo|chévere|guay|vosotros|habéis|tenéis|coger|platita)\b'
  if grep -HniE "$ES" "$DIR/POST.es.md"; then fail=1; else green "  clean"; fi
  grep -qE '\bvos\b' "$DIR/POST.es.md" && { red "  found 'vos' — neutral Spanish uses tú"; fail=1; }
else
  echo "  (no POST.es.md)"
fi

head_ "Image references resolve"
for f in "$DIR"/POST*.md; do
  [ -f "$f" ] || continue
  grep -oE '\]\(([^)]+\.(png|svg|jpg))\)' "$f" | sed -E 's/^\]\(//;s/\)$//' | sort -u | while read -r p; do
    if [ -f "$DIR/$p" ]; then
      printf '  ok    %s → %s\n' "$(basename "$f")" "$p"
    else
      red "  MISS  $(basename "$f") → $p"
    fi
  done
done
grep -rqE '\]\([^)]+\.(png|svg|jpg)\)' "$DIR"/POST*.md 2>/dev/null || echo "  (no image references)"

head_ "Generated assets fresher than their generator"
if [ -f "$DIR/build-visuals.mjs" ]; then
  newest_svg=$(find "$DIR" -maxdepth 1 -name '*.svg' -newer "$DIR/build-visuals.mjs" 2>/dev/null | wc -l | tr -d ' ')
  total_svg=$(find "$DIR" -maxdepth 1 -name '*.svg' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$total_svg" -gt 0 ] && [ "$newest_svg" -eq 0 ]; then
    red "  generator is newer than every .svg — run: node $DIR/build-visuals.mjs"
    fail=1
  else
    green "  ok"
  fi
else
  echo "  (no build-visuals.mjs)"
fi

echo
[ "$fail" -eq 0 ] && green "All mechanical checks passed." || red "Some checks flagged — see above."
exit 0
