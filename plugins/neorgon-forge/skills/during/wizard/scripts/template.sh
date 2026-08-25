#!/usr/bin/env bash
# A wizard: walks a human through the steps only they can take.
#
# Everything above the STAGES marker is the shared library and is identical in
# every wizard the `wizard` skill generates. Do not hand-edit it: a reviewer
# reads the stages and trusts the machinery, which only works while the
# machinery is the same everywhere.
#
# Author your stages below the marker, set TOTAL_STAGES, and delete the example.
set -uo pipefail

TOTAL_STAGES=0          # set this to the number of stages you write
CURRENT_STAGE=0
ENV_FILE="${ENV_FILE:-.env}"
CAPTURED=()             # "KEY=where it went", for the closing summary

# ── Presentation ────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  BLUE=$'\033[34m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
else
  BOLD=''; DIM=''; RESET=''; BLUE=''; GREEN=''; YELLOW=''; RED=''
fi

_clear() { [ -t 1 ] && printf '\033[2J\033[H' || true; }

banner() {
  printf '%s%s%s\n' "$BOLD" "$1" "$RESET"
  printf '%s%s%s\n\n' "$DIM" "$(printf '%0.s─' $(seq 1 ${#1}))" "$RESET"
}

# One screen per stage. Anything the human needs must fit on it.
stage() {
  CURRENT_STAGE=$((CURRENT_STAGE + 1))
  _clear
  printf '%s[%d/%d]%s %s%s%s\n\n' \
    "$DIM" "$CURRENT_STAGE" "$TOTAL_STAGES" "$RESET" "$BOLD" "$1" "$RESET"
}

say()  { printf '  %s\n' "$1"; }
step() { printf '  %s>%s %s\n' "$BLUE" "$RESET" "$1"; }
note() { printf '  %s%s%s\n' "$DIM" "$1" "$RESET"; }
warn() { printf '  %s! %s%s\n' "$YELLOW" "$1" "$RESET"; }
ok()   { printf '  %s+%s %s\n' "$GREEN" "$RESET" "$1"; }
fail() { printf '  %sx %s%s\n' "$RED" "$1" "$RESET"; }

# ── Browser ─────────────────────────────────────────────────────────────────
# Always open the URL before asking for the value it produces.
open_url() {
  local url="$1"
  step "Opening: $url"
  if   command -v open        >/dev/null 2>&1; then open "$url" >/dev/null 2>&1 &
  elif command -v wslview     >/dev/null 2>&1; then wslview "$url" >/dev/null 2>&1 &
  elif command -v xdg-open    >/dev/null 2>&1; then xdg-open "$url" >/dev/null 2>&1 &
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile Start-Process "$url" >/dev/null 2>&1 &
  else
    note "could not open a browser here, visit it by hand"
  fi
  sleep 1
}

# ── Gates ───────────────────────────────────────────────────────────────────
pause() { printf '\n  %sPress enter when done.%s ' "$DIM" "$RESET"; read -r _; }

# Use before anything irreversible. Name what is about to happen: a bare
# "Continue?" gets a reflexive yes.
confirm() {
  local ans
  printf '\n  %s%s%s [y/N] ' "$YELLOW" "$1" "$RESET"
  read -r ans
  case "$ans" in [yY]|[yY][eE][sS]) return 0 ;; *) fail "stopped"; exit 1 ;; esac
}

# ── Capture ─────────────────────────────────────────────────────────────────
# A value already in .env is offered as the default, so re-running the wizard
# to fix one stage does not mean retyping every earlier one.
_existing() {
  [ -f "$ENV_FILE" ] || return 1
  local line; line=$(grep -m1 "^$1=" "$ENV_FILE" 2>/dev/null) || return 1
  printf '%s' "${line#*=}" | sed 's/^"//; s/"$//'
}

