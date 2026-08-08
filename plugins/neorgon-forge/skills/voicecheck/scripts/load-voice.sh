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
if [ -f "$PROJECT_DIR/PROJECTS.md" ] || [ -f "$PROJECT_DIR/../PROJECTS.md" ]; then
  if [ -f "$OVERLAY" ]; then
    echo "----- LOCAL OVERLAY ($OVERLAY) [chrome invariants, non-overridable] -----"
    cat "$OVERLAY"
  fi
else
  echo "----- LOCAL OVERLAY: not applicable (no suite detected) -----"
fi
