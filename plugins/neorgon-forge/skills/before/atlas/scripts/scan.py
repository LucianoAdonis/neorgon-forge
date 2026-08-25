#!/usr/bin/env python3
"""Build a dependency model of an application from its source.

Everything else in this skill reads the model this writes. Diagrams are
generated from it, questions are answered from it, and staleness is measured
against the commit it was built at. That indirection is the point: a diagram
drawn by hand is a second source of truth that goes stale silently, while a
diagram generated from a model goes stale loudly, because the model carries the
commit it was built from.

Every edge records the file and line the import was found on. A dependency claim
without a location is unverifiable, and the whole value of the model is that
each of its claims can be checked in seconds.

Anchored on the cwd: run it from the root of the project being mapped.

Usage:
  scan.py [--root .] [--out docs/atlas/model.json] [--areas-from .forge]
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

PROJECT = Path.cwd().resolve()

SKIP_DIRS = {
    ".git", "node_modules", "__pycache__", "dist", "build", ".next", "vendor",
    ".venv", "venv", "coverage", ".cache", "site", ".forge", "png",
}

JS_EXT = (".js", ".mjs", ".jsx", ".ts", ".tsx")
PY_EXT = (".py",)
HTML_EXT = (".html",)
CSS_EXT = (".css",)

# Import forms, in one pass per file. Regex rather than a parser because the
# model tolerates a missed exotic import far better than it tolerates a
# toolchain dependency per language, and a missed edge shows up as a node with
# no inbound arrows, which is visible.
#
# Horizontal whitespace only, never \s, before the keyword. An \s* that can
# cross newlines makes the match start on a blank line above the import, and the
# reported line number is then off by however many blank lines precede it, which
# quietly breaks the one property that makes an edge checkable.
# The named-import list may span lines, so that branch crosses newlines. It stays
# bounded by excluding quotes and semicolons, which stops it from running past
# the end of a real import into an unrelated `from '...'` further down the file.
JS_IMPORT = re.compile(
    r"""^[ \t]*(?:import|export)\b[^;'"]*?from[ \t]*['"]([^'"]+)['"]"""
    r"""|^[ \t]*import[ \t]*['"]([^'"]+)['"]"""
    r"""|\bimport[ \t]*\([ \t]*['"]([^'"]+)['"][ \t]*\)"""
    r"""|\brequire[ \t]*\([ \t]*['"]([^'"]+)['"][ \t]*\)""",
    re.M,
)
PY_IMPORT = re.compile(
    r"""^\s*(?:from\s+([.\w]+)\s+import\b|import\s+([\w.]+))""", re.M
)
# A static page's dependencies are the tags that pull a file in. This is what
# makes index.html an entry point in fact and not only in ENTRY_NAMES: without
# it, the file every one of these projects boots from has no outbound edges, and
# "distance from an entry point" is measured from whatever module happened to
# import nothing.
# A <link> is only a dependency for some rel values. `canonical`, `alternate`
# and `preconnect` name a URL the page talks *about* rather than one it loads,
# and treating those as edges puts the site's own public hostname in the model
# beside its npm packages.
HTML_IMPORT = re.compile(
    r"""<script\b[^>]*\bsrc[ \t]*=[ \t]*['"]([^'"]+)['"]"""
    r"""|<link\b(?=[^>]*\brel[ \t]*=[ \t]*['"](?:stylesheet|modulepreload|preload)['"])"""
    r"""[^>]*\bhref[ \t]*=[ \t]*['"]([^'"]+)['"]""",
    re.I,
)
# @import only. A url() points at a font or an image, which is an asset rather
# than a module, and modelling those buries the stylesheet graph in leaf nodes.
CSS_IMPORT = re.compile(
    r"""@import[ \t]+(?:url\([ \t]*)?['"]([^'"]+)['"]""", re.I
)

ENTRY_NAMES = {
    "app.js", "main.js", "index.js", "main.ts", "index.ts", "app.ts",
    "main.tsx", "index.tsx", "main.py", "app.py", "__main__.py", "manage.py",
    "index.html", "cli.py", "server.js", "worker.js",
}
STORE_HINTS = ("state", "store", "db", "database", "schema", "model", "storage")
CONFIG_HINTS = ("config", "settings", "constants", "tokens", "env")


