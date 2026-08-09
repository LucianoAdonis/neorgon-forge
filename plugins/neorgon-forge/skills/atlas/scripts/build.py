#!/usr/bin/env python3
"""Write the MkDocs corpus from the model, into docs/atlas/ beside it.

Generated pages carry a provenance line naming the model commit they were built
from, and land under docs/atlas/reference/. Everything this skill writes lives
under the one docs/atlas/ root: the model, the pages generated from it, and the
exported diagrams. That single boundary is the entire discipline — hand-written
pages elsewhere in docs/ are never touched, and a generated page is never edited
by hand, because the next build overwrites it.

Without the boundary the corpus becomes a place where some pages are true and some
are stale and nothing distinguishes them, which is worse than no corpus at all —
a reader trusts it either way. One root rather than three is what makes the
boundary memorable enough to hold: a rule with three exceptions to recall is a
rule someone eventually edits across.

Usage:
  build.py [--model docs/atlas/model.json] [--docs docs] [--scaffold]

  --scaffold  also write mkdocs.yml and the hand-owned page stubs, if absent.
              Never overwrites either.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import atlas_model as am
import diagram

PROJECT = Path.cwd().resolve()
# Everything atlas owns hangs off one root inside docs/, so "what does this skill
# write" has a single answer. Pages are the part MkDocs navigates; the model and
# the exported diagrams sit beside them under the same root.
ATLAS_ROOT = "atlas"
GENERATED = f"{ATLAS_ROOT}/reference"

MKDOCS_YML = """site_name: {name}
theme:
  name: material
  palette:
    - media: "(prefers-color-scheme: light)"
      scheme: default
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.instant
    - navigation.tracking
    - navigation.sections
    - content.code.copy
    - search.suggest
    - search.highlight

markdown_extensions:
  - attr_list
  - md_in_html
  - admonition
  - toc:
      permalink: true
  - pymdownx.details
  - pymdownx.highlight
  - pymdownx.inlinehilite
  - pymdownx.snippets
  - pymdownx.blocks.caption
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format

plugins:
  - search
"""

INDEX_STUB = """# {name}

Hand-written. This page is yours; `atlas` never overwrites it.

Start with [the architecture overview](atlas/reference/architecture.md), which is
generated from the source and carries the commit it was built from.

## What this is

_Describe the app in a sentence a newcomer would understand._

## What it is not

