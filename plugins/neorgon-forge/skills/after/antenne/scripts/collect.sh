#!/usr/bin/env bash
# Gather everything a story about this session's work has to rest on, from
# sources that cannot lie: the repo's own log and working tree, the brief the
# work kept, the registry row that decides how the site may be described, the
# published feed, and the ids already waiting at the desk.
#
# Why the skill needs it up front: a story written from what the session
# remembers doing is the one failure this whole path exists to prevent. The
# archive is public and permanent, so every sentence has to be traceable to a
# diff, and every claim that a site is open has to be traceable to the registry.
#
# Read-only. It commits nothing, writes nothing, and never reads a key or a
# .env; it only tests whether a submit key exists.
#
# Usage: collect.sh [repo-dir] [--since YYYY-MM-DD] [--root <monorepo-root>]
# Exit 0 when it ran, 2 on a usage or environment error, 3 when the repo is a
# source the rules forbid, 4 when it is outside the fleet's scope. On 3 and 4
# nothing at all is gathered: the verdict is already in.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

repo="."
root=""
since=""
while [ $# -gt 0 ]; do
  case "$1" in
    --since|--root)
      if [ $# -lt 2 ]; then printf '%s needs a value\n' "$1" >&2; exit 2; fi
      if [ "$1" = "--since" ]; then since="$2"; else root="$2"; fi
      shift 2 ;;
    -h|--help)
      sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*)
      printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    *)
      repo="$1"; shift ;;
  esac
done

head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

# A section's body: the lines under `## <name>` and above the next `## ` heading,
# or the end of the file when it is the last one. This was a sed range plus
# `1d;$d`, where the `$d` meant the final line of the whole stream: when `## Open`
# ended the brief, as it does in the template, the newest open item was the line
# it deleted.
section() {
  awk -v want="$1" '
    /^## / { inside = (index($0, "## " want) == 1); next }
    inside { print }'
}

# Cut the brief template's own HTML comments out of a section, whole.
#
# This was `sed '/<!--/,/-->/d'`, and a sed range whose start and end patterns
# both match on ONE line opens a range that never closes: everything after that
# line was deleted in silence. brief.sh writes exactly that shape, a one-line
# comment under `## Open`, so the section naming what has NOT landed was the one
# most likely to vanish. Walking each line closes the comment where it closes.
strip_comments() {
  awk '
    {
      line = $0
      while (1) {
        if (inside) {
          at = index(line, "-->")
          if (at == 0) { line = ""; break }
          line = substr(line, at + 3); inside = 0
        } else {
          at = index(line, "<!--")
          if (at == 0) break
          shut = index(substr(line, at + 4), "-->")
          if (shut == 0) { line = substr(line, 1, at - 1); inside = 1; break }
          line = substr(line, 1, at - 1) substr(line, at + shut + 6)
        }
      }
      print line
    }'
}

top="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$top" ]; then
  printf 'collect: %s is not a git work tree, so there is no diff to read\n' "$repo" >&2
  exit 2
fi

# The monorepo root, found by the one marker that has not moved: PROJECTS.md.
# Keying on a projects/ layout instead is how a sibling skill silently lost a
# feature when the fleet reorganised.
if [ -z "$root" ]; then
  probe="$top"
  while [ "$probe" != "/" ] && [ -n "$probe" ]; do
    if [ -f "$probe/PROJECTS.md" ] && [ -d "$probe/scripts" ]; then root="$probe"; break; fi
    probe="$(dirname "$probe")"
  done
fi

# Both names, never a swap: the project folder is being renamed from
# dispatch-site to antenne-site, and a collector that knows only one of them is
# broken on one side of that rename with nothing to say so.
dispatch=""
if [ -n "$root" ]; then
  for candidate in "$root/projects/antenne-site" "$root/projects/dispatch-site"; do
    if [ -d "$candidate" ]; then dispatch="$candidate"; break; fi
  done
fi

# The window: the newest published story, so the same ground is not retold.
# Read from origin/main when the clone has it, because the publish workflow
# commits upstream as a bot and a clone that only fetched is not behind.
newest=""
if [ -n "$dispatch" ]; then
  newest="$(dispatch_dir="$dispatch" python3 - <<'PY' 2>/dev/null
