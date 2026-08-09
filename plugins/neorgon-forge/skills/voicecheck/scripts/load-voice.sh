#!/usr/bin/env bash
# Print the voice context for a project, in precedence order.
#
# The skill reads this instead of recalling the rules, because a voice audit
# graded against a remembered standard is an opinion.
#
# Usage: load-voice.sh [project-dir]   (defaults to cwd)
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULTS="$SKILL_DIR/reference/voice-defaults.md"
OVERLAY="$SKILL_DIR/reference/neorgon.md"

PROJECT_DIR="${1:-.}"
[ -d "$PROJECT_DIR" ] || { printf 'no such directory: %s\n' "$PROJECT_DIR" >&2; exit 1; }
PROJECT_VOICE="$PROJECT_DIR/VOICE.md"

echo "===== voicecheck context ====="
echo "project-dir: $PROJECT_DIR"
echo

if [ -f "$PROJECT_VOICE" ]; then
  echo "----- PROJECT VOICE.md ($PROJECT_VOICE) [overrides the baseline] -----"
  cat "$PROJECT_VOICE"
  echo
else
  echo "----- PROJECT VOICE.md: none (the baseline is the standard) -----"
  echo
fi

[ -f "$DEFAULTS" ] || { printf 'baseline missing at %s\n' "$DEFAULTS" >&2; exit 1; }
echo "----- BASELINE ($DEFAULTS) [always applies] -----"
cat "$DEFAULTS"
echo

# The overlay carries suite chrome rules that hold in one monorepo and nowhere
# else. Detected rather than assumed: printing it elsewhere would invent
# invariants the project never agreed to.
#
# Walk up rather than testing a fixed number of levels. The suite marker was one
# level above a project until the sites moved under projects/, at which point it
# became two and a two-level test would have gone quietly dead the same way — the
# gate fails closed, so a miss prints "not applicable" and looks like a correct
# answer in an unrelated repo. Walking up has no such version to get wrong.
suite=""
probe="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)"
while [ -n "$probe" ] && [ "$probe" != "/" ]; do
  if [ -f "$probe/PROJECTS.md" ]; then suite="$probe"; break; fi
  probe="$(dirname "$probe")"
done

if [ -n "$suite" ]; then
  echo "suite detected at: $suite/PROJECTS.md"
  if [ -f "$OVERLAY" ]; then
    echo "----- LOCAL OVERLAY ($OVERLAY) [chrome invariants, non-overridable] -----"
    cat "$OVERLAY"
  fi
else
  echo "----- LOCAL OVERLAY: not applicable (no suite detected) -----"
fi