_The boundary. Cheaper to state than to infer._
"""


def provenance(model):
    commit = model.get("commit_short") or "no commit"
    dirty = " + uncommitted changes" if model.get("dirty") else ""
    return (
        f"!!! info \"Generated\"\n"
        f"    Built by `atlas` from `{model['generated_by']}` at "
        f"`{commit}`{dirty}.\n"
        f"    Do not edit — run `atlas build` again instead.\n"
    )


def fence(body):
    """A mermaid fence, with the theme frontmatter stripped if present.

    Material injects theme variables from the active palette, so a baked theme
    inside a page fence wins and the diagram then stays one scheme while the rest
    of the page switches. The export target keeps its theme; a page never gets one.
    """
    if body.startswith("---\n"):
        end = body.find("\n---\n", 4)
        if end != -1:
            body = body[end + 5:]
    return "```mermaid\n" + body.rstrip("\n") + "\n```\n"


def caption(text):
    return f"/// caption\n{text}\n///\n"


def plural(count, noun):
    return f"{count} {noun}" if count == 1 else f"{count} {noun}s"


def page_architecture(model):
    entry_ids, entry_source = am.entries(model)
    cycle_groups = am.cycles(model)
    areas = am.areas_of(model)
    edges = am.area_edges(model)

    out = [f"# Architecture\n\n{provenance(model)}\n"]
    out.append(
        f"`{model['root']}` is {plural(len(model['nodes']), 'module')} in "
        f"{plural(len(areas), 'area')}, with "
        f"{plural(len(model['edges']), 'internal import')} between them.\n"
    )
    out.append("\n## Areas\n\n")
    out.append(fence(diagram.emit_areas(model, "page")))
    out.append(
        caption(
            "Each arrow is labelled with how many imports it aggregates. "
            "A thick arrow is five or more."
        )
    )

    out.append("\n## The dependency spine\n\n")
    out.append(fence(diagram.emit_flow(model, "page")))
    out.append(
        caption(
            "One arrow per module, showing how an entry point reaches it. "
            "Dotted arrows close an import cycle. Shape carries role: "
            "rounded is an entry point, cylinder a store, hexagon config."
        )
    )

    out.append("\n## Entry points\n\n")
    if entry_source == "inferred":
        out.append(
            "No module declared itself an entry point, so these are inferred "
            "from having no importers — which is also what dead code looks like.\n\n"
        )
    for node_id in entry_ids:
        out.append(f"- `{node_id}`\n")

    hub_list = am.hubs(model, 8)
    if hub_list:
        out.append("\n## Most depended on\n\n")
        out.append("Changing one of these has the widest blast radius.\n\n")
        out.append("| Module | Importers | Lines |\n|---|---:|---:|\n")
        for hub in hub_list:
            out.append(f"| `{hub['id']}` | {hub['importers']} | {hub['loc']} |\n")

    if cycle_groups:
        out.append("\n## Import cycles\n\n")
        out.append(
            "A cycle makes \"which layer is this in\" unanswerable, and is "
            "invisible when reading any single file in it.\n\n"
        )
        for group in cycle_groups:
            out.append("- " + " → ".join(f"`{n}`" for n in group) + " → …\n")

    stray = am.orphans(model)
    if stray:
        out.append("\n## Imported by nothing\n\n")
        out.append(
            "Either dead code or an entry point the scan did not recognise. "
            "The two need opposite responses, so this lists them rather than "
            "concluding.\n\n"
        )
        for node_id in stray:
            out.append(f"- `{node_id}`\n")

    if edges:
        out.append("\n## Coupling between areas\n\n")
        out.append("| From | To | Imports |\n|---|---|---:|\n")
        for edge in edges:
            out.append(f"| `{edge['from']}` | `{edge['to']}` | {edge['count']} |\n")

    return "".join(out)


def page_area(model, area):
    members = am.in_area(model, area)
    _, into = am.adjacency(model)
    out = [f"# {area}\n\n{provenance(model)}\n"]
    out.append(f"{plural(len(members), 'module')} in this area.\n\n")
    out.append(fence(diagram.emit_area_detail(model, "page", area)))
    out.append(
        caption(
            "Solid arrows are imports within the area; dotted arrows cross its "
            "boundary. An area drawn with its boundary cut looks self-contained "
            "when it is not."
        )
    )
    out.append("\n## Modules\n\n")
    out.append("| Module | Role | Importers | Lines |\n|---|---|---:|---:|\n")
    for node in sorted(members, key=lambda n: -len(into[n["id"]])):
        out.append(
            f"| `{node['id']}` | {node['kind']} | "
            f"{len(into[node['id']])} | {node['loc']} |\n"
        )
    return "".join(out)


def page_dependencies(model):
    out = [f"# Dependencies\n\n{provenance(model)}\n"]
    if not model["externals"]:
        out.append(
            "No external packages are imported. Every dependency is internal, "
            "which is a real architectural fact worth stating.\n"
        )
        return "".join(out)

    out.append(fence(diagram.emit_externals(model, "page")))
    out.append(caption("Arrow labels count the files importing each package."))
    out.append("\n## Every external package\n\n")
    out.append(
        "Each row lists where the import actually is, so any line here can be "
        "checked in seconds.\n\n"
    )
    out.append("| Package | Files | First import at |\n|---|---:|---|\n")
    for package in model["externals"]:
        first = package["importers"][0]
        out.append(
            f"| `{package['id']}` | {len(package['importers'])} | `{first}` |\n"
        )
    return "".join(out)


def page_modules(model):
    outbound, inbound = am.adjacency(model)
    depth = am.depths(model)

    lines = [f"# Module index\n\n{provenance(model)}\n"]
    lines.append(
        "Every module, what it imports, and what imports it. This is the page "
        "to grep when a question names a file.\n\n"
    )
    for node in model["nodes"]:
        node_id = node["id"]
        lines.append(f"## `{node_id}`\n\n")
        depth_text = (
            f"{depth[node_id]} from an entry point"
            if node_id in depth else "not reachable from any entry point"
        )
        lines.append(
            f"{node['kind']} in `{node['area']}` · {node['loc']} lines · "
            f"depth {depth_text}\n\n"
        )
        if inbound[node_id]:
            lines.append("Imported by: " + ", ".join(
                f"`{n}`" for n in sorted(set(inbound[node_id]))) + "\n\n")
        if outbound[node_id]:
            lines.append("Imports: " + ", ".join(
                f"`{n}`" for n in sorted(set(outbound[node_id]))) + "\n\n")
    return "".join(lines)


def slug(area):
    return area.replace("/", "-").replace(".", "-") or "root"


def main():
    argv = sys.argv[1:]
    model_path = PROJECT / diagram.am_option(argv, "--model", "docs/atlas/model.json")
    docs = PROJECT / diagram.am_option(argv, "--docs", "docs")
    model = am.load(model_path)

    ref = docs / GENERATED
    ref.mkdir(parents=True, exist_ok=True)

    written = []

    def write(path, body):
        path.write_text(body)
        written.append(path.relative_to(PROJECT).as_posix())

    write(ref / "architecture.md", page_architecture(model))
    write(ref / "dependencies.md", page_dependencies(model))
    write(ref / "modules.md", page_modules(model))
    for area in am.areas_of(model):
        write(ref / f"area-{slug(area)}.md", page_area(model, area))

    if "--scaffold" in argv:
        config = PROJECT / "mkdocs.yml"
        if config.exists():
            print("mkdocs.yml exists — left alone")
        else:
            config.write_text(MKDOCS_YML.format(name=model["root"]))
            written.append("mkdocs.yml")
        index = docs / "index.md"
        if index.exists():
            print("docs/index.md exists — left alone")
        else:
            write(index, INDEX_STUB.format(name=model["root"]))

        # `mkdocs build` writes site/ next to the source it was built from, and a
        # committed build output diverges from the source it claims to render.
        # Appended rather than written, so an existing .gitignore survives.
        ignore = PROJECT / ".gitignore"
        existing = ignore.read_text() if ignore.is_file() else ""
        if "site/" not in existing:
            with ignore.open("a") as handle:
                if existing and not existing.endswith("\n"):
                    handle.write("\n")
                handle.write("\n# MkDocs build output\nsite/\n")
            print("  .gitignore — added site/")

    for path in written:
        print(f"  {path}")
    print(f"{plural(len(written), 'file')} written")
    print(f"everything atlas owns lives under "
          f"{(docs / ATLAS_ROOT).relative_to(PROJECT).as_posix()}/ — "
          "never edit it, rerun instead")
    if model.get("dirty"):
        print("model was built from a dirty tree, so provenance names a commit "
              "the pages do not exactly match")
    return 0


if __name__ == "__main__":
    sys.exit(main())
