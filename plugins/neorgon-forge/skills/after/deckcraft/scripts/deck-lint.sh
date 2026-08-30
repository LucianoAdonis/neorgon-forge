#!/usr/bin/env bash
# Lint a slides-site deck for the faults its own audit structurally cannot see.
#
# validate.mjs checks density: bullet counts, word counts, table dimensions. It is
# DOM-free and content-blind by design, so it cannot tell a heading that states a
# claim from one that names a subject, and it cannot notice that a slide promises
# a link the deck does not contain. Those are the faults that make a deck useless
# while it passes clean, so deckcraft needs them reported before it critiques.
#
# Every check here is textual and deterministic. Nothing is a judgment call the
# model then has to re-derive, and nothing overlaps validate.mjs.
#
# Usage: deck-lint.sh <deck.yaml> [more.yaml ...]
#        deck-lint.sh <directory>
set -uo pipefail

command -v python3 >/dev/null 2>&1 || { printf 'python3 not found\n' >&2; exit 2; }

TARGET="${1:-.}"
[ -e "$TARGET" ] || { printf 'no such file or directory: %s\n' "$TARGET" >&2; exit 2; }

if [ -d "$TARGET" ]; then
  FILES=$(find "$TARGET" -maxdepth 1 -name '*.yaml' -o -maxdepth 1 -name '*.yml' | sort)
else
  FILES="$*"
fi

[ -n "$FILES" ] || { printf 'no .yaml files found in %s\n' "$TARGET" >&2; exit 2; }

# The deck is read as text rather than parsed: PyYAML is not guaranteed present,
# and every check here is about surface strings the author actually typed.
fail=0
for f in $FILES; do
  python3 - "$f" <<'PYEOF'
import re, sys, os

path = sys.argv[1]
lines = open(path, encoding='utf-8').read().splitlines()
name = os.path.basename(path)

findings = []
def flag(level, line_no, msg):
    findings.append((level, line_no, msg))

# ── Heading shape ─────────────────────────────────────────────────────────────
# A topic label names a subject; an assertion makes a claim. No POS tagger here,
# so this is deliberately two-sided: a high-precision stoplist that is worth
# acting on, and a weak-signal count reported as one line rather than per slide.
STOPLIST = {
    'agenda', 'overview', 'background', 'problem', 'the problem', 'solution',
    'the solution', 'timeline', 'rollout', 'actions', 'action items', 'results',
    'next steps', 'next step', 'the ask', 'ask', 'blockers', 'today', 'yesterday',
    'setup', 'summary', 'conclusion', 'conclusions', 'questions', 'context',
    'impact', 'goals', 'objectives', 'scope', 'risks', 'demo', 'appendix',
}
# A verb-ish token is the weak half of the test. Kept small on purpose: a long
# list produces confident wrong answers.
VERBISH = re.compile(
    r'\b(is|are|was|were|has|have|had|will|can|cannot|costs?|takes?|buys?|breaks?|'
    r'drops?|falls?|rose|grew|ships?|moves?|needs?|means?|beats?|saves?|leaves?|'
    r'stays?|goes?|gets?|makes?|does|did|should|must|wins?|fails?|runs?)\b', re.I)

headings = []          # (line_no, text, slide_type)
current_type = None
type_line = {}

for i, line in enumerate(lines, 1):
    m = re.match(r'\s*-\s+type:\s*(\S+)', line)
    if m:
        current_type = m.group(1).strip('"\'')
        type_line[i] = current_type
        continue
    m = re.match(r'\s*heading:\s*["\']?(.+?)["\']?\s*$', line)
    if m:
        headings.append((i, m.group(1).strip(), current_type))

# title/qa/appendix headings are exempt: a title is a name, a qa heading is a
# prompt, an appendix marker is a signpost. Demanding a claim there is wrong.
EXEMPT = {'title', 'qa', 'appendix'}
content_headings = [h for h in headings if h[2] not in EXEMPT]

labels = 0
for line_no, text, _t in content_headings:
    bare = text.lower().strip().rstrip('?:')
    if bare in STOPLIST:
        flag('warn', line_no, f'Topic label heading: "{text}". State the claim instead.')
        labels += 1
    elif not VERBISH.search(text):
        # No finite verb anywhere: it is a noun phrase, so it names rather than
        # claims. Length is not the signal: "The dashboard, before and after"
        # is five words and still a label. Counted, not flagged per slide,
        # because this half is a heuristic and will misjudge some headings.
        labels += 1

if content_headings:
    pct = round(100 * labels / len(content_headings))
    lvl = 'warn' if pct >= 50 else 'info'
    flag(lvl, 0, f'{labels} of {len(content_headings)} content headings look like topic '
                 f'labels ({pct}%). A heading should make a claim you could disagree with.')

