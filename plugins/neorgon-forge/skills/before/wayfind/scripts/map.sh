#!/usr/bin/env bash
# Maintain a map of an application: its navigable areas, its path rules, and
# what practice taught that the census did not.
#
# Three problems this solves, all of them re-solved from scratch every session
# otherwise. Where does a change of this kind go: answered by a rule with a
# recorded basis rather than by inference from whichever file was opened first.
# Which area does this ticket touch: answered by resolving its terms against
# the map instead of grepping the whole repo again. And has the map gone stale,
# answered by `check`, because a rule whose glob now matches nothing is worse
# than no rule: it is confidently wrong.
#
# Every rule carries a basis. A rule with no basis is a guess that outlives the
# session that guessed it, and `rule` refuses to record one.
#
# If tools here fail with "command not found": some harness shells drop PATH
# inside loop bodies: run `export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin` first.
#
# Usage:
#   map.sh init "<application>"
#   map.sh area <name> <paths,comma,separated> "<what lives here>"
#   map.sh rule <glob> <kind> "<basis: how this was established>"
#   map.sh learn "<what practice taught>" [--rule <glob>]
#   map.sh resolve <path>                which rules and area apply
#   map.sh ticket "<ticket text>"        candidate paths, ranked
#   map.sh check                         rules that no longer match anything
#   map.sh index [root]                  aggregate child repos' maps (submodule hubs)
#   map.sh status
#   map.sh path
set -uo pipefail

# Logs written before 2026-08 head their first line with an em dash. New ones
# use a colon. Readers accept both, so a file already on disk stays readable.
# Built from an escape so this file contains no em dash of its own.
LEGACY_SEP=$(printf '\u2014')

FORGE_DIR="${FORGE_BRIEF_DIR:-.forge}"
MAP="$FORGE_DIR/map.md"
RULES="$FORGE_DIR/map-rules.tsv"
AREAS="$FORGE_DIR/map-areas.tsv"
LESSONS="$FORGE_DIR/map-lessons.tsv"

now() { date '+%Y-%m-%d %H:%M'; }

die()   { printf '\033[31m%s\033[0m\n' "$1" >&2; exit 1; }
ok()    { printf '\033[32m%s\033[0m\n' "$1"; }
warn()  { printf '\033[33m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }
head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

PRUNE=(-type d \( -name .git -o -name node_modules -o -name __pycache__ \
  -o -name dist -o -name build -o -name .next -o -name vendor -o -name .venv \) -prune)

need_map() {
  [ -f "$MAP" ] || die "no map at $MAP: run: map.sh init \"<application>\""
}

# Same guard as task's brief.sh, same reason: a git tree in a cloud-sync
# folder forks concurrently-written files into silent "name 2.ext" copies,
# and the map is exactly the kind of long-lived file that loses. Details:
# skills/task/reference/hazards.md.
warn_cloud_sync() {
  case "$PWD" in
    *"/Mobile Documents/"*|*"/Dropbox/"*|*"/Dropbox"|*"/OneDrive"*|*"/Google Drive/"*|*"/My Drive/"*)
      printf '\033[31mWARNING: this directory is inside a cloud-sync folder.\033[0m\n' >&2
      printf '\033[31m  git and sync daemons both assume they own the tree, concurrent writes fork\033[0m\n' >&2
      printf '\033[31m  files silently. Move the repo to an unsynced path before mapping it.\033[0m\n' >&2
      ;;
  esac
}

# Terms, not sentences: words under four characters and the obvious filler
# match everything and rank nothing. Shared by `ticket` and `index` so the
# two cannot drift into tokenizing differently.
extract_terms() {
  tr '[:upper:]' '[:lower:]' |
    tr -cs '[:alnum:]_-' '\n' |
    awk 'length($0) > 3 && $0 !~ /^(the|and|when|with|that|this|from|into|user|users|page|should|would|does|doesnt|isnt|need|needs|make|makes|show|shows|after|before|because|there|their|been|have|will|only|also|then|than|some|what|which|where|while|about|able)$/' |
    sort -u
}

# A glob is matched with find -path, so `*` spans directory separators. That is
# deliberate: `src/components/*.tsx` should find a nested one too, because a
# rule about a kind of file is about the kind, not the depth.
glob_files() {
  find . "${PRUNE[@]}" -o -type f -path "./$1" -print 2>/dev/null | sort
}
glob_count() { glob_files "$1" | wc -l | tr -d ' '; }

