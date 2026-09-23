#!/usr/bin/env bash
# Put a drafted story through Antenne's own client, and only ever through the
# root's trust wrapper, so the shared post rules and the owner's reviewed pin
# both apply before anything leaves this machine.
#
# Why the skill needs it: the client is in a public repo that more than the
# owner can push to, and it runs here beside every credential on the machine.
# Reaching for it directly is the one mistake that turns a news skill into a
# supply chain. This script has no other way to call it. It also keeps the two
# irreversible edges apart: `check` sends nothing, `send` needs the operator to
# have said so, and neither approves, writes the feed, commits or pushes.
#
# Usage:
#   submit.sh scratch                       print a fresh directory outside every repo
#   submit.sh check <file.json>...          validate in submit mode, send nothing
#   submit.sh send  <file.json>...          submit to the private desk queue
#   submit.sh --selftest                    exercise the whole path against a fake
# Options: --root <monorepo-root>   default: the nearest parent with PROJECTS.md
#
# Exit 0 clean, 1 a story was refused or did not land, 2 usage or environment,
# 3 the trust check refused: the client changed since the owner read it.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Absolute, so a selftest that re-enters this script does not depend on the
# cwd it was first called from.
self="$here/$(basename "${BASH_SOURCE[0]}")"

say()  { printf 'antenne: %s\n' "$1" >&2; }
head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

find_root() {
  # The one marker that has not moved through two reorganisations.
  local probe="$1"
  while [ "$probe" != "/" ] && [ -n "$probe" ]; do
    if [ -f "$probe/PROJECTS.md" ] && [ -d "$probe/scripts" ]; then printf '%s' "$probe"; return 0; fi
    probe="$(dirname "$probe")"
  done
  return 1
}

find_dispatch() {
  # Both names, never a swap: the folder is being renamed from dispatch-site to
  # antenne-site, and knowing only one of them breaks on one side of the rename.
  local candidate
  for candidate in "$1/projects/antenne-site" "$1/projects/dispatch-site"; do
    if [ -d "$candidate" ]; then printf '%s' "$candidate"; return 0; fi
  done
  return 1
}

key_path() {
  # Where the client looks, and the same override it takes as --key-file. The
  # key itself is never read here, never printed, and never passed as an
  # argument: only its existence is tested.
  printf '%s' "${ANTENNE_KEY_FILE:-${HOME}/.config/antenne/submit-key}"
}

have_key() {
  [ -n "${ANTENNE_KEY:-}" ] && return 0
  [ -f "$(key_path)" ] && return 0
  return 1
}

check_files() {
  # A story file inside a git work tree is the accident that publishes a draft:
  # the Antenne repo is public, and so is every site repo beside it.
  local file toplevel
  for file in "$@"; do
    if [ ! -f "$file" ]; then
      say "no such story file: $file"
      return 2
    fi
    toplevel="$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null)"
    if [ -n "$toplevel" ]; then
      say "refusing $file: it sits inside the git work tree $toplevel, and these repos are public."
      say "write each story to a scratch directory instead: $(basename "$self") scratch"
      return 2
    fi
  done
  return 0
}

explain() {
  # One sentence per failure, naming what to do about it. A refusal that only
  # prints an exit code makes the operator guess, and guessing here means
  # retrying a request that was refused on purpose.
  case "$1" in
    0) return 0 ;;
    1) say "a story was refused or did not land: read the codes above, fix that story, and run this again." ;;
    2) say "the input, the key or the desk backend could not be read: nothing was sent, and nothing to retry yet." ;;
    3) say "the trust check refused: Antenne's client changed since the owner last read it, so nothing ran."
       say "report the line above and stop. Never run the pin command yourself: pinning is the owner's review of that diff." ;;
    *) say "the client exited $1, which is not one of its documented codes: report it and stop." ;;
  esac
}

run_client() {
  # The only call path. Never python3 on the client directly.
  python3 "$1/scripts/antenne_trust.py" run "$2" scripts/submit-drafts.py "${@:3}"
}