ask() {
  local key="$1" prompt="$2" cur val
  cur=$(_existing "$key") || cur=''
  if [ -n "$cur" ]; then
    printf '\n  %s [%s]: ' "$prompt" "$cur"
  else
    printf '\n  %s: ' "$prompt"
  fi
  read -r val
  [ -z "$val" ] && val="$cur"
  [ -z "$val" ] && { fail "$key is required"; exit 1; }
  printf -v "$key" '%s' "$val"
  export "${key?}"
}

# Never echoes. Use for anything that must not survive in scrollback.
ask_secret() {
  local key="$1" prompt="$2" cur val
  cur=$(_existing "$key") || cur=''
  if [ -n "$cur" ]; then
    printf '\n  %s [keep existing]: ' "$prompt"
  else
    printf '\n  %s: ' "$prompt"
  fi
  read -rs val; printf '\n'
  [ -z "$val" ] && val="$cur"
  [ -z "$val" ] && { fail "$key is required"; exit 1; }
  printf -v "$key" '%s' "$val"
  export "${key?}"
}

# ── Persistence ─────────────────────────────────────────────────────────────
# Idempotent: re-running replaces the line rather than appending a second one,
# which is the bug that makes a half-finished wizard run unrecoverable.
write_env() {
  local key="$1" val="$2"
  touch "$ENV_FILE"
  if grep -q "^$key=" "$ENV_FILE" 2>/dev/null; then
    local tmp; tmp=$(mktemp)
    grep -v "^$key=" "$ENV_FILE" > "$tmp" && mv "$tmp" "$ENV_FILE"
  fi
  printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
  CAPTURED+=("$key -> $ENV_FILE")
  ok "$key written to $ENV_FILE"
}

# The name must match a secrets.* reference in CI exactly. CI reports a
# mismatched name as an empty string, never as an error.
set_secret() {
  local key="$1" val="$2"
  command -v gh >/dev/null 2>&1 || { warn "gh not installed, skipping secret $key"; return 0; }
  if printf '%s' "$val" | gh secret set "$key" --body-file - 2>/dev/null; then
    CAPTURED+=("$key -> GitHub secret")
    ok "$key set as a GitHub secret"
  else
    fail "could not set GitHub secret $key (is gh authenticated for this repo?)"
  fi
}

set_var() {
  local key="$1" val="$2"
  command -v gh >/dev/null 2>&1 || { warn "gh not installed, skipping variable $key"; return 0; }
  if gh variable set "$key" --body "$val" >/dev/null 2>&1; then
    CAPTURED+=("$key -> GitHub variable")
    ok "$key set as a GitHub variable"
  else
    fail "could not set GitHub variable $key"
  fi
}

# ── Close ───────────────────────────────────────────────────────────────────
finish() {
  _clear
  banner "Done"
  if [ ${#CAPTURED[@]} -gt 0 ]; then
    say "Captured:"
    for entry in "${CAPTURED[@]}"; do note "  $entry"; done
    printf '\n'
  fi
  [ $# -gt 0 ] && { say "$1"; printf '\n'; }
  if [ "$CURRENT_STAGE" -ne "$TOTAL_STAGES" ]; then
    warn "ran $CURRENT_STAGE of $TOTAL_STAGES stages: TOTAL_STAGES is wrong, or a stage was skipped"
  fi
}

# ---- STAGES ----------------------------------------------------------------
# Everything above is the shared library. Author below.
# Delete this example, write one `stage` per step, and set TOTAL_STAGES above.

_clear
banner "Example wizard"
say "Replace this whole section. Set TOTAL_STAGES to the number of stages you write."
printf '\n'
pause

stage "Get the API key"
say "You need a key from the provider dashboard."
open_url "https://example.com/dashboard/api-keys"
step "Developers -> API keys -> Create key -> copy it"
ask_secret EXAMPLE_API_KEY "Paste the key"
write_env EXAMPLE_API_KEY "$EXAMPLE_API_KEY"
set_secret EXAMPLE_API_KEY "$EXAMPLE_API_KEY"
pause

finish "Run the app to confirm the key works."
