#!/usr/bin/env bash
# Report the shape of an unfamiliar application: how it routes, where code of
# each kind lives, and what the naming convention appears to be.
#
# This runs before any claim about the codebase is made. The failure mode it
# prevents is asserting a convention from two files that happened to be opened
# first — "components live in src/components" is true of most repos and false in
# the one that matters, and the correction arrives after the change is written.
#
# It reports counts and locations, not conclusions. A census is evidence for a
# rule; the rule still has to be stated and recorded by whoever reads this.
#
# Reads only. Nothing here writes to the surveyed repo.
#
# If tools here fail with "command not found": some harness shells drop PATH
# inside loop bodies — run `export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin` first.
#
# Usage: orient.sh [dir]
set -uo pipefail

DIR="${1:-.}"
[ -d "$DIR" ] || { printf 'no such directory: %s\n' "$DIR" >&2; exit 1; }

head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }

PRUNE=(-type d \( -name .git -o -name node_modules -o -name __pycache__ \
  -o -name dist -o -name build -o -name .next -o -name vendor -o -name .venv \
  -o -name coverage -o -name .cache \) -prune)

head_ "Root"
printf '  %s\n' "$(cd "$DIR" && pwd)"

# ── Framework, from its own manifest ────────────────────────────────
# Detected rather than guessed: the routing model decides what a "path" even
# means here, and getting it wrong makes every later answer wrong in the same
# direction.
head_ "Stack"
found=0
for marker in package.json requirements.txt pyproject.toml Gemfile go.mod Cargo.toml \
  composer.json pom.xml build.gradle Makefile; do
  if [ -f "$DIR/$marker" ]; then
    printf '  %s\n' "$marker"
    found=1
  fi
done
[ "$found" -eq 0 ] && dim "  no manifest at root — this may be a static site or a subdirectory"

if [ -f "$DIR/package.json" ] && command -v python3 >/dev/null 2>&1; then
  python3 - "$DIR/package.json" <<'PY' 2>/dev/null
import json, sys
data = json.load(open(sys.argv[1]))
deps = {**data.get("dependencies", {}), **data.get("devDependencies", {})}
known = ["next", "react-router-dom", "react-router", "@remix-run/react", "vue-router",
         "nuxt", "@angular/router", "svelte", "@sveltejs/kit", "astro", "express",
         "fastify", "koa", "hono", "@nestjs/core", "vite", "webpack"]
hits = [f"{n}@{deps[n]}" for n in known if n in deps]
if hits:
    print("  routing / build:", ", ".join(hits))
scripts = data.get("scripts", {})
for key in ("dev", "start", "build", "serve", "test"):
    if key in scripts:
        print(f"  script {key}: {scripts[key]}")
PY
fi

# ── The navigable surface ───────────────────────────────────────────
head_ "Route definitions"
dim "  Files that declare where a path goes. Read these before inferring anything."
routes=0
while IFS= read -r f; do
  printf '  %s\n' "${f#"$DIR"/}"
  routes=$((routes + 1))
done < <(find "$DIR" "${PRUNE[@]}" -o -type f \
  \( -iname 'router*' -o -iname 'routes*' -o -iname 'urls.py' -o -iname 'app-routing*' \
     -o -iname 'config.routes*' \) -print 2>/dev/null | sort | head -30)
[ "$routes" -eq 0 ] && dim "  none by name — routing is probably file-based (see the tree below) or inline"

head_ "File-based route roots"
for candidate in pages app src/pages src/app src/routes routes app/routes views src/views; do
  if [ -d "$DIR/$candidate" ]; then
    n=$(find "$DIR/$candidate" -type f | wc -l | tr -d ' ')
    printf '  %-16s %s files\n' "$candidate" "$n"
  fi
done

head_ "Entry points"
entries=0
for candidate in index.html src/main.ts src/main.js src/index.ts src/index.js src/index.tsx \
  src/App.tsx main.py app.py manage.py wsgi.py asgi.py main.go cmd; do
  [ -e "$DIR/$candidate" ] && { printf '  %s\n' "$candidate"; entries=$((entries + 1)); }
done
[ "$entries" -eq 0 ] && dim "  none of the usual names — with file-based routing the route roots above are
  the entry model; in an infra-heavy repo the manifests below are"

