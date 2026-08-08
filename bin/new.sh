#!/usr/bin/env bash
# Scaffold a new skill: directory, frontmatter, the section headings that
# make a skill good, and registration.
#
# The template deliberately ships with prompts rather than filler prose.
# A scaffold full of plausible placeholder text gets shipped as-is; a
# scaffold full of questions does not.
#
# Usage:
#   new.sh <name> "<one-line purpose>"
#   new.sh <name> "<purpose>" --no-scripts
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/plugins/neorgon-forge/skills"

NAME="${1:-}"
PURPOSE="${2:-}"
WANT_SCRIPTS=1
shift 2 2>/dev/null || true
while [ $# -gt 0 ]; do
  case "$1" in
    --no-scripts) WANT_SCRIPTS=0; shift ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }

[ -n "$NAME" ] && [ -n "$PURPOSE" ] || {
  red 'usage: new.sh <name> "<one-line purpose>"'
  exit 1
}

# kebab-case is the convention across every skill; enforcing it here
# avoids a rename later when the directory and frontmatter must match.
grep -qE '^[a-z][a-z0-9-]*[a-z0-9]$' <<<"$NAME" || {
  red "name must be kebab-case: $NAME"
  exit 1
}

DIR="$SRC/$NAME"
[ -e "$DIR" ] && { red "already exists: $DIR"; exit 1; }

mkdir -p "$DIR/reference"
[ "$WANT_SCRIPTS" -eq 1 ] && mkdir -p "$DIR/scripts"

cat >"$DIR/SKILL.md" <<EOF
---
name: $NAME
description: "Use when TODO — the situation, in the words a user would actually type. Then what it covers, concretely. Then: Triggers on: 'TODO', 'TODO', 'TODO'. Then: Not for TODO (use TODO instead). Aim 300-900 chars: this string is the only thing loaded until the skill fires, so it carries the whole routing decision."
argument-hint: "[TODO|TODO] [target]"
user-invocable: true
license: MIT
---

# $NAME — $PURPOSE

TODO: two sentences. What this does, and the failure mode it exists to prevent.
The second sentence is the one that makes a skill worth having — if you cannot
name what goes wrong without it, the skill is a preference, not a skill.

## Step 1 — TODO

TODO: the first thing to do, concretely enough to follow without interpretation.

$([ "$WANT_SCRIPTS" -eq 1 ] && cat <<'INNER'
```bash
bash "$FORGE/skills/SKILLNAME/scripts/collect.sh" <args>
```

Mechanical work belongs in a script. A model re-deriving the same grep every
run wastes tokens and gets it subtly different each time.
INNER
)

## Step 2 — TODO

TODO.

## TODO: the judgment section

Every good skill has one section that is not steps — a table of trade-offs, a
list of what to keep versus cut, the thing an experienced person knows and a
first-timer does not. That section is why the skill beats a plain prompt.

| TODO | TODO |
|---|---|
| TODO | TODO |

## Invariants

TODO: the non-negotiables, as imperatives. These are what you would call out in
review. Three to five; a list of twelve is a list nobody reads.

- **TODO.** TODO — why it matters.
EOF

# Fix the placeholder path in the heredoc above, which could not interpolate
# inside a quoted inner heredoc.
if [ "$WANT_SCRIPTS" -eq 1 ]; then
  sed -i.bak "s/SKILLNAME/$NAME/g" "$DIR/SKILL.md" && rm -f "$DIR/SKILL.md.bak"

  cat >"$DIR/scripts/collect.sh" <<'EOF'
#!/usr/bin/env bash
# TODO: what facts this gathers, and why the skill needs them up front.
set -uo pipefail

head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

head_ "TODO"
echo "  TODO"
EOF
  chmod +x "$DIR/scripts/collect.sh"
fi

cat >"$DIR/reference/.gitkeep" <<'EOF'
EOF

green "created $DIR"
dim "  SKILL.md              the skill — every TODO must go"
[ "$WANT_SCRIPTS" -eq 1 ] && dim "  scripts/collect.sh    mechanical fact-gathering"
dim "  reference/            detail loaded on demand, not every session"

cat <<EOF

Next:
  1. Write the description first — it is the router, and the hardest part.
     Read: docs/authoring.md
  2. Fill every TODO. A shipped TODO is worse than a missing section.
  3. bash bin/validate.sh $NAME
  4. bash bin/install.sh
  5. Restart Claude Code, then try: /$NAME
EOF