report_outcomes() {
  # Per id, in the client's own words, plus the one sentence each outcome earns.
  # The closing line is computed from the outcomes rather than from the exit
  # code: "nothing is public yet" printed under a `published` row contradicted
  # the row two lines above it, and that line is the last thing the operator
  # reads. Usage: report_outcomes <json-file> <check|send>
  python3 - "$1" "$2" <<'PY'
import json, sys
mode = sys.argv[2] if len(sys.argv) > 2 else "check"
try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        doc = json.load(handle)
except (OSError, ValueError):
    print("  (the client printed no readable outcome list)")
    raise SystemExit(0)
meaning = {
    "created": "a new draft is waiting at the desk",
    "updated": "it replaced a pending draft nobody had touched",
    "unchanged": "already queued with the same text, nothing moved",
    "kept-human-edits": "a reviewer had already edited it, and their copy stands",
    "already-decided": "past review, nothing changed",
    "published": "already published, nothing changed",
    "invalid": "the server refused it: fix that story and submit it again",
    "queue-full": "the queue holds as many machine drafts as it allows",
}
outcomes = doc.get("outcomes") if isinstance(doc, dict) else None
if not outcomes:
    for row in (doc.get("results") or []) if isinstance(doc, dict) else []:
        codes = ", ".join(f"{p.get('field')}:{p.get('code')}" for p in row.get("problems") or [])
        print(f"  {row.get('id')}  {'ok' if row.get('ok') else 'invalid'}{'  ' + codes if codes else ''}")
    raise SystemExit(0)
full = False
counted = {}
for row in outcomes:
    outcome = row.get("outcome")
    full = full or outcome == "queue-full"
    counted[outcome] = counted.get(outcome, 0) + 1
    print(f"  {row.get('id')}  {outcome}: {meaning.get(outcome, 'an outcome this skill does not know')}")
if doc.get("unsent"):
    print(f"  {doc['unsent']} stories were never sent, because a request failed before them")
if full:
    print("  the queue is full: stop submitting and ask the operator to work through the desk first.")


def tally(*names):
    return sum(counted.get(name, 0) for name in names)


def stories(count):
    return "story" if count == 1 else "stories"


if mode == "send":
    # One line per group, each saying what is true of that group alone. A story
    # the desk had already published is public; a draft this run queued is not;
    # the two cannot share a sentence.
    waiting = tally("created", "updated", "unchanged", "kept-human-edits")
    decided = tally("already-decided")
    live = tally("published")
    refused = tally("invalid", "queue-full")
    if waiting:
        print(f"  {waiting} {stories(waiting)} waiting at the desk, and none of that is public:"
              " a reviewer approves or spikes each one.")
    if decided:
        print(f"  {decided} {stories(decided)} the desk had already decided, so this run"
              " changed nothing there.")
    if live:
        it = "that one is" if live == 1 else "those are"
        them = "it" if live == 1 else "them"
        print(f"  {live} {stories(live)} already published: {it} in the public archive"
              f" already, and nothing here put {them} there or changed {them}.")
    if refused:
        print(f"  {refused} {stories(refused)} did not land, so nothing about"
              f" {'it' if refused == 1 else 'them'} reached the desk.")
    if not (waiting or decided or live or refused):
        print("  nothing landed and nothing changed.")
PY
}

