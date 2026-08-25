#!/usr/bin/env python3
"""Answer a question from the model, and say when the model cannot answer it.

The point of querying the model rather than grepping the docs: a generated page
is prose about the model, and prose loses the structure. "What breaks if I change
schema.js" is one lookup here and a reading comprehension exercise there.

Every answer that names a file names a line too, so it can be checked. And every
answer reports the commit the model was built at, because an answer from a stale
model is worse than no answer: it is indistinguishable from a current one.

Usage:
  ask.py <question> [--model docs/atlas/model.json]

  where <question> is one of:
    impact <path>       what depends on this, transitively
    needs <path>        what this depends on, transitively
    where <term>        which modules match a term
    layers              modules grouped by distance from an entry point
    risk                widest blast radius, cycles, orphans
    stale               whether the model still matches the working tree
    areas               areas, sizes, and coupling
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import atlas_model as am
from diagram import am_option

PROJECT = Path.cwd().resolve()


def plural(count, noun):
    return f"{count} {noun}" if count == 1 else f"{count} {noun}s"


def stamp(model):
    commit = model.get("commit_short") or "no commit"
    suffix = " (built from a dirty tree)" if model.get("dirty") else ""
    return f"model at {commit}{suffix}"


def pick(model, fragment):
    matches = am.resolve(model, fragment)
    if not matches:
        raise SystemExit(
            f"nothing in the model matches {fragment!r}\n"
            "the model only contains scanned source files, "
            "run scan.py again if the file is new"
        )
    if len(matches) > 1:
        raise SystemExit(
            f"{fragment!r} matches {len(matches)} modules, name one:\n  "
            + "\n  ".join(matches)
        )
    return matches[0]


def reach(model, start, direction):
    out, into = am.adjacency(model)
    graph = into if direction == "up" else out
    layers, frontier, seen = [], [start], {start}
    while frontier:
        nxt = []
        for node in frontier:
            for other in graph[node]:
                if other not in seen:
                    seen.add(other)
                    nxt.append(other)
        if nxt:
            layers.append(sorted(nxt))
        frontier = nxt
    return layers


def edge_sites(model, src, dst):
    return [e["at"] for e in model["edges"] if e["from"] == src and e["to"] == dst]


def q_impact(model, fragment):
    target = pick(model, fragment)
    _, into = am.adjacency(model)
    layers = reach(model, target, "up")
    total = sum(len(layer) for layer in layers)

    print(f"impact of changing {target}: {stamp(model)}\n")
    if not layers:
        print("nothing imports it. Changing it affects no other module in the model.")
        print("That means it is an entry point, or it is dead, check which.")
        return
    print(f"{plural(total, 'module')} depend on it, across "
          f"{plural(len(layers), 'level')}.\n")
    print("directly:")
    for node in layers[0]:
        sites = edge_sites(model, node, target)
        print(f"  {node}  at {', '.join(sites)}")
    for depth, layer in enumerate(layers[1:], start=2):
        print(f"\nvia {depth} hops:")
        for node in layer:
            print(f"  {node}")


def q_needs(model, fragment):
    target = pick(model, fragment)
    layers = reach(model, target, "down")
    print(f"what {target} depends on: {stamp(model)}\n")
    if not layers:
        print("nothing. It imports no other module in the model.")
        return
    print("directly:")
    for node in layers[0]:
        sites = edge_sites(model, target, node)
        print(f"  {node}  at {', '.join(sites)}")
    for depth, layer in enumerate(layers[1:], start=2):
        print(f"\nvia {depth} hops:")
        for node in layer:
            print(f"  {node}")
    reachable = sum(len(layer) for layer in layers)
    print(f"\nto understand {target} you have to hold "
          f"{plural(reachable, 'module')} in your head")


def q_where(model, term):
    matches = am.resolve(model, term)
    print(f"modules matching {term!r}: {stamp(model)}\n")
    if not matches:
        print("none. The model indexes file paths, not contents,")
        print("grep the source for a term that appears inside a file.")
        return
    nodes = am.index(model)
    _, into = am.adjacency(model)
    for node_id in matches:
        node = nodes[node_id]
        print(f"  {node_id}  ({node['kind']}, {node['area']}, "
              f"{plural(len(into[node_id]), 'importer')}, {node['loc']} lines)")


def q_layers(model):
    depth = am.depths(model)
    starts, source = am.entries(model)
    print(f"modules by distance from an entry point, {stamp(model)}\n")
    if source == "inferred":
        print("entry points were inferred from having no importers, not declared.\n")
    grouped = {}
    for node_id, level in depth.items():
        grouped.setdefault(level, []).append(node_id)
    for level in sorted(grouped):
        print(f"depth {level}:")
        for node_id in sorted(grouped[level]):
            print(f"  {node_id}")
    unreached = [n["id"] for n in model["nodes"] if n["id"] not in depth]
    if unreached:
        print("\nnot reachable from any entry point:")
        for node_id in unreached:
            print(f"  {node_id}")


def q_risk(model):
    print(f"where change is expensive: {stamp(model)}\n")
    print("widest blast radius:")
    for hub in am.hubs(model, 6):
        print(f"  {hub['id']}  {plural(hub['importers'], 'importer')}, "
              f"{hub['loc']} lines")

    groups = am.cycles(model)
    print("\nimport cycles:")
    if groups:
        for group in groups:
            print("  " + " -> ".join(group) + " -> ...")
        print("  a cycle means these modules cannot be understood or tested apart")
    else:
        print("  none")

    stray = am.orphans(model)
    print("\nimported by nothing:")
    if stray:
        for node_id in stray:
            print(f"  {node_id}")
        print("  each is dead code or an unrecognised entry point, "
              "the two need opposite responses")
    else:
        print("  none")


def q_areas(model):
    counts = {}
    for node in model["nodes"]:
        counts[node["area"]] = counts.get(node["area"], 0) + 1
    print(f"areas: {stamp(model)} (from {model['areas_from']})\n")
    for area in am.areas_of(model):
        print(f"  {area}  {plural(counts[area], 'module')}")
    edges = am.area_edges(model)
    print("\ncoupling:")
    if edges:
        for edge in edges:
            print(f"  {edge['from']} -> {edge['to']}  {edge['count']} imports")
    else:
        print("  none: every area is self-contained")


def q_stale(model):
    """Whether the model still describes the tree, by asking git rather than mtimes.

    A file touched but not changed has a new mtime and identical content, so an
    mtime check reports drift that does not exist and gets ignored within a week.
    """
    commit = model.get("commit")
    print(f"staleness: {stamp(model)}\n")
    if not commit:
        print("the model records no commit, so drift cannot be measured.")
        print("commit the repo and rerun scan.py.")
        return

    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=PROJECT,
        capture_output=True, text=True,
    ).stdout.strip()
    if head == commit:
        print("HEAD matches the model commit.")
    else:
        print(f"HEAD is {head[:8]}, the model was built at {commit[:8]}.")

    changed = subprocess.run(
        ["git", "diff", "--name-only", f"{commit}..HEAD"], cwd=PROJECT,
        capture_output=True, text=True,
    ).stdout.split()
    known = {n["id"] for n in model["nodes"]}
    relevant = [path for path in changed if path in known]
    new = [
        path for path in changed
        if path not in known and path.endswith(
            (".js", ".mjs", ".jsx", ".ts", ".tsx", ".py")
        )
    ]

    # Only source counts as a dirty tree. The corpus, the model and the built
    # site are this skill's own output, so counting them means `stale` reports
    # drift every single time it runs, and a check that always fires is a check
    # nobody reads.
    dirty = [
        line[3:] for line in subprocess.run(
            ["git", "status", "--porcelain"], cwd=PROJECT,
            capture_output=True, text=True,
        ).stdout.splitlines()
        if line[3:].endswith((".js", ".mjs", ".jsx", ".ts", ".tsx", ".py"))
    ]

    if relevant:
        print(f"\n{plural(len(relevant), 'modelled file')} changed since:")
        for path in relevant:
            print(f"  {path}")
    if new:
        print(f"\n{plural(len(new), 'source file')} the model never saw:")
        for path in new:
            print(f"  {path}")
    if dirty:
        print(f"\n{plural(len(dirty), 'source file')} with uncommitted changes:")
        for path in dirty:
            print(f"  {path}")
    if not (relevant or new or dirty or head != commit):
        print("nothing relevant changed. Every answer from this model is current.")
    else:
        print("\nrerun scan.py then build.py: answers below that line are about "
              "an older tree")


def main():
    argv = sys.argv[1:]
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.strip(), file=sys.stderr)
        return 2

    question = argv[0]
    model = am.load(PROJECT / am_option(argv, "--model", "docs/atlas/model.json"))
    needs_arg = ("impact", "needs", "where")

    if question in needs_arg:
        if len(argv) < 2 or argv[1].startswith("--"):
            raise SystemExit(f"{question} needs an argument")
        subject = argv[1]

    if question == "impact":
        q_impact(model, subject)
    elif question == "needs":
        q_needs(model, subject)
    elif question == "where":
        q_where(model, subject)
    elif question == "layers":
        q_layers(model)
    elif question == "risk":
        q_risk(model)
    elif question == "areas":
        q_areas(model)
    elif question == "stale":
        q_stale(model)
    else:
        raise SystemExit(
            f"unknown question {question!r}: "
            "impact, needs, where, layers, risk, areas, stale"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