# ── A promise the deck does not keep ──────────────────────────────────────────
text_all = '\n'.join(lines)
has_url = bool(re.search(r'https?://', text_all))
for i, line in enumerate(lines, 1):
    if re.search(r'\b(link|url|slides|code|repo|recording)\b.*\b(last slide|below|here|'
                 r'on the final|at the end)\b', line, re.I) and not has_url:
        flag('warn', i, 'Promises a link the deck does not contain: no URL appears anywhere.')

# ── Self-contradicting bullet sets ────────────────────────────────────────────
# "None" alongside a real item is the shipped example of this.
def check_block(block):
    vals = [b[1].lower().strip('.') for b in block]
    if len(vals) > 1 and any(v in ('none', 'n/a', 'nothing') for v in vals):
        flag('warn', block[0][0],
             'A bullet list contains "None" alongside other items. Pick one.')

bullet_block = []
for i, line in enumerate(lines, 1):
    m = re.match(r'\s*-\s+["\']?(.+?)["\']?\s*$', line)
    if m and not re.match(r'\s*-\s+(type|label|name|heading):', line):
        bullet_block.append((i, m.group(1).strip()))
    else:
        check_block(bullet_block)
        bullet_block = []
# A deck that ENDS on its bullets never reaches the else branch. The one shipped
# example of this fault is exactly such a file, so without this the guard was
# silently inert on the case it was written for.
check_block(bullet_block)

# ── Numbers asserted in a heading but absent from the slide ───────────────────
for idx, (line_no, text, _t) in enumerate(headings):
    nums = re.findall(r'\d[\d,.]*%?', text)
    if not nums:
        continue
    end = headings[idx + 1][0] if idx + 1 < len(headings) else len(lines) + 1
    body = '\n'.join(lines[line_no:end - 1])
    for n in nums:
        if n not in body:
            flag('info', line_no,
                 f'Heading claims "{n}" but that value does not appear on its own slide.')
            break

# ── Alt text, which nothing else checks ───────────────────────────────────────
for i, line in enumerate(lines, 1):
    if re.match(r'\s*src:\s*\S', line):
        window = '\n'.join(lines[max(0, i - 6):i + 6])
        if not re.search(r'\balt:\s*\S', window):
            flag('warn', i, 'Image has no alt text. Nothing in the audit checks this.')

# ── Unlabelled comparison columns ─────────────────────────────────────────────
for i, line in enumerate(lines, 1):
    m = re.match(r'\s*-\s+type:\s*(split|columns)\b', line)
    if not m:
        continue
    end = min(i + 24, len(lines))
    block = '\n'.join(lines[i:end])
    if len(re.findall(r'^\s+heading:', block, re.M)) < 3:   # slide heading + 2 columns
        flag('info', i, f'{m.group(1)} slide: columns may be unlabelled. '
                        'Give left and right their own heading.')

# ── Speaker notes, and where they go to die ───────────────────────────────────
note_count = len(re.findall(r'^\s*note:\s*\S', text_all, re.M))
slide_count = len(type_line)
if slide_count > 6 and note_count == 0:
    flag('info', 0, f'{slide_count} slides and no speaker notes. The note is where the '
                    'sentence you actually say lives.')
if note_count:
    flag('info', 0, f'{note_count} speaker note(s): these are dropped by the PPTX, Marp and '
                    'standalone HTML exports, and unopenable in Reveal. Do not rely on them '
                    'in an exported file.')

# ── Report ────────────────────────────────────────────────────────────────────
order = {'warn': 0, 'info': 1}
findings.sort(key=lambda f: (order[f[0]], f[1]))
warns = sum(1 for f in findings if f[0] == 'warn')

print(f'\n── {name}')
if not findings:
    print('   nothing to report')
for level, line_no, msg in findings:
    where = f'line {line_no}' if line_no else 'deck'
    print(f'   {level:<5} {where:<9} {msg}')
print(f'   {len(type_line)} slides · {warns} warning(s) · {len(findings) - warns} note(s)')
# A warning is a finding. Exiting 0 regardless made this safe to chain
# behind && in a publishing path, which is the opposite of the truth.
import sys as _sys; _sys.exit(1 if warns else 0)
PYEOF
  [ $? -eq 0 ] || fail=1
done

printf '\nThese checks are content-shaped and complement validate.mjs, which owns density.\n'
printf 'Run both: node validate.mjs <deck> for the limits, this for the argument.\n'
# 0 clean, 1 findings, 2 usage.
exit "$fail"
