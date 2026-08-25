#!/usr/bin/env bash
# Enumerate the full population matching a pattern, then point at the outliers.
#
# If tools here fail with "command not found": some harness shells drop PATH
# inside loop bodies: run `export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin` first.
#
# The `scale` branch fails in one specific way: a pattern is inferred from the
# two or three instances that happened to be read first, thirty mechanical edits
# follow, and the outlier that breaks the pattern is discovered afterwards. This
# script exists so the population comes from the filesystem rather than from
# recollection, and so the instances chosen for reading are chosen to be
# *different*: oldest, newest, densest, instead of alphabetically first.
#
# It also reports which directories the matches cluster in, because that is the
# partition a campaign is delegated along, and which files carry only one match,
# because those are usually the cheap tail rather than the interesting cases.
#
# Reads only. Nothing here writes to the surveyed repo.
#
# Usage:
#   survey.sh <pattern> [dir]        pattern is an extended regex (grep -E)
#   survey.sh --files <glob> [dir]   enumerate by filename instead of content
set -uo pipefail

MODE=content
if [ "${1:-}" = "--files" ]; then
  MODE=files
  shift
fi

PATTERN="${1:-}"
DIR="${2:-.}"

if [ -z "$PATTERN" ]; then
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi
[ -d "$DIR" ] || { printf 'no such directory: %s\n' "$DIR" >&2; exit 1; }

head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }

EXCLUDES=(
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=__pycache__
  --exclude-dir=dist --exclude-dir=build --exclude-dir=.next --exclude-dir=vendor
  --exclude-dir=.cache --exclude-dir=coverage
)

# A plain array rather than a pipeline: `grep | while read` runs the loop in a
# subshell, so every count accumulated inside it is discarded on exit.
files=()
if [ "$MODE" = content ]; then
  while IFS= read -r f; do
    files+=("$f")
  done < <(grep -rlI -E "${EXCLUDES[@]}" -- "$PATTERN" "$DIR" 2>/dev/null | sort)
else
  while IFS= read -r f; do
    files+=("$f")
  done < <(find "$DIR" \
    -type d \( -name .git -o -name node_modules -o -name __pycache__ -o -name dist -o -name build \) -prune -o \
    -type f -name "$PATTERN" -print 2>/dev/null | sort)
fi

head_ "Population"
printf '  pattern: %s   (%s)\n' "$PATTERN" "$MODE"
printf '  root:    %s\n' "$DIR"

if [ "${#files[@]}" -eq 0 ]; then
  printf '\n  0 files matched.\n'
  dim '  A zero count is a finding: the pattern is wrong, or the thing was already done,'
  dim '  or it lives under an excluded directory. Do not proceed on the assumption of zero.'
  exit 0
fi
printf '  files:   %s\n' "${#files[@]}"

if [ "$MODE" = content ]; then
  total=0
  for f in "${files[@]}"; do
    n=$(grep -cE -- "$PATTERN" "$f" 2>/dev/null || echo 0)
    total=$((total + n))
  done
  printf '  matches: %s\n' "$total"
fi

# ── Where it clusters ────────────────────────────────────────────────
# The partition a campaign gets delegated along. Slices that share a directory
# usually share a file eventually, and files cannot be edited in parallel.
head_ "By directory"
for f in "${files[@]}"; do dirname "$f"; done | sort | uniq -c | sort -rn | head -20 |
  while read -r count dir; do
    printf '  %4s  %s\n' "$count" "$dir"
  done

# ── Density ─────────────────────────────────────────────────────────
if [ "$MODE" = content ]; then
  head_ "Densest files"
  dim "  Many matches in one file is one edit, not many. Weight the plan accordingly."
  for f in "${files[@]}"; do
    printf '%s\t%s\n' "$(grep -cE -- "$PATTERN" "$f" 2>/dev/null || echo 0)" "$f"
  done | sort -rn | head -10 | while IFS=$'\t' read -r count f; do
    printf '  %4s  %s\n' "$count" "$f"
  done

  singles=0
  for f in "${files[@]}"; do
    [ "$(grep -cE -- "$PATTERN" "$f" 2>/dev/null || echo 0)" -eq 1 ] && singles=$((singles + 1))
  done
  printf '\n  %s of %s files contain exactly one match\n' "$singles" "${#files[@]}"
fi

# ── The instances worth reading ─────────────────────────────────────
# Chosen to be different from each other. The oldest predates whatever
# convention now applies; the newest is the convention as currently understood;
# the divergence between them is the pattern the survey exists to find.
if git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
  head_ "Read these three"
  dated=()
  for f in "${files[@]}"; do
    when=$(git -C "$DIR" log -1 --format=%at -- "$f" 2>/dev/null)
    [ -n "$when" ] && dated+=("$when	$f")
  done

  if [ "${#dated[@]}" -ge 2 ]; then
    sorted=$(printf '%s\n' "${dated[@]}" | sort -n)
    oldest=$(printf '%s' "$sorted" | head -1)
    newest=$(printf '%s' "$sorted" | tail -1)
    printf '  oldest touched  %s  %s\n' \
      "$(date -r "${oldest%%	*}" '+%Y-%m-%d' 2>/dev/null)" "${oldest#*	}"
    printf '  newest touched  %s  %s\n' \
      "$(date -r "${newest%%	*}" '+%Y-%m-%d' 2>/dev/null)" "${newest#*	}"
    dim "  third: the one someone warns you about. Ask, or take the densest above."
  else
    dim "  not enough git history to date these, pick by directory instead"
  fi

  head_ "Untracked matches"
  untracked=0
  for f in "${files[@]}"; do
    if ! git -C "$DIR" ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
      printf '  %s\n' "$f"
      untracked=$((untracked + 1))
    fi
  done
  [ "$untracked" -eq 0 ] && printf '  none: every match is tracked\n'
fi

head_ "Next"
dim "  Sample the three above before generalising. Then partition into slices that"
dim "  share no file, register each with brief.sh stream add, and hand execution to"
dim "  task --scope campaign."
exit 0