import json, os, subprocess, sys
where = os.environ["dispatch_dir"]
doc = None
try:
    done = subprocess.run(["git", "-C", where, "show", "origin/main:data/posts.json"],
                          stdin=subprocess.DEVNULL, capture_output=True, timeout=10,
                          env=dict(os.environ, GIT_OPTIONAL_LOCKS="0"))
    doc = json.loads(done.stdout.decode("utf-8")) if done.returncode == 0 else None
except (OSError, subprocess.SubprocessError, ValueError):
    doc = None
if not isinstance(doc, dict):
    try:
        with open(os.path.join(where, "data", "posts.json"), encoding="utf-8") as handle:
            doc = json.load(handle)
    except (OSError, ValueError):
        sys.exit(0)
posts = doc.get("posts") or []
print(max((p.get("date", "") for p in posts if isinstance(p, dict)), default=""))
PY
)"
fi
if [ -z "$since" ]; then
  since="$newest"
fi
if [ -z "$since" ]; then
  since="$(python3 -c 'import datetime; print(datetime.date.today() - datetime.timedelta(days=14))' 2>/dev/null)"
fi
if [ -z "$since" ]; then
  printf 'collect: cannot work out a window, pass --since YYYY-MM-DD\n' >&2
  exit 2
fi

# The forbidden sources, the narrowed commit list and the registry row. This
# refuses outright inside a source the rules forbid (exit 3) or a repo outside
# the fleet's scope (exit 4), and nothing below it runs, so a refusal gathers
# nothing rather than gathering and warning.
signal_args=("$repo" "$since")
[ -n "$root" ] && signal_args+=(--root "$root")
python3 "$here/news-signal.py" "${signal_args[@]}"
code=$?
if [ "$code" -ne 0 ]; then
  exit "$code"
fi

# ── What the work itself said it was for ──────────────────────────────
# The brief is a private working note. It is raw material to summarize in your
# own words and never copy: no quoting, no names, no employers, no email
# addresses, no internal paths.
head_ "Brief (private: summarize, never quote)"
brief="$top/.forge/brief.md"
if [ -f "$brief" ]; then
  echo "  $brief"
  # The HTML comments are the brief template's own prompts to its author, so
  # they are cut whole: a half-quoted comment reads like the work said it.
  section Problem <"$brief" | strip_comments \
    | grep -v '^[[:space:]]*$' | head -3 | cut -c1-110 | sed 's/^/    problem: /'
  section Open <"$brief" | strip_comments \
    | grep -v '^[[:space:]]*$' | head -4 | cut -c1-110 | sed 's/^/    open:    /'
else
  echo "  (no .forge/brief.md here: the diff and the log are the whole record)"
fi

# ── What has already been told ────────────────────────────────────────
head_ "Published feed"
if [ -n "$dispatch" ]; then
  echo "  feed at $dispatch"
  echo "  newest published story: ${newest:-none}"
  dispatch_dir="$dispatch" project="$(basename "$top")" python3 - <<'PY' 2>/dev/null || echo "  (could not read the published feed)"
import json, os, subprocess
where, project = os.environ["dispatch_dir"], os.environ["project"]
doc = None
try:
    done = subprocess.run(["git", "-C", where, "show", "origin/main:data/posts.json"],
                          stdin=subprocess.DEVNULL, capture_output=True, timeout=10,
                          env=dict(os.environ, GIT_OPTIONAL_LOCKS="0"))
    doc = json.loads(done.stdout.decode("utf-8")) if done.returncode == 0 else None
except (OSError, subprocess.SubprocessError, ValueError):
    doc = None
if not isinstance(doc, dict):
    with open(os.path.join(where, "data", "posts.json"), encoding="utf-8") as handle:
        doc = json.load(handle)
posts = [p for p in (doc.get("posts") or []) if isinstance(p, dict)]
mine = [p for p in posts if p.get("site") == project][:8]
if mine:
    print(f"  stories already published about {project}:")
    for post in mine:
        print(f"    {post.get('id')}  {str(post.get('title'))[:70]}")
else:
    print(f"  no published story names {project} yet")
PY
else
  echo "  (no Antenne checkout beside this repo: the feed and its ids are unread)"
fi