# ── Infra manifests ─────────────────────────────────────────────────
# In an AWS-heavy repo the real entry points and the real topology — Step
# Functions, cron schedules, queues, a function with no obvious handler file —
# live in SAM/CloudFormation/serverless/Terraform manifests, not in the code
# file census. A census that skips these reports the app and misses the system.
head_ "Infra manifests"
infra=0
while IFS= read -r f; do
  infra=$((infra + 1))
  printf '  %s\n' "${f#"$DIR"/}"
  # Resource names sit at indent 2 under Resources:, their Type at indent 4.
  # Enumerated from the manifest, not from handler files, so a function that
  # exists only here is still listed.
  awk '
    /^(Resources|functions):[[:space:]]*$/ { in_res = 1; next }
    in_res && /^[^[:space:]]/              { in_res = 0 }
    in_res && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
      cur = $1; sub(/:$/, "", cur); next
    }
    in_res && cur != "" && /^    ([Tt]ype|handler):[[:space:]]*[^[:space:]]/ {
      printf "    %-30s %s\n", cur, $2; cur = ""
    }
  ' "$f"
  grep -nE '[Ss]chedule([Ee]xpression)?:|rate\([^)]+\)|cron\([^)]+\)' "$f" 2>/dev/null |
    sed 's/^\([0-9]*\):[[:space:]]*/    L\1  /' | head -8
done < <(find "$DIR" "${PRUNE[@]}" -o -type f \
  \( -name 'template.yaml' -o -name 'template.yml' -o -name 'serverless.yml' \
     -o -name 'serverless.yaml' -o -iname '*cloudformation*.yml' \
     -o -iname '*cloudformation*.yaml' \) -print 2>/dev/null | sort | head -6)

tf_files=$(find "$DIR" "${PRUNE[@]}" -o -type f -name '*.tf' -print 2>/dev/null | sort)
if [ -n "$tf_files" ]; then
  infra=$((infra + 1))
  tf_n=$(printf '%s\n' "$tf_files" | wc -l | tr -d ' ')
  printf '  terraform (%s .tf %s)\n' "$tf_n" "$([ "$tf_n" -eq 1 ] && echo file || echo files)"
  printf '%s\n' "$tf_files" | tr '\n' '\0' | xargs -0 grep -h '^resource "' 2>/dev/null |
    awk -F'"' '{ count[$2]++ } END { for (t in count) printf "%6d  %s\n", count[t], t }' |
    sort -rn | head -15 | sed 's/^/  /'
fi
if [ "$infra" -eq 0 ]; then
  dim "  none — the code census above is the whole story here"
else
  dim "  reconcile the function list against the handler-file census below: a function"
  dim "  with no obvious handler file is the one that slips review"
fi

# ── Where each kind of file lives ───────────────────────────────────
# The census that path rules get written against. A directory holding one .tsx
# is not a convention; one holding forty is.
head_ "Extension census, by directory"
dim "  count · directory · extension — the basis for a path rule, not the rule itself"
find "$DIR" "${PRUNE[@]}" -o -type f -print 2>/dev/null |
  sed "s|^$DIR/||" |
  awk -F/ '
    NF > 1 {
      dir = $1
      if (NF > 2) dir = $1 "/" $2
      name = $NF
      ext = (name ~ /\./) ? substr(name, match(name, /\.[^.]*$/)) : "(none)"
      key = dir " " ext
      count[key]++
    }
    END { for (k in count) printf "%6d  %s\n", count[k], k }
  ' | sort -rn | head -25

# ── Naming conventions, stated as counts ────────────────────────────
head_ "Naming"
census() {
  local label="$1" pattern="$2"
  local n
  n=$(find "$DIR" "${PRUNE[@]}" -o -type f -name "$pattern" -print 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] && printf '  %-28s %s\n' "$label" "$n"
}
census "PascalCase.tsx"        '[A-Z]*.tsx'
census "kebab-case.ts"         '*-*.ts'
census "*.test.*"              '*.test.*'
census "*.spec.*"              '*.spec.*'
census "test_*.py"             'test_*.py'
census "*.module.css"          '*.module.css'
census "*.stories.*"           '*.stories.*'
census "index.* (barrel)"      'index.*'
census "*.d.ts"                '*.d.ts'

head_ "Convention documents"
docs=0
while IFS= read -r f; do
  printf '  %s\n' "${f#"$DIR"/}"
  docs=$((docs + 1))
done < <(find "$DIR" -maxdepth 2 "${PRUNE[@]}" -o -type f \
  \( -iname 'CLAUDE.md' -o -iname 'AGENTS.md' -o -iname 'CONTRIBUTING*' \
     -o -iname 'ARCHITECTURE*' -o -iname 'CONVENTIONS*' -o -iname '.editorconfig' \
     -o -iname 'DESIGN.md' \) -print 2>/dev/null | sort)
if [ "$docs" -eq 0 ]; then
  dim "  none — every rule here will have to come from a census or from the user"
else
  dim "  a stated convention outranks a census: read these before writing rules"
fi

head_ "Next"
dim "  Record what this establishes, with its basis:"
dim "    map.sh rule 'src/components/*.tsx' component 'census: 41 files, no exceptions'"
dim "  A rule with no basis is a guess that outlives the session that guessed it."
exit 0
