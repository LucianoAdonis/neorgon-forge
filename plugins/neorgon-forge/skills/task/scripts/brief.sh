#!/usr/bin/env bash
# Maintain .forge/brief.md — the record of what a task was for, what was
# decided, and what is still open.
#
# The point is that it gets written *while* the work happens. A decision
# recalled at the end of a long session has already lost the alternative
# it beat, which is the part worth reporting.
#
# Usage:
#   brief.sh init "<problem>"              start a brief (idempotent)
#   brief.sh note "<what you learned>"     append a timestamped decision
#   brief.sh stream add "<name>" "<goal>"  register a workstream
#   brief.sh stream start "<name>"         mark it in progress
#   brief.sh stream done "<name>" "<outcome>"
#   brief.sh stream block "<name>" "<why>"
#   brief.sh status                        streams and their state
#   brief.sh close                         stamp it complete
#   brief.sh path                          print the brief path
set -uo pipefail

FORGE_DIR="${FORGE_BRIEF_DIR:-.forge}"
BRIEF="$FORGE_DIR/brief.md"
STREAMS="$FORGE_DIR/streams.tsv"

# Timestamps come from the shell because a model cannot read a clock.
now()   { date '+%Y-%m-%d %H:%M'; }
today() { date '+%Y-%m-%d'; }

die()   { printf '\033[31m%s\033[0m\n' "$1" >&2; exit 1; }
ok()    { printf '\033[32m%s\033[0m\n' "$1"; }
head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

need_brief() {
  [ -f "$BRIEF" ] || die "no brief at $BRIEF — run: brief.sh init \"<problem>\""
}

