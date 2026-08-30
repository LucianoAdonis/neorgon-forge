#!/usr/bin/env python3
"""Check that the router and the README still describe the set of skills.

Every other rule in bin/validate.sh looks at one skill in isolation. These three
look at the set, which is the class of drift that isolation cannot see: four
skills were added to the tree in one week, and the router mentioned three of
them, the README none. CLAUDE.md called the router line "the one nothing can
check". This is that check.

Reads SRC (the skills tree) and REPO (the repo root) from the environment.
Exit 0 when the set is described, 1 when it is not.
"""
import os
import pathlib
import re
import sys

SRC = pathlib.Path(os.environ["SRC"])
REPO = pathlib.Path(os.environ["REPO"])

ok = True


def red(s):
    print(f"\033[31m{s}\033[0m")


def green(s):
    print(f"\033[32m{s}\033[0m")


def read(rel):
    p = REPO / rel
    return p.read_text() if p.exists() else ""


bucket = {d.name: d.parent.name for d in SRC.glob("*/*") if d.is_dir()}
names = sorted(bucket)
count = len(names)

ROUTER = "plugins/neorgon-forge/skills/before/forge/SKILL.md"
router = read(ROUTER)
readme = read("README.md")

# 1. Every skill is reachable from the two documents a reader actually opens.
for label, text, where in (("router", router, ROUTER), ("README", readme, "README.md")):
    if not text:
        red(f"  {where} is missing or empty")
        ok = False
        continue
    missing = [n for n in names if not re.search(rf"\b{re.escape(n)}\b", text)]
    if missing:
        red(f"  {where} never mentions: {', '.join(missing)}")
        red("    a skill absent from the router is one nobody will reach for")
        ok = False
    else:
        green(f"  {label} mentions all {count} skills")

# 2. A docs page whose skill was renamed or deleted is a page nothing links to.
pages = sorted(p.stem for p in (REPO / "docs" / "skills").glob("*.md"))
orphans = [p for p in pages if p not in names]
if orphans:
    red(f"  docs/skills/ pages with no skill on disk: {', '.join(orphans)}")
    red("    rename it with the skill, or delete it")
    ok = False
else:
    green("  docs/skills/ has no orphan pages")

# 2b. The README's diagrams are the map, and a map missing a skill is the same
#     lie as a router missing one. Checking the mermaid blocks separately, rather
#     than trusting check 1, is the point: a bucket-table row satisfies check 1
#     while leaving the new skill off the picture everyone actually reads.
blocks = re.findall(r"```mermaid\n(.*?)```", readme, re.S)
if not blocks:
    red("  README has no mermaid block: the map is gone")
    ok = False
else:
    drawn = "\n".join(blocks)
    off = [n for n in names if f"/{n}" not in drawn]
    if off:
        red(f"  README diagrams never show: {', '.join(off)}")
        red("    put it on the map where it is actually reached for, or say it chains to nothing")
        ok = False
    else:
        green(f"  README diagrams show all {count} skills")

    # Colour in the combos diagram encodes the bucket, and CLAUDE.md explicitly
    # contemplates moving a skill between buckets. Without this, such a move
    # leaves the map quietly mis-coloured, which is worse than uncoloured: it
    # asserts something false rather than saying nothing.
    node_bucket = {}
    for node, skill in re.findall(r'\b(\w+)\["/([a-z][a-z0-9-]*)"\]', drawn):
        node_bucket[node] = skill
    wrong = []
    for nodes, cls in re.findall(r"^\s*class\s+([\w,]+)\s+(\w+)\s*$", drawn, re.M):
        if cls not in {"before", "during", "after", "craft"}:
            continue
        for node in nodes.split(","):
            skill = node_bucket.get(node)
            if skill and bucket.get(skill) and bucket[skill] != cls:
                wrong.append((skill, cls, bucket[skill]))
    if wrong:
        for skill, shown, real in sorted(set(wrong)):
            red(f"  the map colours /{skill} as {shown}/ but it lives in {real}/")
        red("    a mis-coloured node asserts something false; recolour it or move the skill back")
        ok = False
    else:
        green("  every node on the map carries its skill's real bucket")

# 2c. Every relative link in the repo's own prose resolves. This found a docs
#     page linking to `impeccable.md`, a skill that lives outside this plugin
#     and so can never have a page here. A link into the void reads as a
#     cross-reference the reader is expected to follow.
#     An angle-bracket placeholder is the repo's convention and never counts.
broken = []
for md in sorted(list(REPO.glob("*.md")) + list((REPO / "docs").rglob("*.md"))
                 + list((REPO / ".agents").rglob("*.md"))):
    text = md.read_text()
    for m in re.finditer(r"\[[^\]]*\]\(([^)#][^)]*)\)", text):
        target = m.group(1).split("#")[0].strip()
        if not target or target.startswith(("http://", "https://", "mailto:")) or "<" in target:
            continue
        if not (md.parent / target).resolve().exists():
            broken.append((md.relative_to(REPO), text.count("\n", 0, m.start()) + 1, target))
if broken:
    for where, lineno, target in broken:
        red(f"  {where}:{lineno} links to {target}, which does not exist")
    ok = False
else:
    green("  every relative link in the repo's prose resolves")

