#!/usr/bin/env bash
# Check every skill in the repo against the house standard before it ships.
#
# The checks that matter are about the *description*, because that string is
# the only thing loaded until a skill fires — it carries the entire routing
# decision. A skill with a vague description is a skill that never runs.
#
# Usage: validate.sh [skill-name]
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/plugins/neorgon-forge/skills"
ONLY="${1:-}"

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
warn()  { printf '\033[33m%s\033[0m\n' "$1"; }
head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

fail=0
warns=0

# Read one frontmatter field. Frontmatter only — a later body line that
# happens to start with "name:" must not be picked up.
fm() {
  awk -v key="$2" '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---" { exit }
    inside {
      k = key ":"
      if (index($0, k) == 1) { sub("^" k "[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit }
    }
  ' "$1"
}

check_skill() {
  local dir="$1" name
  name=$(basename "$dir")
  local md="$dir/SKILL.md"

  head_ "$name"

  [ -f "$md" ] || { red "  no SKILL.md"; fail=1; return; }

  # ── Frontmatter presence ────────────────────────────────────
  head -1 "$md" | grep -q '^---$' || { red "  frontmatter must be the first line"; fail=1; }

  local fm_name desc hint invocable
  fm_name=$(fm "$md" name)
  desc=$(fm "$md" description)
  hint=$(fm "$md" argument-hint)
  invocable=$(fm "$md" user-invocable)

  if [ -z "$fm_name" ]; then
    red "  missing: name"; fail=1
  elif [ "$fm_name" != "$name" ]; then
    red "  name '$fm_name' does not match directory '$name'"; fail=1
  else
    green "  name ok"
  fi

  # ── The description is the router ───────────────────────────
  if [ -z "$desc" ]; then
    red "  missing: description — the skill will never route"; fail=1
  else
    local len=${#desc}
    if [ "$len" -lt 120 ]; then
      red "  description is ${len} chars — too thin to route on (aim 300-900)"; fail=1
    elif [ "$len" -gt 1400 ]; then
      warn "  description is ${len} chars — long enough to dilute the signal"; warns=$((warns + 1))
    else
      green "  description length ok (${len})"
    fi

    # A description that says what a skill *is* routes worse than one
    # that says when to use it and what not to use it for.
    grep -qiE 'use (this skill )?(when|at|for)|triggers on' <<<"$desc" \
      || { warn "  description does not say WHEN to use it"; warns=$((warns + 1)); }
    grep -qiE "triggers on" <<<"$desc" \
      || { warn "  description has no trigger phrases"; warns=$((warns + 1)); }
    grep -qiE "not for|instead use|rather than|use [a-z-]+ instead" <<<"$desc" \
      || { warn "  description does not say what it is NOT for (overlap risk)"; warns=$((warns + 1)); }
  fi

  if [ -n "$invocable" ]; then
    green "  user-invocable: $invocable"
  else
    warn "  no user-invocable — will not appear as /$name"; warns=$((warns + 1))
  fi
  [ -n "$hint" ] && green "  argument-hint ok"

  # ── Body ────────────────────────────────────────────────────
  local lines
  lines=$(wc -l <"$md" | tr -d ' ')
  if [ "$lines" -gt 500 ]; then
    warn "  SKILL.md is ${lines} lines — move detail into reference/"; warns=$((warns + 1))
  else
    green "  body length ok (${lines} lines)"
  fi

  grep -q '^## Invariants' "$md" \
    || { warn "  no Invariants section — the non-negotiables are unstated"; warns=$((warns + 1)); }

  # ── Scripts ─────────────────────────────────────────────────
  if [ -d "$dir/scripts" ]; then
    for s in "$dir/scripts"/*.sh; do
      [ -f "$s" ] || continue
      if [ ! -x "$s" ]; then
        red "  $(basename "$s") is not executable"; fail=1
      fi
      bash -n "$s" 2>/dev/null || { red "  $(basename "$s") has a syntax error"; fail=1; }
    done
    for s in "$dir/scripts"/*.mjs; do
      [ -f "$s" ] || continue
      if command -v node >/dev/null 2>&1; then
        node --check "$s" 2>/dev/null || { red "  $(basename "$s") has a syntax error"; fail=1; }
      fi
    done
    # Python scripts are imported as modules by their siblings, so they are not
    # required to be executable — only to parse.
    for s in "$dir/scripts"/*.py; do
      [ -f "$s" ] || continue
      if command -v python3 >/dev/null 2>&1; then
        python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$s" 2>/dev/null \
          || { red "  $(basename "$s") has a syntax error"; fail=1; }
      fi
    done
    green "  scripts ok"
  fi

  # ── Secrets ─────────────────────────────────────────────────
  # These ship publicly. A key or an absolute home path committed here is
  # not recoverable by deleting it later.
  # --exclude-dir keeps compiled artefacts out of it: a .pyc embeds the
  # absolute path it was built from, which is a false positive every time.
  local scan=(grep -rlI --exclude-dir=__pycache__ --exclude-dir=node_modules)
  if "${scan[@]}" -E '(sk-[A-Za-z0-9]{20}|AIza[A-Za-z0-9_-]{30}|ghp_[A-Za-z0-9]{30})' "$dir" >/dev/null 2>&1; then
    red "  looks like a committed API key"; fail=1
  fi
  if "${scan[@]}" '/Users/[a-z]' "$dir" >/dev/null 2>&1; then
    red "  hardcoded home directory path"; fail=1
  fi

  # ── Dead references ─────────────────────────────────────────
  # A SKILL.md pointing at a file that does not exist sends the agent
  # looking for guidance it will not find.
  #
  # Read into an array rather than piping into a while loop: a pipeline
  # runs its last stage in a subshell, so fail=1 set in there would be
  # discarded and the script would exit 0 having printed an error.
  # A reference prefixed with skills/<name>/ belongs to a sibling skill —
  # untangle calls task's brief.sh — so it resolves against the skills root,
  # not against this skill's directory.
  local refs=()
  while IFS= read -r ref; do refs+=("$ref"); done < <(
    grep -oE '(skills/[A-Za-z0-9._-]+/)?(reference|scripts)/[A-Za-z0-9._-]+' "$md" | sort -u
  )
  for ref in ${refs+"${refs[@]}"}; do
    case "$ref" in
      skills/*) [ -e "$SRC/${ref#skills/}" ] ||
        { red "  SKILL.md references missing file: $ref"; fail=1; } ;;
      *) [ -e "$dir/$ref" ] ||
        { red "  SKILL.md references missing file: $ref"; fail=1; } ;;
    esac
  done
}

if [ -n "$ONLY" ]; then
  [ -d "$SRC/$ONLY" ] || { red "no such skill: $ONLY"; exit 1; }
  check_skill "$SRC/$ONLY"
else
  for d in "$SRC"/*/; do check_skill "$d"; done

  # ── Manifest consistency ──────────────────────────────────────
  head_ "Manifests"
  for f in "$REPO/.claude-plugin/marketplace.json" "$REPO/plugins/neorgon-forge/.claude-plugin/plugin.json"; do
    rel="${f#"$REPO"/}"
    if [ ! -f "$f" ]; then
      red "  missing: $rel"; fail=1
    elif command -v python3 >/dev/null 2>&1; then
      if python3 -c "import json; json.load(open('$f'))" 2>/dev/null; then
        green "  $rel is valid JSON"
      else
        red "  $rel is not valid JSON"; fail=1
      fi
    fi
  done
fi

printf '\n'
if [ "$fail" -ne 0 ]; then
  red "Validation failed."
  exit 1
fi
if [ "$warns" -gt 0 ]; then
  warn "Passed with $warns warning(s)."
  exit 0
fi
green "All checks passed."