selftest() {
  # The whole path against a fake: no network, no key, nothing from the real
  # client. Two repos (one whose work is news, one whose work is not), a valid
  # story, an invalid one, a refused trust check, a missing key, a story file
  # inside a repo, and a full queue.
  local sandbox fake repo_news repo_quiet keyfile nokey scratch ran fails=0
  sandbox="$(mktemp -d)" || { say "cannot make a sandbox"; return 2; }
  trap 'rm -rf "$sandbox"' RETURN
  fake="$sandbox/fake-root"
  # A key file the test controls, rather than a fake HOME: on a machine whose
  # python3 is a version-manager shim, moving HOME breaks the interpreter and
  # every check fails for a reason that has nothing to do with this skill.
  keyfile="$sandbox/key/submit-key"
  nokey="$sandbox/key/absent"
  scratch="$sandbox/stories"
  ran="$sandbox/client-ran"
  mkdir -p "$fake/scripts" "$fake/projects/dispatch-site/scripts" "$sandbox/key" "$scratch"
  printf 'PROJECTS.md stand-in\n' >"$fake/PROJECTS.md"

  cat >"$fake/scripts/antenne_trust.py" <<'PY'
#!/usr/bin/env python3
"""Stand-in for the root's trust wrapper: same argv, same refusal contract."""
import os, subprocess, sys
if os.environ.get("fake_refuse"):
    print("antenne_trust: refused: scripts/submit-drafts.py does not match its pin; the reviewed "
          "dispatch-site commit is 0123456789ab; review the diff, then run "
          "`python3 scripts/antenne_trust.py pin projects/dispatch-site`.", file=sys.stderr)
    sys.exit(3)
if len(sys.argv) < 4:
    sys.exit(2)
mode, where, script = sys.argv[1], sys.argv[2], sys.argv[3]
if mode == "check":
    sys.exit(0)
sys.exit(subprocess.call([sys.executable, os.path.join(where, script)] + sys.argv[4:]))
PY

  cat >"$fake/projects/dispatch-site/scripts/submit-drafts.py" <<'PY'
#!/usr/bin/env python3
"""Stand-in for Antenne's client: same argv, same JSON shapes, no network."""
import json, os, re, sys
args = sys.argv[1:]
dry = "--dry-run" in args
files, skip = [], False
for arg in args:
    if skip:
        skip = False
    elif arg in ("--key-file", "--site"):
        skip = True
    elif not arg.startswith("--"):
        files.append(arg)
with open(os.environ["fake_ran"], "a", encoding="utf-8") as handle:
    handle.write("ran\n")
results = []
for path in files:
    with open(path, encoding="utf-8") as handle:
        story = json.load(handle)
    problems = []
    story_id = str(story.get("id", ""))
    if not re.fullmatch(r"[a-z0-9-]{1,80}", story_id):
        problems.append({"field": "id", "code": "format"})
    if not story_id.startswith(str(story.get("date", "")) + "-"):
        problems.append({"field": "id", "code": "id-date"})
    if len(str(story.get("title", ""))) > 100:
        problems.append({"field": "title", "code": "too-long"})
    results.append({"id": story_id or "?", "ok": not problems, "problems": problems})
bad = sum(1 for r in results if not r["ok"])
if dry:
    print(json.dumps({"dryRun": True, "today": "2026-09-22", "results": results}, indent=2))
    print(f"submit-drafts: dry run: {len(results) - bad} valid, {bad} invalid, "
          f"1 request planned, nothing sent", file=sys.stderr)
    sys.exit(1 if bad else 0)
if bad:
    print(json.dumps({"refused": True, "today": "2026-09-22", "results": results}, indent=2))
    sys.exit(1)
outcome = os.environ.get("fake_outcome", "created")
print(json.dumps({"outcomes": [{"id": r["id"], "outcome": outcome, "problems": []}
                               for r in results]}, indent=2))
landed = ("created", "updated", "unchanged", "kept-human-edits", "already-decided", "published")
sys.exit(0 if outcome in landed else 1)
PY

  make_repo() {
    local where="$1" subject="$2" file="$3"
    mkdir -p "$where/$(dirname "$file")"
    git -c init.defaultBranch=main init -q "$where" >/dev/null 2>&1
    printf 'one line\n' >"$where/$file"
    git -C "$where" add -A >/dev/null 2>&1
    git -C "$where" -c user.email=selftest@example.invalid -c user.name=selftest \
      -c commit.gpgsign=false commit -q -m "$subject" >/dev/null 2>&1
  }
  repo_news="$sandbox/news-site"
  repo_quiet="$sandbox/quiet-site"
  make_repo "$repo_news" "feat(desk): readers can subscribe to a site's stories" "js/app.js"
  make_repo "$repo_quiet" "chore(footer-kit): sync the vendored footer" "css/neorgon-footer.css"
  make_repo "$sandbox/metrics/inner" "feat(report): a chart nobody outside may see" "chart.js"
  make_repo "$sandbox/assistant" "feat(chat): something a reader could notice" "main.py"
  # A repo that IS the monorepo root. Work lands there too, and passing it as
  # both the repo and the root is the collision that used to eat both arguments.
  root_repo="$sandbox/root-repo"
  make_repo "$root_repo" "feat(desk): stories reach a queue by themselves" "js/desk.js"
  mkdir -p "$root_repo/scripts"
  printf 'PROJECTS.md stand-in\n' >"$root_repo/PROJECTS.md"

  # brief.sh's own shape for an appended run: a section whose first line is a
  # one-line HTML comment, with the real items under it.
  mkdir -p "$repo_news/.forge"
  cat >"$repo_news/.forge/brief.md" <<'MD'
## Problem
<!-- What was wrong, in one line. -->
A reader who cared about one site had to read the whole feed.

## Open
<!-- Deferred work, defects that shipped, decisions left to the user. -->
- Nothing is committed yet.
- The owner still has to run the wizard.
MD

  cat >"$scratch/2026-09-22-a-valid-story.json" <<'JSON'
{
  "id": "2026-09-22-a-valid-story",
  "date": "2026-09-22",
  "kind": "feature",
  "site": "news-site",
  "title": "Readers can follow one site",
  "summary": "A reader who only cares about one site can now follow it alone.",
  "body": ["The feed grew a per-site filter, and the filter has its own address."],
  "links": [{ "label": "Open the feed", "url": "https://neorgon.com/" }],
  "tags": ["feed", "filters"]
}
JSON
  cat >"$scratch/bad.json" <<'JSON'
{
  "id": "not-dated-at-all",
  "date": "2026-09-22",
  "kind": "feature",
  "site": "news-site",
  "title": "An id that does not start with its date",
  "summary": "The client should refuse this one and send nothing.",
  "body": ["One paragraph."],
  "links": [],
  "tags": []
}
JSON

  want() {
    # want <label> <expected-exit> <substring> -- <command...>
    local label="$1" expect="$2" needle="$3" out code
    shift 4
    out="$("$@" 2>&1)"; code=$?
    if [ "$code" -ne "$expect" ]; then
      printf '  FAIL %s: exit %s, wanted %s\n' "$label" "$code" "$expect"
      printf '%s\n' "$out" | sed 's/^/        /' | head -6
      fails=$((fails + 1)); return
    fi
    if [ -n "$needle" ] && ! printf '%s' "$out" | grep -qF "$needle"; then
      printf '  FAIL %s: output never says %s\n' "$label" "$needle"
      printf '%s\n' "$out" | sed 's/^/        /' | head -8
      fails=$((fails + 1)); return
    fi
    printf '  ok   %s\n' "$label"
  }

  head_ "antenne selftest (no network, no key, nothing real is called)"

  want "work that is news is narrowed to a candidate" 0 "1 candidate" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$nokey" fake_ran="$ran" bash "$here/collect.sh" "$repo_news" \
    --since 2026-01-01 --root "$fake"
  want "work that is not news says so and stops" 0 "nothing here looks like news" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$nokey" fake_ran="$ran" bash "$here/collect.sh" "$repo_quiet" \
    --since 2026-01-01 --root "$fake"
  want "a forbidden source is refused and nothing is gathered" 3 "rules forbid" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$nokey" fake_ran="$ran" bash "$here/collect.sh" \
    "$sandbox/metrics/inner" --since 2026-01-01 --root "$fake"
  want "an out-of-scope repo stops the whole collection" 4 "outside the fleet's scope" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$nokey" fake_ran="$ran" bash "$here/collect.sh" \
    "$sandbox/assistant" --since 2026-01-01 --root "$fake"
  # Captured first: under pipefail a non-zero collect.sh (exit 4 here, by design)
  # would decide the pipeline's status whatever grep found, so the needle could
  # never fail the check.
  scoped_out=$(env ANTENNE_KEY="" ANTENNE_KEY_FILE="$nokey" bash "$here/collect.sh" "$sandbox/assistant" \
      --since 2026-01-01 --root "$fake" 2>&1 || true)
  if printf '%s\n' "$scoped_out" | grep -q "Desk queue"; then
    printf '  FAIL the collection carried on past the scope verdict\n'; fails=$((fails + 1))
  else
    printf '  ok   nothing is gathered after the scope verdict\n'
  fi
  want "the brief's open section survives a one-line comment" 0 \
    "The owner still has to run the wizard" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$nokey" fake_ran="$ran" bash "$here/collect.sh" \
    "$repo_news" --since 2026-01-01 --root "$fake"
  want "the monorepo root works as the repo argument" 0 "1 candidate" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$nokey" fake_ran="$ran" bash "$here/collect.sh" \
    "$root_repo" --since 2026-01-01 --root "$root_repo"
  want "a valid story passes the dry run" 0 "nothing was sent" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$keyfile" fake_ran="$ran" bash "$self" check \
    --root "$fake" "$scratch/2026-09-22-a-valid-story.json"
  want "an invalid story is refused before anything is sent" 1 "id-date" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$keyfile" fake_ran="$ran" bash "$self" check \
    --root "$fake" "$scratch/bad.json"
  want "a refused trust check stops the run" 3 "pinning is the owner's review" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$keyfile" fake_ran="$ran" fake_refuse=1 bash "$self" check \
    --root "$fake" "$scratch/2026-09-22-a-valid-story.json"
  cp "$scratch/2026-09-22-a-valid-story.json" "$repo_news/story.json"
  want "a story file inside a repo is refused" 2 "public" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$keyfile" fake_ran="$ran" bash "$self" check \
    --root "$fake" "$repo_news/story.json"

  # The key gate has to stop the run before the client is reached, so prove the
  # client was never executed rather than trusting the exit code.
  : >"$ran"
  want "no key stops a send before the client runs" 2 "setup-antenne" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$nokey" fake_ran="$ran" bash "$self" send \
    --root "$fake" "$scratch/2026-09-22-a-valid-story.json"
  if [ -s "$ran" ]; then
    printf '  FAIL the client ran even though no key was present\n'; fails=$((fails + 1))
  else
    printf '  ok   the client never ran without a key\n'
  fi

  printf 'selftest-not-a-real-key\n' >"$keyfile"
  chmod 600 "$keyfile"
  want "a submitted story reports its outcome per id" 0 "created" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$keyfile" fake_ran="$ran" bash "$self" send \
    --root "$fake" "$scratch/2026-09-22-a-valid-story.json"
  want "a full queue says to work the desk first" 1 "work through the desk" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$keyfile" fake_ran="$ran" fake_outcome=queue-full bash "$self" send \
    --root "$fake" "$scratch/2026-09-22-a-valid-story.json"
  want "a story the desk already published is reported as public" 0 \
    "already published: that one is in the public archive" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$keyfile" fake_ran="$ran" fake_outcome=published bash "$self" send \
    --root "$fake" "$scratch/2026-09-22-a-valid-story.json"
  published_out=$(env ANTENNE_KEY="" ANTENNE_KEY_FILE="$keyfile" fake_ran="$ran" fake_outcome=published \
      bash "$self" send --root "$fake" "$scratch/2026-09-22-a-valid-story.json" 2>&1 || true)
  if printf '%s\n' "$published_out" | grep -q "nothing is public yet"; then
    printf '  FAIL a published story was still called private by the closing line\n'
    fails=$((fails + 1))
  else
    printf '  ok   the closing line never contradicts the outcome above it\n'
  fi
  want "a missing monorepo root is an environment error" 2 "PROJECTS.md" -- \
    env ANTENNE_KEY="" ANTENNE_KEY_FILE="$keyfile" fake_ran="$ran" bash "$self" check \
    --root "$sandbox/nowhere" "$scratch/2026-09-22-a-valid-story.json"

  # Running a script puts its own directory first on sys.path, so a file named
  # after a stdlib module replaces that module for everything imported here.
  # signal.py did, and subprocess found out only while killing a timed-out git.
  # Asserted against the real directory rather than a copy, because the file
  # name is the thing under test.
  if (cd "$here" && python3 - "$here" <<'PY'
import pathlib, sys
here = pathlib.Path(sys.argv[1])
clashing = sorted(p.name for p in here.glob("*.py") if p.stem in sys.stdlib_module_names)
if clashing:
    print("shadows the stdlib: " + ", ".join(clashing))
    raise SystemExit(1)
import signal
import subprocess
if not hasattr(signal, "SIGKILL") or subprocess.signal is not signal:
    print("subprocess did not get the stdlib signal module")
    raise SystemExit(1)
PY
  ); then
    printf '  ok   no script here shadows a stdlib module\n'
  else
    printf '  FAIL a script here shadows a stdlib module\n'; fails=$((fails + 1))
  fi

  printf '\n'
  if [ "$fails" -ne 0 ]; then
    say "$fails selftest check(s) failed"
    return 1
  fi
  printf 'antenne selftest: every check passed\n'
  return 0
}

