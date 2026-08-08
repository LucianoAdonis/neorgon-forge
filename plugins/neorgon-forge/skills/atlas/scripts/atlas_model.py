"""Load a scanned model and derive the facts every other script needs.

Imported by diagram.py, build.py and ask.py rather than reimplemented in each,
because "most depended on" computed three slightly different ways produces three
answers and no way to tell which is right.

Nothing here reads the filesystem except load(). The derivations are pure
functions of the model, so a question answered from them is answered about the
commit the model records, not about whatever is on disk now.
"""
import json
from collections import defaultdict
from pathlib import Path


def load(path):
    path = Path(path)
    if not path.is_file():
        raise SystemExit(
            f"no model at {path}\nrun scan.py first — every other step reads it"
        )
    return json.loads(path.read_text())


def index(model):
    return {node["id"]: node for node in model["nodes"]}


def adjacency(model):
    out, into = defaultdict(list), defaultdict(list)
    for edge in model["edges"]:
        out[edge["from"]].append(edge["to"])
        into[edge["to"]].append(edge["from"])
    return out, into


def entries(model):
    """Entry points, preferring declared kind over inferred position.

    A file with no inbound edges is usually an entry, but it is also what an
    orphan looks like, so a node whose kind says entry wins. When nothing says
    entry the position-based guess is all there is, and callers should say so.
    """
    declared = [n["id"] for n in model["nodes"] if n["kind"] == "entry"]
    if declared:
        return declared, "declared"
    _, into = adjacency(model)
    return [n["id"] for n in model["nodes"] if not into[n["id"]]], "inferred"


def depths(model):
    """Distance from the nearest entry point, by breadth-first layers.

    Unreachable nodes get no depth rather than a sentinel: a module nothing
    imports has no position in the flow, and giving it depth 0 would draw it
    beside the entry point as though it were one.
    """
    out, _ = adjacency(model)
    starts, _ = entries(model)
    depth, frontier, seen = {}, list(starts), set(starts)
    level = 0
    while frontier:
        nxt = []
        for node in frontier:
            depth[node] = level
            for target in out[node]:
                if target not in seen:
                    seen.add(target)
                    nxt.append(target)
        frontier, level = nxt, level + 1
    return depth


def cycles(model):
    """Import cycles, as the node lists of each strongly connected component.

    Worth surfacing on its own: a cycle is the one structural fact that makes
    "which layer is this in" unanswerable, and it is invisible when reading any
    single file in it.
    """
    out, _ = adjacency(model)
    nodes = [n["id"] for n in model["nodes"]]
    order, seen = [], set()

    for start in nodes:
        if start in seen:
            continue
        stack = [(start, iter(out[start]))]
        seen.add(start)
        while stack:
            node, children = stack[-1]
            advanced = False
            for child in children:
                if child not in seen:
                    seen.add(child)
                    stack.append((child, iter(out[child])))
                    advanced = True
                    break
            if not advanced:
                order.append(stack.pop()[0])

    reverse = defaultdict(list)
    for edge in model["edges"]:
        reverse[edge["to"]].append(edge["from"])

    assigned, found = set(), []
    for start in reversed(order):
        if start in assigned:
            continue
        component, stack = [], [start]
        assigned.add(start)
        while stack:
            node = stack.pop()
            component.append(node)
            for parent in reverse[node]:
                if parent not in assigned:
                    assigned.add(parent)
                    stack.append(parent)
        if len(component) > 1:
            found.append(sorted(component))
    return sorted(found, key=len, reverse=True)


def hubs(model, limit=8):
    _, into = adjacency(model)
    ranked = sorted(model["nodes"], key=lambda n: -len(into[n["id"]]))
    return [
        {"id": n["id"], "importers": len(into[n["id"]]), "loc": n["loc"]}
        for n in ranked
        if into[n["id"]]
    ][:limit]


def orphans(model):
    """Modules nothing imports and that are not entry points.

    Either dead code or an undetected entry point, and the two need opposite
    responses, so this reports the set rather than a conclusion.
    """
    _, into = adjacency(model)
    declared, source = entries(model)
    if source == "inferred":
        return []
    known = set(declared)
    return [
        n["id"] for n in model["nodes"]
        if not into[n["id"]] and n["id"] not in known and n["kind"] != "test"
    ]


def area_edges(model):
    """Edges collapsed to area-to-area, with the count each one aggregates.

    The count is the point. Two areas joined by one import are coupled
    differently from two joined by thirty, and a diagram that draws both as one
    arrow has hidden the only interesting difference.
    """
    nodes = index(model)
    tally = defaultdict(int)
    for edge in model["edges"]:
        src = nodes[edge["from"]]["area"]
        dst = nodes[edge["to"]]["area"]
        if src != dst:
            tally[(src, dst)] += 1
    return [
        {"from": src, "to": dst, "count": count}
        for (src, dst), count in sorted(tally.items(), key=lambda kv: -kv[1])
    ]


def areas_of(model):
    seen = []
    for node in model["nodes"]:
        if node["area"] not in seen:
            seen.append(node["area"])
    return seen


def in_area(model, area):
    return [n for n in model["nodes"] if n["area"] == area]


def neighborhood(model, target):
    out, into = adjacency(model)
    return {
        "id": target,
        "imports": sorted(set(out[target])),
        "imported_by": sorted(set(into[target])),
    }


def resolve(model, fragment):
    """Match a path fragment to node ids, exact first.

    A question is asked with 'state' or 'the modal', not with 'js/state.js', and
    guessing one candidate when three matched is how an answer ends up being
    about the wrong file.
    """
    ids = [n["id"] for n in model["nodes"]]
    if fragment in ids:
        return [fragment]
    lowered = fragment.lower()
    stem = [i for i in ids if i.rsplit("/", 1)[-1].rsplit(".", 1)[0].lower() == lowered]
    return stem or [i for i in ids if lowered in i.lower()]
