#!/usr/bin/env bash
# Install the forge skills by symlinking them into ~/.claude/skills.
#
# Symlinks rather than copies, deliberately: editing a skill in this repo
# takes effect on the next invocation with no sync step. That is the whole
# point of authoring locally. Anyone who just wants to *use* the skills
# should install the plugin instead (see README).
#
# Usage:
#   install.sh                 symlink every skill into ~/.claude/skills
#   install.sh --project DIR   symlink into DIR/.claude/skills instead
#   install.sh --dry-run       print what would happen
#   install.sh --force         replace a real directory that is in the way
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/plugins/neorgon-forge/skills"
DEST="$HOME/.claude/skills"
DRY=0
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --project) DEST="${2:?--project needs a directory}/.claude/skills"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --force)   FORCE=1; shift ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }

[ -d "$SRC" ] || { red "no skills at $SRC"; exit 1; }

printf '\033[1mForge:\033[0m %s\n' "$REPO"
printf '\033[1mTarget:\033[0m %s\n\n' "$DEST"
[ "$DRY" -eq 1 ] && dim "dry run — nothing will be written"

[ "$DRY" -eq 0 ] && mkdir -p "$DEST"

linked=0
skipped=0
for dir in "$SRC"/*/; do
  name=$(basename "$dir")
  target="$DEST/$name"

  if [ -L "$target" ]; then
    current=$(readlink "$target")
    if [ "$current" = "$dir" ] || [ "$current" = "${dir%/}" ]; then
      dim "  = $name (already linked)"
      linked=$((linked + 1))
      continue
    fi
    # A symlink pointing somewhere else is safe to replace; we are not
    # destroying content, only re-pointing.
    [ "$DRY" -eq 0 ] && rm "$target"
    printf '  ~ %s (re-pointed from %s)\n' "$name" "$current"
  elif [ -e "$target" ]; then
    # A real directory might be the user's own work. Never clobber it
    # without --force.
    if [ "$FORCE" -eq 0 ]; then
      red "  ! $name — a real directory is in the way, not touching it"
      dim "      move it, or re-run with --force to replace it"
      skipped=$((skipped + 1))
      continue
    fi
    backup="$target.before-forge.$(date +%Y%m%d%H%M%S)"
    if [ "$DRY" -eq 0 ]; then
      mv "$target" "$backup"
    fi
    printf '  ~ %s (existing moved to %s)\n' "$name" "$(basename "$backup")"
  fi

  if [ "$DRY" -eq 0 ]; then
    ln -s "${dir%/}" "$target"
  fi
  green "  + $name"
  linked=$((linked + 1))
done

printf '\n%s skill(s) linked' "$linked"
[ "$skipped" -gt 0 ] && printf ', \033[31m%s skipped\033[0m' "$skipped"
printf '\n'

if [ "$DRY" -eq 0 ] && [ "$linked" -gt 0 ]; then
  cat <<'EOF'

Skills are read at session start — restart Claude Code, or run /doctor to confirm.
Verify with: /task, /debrief, /writeup
EOF
fi

[ "$skipped" -gt 0 ] && exit 1
exit 0