# ── What is already waiting for a reviewer ────────────────────────────
# One line, and only when a submit key exists. Fail-soft inside a 5 s budget: a
# backend that is down costs a line, never the collection. dispatch-site's
# client runs only through the root's ./scripts/antenne_trust.py, which checks
# it against the sha256 the owner pinned after reading it; others can push to
# that public repo, and this runs beside every credential on the machine.
head_ "Desk queue"
if [ -z "$root" ]; then
  echo "  (outside the monorepo: the queue cannot be read from here)"
elif [ ! -f "$root/scripts/antenne_trust.py" ]; then
  echo "  not read: there is no ./scripts/antenne_trust.py here to check the client against its review"
elif [ -z "$dispatch" ]; then
  echo "  not read: no Antenne checkout under projects/"
elif [ -z "${ANTENNE_KEY:-}" ] && [ ! -f "${ANTENNE_KEY_FILE:-${HOME}/.config/antenne/submit-key}" ]; then
  echo "  no submit key on this machine, so the queue is unread and nothing can be submitted."
  echo "  run ./scripts/setup-antenne.sh to set one up; never read or print the key itself."
else
  trust_root="$root" dispatch_dir="$dispatch" python3 - <<'PY' 2>/dev/null || echo "  (could not read the desk queue)"
import json, os, subprocess, sys, time
trust = os.path.join(os.environ["trust_root"], "scripts", "antenne_trust.py")
site = os.environ["dispatch_dir"]
start = time.monotonic()
try:
    checked = subprocess.run([sys.executable, trust, "check", site], stdin=subprocess.DEVNULL,
                             capture_output=True, text=True, timeout=2)
    if checked.returncode != 0:
        why = (checked.stderr.strip().splitlines() or ["the check failed"])[-1]
        why = why.replace("antenne_trust: ", "", 1).replace("refused: ", "", 1)
        print(f"  not read: {why.replace(os.path.expanduser('~'), '~')[:400]}")
        raise SystemExit(0)
    key_file = os.environ.get("ANTENNE_KEY_FILE", "")
    # The gate above accepts ANTENNE_KEY_FILE, so the client has to hear about it
    # too, or the probe reads the default path and reports no key on a machine
    # that has one. submit.sh's send path forwards it the same way.
    where = ["--key-file", key_file] if key_file and not os.environ.get("ANTENNE_KEY") else []
    done = subprocess.run([sys.executable, trust, "run", site, "scripts/submit-drafts.py", "--status", *where],
                          stdin=subprocess.DEVNULL, capture_output=True, text=True,
                          timeout=max(0.5, 4.5 - (time.monotonic() - start)))
except subprocess.TimeoutExpired:
    print("  no answer within 5 s")
    raise SystemExit(0)
if done.returncode != 0:
    why = (done.stderr.strip().splitlines() or ["no reason given"])[-1]
    why = why.replace("submit-drafts: ", "", 1).replace(os.path.expanduser("~"), "~")
    print(f"  unavailable: {why.split('; ')[0][:160]}")
    raise SystemExit(0)
status = json.loads(done.stdout)
counts = status.get("counts") or {}
run = status.get("lastRun") if isinstance(status.get("lastRun"), dict) else {}
queue = [q for q in (status.get("queue") or []) if isinstance(q, dict)]
print(f"  {counts.get('pending', 0)} pending, {counts.get('approved', 0)} approved waiting,"
      f" last run {run.get('state') or 'none'}")
waiting = [q.get("storyId") for q in queue if q.get("status") == "pending" and q.get("storyId")]
if waiting:
    print("  ids already queued (never redraft one of these):")
    for story in waiting[:12]:
        print(f"    {story}")
PY
fi

head_ "The rules that govern the story"
if [ -n "$root" ] && [ -f "$root/.claude/commands/newsroom.md" ]; then
  echo "  canonical: $root/.claude/commands/newsroom.md"
  echo "  read its hard rules 1 to 3, its kinds, and its story schema before drafting."
else
  echo "  the monorepo's newsroom rules are not here; reference/story.md carries the fallback."
fi
echo "  privacy: never read o11y-harness, metrics or cartograph-site; summarize private"
echo "  notes rather than quoting them; never a person's name and never an email address."
