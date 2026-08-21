#!/usr/bin/env bash
# persona-lint.sh: check a document against a persona's ban/cap rules.
#
# Rules live in a ```lint fenced block inside the persona file:
#   ban /regex/ message          every match is a violation, reported file:line
#   cap N /regex/ message        more than N total matches blows the budget
# Regexes are perl-compatible and must not contain "/". Fenced code blocks in
# the document are excluded from matching (line numbers are preserved).
#
# Usage:
#   persona-lint.sh <doc.md> --persona <name>
#   persona-lint.sh <doc.md> --persona-file <path/to/persona.md>
#
# Exit codes: 0 clean · 1 violations · 2 the run itself failed (missing doc,
# persona, or lint block). Exit 2 must never be read as a pass: a lint that
# silently checked nothing is worse than no lint, because it gets quoted.
set -uo pipefail

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }

DOC="" PERSONA="" PFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --persona)      PERSONA="${2:-}"; shift 2 ;;
    --persona-file) PFILE="${2:-}";   shift 2 ;;
    -*) red "unknown option: $1" >&2; exit 2 ;;
    *)  DOC="$1"; shift ;;
  esac
done

[ -n "$DOC" ] || { red "usage: persona-lint.sh <doc.md> --persona <name>" >&2; exit 2; }
[ -r "$DOC" ] || { red "cannot read document: $DOC" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "$PFILE" ]; then
  [ -n "$PERSONA" ] || { red "pick a persona: --persona <name> or --persona-file <path>" >&2; exit 2; }
  PFILE="$HERE/../personas/$PERSONA.md"
fi
[ -r "$PFILE" ] || { red "no persona file at: $PFILE" >&2; exit 2; }

RULES="$(awk '/^```lint$/{on=1;next} /^```$/{on=0} on' "$PFILE")"
[ -n "$RULES" ] || { red "persona has no \`\`\`lint block: $PFILE (nothing was checked)" >&2; exit 2; }

# Blank out fenced code blocks so code samples cannot trip prose rules, while
# keeping every reported line number true to the original file.
STRIPPED="$(awk '/^```/{fence=!fence; print ""; next} fence{print ""; next} {print}' "$DOC")"

violations=0

while IFS= read -r rule; do
  [ -n "$rule" ] || continue
  case "$rule" in \#*) continue ;; esac
  kind="${rule%% *}"

  case "$kind" in
    ban)
      rest="${rule#ban }" ;;
    cap)
      rest="${rule#cap }"
      budget="${rest%% *}"
      rest="${rest#* }" ;;
    *)
      red "unparseable lint rule (skipped, counts as failure): $rule" >&2
      violations=$((violations + 1))
      continue ;;
  esac

  case "$rest" in
    /*) : ;;
    *)  red "unparseable lint rule (skipped, counts as failure): $rule" >&2
        violations=$((violations + 1)); continue ;;
  esac
  body="${rest#/}"
  regex="${body%%/ *}"
  msg="${body#*/ }"

  # One line number per match occurrence (a line can match twice).
  hits="$(printf '%s\n' "$STRIPPED" | PLRE="$regex" perl -ne 'while (/$ENV{PLRE}/g) { print "$.\n" }')"
  count=0
  [ -n "$hits" ] && count="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"

  if [ "$kind" = "ban" ]; then
    if [ "$count" -gt 0 ]; then
      violations=$((violations + count))
      while IFS= read -r ln; do
        printf '%s:%s: %s\n' "$DOC" "$ln" "$msg"
      done <<< "$hits"
    fi
  else
    if [ "$count" -gt "$budget" ]; then
      violations=$((violations + 1))
      lines="$(printf '%s\n' "$hits" | head -8 | paste -sd, - | sed 's/,/, /g')"
      printf '%s: budget blown (%s > %s) at lines %s: %s\n' "$DOC" "$count" "$budget" "$lines" "$msg"
    fi
  fi
done <<< "$RULES"

if [ "$violations" -gt 0 ]; then
  red "$violations violation(s) against $(basename "$PFILE" .md)"
  exit 1
fi
green "clean against $(basename "$PFILE" .md)"
exit 0
