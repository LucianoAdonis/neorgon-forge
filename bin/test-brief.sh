#!/usr/bin/env bash
# brief.sh is the repo's most-read artifact: debrief, writeup, closeout and
# docket all parse it, and four commands manipulate it with awk. It had no test
# of any kind, and it was silently corrupting every brief with more than one
# run. This is that test. Run it from the repo root.
set -uo pipefail

BRIEF_SH="$(cd "$(dirname "$0")/.." && pwd)/plugins/neorgon-forge/skills/during/task/scripts/brief.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
fail=0

red()   { printf '\033[31m  FAIL %s\033[0m\n' "$1"; fail=1; }
green() { printf '\033[32m  ok   %s\033[0m\n' "$1"; }
b()     { (cd "$WORK" && bash "$BRIEF_SH" "$@") >/dev/null 2>&1; }
brief() { cat "$WORK/.forge/brief.md"; }
lineof(){ grep -n "$1" "$WORK/.forge/brief.md" | tail -1 | cut -d: -f1; }

printf '\n\033[1m== brief.sh\033[0m\n'

# 1. A second run's decisions belong to the second run. This is the defect that
#    put today's notes 122 lines above their own run heading in this repo.
b init "first problem"
b note "first decision"
b close
b init "second problem"
b note "second decision"
if [ "$(lineof 'second decision')" -gt "$(lineof '^## Run:')" ] 2>/dev/null; then
  green "a second run's note lands under the second run's heading"
else
  red "a second run's note landed above its own '## Run:' heading"
fi
if [ "$(lineof 'second decision')" -gt "$(lineof '^_Closed ')" ] 2>/dev/null; then
  green "a second run's note lands below the first run's closed stamp"
else
  red "a second run's note landed above the first run's closed stamp"
fi
grep -c '^## Decisions$' "$WORK/.forge/brief.md" | grep -q '^2$' \
  && green "each run carries its own Decisions heading" \
  || red "the second run reuses the first run's Decisions heading"

# 2. correct must strike a note in the current run, never one in an earlier run.
b correct "second decision" "actually the other thing"
if brief | grep -q '~~`.*` second decision~~'; then
  green "correct strikes the current run's note"
else
  red "correct did not strike the current run's note"
fi
brief | grep -q '~~.*first decision~~' && red "correct struck an earlier run's note" \
                                       || green "correct left the earlier run alone"

# 3. A multi-line or tabbed outcome must not split a streams.tsv record.
b stream add "s" "x"
b stream "done" "s" "line one
line two	tabbed"
bad=$(awk -F'\t' 'NF != 4 { n++ } END { print n + 0 }' "$WORK/.forge/streams.tsv")
[ "$bad" -eq 0 ] && green "a multi-line outcome stays one 4-field record" \
                 || red "a multi-line outcome split streams.tsv into $bad malformed rows"

# 4. The done condition is asked for by SKILL.md Step 1 and has to land somewhere.
brief | grep -q '^## Done when' && green "the scaffold has somewhere to put the done condition" \
                                || red "no '## Done when' section: the answer to Step 1 is discarded"

# 5. index: it counts runs across three generations of marker, and it must
#    carry Rejected, the section that answers "did we already try this?".
b close
# index looks for */.forge/brief.md under a root, so give it a repo to find.
mkdir -p "$WORK/root/repo"
cp -R "$WORK/.forge" "$WORK/root/repo/.forge"
python3 - "$WORK/root/repo/.forge/brief.md" <<'PYX'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); t = p.read_text()
t = t.replace("## Rejected\n", "## Rejected\n\nthe CSS-only variant, which cannot measure\n", 1)
# an older-generation run marker, to exercise the run counter
t += "\n---\n\n**Problem.** a legacy-marker run\n"
p.write_text(t)
PYX
(cd "$WORK/root" && bash "$BRIEF_SH" index . >/dev/null 2>&1)
IDX="$WORK/root/.forge/brief-index.md"
if [ -f "$IDX" ]; then
  grep -q 'rejected: the CSS-only variant' "$IDX" \
    && green "the index carries Rejected, the anti-rework section" \
    || red "the index drops Rejected"
  grep -q '3 run(s)' "$IDX" \
    && green "the index counts runs across all three marker generations" \
    || red "run count wrong: $(grep -o '[0-9]* run(s)' "$IDX" | head -1), expected 3"
  grep -q 'problem: second problem' "$IDX" \
    && green "the index reads a run's own '## Problem' section" \
    || red "the index cannot read a scaffolded run's problem"
else
  red "index produced no file"
fi

printf '\n'
[ "$fail" -eq 0 ] && { printf '\033[32mbrief.sh checks passed.\033[0m\n'; exit 0; }
printf '\033[31mbrief.sh checks failed.\033[0m\n'; exit 1
