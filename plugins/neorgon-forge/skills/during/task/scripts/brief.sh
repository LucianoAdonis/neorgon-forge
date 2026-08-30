#!/usr/bin/env bash
# Maintain .forge/brief.md: the record of what a task was for, what was
# decided, and what is still open.
#
# The point is that it gets written *while* the work happens. A decision
# recalled at the end of a long session has already lost the alternative
# it beat, which is the part worth reporting.
#
# If tools here fail with "command not found": some harness shells drop PATH
# inside loop bodies: run `export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin` first.
#
# Usage:
#   brief.sh init "<problem>"              start a brief (idempotent)
#   brief.sh note "<what you learned>"     append a timestamped decision
#   brief.sh correct "<old claim>" "<truth>"  supersede a wrong note in place
#   brief.sh stream add "<name>" "<goal>"  register a workstream
#   brief.sh stream start "<name>"         mark it in progress
#   brief.sh stream done "<name>" "<outcome>"
#   brief.sh stream block "<name>" "<why>"
#   brief.sh status                        streams and their state
#   brief.sh close                         stamp it complete
#   brief.sh path                          print the brief path
#   brief.sh index [root]                  index every repo's brief under root
set -uo pipefail

# Briefs written before 2026-08 head their problem line with an em dash.
# New ones use a colon. Readers accept both; only the writer changed, so an
# existing .forge/brief.md stays readable. Built from an escape so this file
# contains no em dash of its own.
LEGACY_SEP=$(printf '\u2014')

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
  [ -f "$BRIEF" ] || die "no brief at $BRIEF, run: brief.sh init \"<problem>\""
}

# A git tree inside a cloud-sync folder loses work silently: the sync daemon
# forks concurrently-written files into "name 2.ext" copies and reports
# nothing. Checked at init because that is the moment before dozens of edits.
# A warning, not a refusal, but the right response is to move the repo, not
# to proceed carefully. Details and recovery: reference/hazards.md.
warn_cloud_sync() {
  case "$PWD" in
    *"/Mobile Documents/"*|*"/Dropbox/"*|*"/Dropbox"|*"/OneDrive"*|*"/Google Drive/"*|*"/My Drive/"*)
      printf '\033[31mWARNING: this directory is inside a cloud-sync folder.\033[0m\n' >&2
      printf '\033[31m  git and sync daemons both assume they own the tree. Concurrent writes\033[0m\n' >&2
      printf '\033[31m  fork files into "name 2.ext" copies silently, observed losses include\033[0m\n' >&2
      printf '\033[31m  whole source trees. Move the repo to an unsynced path before continuing.\033[0m\n' >&2
      ;;
  esac
}

