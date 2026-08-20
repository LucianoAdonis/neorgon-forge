#!/usr/bin/env bash
# feedback-add.sh — append one distilled rule to a persona's feedback ledger.
#
# The ledger is what makes a correction survive the session that produced it.
# A rule that needs its example to be understood is not distilled yet: write
# the pattern, not the case.
#
# Usage:
#   feedback-add.sh <persona> "<rule>" --section <name>
#
# The duplicate guard compares significant words. It catches a restatement,
# not a paraphrase in different words, so it prints the section back for a
# human read. Treat it as a guard, never as a guarantee.
#
# Exit: 0 appended · 1 a near-duplicate already exists (nothing written,
# edit that line instead) · 2 the run itself failed. Exit 2 is never a pass.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
red() { printf '\033[31m%s\033[0m\n' "$1"; }
ok()  { printf '\033[32m%s\033[0m\n' "$1"; }

PERSONA="${1:-}"; RULE="${2:-}"; SECTION=""
shift 2 2>/dev/null || true
while [ $# -gt 0 ]; do
  case "$1" in
    --section) SECTION="${2:-}"; shift 2 ;;
    *) red "unknown flag: $1" >&2; exit 2 ;;
  esac
done

[ -n "$PERSONA" ] && [ -n "$RULE" ] || {
  red 'usage: feedback-add.sh <persona> "<rule>" --section <name>' >&2; exit 2; }

LEDGER="$HERE/../feedback/$PERSONA.md"
[ -r "$LEDGER" ] || { red "no ledger at: $LEDGER (nothing was written)" >&2; exit 2; }

python3 - "$LEDGER" "$RULE" "$SECTION" <<'PY'
import re, sys
ledger, rule, section = sys.argv[1], sys.argv[2].strip(), sys.argv[3].strip()
rule = rule.rstrip('.') + '.'
text = open(ledger, encoding='utf-8').read()

def sig(s):
    return {w for w in re.findall(r"[a-záéíóúñü]+", s.lower()) if len(w) > 4}

new = sig(rule)
if not new:
    print("rule has no significant words; write a fuller line", file=sys.stderr); sys.exit(2)

for line in text.splitlines():
    if not line.startswith('- '):
        continue
    old = sig(line)
    if old and len(new & old) / len(new) >= 0.5:
        print(f"near-duplicate already in the ledger:\n  {line}\n"
              f"edit that line instead of appending a second.", file=sys.stderr)
        sys.exit(1)

sections = re.findall(r'^## (.+)$', text, re.M)
if not sections:
    print("ledger has no ## sections", file=sys.stderr); sys.exit(2)
if not section:
    print(f"--section is required. Existing: {', '.join(sections)}", file=sys.stderr)
    sys.exit(2)
match = next((s for s in sections if s.lower() == section.lower()), None)
if match is None:
    print(f"no section '{section}'. Existing: {', '.join(sections)}", file=sys.stderr)
    sys.exit(2)
section = match

# append as the last bullet of that section
lines = text.splitlines()
start = next(i for i, l in enumerate(lines) if l == f'## {section}')
end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith('## ')), len(lines))
last = max(i for i in range(start, end) if lines[i].startswith('- '))
lines.insert(last + 1, f'- {rule}')
open(ledger, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print(f"appended under ## {section}. The word-overlap guard catches restatements, not\n"
      f"paraphrases, so read the section and merge by hand if this duplicates one:")
for l in lines[start:end + 1]:
    if l.startswith('- '):
        print(f"  {l}")
PY
status=$?
[ $status -eq 0 ] && ok "ledger updated: $LEDGER"
exit $status
