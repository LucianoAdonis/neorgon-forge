#!/usr/bin/env bash
# Bring the local install up to date with the repo, and report anything
# that drifted.
#
# With symlinked skills there is usually nothing to copy: the link already
# points at the live files. What this actually does is pull, re-link
# anything new, re-validate, and tell you which installs have gone stale.
#
# Usage:
#   refresh.sh              pull, re-link, validate
#   refresh.sh --no-pull    skip git pull (offline, or dirty tree)
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PULL=1

while [ $# -gt 0 ]; do
  case "$1" in
    --no-pull) PULL=0; shift ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

green() { printf '\033[32m%s\033[0m\n' "$1"; }
warn()  { printf '\033[33m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }
head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

cd "$REPO" || { printf 'cannot enter %s\n' "$REPO" >&2; exit 1; }

head_ "Source"
if [ "$PULL" -eq 1 ] && git rev-parse --git-dir >/dev/null 2>&1; then
  if [ -n "$(git status --porcelain)" ]; then
    warn "  working tree is dirty: skipping pull so nothing gets clobbered"
    git status --short | sed 's/^/    /'
  elif git remote | grep -q .; then
    git pull --ff-only 2>&1 | sed 's/^/  /'
  else
    dim "  no remote configured: nothing to pull"
  fi
else
  dim "  pull skipped"
fi
printf '  at %s\n' "$(git log -1 --format='%h %s' 2>/dev/null || echo 'no commits')"

head_ "Links"
bash "$REPO/bin/install.sh" | sed 's/^/  /'

head_ "Stale links elsewhere"
# A skill directory in ~/.claude/skills that shares a name with one of ours
# but is not a link into this repo will win or lose unpredictably. Worth
# knowing about.
for dir in "$REPO"/plugins/neorgon-forge/skills/*/*/; do
  name=$(basename "$dir")
  target="$HOME/.claude/skills/$name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    warn "  $name in ~/.claude/skills is a real directory, not a link to this repo"
  elif [ -L "$target" ]; then
    link=$(readlink "$target")
    case "$link" in
      "$REPO"*) : ;;
      *) warn "  $name links to $link, outside this repo" ;;
    esac
  fi
done

# The project-level copy in this monorepo is the other place these skills
# live; a divergence there is the likeliest source of confusion.
PROJECT_SKILLS="$(dirname "$REPO")/.claude/skills"
if [ -d "$PROJECT_SKILLS" ]; then
  head_ "Monorepo project skills"
  for dir in "$REPO"/plugins/neorgon-forge/skills/*/*/; do
    name=$(basename "$dir")
    p="$PROJECT_SKILLS/$name"
    if [ -L "$p" ]; then
      dim "  $name → $(readlink "$p")"
    elif [ -d "$p" ]; then
      if diff -rq "$dir" "$p" >/dev/null 2>&1; then
        green "  $name is identical to the repo copy"
      else
        warn "  $name DIFFERS from the repo copy: two sources of truth"
        dim "      diff -ru $p $dir"
      fi
    fi
  done
fi

head_ "Validation"
bash "$REPO/bin/validate.sh" | tail -20 | sed 's/^/  /'

printf '\nRestart Claude Code to pick up changed skills.\n'

printf '\n\033[1m== Install state\033[0m\n'
python3 "$(dirname "$0")/check-install.py" || true