def sh(*args):
    try:
        out = subprocess.run(
            args, cwd=PROJECT, capture_output=True, text=True, timeout=15
        )
        return out.stdout.strip() if out.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def walk(root: Path):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS and not d.startswith("."))
        for name in sorted(filenames):
            yield Path(dirpath) / name


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(PROJECT).as_posix()
    except ValueError:
        return path.as_posix()


def classify(path: str) -> str:
    """Kind drives the node shape, so the shape carries meaning without a legend."""
    name = path.rsplit("/", 1)[-1]
    stem = name.rsplit(".", 1)[0].lower()
    lowered = path.lower()
    if name in ENTRY_NAMES:
        return "entry"
    if path.endswith(CSS_EXT):
        return "style"
    if path.endswith(HTML_EXT):
        return "page"
    if "/data/" in lowered or lowered.endswith(".json"):
        return "data"
    if any(h in stem for h in STORE_HINTS):
        return "store"
    if any(h in stem for h in CONFIG_HINTS):
        return "config"
    if "test" in stem or "spec" in stem:
        return "test"
    return "module"


def js_resolve(spec: str, importer: Path):
    """Resolve a relative specifier to a real file, or report it as external.

    Extensionless and directory-index imports both resolve here, because a model
    that lists './utils' and './utils.js' as two different nodes shows an edge
    count that is simply wrong.
    """
    if not spec.startswith("."):
        parts = spec.split("/")
        pkg = "/".join(parts[:2]) if spec.startswith("@") else parts[0]
        return None, pkg
    base = (importer.parent / spec).resolve()
    candidates = [base]
    candidates += [base.with_suffix(ext) for ext in JS_EXT]
    candidates += [base / f"index{ext}" for ext in JS_EXT]
    for cand in candidates:
        if cand.is_file():
            return cand, None
    return None, None


def asset_resolve(spec: str, importer: Path):
    """Resolve an href/src/@import to a file in the project, or to a CDN host.

    A remote stylesheet is a real dependency and belongs in the model, but it is
    not a package: reporting `cdn.neorgon.org` under the same heading as an npm
    import would be wrong. It comes back as a host so the caller can decide.
    """
    if spec.startswith(("http://", "https://", "//")):
        host = spec.split("//", 1)[1].split("/", 1)[0]
        return None, host
    if spec.startswith(("data:", "#", "mailto:")):
        return None, None
    local = spec.split("?", 1)[0].split("#", 1)[0]
    if not local:
        return None, None
    base = PROJECT if local.startswith("/") else importer.parent
    target = (base / local.lstrip("/")).resolve()
    return (target, None) if target.is_file() else (None, None)


def py_resolve(spec: str, importer: Path, roots):
    if spec.startswith("."):
        depth = len(spec) - len(spec.lstrip("."))
        tail = spec[depth:].replace(".", "/")
        base = importer.parent
        for _ in range(depth - 1):
            base = base.parent
        target = (base / tail) if tail else base
        for cand in (target.with_suffix(".py"), target / "__init__.py"):
            if cand.is_file():
                return cand, None
        return None, None
    head = spec.split(".")[0]
    for root in roots:
        for cand in (root / f"{head}.py", root / head / "__init__.py"):
            if cand.is_file():
                return cand, None
    if head in sys.stdlib_module_names:
        return None, None
    return None, head


def line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def read_areas(forge_dir: Path):
    """Reuse wayfind's areas when they exist.

    An area named by the person who works here beats one derived from the
    directory tree, and re-deriving it would produce a second, differently-named
    set of the same regions.
    """
    tsv = forge_dir / "map-areas.tsv"
    if not tsv.is_file():
        return None
    areas = []
    for line in tsv.read_text().splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            areas.append({
                "name": parts[0],
                "paths": [p.strip() for p in parts[1].split(",") if p.strip()],
                "note": parts[2] if len(parts) > 2 else "",
            })
    return areas or None


def area_of(path: str, areas) -> str:
    if areas:
        for area in areas:
            for prefix in area["paths"]:
                prefix = prefix.rstrip("/")
                if path == prefix or path.startswith(prefix + "/"):
                    return area["name"]
        return "unassigned"
    # The containing directory, not the top-level one. Most of these projects put
    # every module under js/, so grouping by first segment yields a single area and
    # an area diagram with one box in it: technically correct and worth nothing.
    parent = path.rsplit("/", 1)[0] if "/" in path else "root"
    return parent


