#!/usr/bin/env python3
"""Generate Mermaid diagrams from a scanned model.

Two rendering targets that need opposite theming, which is the one thing about
Mermaid-in-MkDocs that is easy to get wrong:

  page    a fence inside a Markdown page. Emits NO theme block, because Material
          injects its own theme variables from the active palette. A frontmatter
          theme here bakes one palette into the diagram and it then stays dark on
          the light scheme and vice versa.

  export  a standalone .mmd rendered by mmdc to SVG/PNG. Nothing injects a theme,
          so the palette is baked in on purpose.

Meaning is carried by node SHAPE, not colour, in both targets. A shape survives
a palette switch, greyscale printing, and colourblind readers; a legend mapping
six hex values to six roles does not survive any of them.

Usage:
  diagram.py <kind> [--model docs/atlas/model.json] [--target page|export]
             [--area NAME] [--focus PATH] [--out FILE]

  kind: areas | flow | area-detail | focus | externals
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import atlas_model as am

PROJECT = Path.cwd().resolve()

# Baked only for the export target. Tuned against the dark plate these render on:
# a mid-navy fill under a cyan edge reads as depth rather than as decoration.
EXPORT_THEME = """---
config:
  theme: base
  themeVariables:
    background: "#040714"
    primaryColor: "#0f172a"
    primaryTextColor: "#e2e8f0"
    primaryBorderColor: "#0063e5"
    secondaryColor: "#141c33"
    tertiaryColor: "#0a1020"
    lineColor: "#38bdf8"
    textColor: "#cbd5e1"
    clusterBkg: "#0a1020"
    clusterBorder: "#1e293b"
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "13px"
  flowchart:
    curve: basis
    nodeSpacing: 45
    rankSpacing: 55
---
"""

# Shape by role. The pairs wrap the label, so the role is legible in the source
# as well as the render — a reviewer reading the .mmd sees the same distinction a
# reader of the SVG sees.
SHAPES = {
    "entry": ("([", "])"),
    "store": ("[(", ")]"),
    "config": ("{{", "}}"),
    "data": ("[/", "/]"),
    "test": ("[[", "]]"),
    "page": ("[", "]"),
    "style": ("(((", ")))"),
    "module": ("(", ")"),
}

# Emphasis, not identity. Three classes at most: the way in, the things many
# modules depend on, and anything structurally wrong. A palette that assigns a
# colour per area turns the diagram into something you decode instead of read.
PAGE_CLASSES = """
    classDef entry stroke-width:2px
    classDef hub stroke-width:2px,stroke-dasharray:0
    classDef cycle stroke-width:2px,stroke-dasharray:4 3
"""
EXPORT_CLASSES = """
    classDef entry fill:#132a4a,stroke:#38bdf8,stroke-width:2px,color:#e2e8f0
    classDef hub fill:#1a1435,stroke:#a855f7,stroke-width:2px,color:#e9d5ff
    classDef cycle fill:#2a1420,stroke:#f43f5e,stroke-width:2px,stroke-dasharray:4 3,color:#fecdd3