mode=""
root=""
files=()
while [ $# -gt 0 ]; do
  case "$1" in
    --selftest) mode="selftest"; shift ;;
    --root)
      if [ $# -lt 2 ]; then say "--root needs a directory"; exit 2; fi
      root="$2"; shift 2 ;;
    -h|--help) sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*) say "unknown option: $1"; exit 2 ;;
    check|send|scratch)
      if [ -z "$mode" ]; then mode="$1"; else files+=("$1"); fi
      shift ;;
    *) files+=("$1"); shift ;;
  esac
done

case "$mode" in
  selftest) selftest; exit $? ;;
  scratch)
    dir="$(mktemp -d)" || { say "cannot make a scratch directory"; exit 2; }
    printf '%s\n' "$dir"
    say "write each story to $dir/<id>.json. It is outside every repo, which is the point."
    exit 0 ;;
  check|send) : ;;
  "") say "usage: submit.sh [scratch|check|send] [--root DIR] [FILE...], or --selftest"; exit 2 ;;
esac

if [ ${#files[@]} -eq 0 ]; then
  say "$mode needs at least one story file"
  exit 2
fi

if [ -z "$root" ]; then
  root="$(find_root "$PWD")" || {
    say "no PROJECTS.md above $PWD, so this is not the Neorgon monorepo and Antenne's client cannot be reached from here."
    exit 2
  }
elif [ ! -f "$root/PROJECTS.md" ]; then
  say "no PROJECTS.md in $root, so it is not the Neorgon monorepo root."
  exit 2
fi
if [ ! -f "$root/scripts/antenne_trust.py" ]; then
  say "no ./scripts/antenne_trust.py under $root, and Antenne's client only ever runs through it."
  exit 2
fi
dispatch="$(find_dispatch "$root")" || {
  say "no Antenne checkout under $root/projects (antenne-site or dispatch-site): clone it first."
  exit 2
}

check_files "${files[@]}" || exit 2

out="$(mktemp)" || { say "cannot make a temporary file"; exit 2; }
err="$(mktemp)" || { rm -f "$out"; say "cannot make a temporary file"; exit 2; }
trap 'rm -f "$out" "$err"' EXIT

if [ "$mode" = "check" ]; then
  head_ "Dry run: validated in submit mode, nothing sent"
  run_client "$root" "$dispatch" --dry-run "${files[@]}" >"$out" 2>"$err"
  code=$?
  cat "$err" >&2
  report_outcomes "$out" check
  if [ "$code" -eq 0 ]; then
    printf '  every story is valid, and nothing was sent.\n'
    printf '  show the operator the story and this verdict, then ask before sending.\n'
  fi
  explain "$code"
  exit "$code"
fi

if ! have_key; then
  say "no submit key on this machine, so nothing can be submitted: ANTENNE_KEY is unset and $(key_path) does not exist."
  say "run ./scripts/setup-antenne.sh to set one up, and never read or print the key itself."
  exit 2
fi

key_args=()
if [ -z "${ANTENNE_KEY:-}" ] && [ -n "${ANTENNE_KEY_FILE:-}" ]; then
  key_args=(--key-file "$ANTENNE_KEY_FILE")
fi

head_ "Submitting to the private desk queue"
run_client "$root" "$dispatch" ${key_args[@]+"${key_args[@]}"} "${files[@]}" >"$out" 2>"$err"
code=$?
cat "$err" >&2
report_outcomes "$out" send
explain "$code"
exit "$code"
