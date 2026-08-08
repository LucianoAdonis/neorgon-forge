#!/usr/bin/env bash
# Track competing hypotheses and the observations that kill them.
#
# The discipline this enforces is refutation. A hypothesis registered here
# must come with the observation that would rule it out, because a theory
# nothing could disprove cannot be crossed off — it lingers, gets
# re-litigated, and quietly becomes the assumption everything else rests on.
#
# `status` sorts live theories to the top and prints the refuting test for
# each, so the next step is always the cheapest discriminating check rather
# than whichever theory feels warmest.
#
# Usage:
#   evidence.sh init "<symptom>"                    start a log
#   evidence.sh hypothesis "<theory>" "<what would refute it>"
#   evidence.sh observe "<what you saw>" [--refutes N] [--supports N]
#   evidence.sh refute N "<the observation that killed it>"
#   evidence.sh confirm N "<how it was proven, reproducibly>"
#   evidence.sh status                              live theories first
#   evidence.sh path
set -uo pipefail

FORGE_DIR="${FORGE_BRIEF_DIR:-.forge}"
LOG="$FORGE_DIR/evidence.md"
HYP="$FORGE_DIR/hypotheses.tsv"

now() { date '+%Y-%m-%d %H:%M'; }

die()   { printf '\033[31m%s\033[0m\n' "$1" >&2; exit 1; }
ok()    { printf '\033[32m%s\033[0m\n' "$1"; }
warn()  { printf '\033[33m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }
head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

need_log() {
  [ -f "$LOG" ] || die "no evidence log at $LOG — run: evidence.sh init \"<symptom>\""
}

# Hypotheses are numbered from 1 and referenced by number everywhere, so a
# note can point at one without restating it.
next_id() {
  [ -s "$HYP" ] || { echo 1; return; }
  awk -F'\t' 'BEGIN { max = 0 } $1 > max { max = $1 } END { print max + 1 }' "$HYP"
}

hyp_state() { awk -F'\t' -v n="$1" '$1 == n { print $2 }' "$HYP" 2>/dev/null | tail -1; }
hyp_text()  { awk -F'\t' -v n="$1" '$1 == n { print $3 }' "$HYP" 2>/dev/null | tail -1; }

hyp_exists() {
  [ -s "$HYP" ] && [ -n "$(hyp_state "$1")" ]
}

append_log() {
  # The backticks are Markdown code fencing for the timestamp, not a
  # subshell — the log is a document someone reads.
  # shellcheck disable=SC2016
  printf -- '- `%s` %s\n' "$(now)" "$1" >>"$LOG"
}

cmd_init() {
  local symptom="${1:-}"
  [ -n "$symptom" ] || die 'usage: evidence.sh init "<symptom>"'
  mkdir -p "$FORGE_DIR"
  if [ -f "$LOG" ]; then
    ok "evidence log already exists at $LOG"
    return 0
  fi

  cat >"$LOG" <<EOF
# Evidence — $symptom

Started $(now). Maintained by the \`untangle\` skill.

## Observed

<!-- What actually happens, in terms someone else could reproduce. No
     interpretation: "returns 403 for locale=es, 200 for locale=en", not
     "the locale handling is broken". The two get conflated within minutes
     and everything downstream inherits the confusion. -->

- $symptom

## Ruled out

<!-- Appended when a hypothesis is refuted. This section is the actual
     product of a hard investigation: it is what stops the next session,
     or the next person, re-testing what you already killed. -->

## Log

<!-- Appended by: evidence.sh observe "<what you saw>" -->
EOF
  : >"$HYP"
  ok "created $LOG"
}

cmd_hypothesis() {
  need_log
  local theory="${1:-}" refuter="${2:-}"
  [ -n "$theory" ] || die 'usage: evidence.sh hypothesis "<theory>" "<what would refute it>"'
  if [ -z "$refuter" ]; then
    die "refutation test required: what observation would prove this wrong?
  A hypothesis nothing could disprove is a hunch, and it cannot be crossed off."
  fi

  local id
  id=$(next_id)
  mkdir -p "$FORGE_DIR"
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" live "$theory" "$refuter" "$(now)" >>"$HYP"
  append_log "**H$id** proposed: $theory  _(refuted by: $refuter)_"
  ok "H$id registered"

  local live
  live=$(awk -F'\t' '$2 == "live"' "$HYP" | wc -l | tr -d ' ')
  if [ "$live" -eq 1 ]; then
    warn "only one live hypothesis — a single theory is a hunch with a to-do list"
    dim "  register the competing explanation before testing this one"
  fi
}

cmd_observe() {
  need_log
  local text="" refutes="" supports=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --refutes)  refutes="${2:-}"; shift 2 ;;
      --supports) supports="${2:-}"; shift 2 ;;
      *) text="$1"; shift ;;
    esac
  done
  [ -n "$text" ] || die 'usage: evidence.sh observe "<what you saw>" [--refutes N] [--supports N]'

  local tags=""
  if [ -n "$refutes" ]; then
    hyp_exists "$refutes" || die "no hypothesis H$refutes"
    tags=" — refutes **H$refutes**"
  fi
  if [ -n "$supports" ]; then
    hyp_exists "$supports" || die "no hypothesis H$supports"
    tags="$tags — supports **H$supports**"
  fi
  append_log "observed: $text$tags"

  [ -n "$refutes" ] && cmd_refute "$refutes" "$text"
  if [ -n "$supports" ] && [ -z "$refutes" ]; then
    # Support is deliberately not a state change. Confirmation accumulates
    # for whichever theory is being looked at hardest, which is exactly the
    # bias this script exists to interrupt.
    dim "  H$supports supported, not confirmed — what would still rule it out?"
  fi
  ok "logged"
}

hyp_set() {
  local id="$1" state="$2" detail="$3"
  local tmp
  tmp=$(mktemp)
  awk -F'\t' -v n="$id" -v s="$state" -v d="$detail" -v t="$(now)" '
    BEGIN { OFS = "\t" }
    $1 == n { $2 = s; $5 = t; $6 = d }
    { print }
  ' "$HYP" >"$tmp" && mv "$tmp" "$HYP"
}

cmd_refute() {
  need_log
  local id="${1:-}" why="${2:-}"
  [ -n "$id" ] || die 'usage: evidence.sh refute N "<the observation that killed it>"'
  hyp_exists "$id" || die "no hypothesis H$id"
  [ "$(hyp_state "$id")" = "live" ] || dim "  H$id was already $(hyp_state "$id")"

  hyp_set "$id" refuted "${why:-no reason recorded}"

  # Ruled-out theories go in the document, not only the TSV: this section is
  # what a later session reads to avoid re-testing them.
  local tmp
  tmp=$(mktemp)
  awk -v entry="- **H$id** $(hyp_text "$id") — ruled out: ${why:-no reason recorded}" '
    /^## / && inside && !placed { print entry; print ""; placed = 1; inside = 0 }
    { print }
    /^## Ruled out$/ { inside = 1 }
    END { if (inside && !placed) print entry }
  ' "$LOG" >"$tmp" && mv "$tmp" "$LOG"

  ok "H$id refuted"
  cmd_status
}

cmd_confirm() {
  need_log
  local id="${1:-}" how="${2:-}"
  [ -n "$id" ] || die 'usage: evidence.sh confirm N "<how it was proven, reproducibly>"'
  hyp_exists "$id" || die "no hypothesis H$id"
  if [ -z "$how" ]; then
    die "state how it was proven: can you make the symptom appear and disappear on demand?
  Anything less is a correlation, and a fix built on one comes back."
  fi
  hyp_set "$id" confirmed "$how"
  append_log "**H$id** CONFIRMED — $how"
  ok "H$id confirmed"

  local live
  live=$(awk -F'\t' '$2 == "live"' "$HYP" | wc -l | tr -d ' ')
  if [ "$live" -gt 0 ]; then
    warn "$live hypothesis/es still live — two causes with one symptom is common"
    dim "  refute them explicitly, or note in the brief that they were left untested"
  fi
}

cmd_status() {
  need_log
  head_ "Symptom"
  grep -m1 '^# Evidence' "$LOG" | sed 's/^# Evidence — /  /'

  head_ "Hypotheses"
  if [ ! -s "$HYP" ]; then
    echo "  (none registered — a single unstated theory is the default failure)"
  else
    # Live first: the point of the display is what to test next, not history.
    awk -F'\t' '
      function mark(s) { return (s == "refuted") ? "[x]" : (s == "confirmed") ? "[!]" : "[ ]" }
      $2 == "live"      { printf "  %s H%s  %s\n      refuted by: %s\n", mark($2), $1, $3, $4 }
      END { }
    ' "$HYP"
    awk -F'\t' '
      function mark(s) { return (s == "refuted") ? "[x]" : (s == "confirmed") ? "[!]" : "[ ]" }
      $2 != "live" { printf "  %s H%s  %s\n      %s: %s\n", mark($2), $1, $3, $2, ($6 == "" ? "-" : $6) }
    ' "$HYP"

    local live confirmed
    live=$(awk -F'\t' '$2 == "live"' "$HYP" | wc -l | tr -d ' ')
    confirmed=$(awk -F'\t' '$2 == "confirmed"' "$HYP" | wc -l | tr -d ' ')
    printf '\n  %s live, %s confirmed, %s total\n' \
      "$live" "$confirmed" "$(wc -l <"$HYP" | tr -d ' ')"

    # The stuck heuristic, made mechanical. Three dead theories and nothing
    # confirmed is the point where continuing costs more than asking.
    local refuted
    refuted=$(awk -F'\t' '$2 == "refuted"' "$HYP" | wc -l | tr -d ' ')
    if [ "$refuted" -ge 3 ] && [ "$confirmed" -eq 0 ]; then
      warn "  $refuted refuted, none confirmed — this is the stuck signal"
      dim "      report what is known and what you would try next, and ask"
    fi
    if [ "$live" -eq 0 ] && [ "$confirmed" -eq 0 ]; then
      warn "  no live theories left — the cause is outside every assumption so far"
      dim "      re-read ## Observed: one of those observations is probably interpretation"
    fi
  fi
  return 0
}

case "${1:-}" in
  init)       shift; cmd_init "$@" ;;
  hypothesis) shift; cmd_hypothesis "$@" ;;
  observe)    shift; cmd_observe "$@" ;;
  refute)     shift; cmd_refute "$@" ;;
  confirm)    shift; cmd_confirm "$@" ;;
  status)     cmd_status ;;
  path)       echo "$LOG" ;;
  *)          sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
