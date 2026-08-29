#!/usr/bin/env bash
# Check every skill in the repo against the house standard before it ships.
#
# The checks that matter are about the *description*, because that string is
# the only thing loaded until a skill fires: it carries the entire routing
# decision. A skill with a vague description is a skill that never runs.
#
# Usage: validate.sh [skill-name]
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/plugins/neorgon-forge/skills"
ONLY="${1:-}"

# Skills live under skills/<bucket>/<name>/ in the repo but install flat, so
# every lookup by bare name has to search the buckets.
skill_dir() {
  local d
  for d in "$SRC"/*/"$1"; do [ -d "$d" ] && { printf '%s' "$d"; return 0; }; done
  return 1
}

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
warn()  { printf '\033[33m%s\033[0m\n' "$1"; }
head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

fail=0
warns=0

# Read one frontmatter field. Frontmatter only: a later body line that
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
  local dir="$1" name em_hits
  name=$(basename "$dir")
  local md="$dir/SKILL.md"

  head_ "$name"

  [ -f "$md" ] || { red "  no SKILL.md"; fail=1; return; }

  # ── Frontmatter presence ────────────────────────────────────
  head -1 "$md" | grep -q '^---$' || { red "  frontmatter must be the first line"; fail=1; }

  local fm_name desc hint invocable nomodel user_invoked
  fm_name=$(fm "$md" name)
  desc=$(fm "$md" description)
  hint=$(fm "$md" argument-hint)
  invocable=$(fm "$md" user-invocable)
  nomodel=$(fm "$md" disable-model-invocation)
  # Invocation is the one axis that changes what a good description looks like.
  # A model-invoked skill's description is the router and is read by nothing
  # else until it fires; a user-invoked one is a line in a slash-command list
  # that a person skims, and trigger phrasing in it is noise the model can
  # never act on.
  [ "$nomodel" = "true" ] && user_invoked=1 || user_invoked=0

  if [ -z "$fm_name" ]; then
    red "  missing: name"; fail=1
  elif [ "$fm_name" != "$name" ]; then
    red "  name '$fm_name' does not match directory '$name'"; fail=1
  else
    green "  name ok"
  fi

  # ── The description, judged by who can reach the skill ──────
  if [ -z "$desc" ]; then
    red "  missing: description. The skill will never route"; fail=1
  elif [ "$user_invoked" -eq 1 ]; then
    # Human-facing: one line in a slash-command list. Short is correct.
    local len=${#desc}
    if [ "$len" -gt 320 ]; then
      red "  user-invoked description is ${len} chars: this is read by a person browsing"
      red "    slash commands, not by a router. One or two sentences (aim under 320)"; fail=1
    else
      green "  description length ok for a user-invoked skill (${len})"
    fi
    # Trigger phrasing here is dead weight: nothing can ever act on it.
    grep -qiE "triggers on" <<<"$desc" && {
      red "  user-invoked description carries trigger phrases, which no model can act on"
      red "    (drop them, or remove disable-model-invocation)"; fail=1; }
  else
    # Model-facing: this string is the whole routing decision.
    local len=${#desc}
    if [ "$len" -lt 300 ]; then
      red "  description is ${len} chars: too thin to route on (aim 300-900)"; fail=1
    elif [ "$len" -gt 1400 ]; then
      warn "  description is ${len} chars: long enough to dilute the signal"; warns=$((warns + 1))
    else
      green "  description length ok (${len})"
    fi

    # A description that says what a skill *is* routes worse than one that says
    # when to use it and what not to use it for. For a model-invoked skill
    # these are the whole product, so they fail rather than warn.
    grep -qiE 'use (this skill )?(when|at|for)|triggers on' <<<"$desc" \
      || { red "  description does not say WHEN to use it"; fail=1; }
    grep -qiE "triggers on" <<<"$desc" \
      || { red "  description has no trigger phrases"; fail=1; }
    grep -qiE "not for|instead use|rather than|use [a-z-]+ instead" <<<"$desc" \
      || { red "  description does not say what it is NOT for (overlap risk)"; fail=1; }
  fi

  if [ -n "$invocable" ]; then
    green "  user-invocable: $invocable"
  else
    red "  no user-invocable: will not appear as /$name"; fail=1
  fi
  [ -n "$hint" ] && green "  argument-hint ok"

  # ── Invocation agrees across harnesses ──────────────────────
  # A skill is user-invoked in every harness or in none. Two harnesses
  # disagreeing means the model can reach through the one that was missed,
  # which is the failure the whole distinction exists to prevent.
  local yaml="$dir/agents/openai.yaml"
  if [ ! -f "$yaml" ]; then
    red "  no agents/openai.yaml: the skill has no identity outside Claude Code"; fail=1
  else
    grep -q '^interface:' "$yaml" || { red "  openai.yaml has no interface block"; fail=1; }
    grep -q 'display_name:' "$yaml" || { red "  openai.yaml has no display_name"; fail=1; }
    grep -q 'short_description:' "$yaml" || { red "  openai.yaml has no short_description"; fail=1; }
    local yaml_closed=0
    grep -q 'allow_implicit_invocation: *false' "$yaml" && yaml_closed=1
    if [ "$user_invoked" -eq 1 ] && [ "$yaml_closed" -eq 0 ]; then
      red "  user-invoked here but model-reachable in Codex: openai.yaml needs"
      red "    policy.allow_implicit_invocation: false"; fail=1
    elif [ "$user_invoked" -eq 0 ] && [ "$yaml_closed" -eq 1 ]; then
      red "  model-invoked here but closed in Codex: the two harnesses disagree"; fail=1
    else
      green "  invocation agrees across harnesses ($([ "$user_invoked" -eq 1 ] && echo user-invoked || echo model-invoked))"
    fi
  fi

  # ── Body ────────────────────────────────────────────────────
  local lines
  lines=$(wc -l <"$md" | tr -d ' ')
  if [ "$lines" -gt 500 ]; then
    warn "  SKILL.md is ${lines} lines: move detail into reference/"; warns=$((warns + 1))
  else
    green "  body length ok (${lines} lines)"
  fi

  if [ "$user_invoked" -eq 0 ]; then
    grep -q '^## Invariants' "$md" \
      || { warn "  no Invariants section: the non-negotiables are unstated"; warns=$((warns + 1)); }
  fi

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
    # required to be executable: only to parse.
    for s in "$dir/scripts"/*.py; do
      [ -f "$s" ] || continue
      if command -v python3 >/dev/null 2>&1; then
        python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$s" 2>/dev/null \
          || { red "  $(basename "$s") has a syntax error"; fail=1; }
      fi
    done
    green "  scripts ok"
  fi

  # ── Output roots ────────────────────────────────────────────
  # Every file a skill writes must land under one of three roots, chosen by
  # lifetime: .forge/ is ephemeral and gitignored, docs/atlas/ is regenerable
  # and committed, post/ and images/ are shippable deliverables. See
  # docs/authoring.md. A skill that invents a fourth root leaves a repo with no
  # rule about which directories are safe to delete.
  #
  # Two shapes are checked, because those are the two ways a root gets created:
  # a literal mkdir target, and a directory constant a script later writes into.
  # Literals only: a path taken from an argument or an env var is the caller's
  # choice and cannot be judged from here. A path a script only *reads* is also
  # out of scope: build-preview.py loads the project's own js/mascot.js, which is
  # not this skill claiming a root.
  # Second argued exception: the bare file `.env`. wizard's template upserts
  # into it, and it is none of the three lifetimes: not ephemeral, not
  # regenerable, not shipped. It is also not a root at all, but a single
  # conventional dotfile that already exists in most projects, so it claims no
  # directory and leaves no rule about what is safe to delete. Allowed as an
  # exact match only, never as a prefix.
  # One argued exception: scripts/mascot/masters holds mascot-forge's
  # full-resolution masters: paid generation plus hand curation, so not
  # ephemeral; not derivable from source, so not regenerable; deliberately
  # unshipped, so not a deliverable. The argument lives in docs/authoring.md;
  # a new exception goes there first, never just here.
  if [ -d "$dir/scripts" ]; then
    local roots='^(\.forge|docs/atlas|post|images|scripts/mascot/masters|\.env)$|^(\.forge|docs/atlas|post|images|scripts/mascot/masters)/'
    local bad=()
    while IFS= read -r hit; do bad+=("$hit"); done < <(
      # mkdir -p <literal>, mkdirSync('<literal>'), Path("<literal>").mkdir()
      grep -rhoE "mkdir -p +['\"]?[A-Za-z_.][^\"' )\$]*" "$dir/scripts" 2>/dev/null \
        | sed -E "s/mkdir -p +['\"]?//"
      grep -rhoE "mkdirSync\( *['\"][A-Za-z_.][^\"']*" "$dir/scripts" 2>/dev/null \
        | sed -E "s/mkdirSync\( *['\"]//"
      # A module-level directory constant: OUT_DIR = PROJECT / "images" / "mascot"
      grep -rhoE '^[A-Z][A-Z0-9_]* *= *(PROJECT|ROOT) */ *"[A-Za-z_.][^"]*"( */ *"[^"]*")*' \
        "$dir/scripts" 2>/dev/null \
        | sed -E 's/^.*(PROJECT|ROOT) *\/ *//; s/" *\/ *"/\//g; s/"//g'
      # The shell equivalent, bare or with an env override supplying the default:
      #   DIR="docs/atlas/diagrams"      FORGE_DIR="${FORGE_BRIEF_DIR:-.forge}"
      grep -rhoE '^[A-Z][A-Z0-9_]*="[A-Za-z_.][^"$]*"' "$dir/scripts" 2>/dev/null \
        | sed -E 's/^[^=]*="//; s/"$//'
      grep -rhoE '^[A-Z][A-Z0-9_]*="\$\{[A-Za-z_][A-Za-z0-9_]*:-[A-Za-z_.][^}"]*\}"' \
        "$dir/scripts" 2>/dev/null | sed -E 's/^.*:-//; s/\}"$//'
      # An output path a script defaults to when the caller does not pass one.
      # This is where atlas declares its roots, so missing it would exempt the
      # one skill with the most generated output. `--docs` is deliberately not
      # here: it names the docs base that a skill's own root is joined *under*,
      # so `docs` is a correct value for it and a wrong one for a write target.
      grep -rhoE '(option|am_option)\([^)]*"--(out|model)", *"[A-Za-z_.][^"]*"' \
        "$dir/scripts" 2>/dev/null | sed -E 's/^.*, *"//; s/"$//'
    )
    local stray=()
    for target in ${bad+"${bad[@]}"}; do
      # A bare filename or a "." is not a new root; only a rooted path is.
      case "$target" in
        .|./|""|*[\$\{\*]*) continue ;;
      esac
      grep -qE "$roots" <<<"$target" && continue
      stray+=("$target")
    done
    if [ ${#stray[@]} -gt 0 ]; then
      for target in "${stray[@]}"; do
        red "  writes outside the sanctioned roots: $target"
      done
      red "  allowed: .forge/ (ephemeral) · docs/atlas/ (regenerable) · post/, images/ (shipped)"
      red "  (plus one argued exception: scripts/mascot/masters, see docs/authoring.md)"
      fail=1
    else
      green "  output roots ok"
    fi
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

  # ── Docs page ───────────────────────────────────────────────
  # Most of these are reached for by a person who has to remember they exist.
  # The docs page is what relieves that; a skill without one is invisible
  # outside the router.
  if [ -f "$REPO/docs/skills/$name.md" ]; then
    green "  docs page ok"
  else
    red "  no docs page at docs/skills/$name.md (see .agents/writing-docs.md)"; fail=1
  fi

  # ── Prose ───────────────────────────────────────────────────
  # No em dashes anywhere in this repo's prose. Checked here rather than
  # trusted to review, because they arrive one at a time.
  # A line quoting the character as a glyph (`\u2014` in backticks, or /\u2014/ in a
  # lint rule) is a rule *about* it, not prose using it. penname's persona
  # ban lists and voicecheck's defaults both have to name it to forbid it.
  em_hits=$(grep -rnI $'\u2014' "$dir" 2>/dev/null | grep -vE '`\xe2\x80\x94`|/\xe2\x80\x94/' || true)
  if [ -n "$em_hits" ]; then
    red "  contains an em dash: rewrite the sentence, never substitute the character"
    printf '%s\n' "$em_hits" | head -3 | sed "s|$REPO/||; s/^/      /"
    fail=1
  fi

  # ── Dead references ─────────────────────────────────────────
  # A SKILL.md pointing at a file that does not exist sends the agent
  # looking for guidance it will not find.
  #
  # Read into an array rather than piping into a while loop: a pipeline
  # runs its last stage in a subshell, so fail=1 set in there would be
  # discarded and the script would exit 0 having printed an error.
  # A reference prefixed with skills/<name>/ belongs to a sibling skill,
  # untangle calls task's brief.sh, so it resolves against the skills root,
  # not against this skill's directory.
  # A reference followed by `<` is a placeholder the reader fills in
  # (scripts/setup-<thing>.sh), not a file that should exist. Angle brackets
  # are the repo's placeholder convention, so drop those lines before matching
  # rather than teaching every author to phrase around the checker.
  local refs=()
  while IFS= read -r ref; do refs+=("$ref"); done < <(
    grep -oE '(skills/[A-Za-z0-9._-]+/)?(reference|scripts)/[A-Za-z0-9._-]+<?' "$md" \
      | grep -v '<$' | sort -u
  )
  for ref in ${refs+"${refs[@]}"}; do
    case "$ref" in
      skills/*)
        # SKILL.md prose addresses the *installed* layout, which is flat
        # (~/.claude/skills/<name>/), so a cross-skill path never carries a
        # bucket. Resolve it by finding the sibling's bucket here.
        rest="${ref#skills/}"; sib="${rest%%/*}"; tail_="${rest#*/}"
        sib_dir=$(skill_dir "$sib")
        if [ -z "$sib_dir" ] || [ ! -e "$sib_dir/$tail_" ]; then
          red "  SKILL.md references missing file: $ref"; fail=1
        fi ;;
      # The argued output root from the roots check above: a path the skill
      # writes into the *worked project*, so it can never exist in the install
      # and is not a reference to skill guidance at all.
      scripts/mascot|scripts/mascot/*) : ;;
      *) [ -e "$dir/$ref" ] ||
        { red "  SKILL.md references missing file: $ref"; fail=1; } ;;
    esac
  done
}

if [ -n "$ONLY" ]; then
  only_dir=$(skill_dir "$ONLY")
  [ -n "$only_dir" ] || { red "no such skill: $ONLY"; exit 1; }
  check_skill "$only_dir"
else
  for d in "$SRC"/*/*/; do check_skill "$d"; done

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

  # The plugin ships exactly the skills its manifest lists. A skill added to
  # the tree and not to the array is installed by nobody; an entry left behind
  # after a rename breaks the whole plugin load, not just that one skill.
  if command -v python3 >/dev/null 2>&1; then
    on_disk=$(cd "$SRC" && for d in */*/; do printf './skills/%s\n' "${d%/}"; done | sort)
    in_manifest=$(python3 -c "
import json,sys
try: d=json.load(open('$REPO/plugins/neorgon-forge/.claude-plugin/plugin.json'))
except Exception: sys.exit(0)
print('\n'.join(sorted(d.get('skills',[]))))
")
    if [ "$on_disk" = "$in_manifest" ]; then
      green "  plugin.json lists exactly the $(printf '%s' "$on_disk" | grep -c .) skills on disk"
    else
      red "  plugin.json and the skills tree disagree:"
      comm -23 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$in_manifest") \
        | sed 's/^/    on disk, not in the manifest: /'
      comm -13 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$in_manifest") \
        | sed 's/^/    in the manifest, not on disk: /'
      fail=1
    fi
  fi
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