# 2d. A description that names another skill has to name one that exists, or one
#     declared external. The description IS the routing decision, so a name in it
#     that resolves nowhere sends the reader into nothing, and is indistinguishable
#     from a forge skill that was renamed until someone writes the difference down.
declared = set()
ext = REPO / "docs" / "external-skills.md"
if ext.exists():
    declared = set(re.findall(r"^\| `([a-z][a-z0-9-]*)` \|", ext.read_text(), re.M))

NAMED = re.compile(r"\(use ([a-z][a-z0-9-]{2,})\)|use `/?([a-z][a-z0-9-]{2,})`")
dangling = []
for d in sorted(SRC.glob("*/*")):
    md = d / "SKILL.md"
    if not md.is_file():
        continue
    parts = md.read_text().split("---")
    front = parts[1] if len(parts) > 2 else ""
    for groups in NAMED.findall(front):
        for cand in groups:
            if cand and cand not in names and cand not in declared:
                dangling.append((d.name, cand))
if dangling:
    for skill, cand in sorted(set(dangling)):
        red(f"  {skill}'s description names '{cand}', which is neither a skill here")
        red(f"    nor declared in docs/external-skills.md")
    ok = False
else:
    green(f"  every skill named in a description resolves ({len(declared)} declared external)")

# 3. The reverse of check 1: a document naming a skill that does not exist.
#    Coverage alone cannot see this, and a combos diagram is exactly the kind
#    of prose that outlives a rename. Claude Code's own commands are allowed
#    through by name; a placeholder uses the repo's angle-bracket convention
#    (`/<name>`) and never matches.
BUILTINS = {
    "plugin", "doctor", "help", "clear", "compact", "config", "permissions",
    "hooks", "mcp", "agents", "skills", "resume", "review", "artifacts",
}
SLASH = re.compile(r"(?<![\w./-])/([a-z][a-z0-9-]{2,})(?![\w/.-])")

dangling = []
for where, text in (("README.md", readme), (ROUTER, router)):
    for m in SLASH.finditer(text):
        name = m.group(1)
        if name in names or name in BUILTINS:
            continue
        dangling.append((where, text.count("\n", 0, m.start()) + 1, name))

if dangling:
    for where, lineno, name in sorted(set(dangling)):
        red(f"  {where}:{lineno} routes to /{name}, which is not a skill here")
    red("    a router that points at a renamed skill is worse than one that omits it")
    ok = False
else:
    green("  every /command named in the router and README resolves")

# 3. Spelled counts go stale in silence. Only four explicit shapes count as a
#    claim about the set. A looser heuristic fired on "owes five things" and
#    "collapses three separate ideas", and a checker that misfires on good
#    prose is one authors learn to switch off. Missing a fifth phrasing is the
#    cheaper failure. "N skills" alone was still too broad: it caught "four
#    skills were added in one week", which counts an event rather than the set,
#    so the shape now needs a predication about the set (is/are/arranged/here). Matching runs on the text with line breaks flattened,
#    because this repo hard-wraps and a claim straddles the break as often
#    as not.
WORDS = {
    w: i
    for i, w in enumerate(
        "zero one two three four five six seven eight nine ten eleven twelve "
        "thirteen fourteen fifteen sixteen seventeen eighteen nineteen".split()
    )
}
UNITS = "one two three four five six seven eight nine".split()
for tens, base in (("twenty", 20), ("thirty", 30), ("forty", 40)):
    WORDS[tens] = base
    for u, unit in enumerate(UNITS, start=1):
        WORDS[f"{tens}-{unit}"] = base + u

NUM = "|".join(sorted(WORDS, key=len, reverse=True))
SHAPES = [
    # "N skills" in any construction EXCEPT one that counts an event rather
    # than the set. A whitelist of verbs was tried first and silently missed
    # plugin.json's "Twenty-three skills for ...", which is the listing text a
    # plugin directory shows: the one place a stale count survived this check.
    rf"\b(?P<n>{NUM}|\d+)\s+skills\b(?!\s+(?:were|was|had|have|has)\b)",
    rf"\ball\s+(?P<n>{NUM}|\d+)\b",
    rf"\bover\s+the\s+(?P<n>{NUM}|\d+)\b",
    rf"\b(?P<n>{NUM}|\d+)\s+is\s+more\s+than\b",
]

SOURCES = (
    (ROUTER, router),
    ("README.md", readme),
    (".claude-plugin/marketplace.json", read(".claude-plugin/marketplace.json")),
    # plugin.json's description is the listing text a directory shows, and it
    # was the one place a stale count survived this check: it said twenty-two
    # while the tree held twenty-three, found only by preparing a submission.
    ("plugins/neorgon-forge/.claude-plugin/plugin.json",
     read("plugins/neorgon-forge/.claude-plugin/plugin.json")),
)


def value(token):
    return int(token) if token.isdigit() else WORDS[token]


claims = []
for where, text in SOURCES:
    flat = text.replace("\n", " ")
    for shape in SHAPES:
        for m in re.finditer(shape, flat, re.IGNORECASE):
            token = m.group("n").lower()
            if value(token) != count:
                lineno = text.count("\n", 0, m.start()) + 1
                context = " ".join(flat[m.start() - 24 : m.end() + 24].split())
                claims.append((where, lineno, token, context))

if claims:
    for where, lineno, token, context in sorted(set(claims)):
        red(f"  {where}:{lineno} says '{token}' but there are {count}: ...{context}...")
    red("    update the claim, or drop the number if it no longer earns its keep")
    ok = False
else:
    green(f"  every stated skill count agrees with the {count} on disk")

sys.exit(0 if ok else 1)