"""


def ident(path: str) -> str:
    clean = re.sub(r"[^A-Za-z0-9]", "_", path)
    return f"n_{clean}"


def label(text: str) -> str:
    """Quote a label and neutralise what breaks a Mermaid node.

    <br/> for line breaks, never \\n. Mermaid 11 renders labels through an HTML
    foreignObject by default, where a literal backslash-n is two characters of
    text rather than a break — a silent, visible-only-in-the-render regression.
    """
    safe = text.replace('"', "'").replace("\n", "<br/>")
    return f'"{safe}"'


def wrap(node, label_text):
    open_shape, close_shape = SHAPES.get(node["kind"], SHAPES["module"])
    return f"{ident(node['id'])}{open_shape}{label(label_text)}{close_shape}"


def short(node_id: str) -> str:
    return node_id.rsplit("/", 1)[-1]


def header(target, direction="TB"):
    theme = EXPORT_THEME if target == "export" else ""
    return f"{theme}flowchart {direction}\n"


def classes(target):
    return EXPORT_CLASSES if target == "export" else PAGE_CLASSES


def emit_areas(model, target):
    """Area-to-area coupling, with the edge count on the arrow.

    The count is the content. Two areas joined by one import and two joined by
    thirty are different facts, and an unlabelled arrow reports them identically.
    """
    lines = [header(target, "LR")]
    edges = am.area_edges(model)
    counts = {}
    for node in model["nodes"]:
        counts[node["area"]] = counts.get(node["area"], 0) + 1

    for area in am.areas_of(model):
        total = counts[area]
        lines.append(
            f'    {ident(area)}["{area}<br/><small>{total} '
            f'{"module" if total == 1 else "modules"}</small>"]'
        )
    for edge in edges:
        arrow = "==>" if edge["count"] >= 5 else "-->"
        lines.append(
            f"    {ident(edge['from'])} {arrow}|{edge['count']}| {ident(edge['to'])}"
        )
    if not edges:
        lines.append("    %% no cross-area imports: every area is self-contained")
    return "\n".join(lines) + "\n"


def emit_flow(model, target, limit=24):
    """The dependency spine: each module under the shallowest thing that imports it.

    Deliberately NOT every edge. A real app has roughly twice as many imports as
    modules, and drawing all of them produces a plate of spaghetti where no path
    can be followed — the diagram renders, looks impressive, and answers nothing.
    Rendering this project's 19 modules with all 41 edges was unreadable; the
    spine of the same model is not.

    What survives the cut: one arrow per module showing how the entry point
    reaches it, plus the edges inside an import cycle, because a cycle is the one
    structural fact that a tree cannot express and that silently breaks the
    "which layer is this" question. Everything elided is counted in a comment, so
    the reduction is visible rather than implied.
    """
    nodes = am.index(model)
    depth = am.depths(model)
    out, into = am.adjacency(model)
    starts, source = am.entries(model)
    hub_ids = {h["id"] for h in am.hubs(model, 5)}
    cycle_groups = am.cycles(model)
    cycle_ids = {n for group in cycle_groups for n in group}

    ranked = sorted(
        (n for n in model["nodes"] if n["id"] in depth),
        key=lambda n: (depth[n["id"]], -len(into[n["id"]]), n["id"]),
    )[:limit]
    shown = {n["id"] for n in ranked}

    # Left-to-right, so depth runs across and siblings stack down. A top-down
    # spine puts every depth-1 module on one row, and a diagram wider than the
    # content column gets scaled to fit — which in a Material page meant a
    # legible SVG shrunk to unreadable thumbnail. Vertical overflow costs a
    # scroll; horizontal overflow costs the diagram.
    lines = [header(target, "LR")]

    spine = set()
    for node_id in shown:
        if node_id in starts:
            continue
        parents = [
            p for p in into[node_id]
            if p in shown and depth.get(p, 1 << 30) < depth[node_id]
        ]
        if parents:
            spine.add((min(parents, key=lambda p: (depth[p], p)), node_id))

    extra = {
        (e["from"], e["to"]) for e in model["edges"]
        if e["from"] in cycle_ids and e["to"] in cycle_ids
        and e["from"] in shown and e["to"] in shown
    } - spine

    by_area = {}
    for node in ranked:
        by_area.setdefault(node["area"], []).append(node)

    for area, members in by_area.items():
        lines.append(f'    subgraph {ident("sg_" + area)}["{area}"]')
        for node in members:
            lines.append(f"        {wrap(node, short(node['id']))}")
        lines.append("    end")

    for src, dst in sorted(spine):
        lines.append(f"    {ident(src)} --> {ident(dst)}")
    for src, dst in sorted(extra):
        lines.append(f"    {ident(src)} -.-> {ident(dst)}")

    lines.append(classes(target).rstrip("\n"))
    for node_id in starts:
        if node_id in shown:
            lines.append(f"    class {ident(node_id)} entry")
    for node_id in sorted(hub_ids & shown):
        if node_id not in starts:
            lines.append(f"    class {ident(node_id)} hub")
    for node_id in sorted(cycle_ids & shown):
        lines.append(f"    class {ident(node_id)} cycle")

    if source == "inferred":
        lines.append("    %% entry points inferred from having no importers, not declared")
    hidden = len(depth) - len(shown)
    if hidden > 0:
        lines.append(f"    %% {hidden} further modules omitted for legibility")
    elided = len(model["edges"]) - len(spine) - len(extra)
    if elided > 0:
        lines.append(
            f"    %% spine only: {len(spine)} of {len(model['edges'])} imports drawn, "
            f"{elided} elided — see the focus diagram for one module's real edges"
        )
    if cycle_groups:
        lines.append(f"    %% dotted arrows close an import cycle ({len(cycle_groups)} found)")
    return "\n".join(lines) + "\n"


def emit_area_detail(model, target, area):
    """One area's internals, plus the modules outside it that reach in or out.

    The outside neighbours sit in their own subgraph rather than being dropped,
    because an area drawn with its boundary edges cut looks self-contained when it
    is not, which is the opposite of what the reader needs to know.
    """
    members = am.in_area(model, area)
    if not members:
        raise SystemExit(
            f"no area named {area!r}\nareas in this model: {', '.join(am.areas_of(model))}"
        )
    inside = {n["id"] for n in members}
    nodes = am.index(model)
    _, into = am.adjacency(model)

    crossing = [
        e for e in model["edges"]
        if (e["from"] in inside) != (e["to"] in inside)
    ]
    outside = sorted(
        {e["from"] for e in crossing if e["from"] not in inside}
        | {e["to"] for e in crossing if e["to"] not in inside}
    )

    lines = [header(target, "LR"), f'    subgraph sg_in["{area}"]']
    for node in sorted(members, key=lambda n: -len(into[n["id"]])):
        lines.append(f"        {wrap(node, short(node['id']))}")
    lines.append("    end")

    if outside:
        lines.append('    subgraph sg_out["outside this area"]')
        for node_id in outside:
            lines.append(f"        {wrap(nodes[node_id], node_id)}")
        lines.append("    end")

    for edge in model["edges"]:
        if edge["from"] in inside and edge["to"] in inside:
            lines.append(f"    {ident(edge['from'])} --> {ident(edge['to'])}")
    for edge in crossing:
        lines.append(f"    {ident(edge['from'])} -.-> {ident(edge['to'])}")

    lines.append(classes(target).rstrip("\n"))
    for node in members:
        if node["kind"] == "entry":
            lines.append(f"    class {ident(node['id'])} entry")
    if not crossing:
        lines.append(f"    %% {area} has no imports crossing its boundary")
    return "\n".join(lines) + "\n"


def emit_focus(model, target, focus):
    """One module, its importers above it and its dependencies below.

    The shape answers the question that actually gets asked before a change:
    what breaks if I touch this, and what do I have to understand first.
    """
    matches = am.resolve(model, focus)
    if not matches:
        raise SystemExit(f"nothing in the model matches {focus!r}")
    if len(matches) > 1:
        raise SystemExit(
            f"{focus!r} matches {len(matches)} modules — name one:\n  "
            + "\n  ".join(matches)
        )
    target_id = matches[0]
    nodes = am.index(model)
    hood = am.neighborhood(model, target_id)

    lines = [header(target, "LR")]
    if hood["imported_by"]:
        lines.append('    subgraph sg_in["imported by"]')
        for node_id in hood["imported_by"]:
            lines.append(f"        {wrap(nodes[node_id], short(node_id))}")
        lines.append("    end")

    lines.append(f"    {wrap(nodes[target_id], target_id)}")

    if hood["imports"]:
        lines.append('    subgraph sg_out["imports"]')
        for node_id in hood["imports"]:
            lines.append(f"        {wrap(nodes[node_id], short(node_id))}")
        lines.append("    end")

    for node_id in hood["imported_by"]:
        lines.append(f"    {ident(node_id)} --> {ident(target_id)}")
    for node_id in hood["imports"]:
        lines.append(f"    {ident(target_id)} --> {ident(node_id)}")

    lines.append(classes(target).rstrip("\n"))
    lines.append(f"    class {ident(target_id)} hub")
    if not hood["imported_by"]:
        lines.append("    %% nothing imports this: an entry point, or dead")
    return "\n".join(lines) + "\n"


def emit_externals(model, target, limit=12):
    externals = model["externals"][:limit]
    if not externals:
        return (
            header(target, "LR")
            + "    none{{\"no external packages imported\"}}\n"
        )
    lines = [header(target, "LR"), f'    app([{label(model["root"])}])']
    for package in externals:
        count = len(package["importers"])
        lines.append(
            f'    {ident(package["id"])}[/"{package["id"]}"/]'
        )
        arrow = "==>" if count >= 5 else "-->"
        lines.append(f'    app {arrow}|{count}| {ident(package["id"])}')
    dropped = len(model["externals"]) - len(externals)
    if dropped > 0:
        lines.append(f"    %% {dropped} less-used packages omitted")
    return "\n".join(lines) + "\n"


def main():
    argv = sys.argv[1:]
    if not argv or argv[0].startswith("-"):
        print(__doc__.strip(), file=sys.stderr)
        return 2

    kind = argv[0]
    model_path = PROJECT / am_option(argv, "--model", "docs/atlas/model.json")
    target = am_option(argv, "--target", "page")
    if target not in ("page", "export"):
        raise SystemExit("--target must be page or export")

    model = am.load(model_path)

    if kind == "areas":
        body = emit_areas(model, target)
    elif kind == "flow":
        body = emit_flow(model, target)
    elif kind == "area-detail":
        area = am_option(argv, "--area", None)
        if not area:
            raise SystemExit("area-detail needs --area NAME")
        body = emit_area_detail(model, target, area)
    elif kind == "focus":
        focus = am_option(argv, "--focus", None)
        if not focus:
            raise SystemExit("focus needs --focus PATH")
        body = emit_focus(model, target, focus)
    elif kind == "externals":
        body = emit_externals(model, target)
    else:
        raise SystemExit(
            f"unknown diagram kind {kind!r} — "
            "areas, flow, area-detail, focus, externals"
        )

    out = am_option(argv, "--out", None)
    if out:
        path = PROJECT / out
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body)
        print(f"wrote {out}")
    else:
        sys.stdout.write(body)
    return 0


def am_option(argv, flag, default):
    if flag in argv:
        index = argv.index(flag) + 1
        if index < len(argv):
            return argv[index]
    return default


if __name__ == "__main__":
    sys.exit(main())