plural() {
  if [ "$1" -eq 1 ]; then printf '%s %s' "$1" "$2"; else printf '%s %ss' "$1" "$2"; fi
}

append_section() {
  local section="$1" entry="$2" tmp
  tmp=$(mktemp)
  awk -v sec="## $section" -v entry="$entry" '
    /^## / && inside && !placed { print entry; print ""; placed = 1; inside = 0 }
    { print }
    $0 == sec { inside = 1 }
    END { if (inside && !placed) print entry }
  ' "$MAP" >"$tmp" && mv "$tmp" "$MAP"
}

cmd_init() {
  local app="${1:-}"
  [ -n "$app" ] || die 'usage: map.sh init "<application>"'
  warn_cloud_sync
  mkdir -p "$FORGE_DIR"
  if [ -f "$MAP" ]; then
    ok "map already exists at $MAP"
    return 0
  fi

  cat >"$MAP" <<EOF
# Map: $app

Started $(now). Maintained by the \`wayfind\` skill. Run \`map.sh check\` before
trusting it: a rule that no longer matches anything is worse than no rule.

## Areas

<!-- A navigable region of the application, in the user's terms rather than the
     directory's: "checkout", "admin settings", "the public marketing pages".
     Areas are what a ticket names; directories are what a rule names. -->

## Rules

<!-- Where a change of a given kind goes, plus how that was established.
     Basis is not optional: "census: 41 files, no exceptions" is a rule,
     "seems standard" is a guess wearing a rule's clothes. -->

## Learned

<!-- What practice taught that the census could not. The exception, the file
     that looks like the others and is not, the rule that holds everywhere
     except one place and why. This section is the reason the map is worth
     keeping rather than regenerating. -->

## Open questions

<!-- What the map cannot answer yet. Better here than silently guessed. -->
EOF
  : >"$RULES"
  : >"$AREAS"
  : >"$LESSONS"
  ok "created $MAP"
  dim "  next: orient.sh, then record what it establishes as rules"
}

cmd_area() {
  need_map
  local name="${1:-}" paths="${2:-}" desc="${3:-}"
  [ -n "$name" ] && [ -n "$paths" ] ||
    die 'usage: map.sh area <name> <paths,comma,separated> "<what lives here>"'

  local missing=""
  local IFS_SAVE="$IFS"
  IFS=','
  for p in $paths; do
    [ -e "$p" ] || missing="$missing $p"
  done
  IFS="$IFS_SAVE"
  if [ -n "$missing" ]; then
    warn "these paths do not exist:$missing"
    dim "  recorded anyway, but a map of paths that are not there is fiction"
  fi

  printf '%s\t%s\t%s\t%s\n' "$name" "$paths" "$desc" "$(now)" >>"$AREAS"
  append_section Areas "- **$name**: ${desc:-no description} · \`${paths//,/\`, \`}\`"
  ok "area $name recorded"
}

cmd_rule() {
  need_map
  local glob="${1:-}" kind="${2:-}" basis="${3:-}"
  [ -n "$glob" ] && [ -n "$kind" ] ||
    die 'usage: map.sh rule <glob> <kind> "<basis>"'
  if [ -z "$basis" ]; then
    die "basis required: how was this established?
  A census, a stated convention in CONTRIBUTING/CLAUDE.md, or the user saying so.
  Without one it is a guess, and it will be trusted like a fact next session."
  fi

  local n
  n=$(glob_count "$glob")
  if [ "$n" -eq 0 ]; then
    warn "\`$glob\` matches 0 files right now"
    dim "  either the glob is wrong or the convention is aspirational, say which"
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' "$glob" "$kind" "$basis" "$n" "$(now)" >>"$RULES"
  append_section Rules "- \`$glob\` → **$kind** · $(plural "$n" file) at record time · basis: $basis"
  ok "rule recorded: $(plural "$n" file) matched"
}

cmd_learn() {
  need_map
  local text="" glob=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --rule) glob="${2:-}"; shift 2 ;;
      *) text="$1"; shift ;;
    esac
  done
  [ -n "$text" ] || die 'usage: map.sh learn "<what practice taught>" [--rule <glob>]'

  local entry="- $text"
  [ -n "$glob" ] && entry="- \`$glob\`: $text"
  append_section Learned "$entry"

  # Also in a TSV, so `resolve` can surface a lesson attached to a glob rather
  # than only one that happens to name the file literally. A lesson nobody is
  # shown at the moment it applies has not been learned, only written down.
  mkdir -p "$FORGE_DIR"
  printf '%s\t%s\t%s\n' "${glob:-*}" "$text" "$(now)" >>"$LESSONS"

  ok "recorded"
  if [ -z "$glob" ]; then
    dim "  attach it to a glob with --rule so resolve surfaces it on the right files"
  fi
  dim "  if this contradicts a rule, correct the rule too. The map is read as current"
}

cmd_resolve() {
  need_map
  local target="${1:-}"
  [ -n "$target" ] || die 'usage: map.sh resolve <path>'

  head_ "Resolving $target"
  [ -e "$target" ] || dim "  (path does not exist, resolving as a hypothetical)"

  local hits=0 clean="${target#./}"
  head_ "Rules that apply"
  if [ -s "$RULES" ]; then
    while IFS=$'\t' read -r glob kind basis _ _; do
      # The glob is unquoted on purpose: it is a pattern, not a literal. The
      # backticks are Markdown code fencing in output a person reads.
      # shellcheck disable=SC2254,SC2016
      case "$clean" in
        $glob) printf '  \033[1m%s\033[0m via `%s`\n      basis: %s\n' "$kind" "$glob" "$basis"; hits=$((hits + 1)) ;;
      esac
    done <"$RULES"
  fi
  if [ "$hits" -eq 0 ]; then
    warn "  no rule covers this path"
    dim "      either it is a new kind of file, or a rule is missing. Do not invent one:"
    dim "      establish it (orient.sh, or ask) and record it with its basis."
  fi

  head_ "Area"
  local found=0
  if [ -s "$AREAS" ]; then
    while IFS=$'\t' read -r name paths desc _; do
      local IFS_SAVE="$IFS"
      IFS=','
      for p in $paths; do
        case "$clean" in
          "${p%/}"/*|"$p") printf '  %s: %s\n' "$name" "$desc"; found=1 ;;
        esac
      done
      IFS="$IFS_SAVE"
    done <"$AREAS"
  fi
  [ "$found" -eq 0 ] && dim "  no area claims this path"

  head_ "Learned"
  local lessons=0
  if [ -s "$LESSONS" ]; then
    while IFS=$'\t' read -r glob text _; do
      # shellcheck disable=SC2254
      case "$clean" in
        $glob) printf '  %s\n' "$text"; lessons=$((lessons + 1)) ;;
      esac
    done <"$LESSONS"
  fi
  if [ "$lessons" -eq 0 ]; then
    dim "  nothing recorded that applies here"
    dim "      if this file surprises you, that is a lesson: map.sh learn \"…\" --rule '$clean'"
  fi
  return 0
}

cmd_ticket() {
  need_map
  local text="${1:-}"
  [ -n "$text" ] || die 'usage: map.sh ticket "<ticket text>"'

  head_ "Ticket"
  printf '  %s\n' "$text"

  local terms
  terms=$(printf '%s\n' "$text" | extract_terms)

  [ -n "$terms" ] || { warn "  no usable terms. The ticket is too vague to resolve"; return 0; }

  head_ "Terms"
  printf '%s\n' "$terms" | tr '\n' ' ' | sed 's/^/  /;s/ $/\n/'

  # Ranked by how many distinct ticket terms a file mentions. One shared term is
  # coincidence; three is the file the ticket is about.
  head_ "Candidate files"
  dim "  distinct ticket terms matched, per file, read the top of this list first"
  local tmp
  tmp=$(mktemp)
  while IFS= read -r term; do
    grep -rlI --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist \
      --exclude-dir=build --exclude-dir=.next --exclude-dir=__pycache__ \
      --exclude-dir="$FORGE_DIR" -i -- "$term" . 2>/dev/null
  done <<<"$terms" | sort | uniq -c | sort -rn | head -15 >"$tmp"

  if [ ! -s "$tmp" ]; then
    warn "  nothing matched"
    dim "      the ticket's vocabulary is not the code's vocabulary. Ask which feature"
    dim "      it means, or resolve it through Areas below instead of through grep."
  else
    while read -r count file; do
      printf '  %2s  %s\n' "$count" "$file"
    done <"$tmp"
    # A top score of one is not a ranking, it is an alphabetical list of files
    # that share a common word. Saying so prevents the first line being read as
    # an answer.
    if [ "$(awk 'NR == 1 { print $1 }' "$tmp")" = "1" ]; then
      dim "      every candidate matched one term only. This is not yet a ranking"
    fi
  fi
  rm -f "$tmp"

  head_ "Areas mentioning these terms"
  local shown=0
  if [ -s "$AREAS" ]; then
    while IFS=$'\t' read -r name paths desc _; do
      while IFS= read -r term; do
        if printf '%s %s %s' "$name" "$paths" "$desc" | grep -qi -- "$term"; then
          printf '  %s: %s · %s\n' "$name" "$desc" "$paths"
          shown=1
          break
        fi
      done <<<"$terms"
    done <"$AREAS"
  fi
  [ "$shown" -eq 0 ] && dim "  none: either the area is unmapped or the ticket uses different words"

  head_ "Next"
  dim "  resolve the top candidate to get its rules: map.sh resolve <path>"
  dim "  then state the affected area and the files you expect to change, before editing."
  return 0
}

# A submodule hub or monorepo gets one map per child repo, which is right,
# and structurally blind: the same collection, field, or concern touched by two
# repos is invisible when each map is read alone. That blindness is where
# duplicated jobs hide. `index` aggregates the child maps and flags the
# vocabulary they share, so a cross-repo overlap becomes a listed fact instead
# of an open question. It writes the parent's .forge/map-index.md; regenerate
# rather than edit.
cmd_index() {
  local root="${1:-.}"
  [ -d "$root" ] || die "no such directory: $root"

  local list
  list=$(mktemp)
  find "$root" -mindepth 3 -maxdepth 5 \
    \( -name node_modules -o -name .git \) -prune -o \
    -type f -path '*/.forge/map.md' -print 2>/dev/null | sort >"$list"

  if [ ! -s "$list" ]; then
    rm -f "$list"
    warn "no child maps under $root"
    dim "  a child map is <repo>/.forge/map.md, run wayfind inside each repo first"
    return 0
  fi

  mkdir -p "$FORGE_DIR"
  local out="$FORGE_DIR/map-index.md" pairs
  pairs=$(mktemp)

  {
    printf '# Map index: %s\n\n' "$(cd "$root" && pwd)"
    printf 'Generated %s by `map.sh index`. Regenerate rather than edit.\n\n' "$(now)"
    printf '## Repos\n\n'
  } >"$out"

  head_ "Child maps"
  while IFS= read -r m; do
    local rdir rname fdir areas rules lessons anames
    fdir=$(dirname "$m")
    rdir=$(dirname "$fdir")
    rname="${rdir#"$root"/}"
    areas=0; rules=0; lessons=0
    [ -s "$fdir/map-areas.tsv" ]   && areas=$(wc -l <"$fdir/map-areas.tsv" | tr -d ' ')
    [ -s "$fdir/map-rules.tsv" ]   && rules=$(wc -l <"$fdir/map-rules.tsv" | tr -d ' ')
    [ -s "$fdir/map-lessons.tsv" ] && lessons=$(wc -l <"$fdir/map-lessons.tsv" | tr -d ' ')
    anames=$(awk -F'\t' '{ print $1 }' "$fdir/map-areas.tsv" 2>/dev/null | paste -sd, - | sed 's/,/, /g')
    printf '  %-28s %s, %s, %s\n' "$rname" \
      "$(plural "$areas" area)" "$(plural "$rules" rule)" "$(plural "$lessons" lesson)"
    printf -- '- **%s**: %s, %s, %s%s\n' \
      "$rname" "$(plural "$areas" area)" "$(plural "$rules" rule)" "$(plural "$lessons" lesson)" \
      "${anames:+ · areas: $anames}" >>"$out"

    # The vocabulary this repo's map uses: area names and descriptions, plus
    # lesson texts. Rules are globs and excluded, path syntax is not a concern.
    { awk -F'\t' '{ print $1, $3 }' "$fdir/map-areas.tsv" 2>/dev/null
      awk -F'\t' '{ print $2 }'     "$fdir/map-lessons.tsv" 2>/dev/null
    } | extract_terms |
      awk 'length($0) > 3 && $0 !~ /^(file|files|live|lives|here|goes|kind|each|these|other|them)$/' |
      awk -v r="$rname" '{ print $0 "\t" r }' >>"$pairs"
  done <"$list"

  head_ "Shared concerns"
  dim "  a term two repos' maps both use: where duplicated jobs and split ownership hide"
  local shared
  shared=$(sort -u "$pairs" | awk -F'\t' '
    { repos[$1] = repos[$1] ", " $2; n[$1]++ }
    END { for (t in repos) if (n[t] > 1) printf "%d\t%s\t%s\n", n[t], t, substr(repos[t], 3) }
  ' | sort -rn | head -20)

  printf '\n## Shared concerns\n\n' >>"$out"
  if [ -n "$shared" ]; then
    printf '%s\n' "$shared" | while IFS=$'\t' read -r n term repos; do
      printf '  %-24s %s\n' "$term" "$repos"
      printf -- '- `%s`: %s\n' "$term" "$repos" >>"$out"
    done
    echo
    dim "  each of these is a question: same concern, or same job done twice?"
  else
    dim "  none: the child maps share no vocabulary beyond filler"
    printf 'None: the child maps share no vocabulary beyond filler.\n' >>"$out"
  fi

  rm -f "$list" "$pairs"
  echo
  ok "wrote $out"
  return 0
}

cmd_check() {
  need_map
  head_ "Rule drift"
  if [ ! -s "$RULES" ]; then
    dim "  no rules recorded"
    return 0
  fi

  local stale=0 grown=0
  # Backticks below are Markdown fencing for the glob, not command substitution.
  # shellcheck disable=SC2016
  while IFS=$'\t' read -r glob kind _ was _; do
    local n
    n=$(glob_count "$glob")
    if [ "$n" -eq 0 ] && [ "$was" -eq 0 ]; then
      # Never matched anything, not even when recorded. Aspirational rather than
      # drifted, and worth naming differently: the code did not move, the rule
      # was wrong on arrival.
      printf '\033[33m  EMPTY `%s` (%s): matched nothing then either\033[0m\n' "$glob" "$kind"
      stale=$((stale + 1))
    elif [ "$n" -eq 0 ]; then
      printf '\033[31m  DEAD  `%s` (%s): %s when recorded, 0 now\033[0m\n' \
        "$glob" "$kind" "$(plural "$was" file)"
      stale=$((stale + 1))
    elif [ "$n" -gt $((was * 2)) ] && [ "$was" -gt 0 ]; then
      printf '\033[33m  GREW  `%s` (%s): %s → %s files\033[0m\n' "$glob" "$kind" "$was" "$n"
      grown=$((grown + 1))
    else
      printf '  ok    `%s` (%s): %s\n' "$glob" "$kind" "$(plural "$n" file)"
    fi
  done <"$RULES"

  if [ "$stale" -gt 0 ]; then
    echo
    warn "  $(plural "$stale" rule) above match nothing, fix or delete each one"
    dim "      a dead rule is worse than a missing one: it is trusted and it is wrong"
  fi
  if [ "$grown" -gt 0 ]; then
    echo
    dim "  $(plural "$grown" rule) more than doubled, re-sample, the convention may have split"
  fi
  return 0
}

cmd_status() {
  need_map
  head_ "Map"
  grep -m1 '^# Map' "$MAP" | sed -E "s/^# Map( $LEGACY_SEP|:) /  /"
  printf '  %s\n' "$MAP"

  local areas=0 rules=0 learned=0
  [ -s "$AREAS" ] && areas=$(wc -l <"$AREAS" | tr -d ' ')
  [ -s "$RULES" ] && rules=$(wc -l <"$RULES" | tr -d ' ')
  [ -s "$LESSONS" ] && learned=$(wc -l <"$LESSONS" | tr -d ' ')

  printf '\n  %s, %s, %s\n' \
    "$(plural "$areas" area)" "$(plural "$rules" rule)" "$(plural "$learned" lesson)"

  if [ "$rules" -gt 0 ] && [ "$learned" -eq 0 ]; then
    dim "  no lessons yet: expected early. A map with rules and no exceptions after"
    dim "  several tickets means exceptions are being absorbed silently."
  fi
  if [ "$areas" -eq 0 ]; then
    warn "  no areas: tickets arrive in feature words, and only areas translate them"
  fi
  return 0
}

case "${1:-}" in
  init)    shift; cmd_init "$@" ;;
  area)    shift; cmd_area "$@" ;;
  rule)    shift; cmd_rule "$@" ;;
  learn)   shift; cmd_learn "$@" ;;
  resolve) shift; cmd_resolve "$@" ;;
  ticket)  shift; cmd_ticket "$@" ;;
  check)   cmd_check ;;
  index)   shift; cmd_index "$@" ;;
  status)  cmd_status ;;
  path)    echo "$MAP" ;;
  *)       awk 'NR > 1 { if (!/^#/) exit; line = $0; sub(/^# ?/, "", line); print line }' "$0" ;;
esac