def plural(count, noun):
    return f"{count} {noun}" if count == 1 else f"{count} {noun}s"


def option(argv, flag, default):
    if flag in argv:
        index = argv.index(flag) + 1
        if index < len(argv):
            return argv[index]
    return default


def main():
    argv = sys.argv[1:]
    out_path = PROJECT / option(argv, "--out", "docs/atlas/model.json")
    forge_dir = PROJECT / option(argv, "--areas-from", ".forge")

    areas = read_areas(forge_dir)
    scanned = JS_EXT + PY_EXT + HTML_EXT + CSS_EXT
    sources = [p for p in walk(PROJECT) if p.suffix in scanned]
    if not sources:
        print("no sources found under the cwd", file=sys.stderr)
        print("atlas scans .js/.mjs/.jsx/.ts/.tsx/.py/.html/.css, for anything "
              "else, model it by hand", file=sys.stderr)
        return 1

    py_roots = sorted({p.parent for p in sources if p.suffix in PY_EXT} | {PROJECT})
    known = {rel(p) for p in sources}

    nodes, edges, externals = {}, [], {}

    for path in sources:
        key = rel(path)
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        nodes[key] = {
            "id": key,
            "kind": classify(key),
            "area": area_of(key, areas),
            "loc": text.count("\n") + 1,
        }

    for path in sources:
        key = rel(path)
        text = path.read_text(encoding="utf-8", errors="replace")
        if path.suffix in JS_EXT:
            pattern = JS_IMPORT
        elif path.suffix in PY_EXT:
            pattern = PY_IMPORT
        elif path.suffix in HTML_EXT:
            pattern = HTML_IMPORT
        else:
            pattern = CSS_IMPORT
        for match in pattern.finditer(text):
            spec = next((g for g in match.groups() if g), None)
            if not spec:
                continue
            line = line_of(text, match.start())
            if path.suffix in JS_EXT:
                target, package = js_resolve(spec, path)
            elif path.suffix in PY_EXT:
                target, package = py_resolve(spec, path, py_roots)
            else:
                target, package = asset_resolve(spec, path)

            if target is not None:
                dest = rel(target)
                if dest in known and dest != key:
                    edges.append({"from": key, "to": dest, "at": f"{key}:{line}"})
            elif package:
                externals.setdefault(package, {"id": package, "importers": []})
                externals[package]["importers"].append(f"{key}:{line}")

    # Deduplicate: two imports of the same module are one dependency, and
    # counting them twice inflates every "most depended on" answer.
    seen, unique = set(), []
    for edge in edges:
        pair = (edge["from"], edge["to"])
        if pair not in seen:
            seen.add(pair)
            unique.append(edge)

    model = {
        "generated_by": "atlas/scan.py",
        "root": PROJECT.name,
        "commit": sh("git", "rev-parse", "HEAD") or None,
        "commit_short": sh("git", "rev-parse", "--short", "HEAD") or None,
        "dirty": bool(sh("git", "status", "--porcelain")),
        "areas": areas or sorted({n["area"] for n in nodes.values()}),
        "areas_from": "wayfind" if areas else "directory tree",
        "nodes": sorted(nodes.values(), key=lambda n: n["id"]),
        "edges": sorted(unique, key=lambda e: (e["from"], e["to"])),
        "externals": sorted(externals.values(), key=lambda e: -len(e["importers"])),
    }

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(model, indent=2) + "\n")

    print(f"model written to {rel(out_path)}")
    print(f"  {plural(len(model['nodes']), 'module')}, "
          f"{plural(len(model['edges']), 'internal edge')}, "
          f"{plural(len(model['externals']), 'external package')}")
    print(f"  areas from {model['areas_from']}: "
          f"{', '.join(a['name'] if isinstance(a, dict) else a for a in model['areas'])}")
    if model["dirty"]:
        print("  working tree is dirty: the model describes the files on disk, "
              "not the commit")
    if not model["commit"]:
        print("  no git commit: staleness cannot be measured without one")
    return 0


if __name__ == "__main__":
    sys.exit(main())