cmd_init() {
  local problem="${1:-}"
  [ -n "$problem" ] || die 'usage: brief.sh init "<one-line problem>"'
  mkdir -p "$FORGE_DIR"

  if [ -f "$BRIEF" ]; then
    ok "brief already exists at $BRIEF — appending a new run"
    {
      printf '\n---\n\n## Run — %s\n\n' "$(now)"
      printf '**Problem.** %s\n' "$problem"
    } >>"$BRIEF"
    return
  fi

  cat >"$BRIEF" <<EOF
# Brief — $problem

Started $(now). Maintained by the \`task\` skill; read by \`debrief\` and \`writeup\`.

## Problem

$problem

<!-- What was wrong *before*. The symptom someone actually experienced, not the
     absence of the solution. debrief opens its deck on this, so vagueness here
     costs a slide later. -->

## Approach

<!-- What you are doing, in a paragraph. -->

## Rejected

<!-- The alternative you considered and why it lost. Usually the most interesting
     thing in the brief, and the first thing forgotten. -->

## Decisions

<!-- Appended by: brief.sh note "<what you learned>" -->

## Measured

<!-- Numbers you actually observed, with how you got them. An estimate recorded
     here becomes a false claim on a slide, so mark estimates as estimates. -->

## Open

<!-- Deferred work, defects that shipped anyway, decisions left to the user.
     Never empty without a deliberate "nothing open" line. -->
EOF
  : >"$STREAMS"
  ok "created $BRIEF"
}

cmd_note() {
  need_brief
  local text="${1:-}"
  [ -n "$text" ] || die 'usage: brief.sh note "<what you learned>"'
  # Append at the END of the Decisions section, not right after the
  # heading: a decision log reads as a narrative, and newest-first
  # inverts the story it is supposed to tell.
  local tmp
  tmp=$(mktemp)
  awk -v entry="- \`$(now)\` $text" '
    /^## / && inside && !placed { print entry; print ""; placed = 1; inside = 0 }
    { print }
    /^## Decisions$/ { inside = 1 }
    END { if (inside && !placed) print entry }
  ' "$BRIEF" >"$tmp" && mv "$tmp" "$BRIEF"
  ok "noted"
}

stream_field() { awk -F'\t' -v n="$1" '$1 == n { print $2 }' "$STREAMS" 2>/dev/null | tail -1; }

stream_set() {
  local name="$1" state="$2" detail="${3:-}"
  mkdir -p "$FORGE_DIR"
  touch "$STREAMS"
  local tmp
  tmp=$(mktemp)
  awk -F'\t' -v n="$name" '$1 != n' "$STREAMS" >"$tmp"
  printf '%s\t%s\t%s\t%s\n' "$name" "$state" "$(now)" "$detail" >>"$tmp"
  mv "$tmp" "$STREAMS"
}

cmd_stream() {
  need_brief
  local action="${1:-}" name="${2:-}" detail="${3:-}"
  [ -n "$name" ] || die 'usage: brief.sh stream <add|start|done|block> "<name>" ["<detail>"]'
  case "$action" in
    add)   stream_set "$name" pending "$detail";     ok "stream added: $name" ;;
    start) stream_set "$name" active  "$detail";     ok "stream active: $name" ;;
    "done") stream_set "$name" "done" "$detail"
           # The outcome is what debrief reports, so it lands in the brief
           # body too — including whatever the stream got wrong.
           cmd_note "stream **$name** done — ${detail:-no outcome recorded}"
           ok "stream done: $name" ;;
    block) stream_set "$name" blocked "$detail"
           cmd_note "stream **$name** BLOCKED — ${detail:-no reason recorded}"
           ok "stream blocked: $name" ;;
    *)     die "unknown stream action: $action" ;;
  esac
}

cmd_status() {
  need_brief
  head_ "Brief"
  printf '  %s\n' "$BRIEF"
  grep -m1 '^# Brief' "$BRIEF" | sed 's/^# Brief — /  /'

  head_ "Streams"
  if [ ! -s "$STREAMS" ]; then
    echo "  (none — inline task)"
  else
    awk -F'\t' '
      { mark = ($2 == "done") ? "[x]" : ($2 == "active") ? "[>]" : ($2 == "blocked") ? "[!]" : "[ ]"
        printf "  %s %-28s %-8s %s\n", mark, $1, $2, $4 }
    ' "$STREAMS"
    local total done_
    total=$(wc -l <"$STREAMS" | tr -d ' ')
    done_=$(awk -F'\t' '$2 == "done"' "$STREAMS" | wc -l | tr -d ' ')
    printf '\n  %s/%s complete\n' "$done_" "$total"
    awk -F'\t' '$2 == "blocked" { print "  blocked: " $1 " — " $4 }' "$STREAMS"
  fi

  head_ "Unfilled sections"
  # A brief with empty sections is the common failure: the scaffold gets
  # created and never filled, and the deck inherits the emptiness.
  # Reported, never fatal — status is a diagnostic and is expected to run
  # mid-task when sections legitimately are not filled yet.
  local empty=0
  for h in Approach Rejected Measured Open; do
    awk -v h="## $h" '
      $0 == h { inside = 1; next }
      /^## / { inside = 0 }
      inside && !/^[[:space:]]*$/ && !/^<!--/ && !/^ *-->/ && !/^ /  { found = 1 }
      END { exit found ? 0 : 1 }
    ' "$BRIEF" || { printf '  %s is still empty\n' "$h"; empty=1; }
  done
  [ "$empty" -eq 0 ] && ok "  all filled"
  return 0
}

cmd_close() {
  need_brief
  if [ -s "$STREAMS" ]; then
    local open_
    open_=$(awk -F'\t' '$2 != "done"' "$STREAMS" | wc -l | tr -d ' ')
    if [ "$open_" != "0" ]; then
      printf '\033[31m%s\033[0m\n' "  $open_ stream(s) not done — these belong under ## Open, not dropped:"
      awk -F'\t' '$2 != "done" { print "    " $1 " (" $2 ") " $4 }' "$STREAMS"
    fi
  fi
  printf '\n_Closed %s._\n' "$(now)" >>"$BRIEF"
  cmd_status
  ok "closed $BRIEF"
}

case "${1:-}" in
  init)   shift; cmd_init "$@" ;;
  note)   shift; cmd_note "$@" ;;
  stream) shift; cmd_stream "$@" ;;
  status) cmd_status ;;
  close)  cmd_close ;;
  path)   echo "$BRIEF" ;;
  *)      sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