cmd_init() {
  local problem="${1:-}"
  [ -n "$problem" ] || die 'usage: brief.sh init "<one-line problem>"'
  warn_cloud_sync
  mkdir -p "$FORGE_DIR"

  if [ -f "$BRIEF" ]; then
    ok "brief already exists at $BRIEF: appending a new run"
    # A run gets the whole scaffold, not just a heading. Emitting only
    # "## Run:" left every later run's notes filing themselves under the
    # FIRST run's "## Decisions", which put a campaign's decisions above
    # closed-stamps from weeks earlier and read as that older campaign's work.
    {
      printf '\n---\n\n## Run: %s\n\n' "$(now)"
      printf '## Problem\n\n%s\n\n' "$problem"
      printf '## Done when\n\n<!-- The condition that ends this run. Step 1 asks for it;\n'
      printf '     without it a run closes green on "all streams done" even when the\n'
      printf '     agreed bar was "deployed and verified". -->\n\n'
      printf '## Approach\n\n<!-- What you are doing, in a paragraph. -->\n\n'
      printf '## Rejected\n\n<!-- The alternative you considered and why it lost. -->\n\n'
      printf '## Decisions\n\n<!-- Appended by: brief.sh note \"<what you learned>\" -->\n\n'
      printf '## Measured\n\n<!-- Numbers actually observed, with how. -->\n\n'
      printf '## Open\n\n<!-- Deferred work, defects that shipped, decisions left to the user. -->\n'
    } >>"$BRIEF"
    return
  fi

  cat >"$BRIEF" <<EOF
# Brief: $problem

Started $(now). Maintained by the \`task\` skill; read by \`debrief\` and \`writeup\`.

## Problem

$problem

<!-- What was wrong *before*. The symptom someone actually experienced, not the
     absence of the solution. debrief opens its deck on this, so vagueness here
     costs a slide later. -->

## Done when

<!-- The condition that ends this run, in one line. task Step 1 asks for it
     ("tests pass, or deployed and verified") and there was nowhere to put the
     answer, so a campaign closed green on "all streams done" even when the
     agreed bar was never met. close reports this back. -->

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
  # One line, always: a decision is a markdown bullet, and a pasted multi-line
  # outcome silently ended the bullet and left the rest as loose prose.
  text=$(printf '%s' "$text" | tr '\n\t' '  ')
  local start tmp
  # The LAST Decisions heading, not the first. Every run has its own.
  start=$(grep -n '^## Decisions$' "$BRIEF" | tail -1 | cut -d: -f1)
  [ -n "$start" ] || die "no '## Decisions' section in $BRIEF"
  tmp=$(mktemp)
  awk -v entry="- \`$(now)\` $text" -v start="$start" '
    NR > start && /^## / && !placed { print entry; print ""; placed = 1 }
    { print }
    END { if (!placed) print entry }
  ' "$BRIEF" >"$tmp" && mv "$tmp" "$BRIEF"
  ok "noted"
}

# Being wrong then right is the normal shape of a long campaign, and the brief
# should model it rather than flatten it: a reader going top to bottom must not
# meet the wrong claim first and stop there. `correct` strikes the superseded
# note where it stands and appends the correction as a new decision.
cmd_correct() {
  need_brief
  local old="${1:-}" new="${2:-}"
  [ -n "$old" ] && [ -n "$new" ] ||
    die 'usage: brief.sh correct "<fragment of the wrong note>" "<what is actually true>"'

  # Scoped to the current run. Latching on the first '## Decisions' would let a
  # correction strike a note belonging to a campaign that closed weeks earlier.
  local lineno start
  start=$(grep -n '^## Decisions$' "$BRIEF" | tail -1 | cut -d: -f1)
  lineno=$(awk -v s="$old" -v start="${start:-0}" '
    NR <= start      { next }
    /^## /           { inside = 0; next }
    { inside = 1 }
    inside && /^- / && index($0, s) { n = NR }
    END { if (n) print n }
  ' "$BRIEF")
  [ -n "$lineno" ] ||
    die "no decision containing \"$old\": quote a fragment of the note being superseded"

  local tmp
  tmp=$(mktemp)
  awk -v n="$lineno" -v ts="$(now)" '
    NR == n { body = $0; sub(/^- /, "", body); print "- ~~" body "~~ · superseded " ts ", see correction below"; next }
    { print }
  ' "$BRIEF" >"$tmp" && mv "$tmp" "$BRIEF"

  cmd_note "CORRECTION of the struck note above: $new"
  ok "superseded: the wrong claim is struck where it stands, not silently rewritten"
}

stream_field() { awk -F'\t' -v n="$1" '$1 == n { print $2 }' "$STREAMS" 2>/dev/null | tail -1; }

stream_set() {
  local name="$1" state="$2" detail="${3:-}"
  # A record is one tab-separated line. A pasted multi-line outcome, which is
  # exactly the shape a subagent returns, split it into malformed rows that
  # every later read misparsed.
  detail=$(printf '%s' "$detail" | tr '\n\t' '  ')
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
           # body too: including whatever the stream got wrong.
           cmd_note "stream **$name** done: ${detail:-no outcome recorded}"
           ok "stream done: $name" ;;
    block) stream_set "$name" blocked "$detail"
           cmd_note "stream **$name** BLOCKED: ${detail:-no reason recorded}"
           ok "stream blocked: $name" ;;
    *)     die "unknown stream action: $action" ;;
  esac
}

cmd_status() {
  need_brief
  head_ "Brief"
  printf '  %s\n' "$BRIEF"
  grep -m1 '^# Brief' "$BRIEF" | sed -E "s/^# Brief( $LEGACY_SEP|:) /  /"

  head_ "Streams"
  if [ ! -s "$STREAMS" ]; then
    echo "  (none: inline task)"
  else
    awk -F'\t' '
      { mark = ($2 == "done") ? "[x]" : ($2 == "active") ? "[>]" : ($2 == "blocked") ? "[!]" : "[ ]"
        printf "  %s %-28s %-8s %s\n", mark, $1, $2, $4 }
    ' "$STREAMS"
    local total done_
    total=$(wc -l <"$STREAMS" | tr -d ' ')
    done_=$(awk -F'\t' '$2 == "done"' "$STREAMS" | wc -l | tr -d ' ')
    printf '\n  %s/%s complete\n' "$done_" "$total"
    awk -F'\t' '$2 == "blocked" { print "  blocked: " $1 ", " $4 }' "$STREAMS"
  fi

  head_ "Unfilled sections"
  # A brief with empty sections is the common failure: the scaffold gets
  # created and never filled, and the deck inherits the emptiness.
  # Reported, never fatal: status is a diagnostic and is expected to run
  # mid-task when sections legitimately are not filled yet.
  local empty=0 run_start
  # Sections belong to the newest run. Scanning from the top reported the first
  # run's Approach as filled while the run in progress had nothing in it.
  run_start=$(grep -n '^## Run: ' "$BRIEF" | tail -1 | cut -d: -f1)
  for h in "Done when" Approach Rejected Measured Open; do
    awk -v h="## $h" -v start="${run_start:-0}" '
      NR < start { next }
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
      printf '\033[31m%s\033[0m\n' "  $open_ stream(s) not done. These belong under ## Open, not dropped:"
      awk -F'\t' '$2 != "done" { print "    " $1 " (" $2 ") " $4 }' "$STREAMS"
    fi
  fi
  printf '\n_Closed %s._\n' "$(now)" >>"$BRIEF"
  cmd_status
  ok "closed $BRIEF"
}

# "Did I already decide something about X, and where?": collect every repo's
# brief under a root into one grep-able index: problems, state, decisions, and
# what is still open. The index is regenerated wholesale, never merged, so it
# cannot drift from the briefs it summarizes.
cmd_index() {
  local root="${1:-.}"
  [ -d "$root" ] || die "not a directory: $root"
  local briefs
  briefs=$(find "$root" -mindepth 3 -maxdepth 5 -type f -path '*/.forge/brief.md' 2>/dev/null | sort)
  [ -n "$briefs" ] || die "no */.forge/brief.md under $root, nothing was indexed"

  mkdir -p "$root/.forge"
  local out="$root/.forge/brief-index.md"
  {
    printf '# Brief index: generated %s\n\n' "$(now)"
    printf 'By `brief.sh index`. Grep this instead of recalling a decision:\n'
    printf 'every problem, decision, and open item from every brief under this root.\n'
    while IFS= read -r b; do
      local repo runs state
      repo="${b#"$root"/}"; repo="${repo%/.forge/brief.md}"
      # Three generations of run marker are on disk in this fleet: the oldest
      # emitted only '**Problem.**', the next emitted '## Run:' AND
      # '**Problem.**' together, the current one emits '## Run:' with a full
      # section scaffold. Count '## Run:' headings plus any '**Problem.**'
      # that does not belong to one, plus 1 for the file header.
      runs=$(awk '
        /^## Run: /        { n++; lastrun = NR; next }
        /^\*\*Problem\.\*\*/ { if (NR - lastrun > 3) n++ }
        END { print n + 1 }
      ' "$b")
      # Closed means: a _Closed stamp after the LAST run began. Counting
      # stamps misreports a brief that was closed and then reopened.
      state=$(awk '
        /^## Run: / || /^# Brief/ { lastp = NR }
        /^_Closed /               { lastc = NR }
        END { print (lastc > lastp && lastp) ? "closed" : "open" }
      ' "$b")
      printf '\n## %s | %s | %s run(s)\n\n' "$repo" "$state" "$runs"
      # Three problem shapes across the fleet: the file header, the legacy
      # one-line '**Problem.**' marker, and a run's own '## Problem' section.
      awk -v sep="$LEGACY_SEP" '
        $0 ~ "^# Brief( " sep "|:) " { sub("^# Brief( " sep "|:) ", ""); print "- problem: " $0; next }
        /^\*\*Problem\.\*\* / { sub(/^\*\*Problem\.\*\* /, ""); print "- problem: " $0; next }
        /^## Problem$/    { want = 1; next }
        want && NF && !/^<!--/ { print "- problem: " $0; want = 0 }
      ' "$b"
      awk '
        /^## Decisions$/ { inside = 1; next }
        /^## /           { inside = 0 }
        inside && /^- /  { print }
      ' "$b"
      # Rejected is the section that answers "did we already try this?", which
      # is the whole point of an index meant to prevent re-deciding. It was the
      # one section the index dropped.
      awk '
        /^## Rejected$/ { inside = 1; next }
        /^## /          { inside = 0 }
        inside && NF && !/^<!--/ && !/^ *-->/ { print "- rejected: " $0 }
      ' "$b"
      awk '
        /^## Open$/                                    { inside = 1; next }
        /^## / || /^---$/                              { inside = 0 }
        inside && /^- / && !/^<!--/                    { print "- OPEN: " substr($0, 3) }
      ' "$b"
    done <<< "$briefs"
  } >"$out"
  ok "indexed $(printf '%s\n' "$briefs" | wc -l | tr -d ' ') brief(s) into $out"
}

case "${1:-}" in
  init)    shift; cmd_init "$@" ;;
  note)    shift; cmd_note "$@" ;;
  correct) shift; cmd_correct "$@" ;;
  stream) shift; cmd_stream "$@" ;;
  status) cmd_status ;;
  close)  cmd_close ;;
  path)   echo "$BRIEF" ;;
  index)  shift; cmd_index "$@" ;;
  *)      awk 'NR > 1 { if (!/^#/) exit; line = $0; sub(/^# ?/, "", line); print line }' "$0" ;;
esac
