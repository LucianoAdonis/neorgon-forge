#!/usr/bin/env python3
"""Fail when this machine serves a stale second copy of a forge skill.

Every other check in this repo asks whether the REPO is right. This one asks
whether what the model actually reads is the repo, which is a different question
and the one that went wrong.

Found 2026-09-05: twelve skills were installed twice. Once as a symlink from
~/.claude/skills into this repo, and again from a plugin cache frozen at v1.9.0
while the repo was at v2.3.0. Both registered, under `name` and
`neorgon-forge:name`, so the model saw two entries per skill with different text.
Eleven of the twelve cached descriptions had drifted, and every drifted one still
carried the em dashes this repo banned and swept weeks earlier.

A description IS the routing decision. Editing it in the repo while a stale
duplicate is also loaded changes half of what the router reads, and every reach
number measured in that state is measured against a table that is not the repo.

Exit: 0 clean or nothing installed here, 1 a stale duplicate is live.
CI has no ~/.claude, so it degrades to a pass with a note.
"""
import json
import os
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
SRC = REPO / "plugins" / "neorgon-forge" / "skills"
# Overridable so the check is testable, and so a non-default CLAUDE_CONFIG_DIR works.
CACHE_ROOT = pathlib.Path(
    os.environ.get("NEORGON_PLUGIN_CACHE")
    or os.path.expanduser("~/.claude/plugins/cache/neorgon-forge")
)


def red(s):
    print(f"\033[31m{s}\033[0m")


def green(s):
    print(f"\033[32m{s}\033[0m")


def description(p):
    try:
        parts = p.read_text().split("---")
        if len(parts) < 3:
            return None
        m = re.search(r'^description:\s*"?(.*?)"?\s*$', parts[1], re.M | re.S)
        return re.sub(r"\s+", " ", m.group(1)) if m else None
    except OSError:
        return None


def main():
    if not CACHE_ROOT.exists():
        green("  no plugin cache on this machine: the symlinked repo is the only copy")
        return 0

    repo_desc = {}
    for d in SRC.glob("*/*"):
        if d.is_dir():
            repo_desc[d.name] = description(d / "SKILL.md")

    stale, matching, versions = [], [], set()
    for manifest in CACHE_ROOT.glob("*/*/.claude-plugin/plugin.json"):
        try:
            versions.add(json.loads(manifest.read_text()).get("version", "?"))
        except Exception:
            versions.add("?")
    for cached in CACHE_ROOT.glob("*/*/skills/*/SKILL.md"):
        name = cached.parent.name
        if name not in repo_desc:
            stale.append((name, "not in this repo at all"))
            continue
        if description(cached) != repo_desc[name]:
            stale.append((name, "description differs from the repo"))
        else:
            matching.append(name)

    if not stale:
        green(f"  plugin cache present and every cached description matches the repo "
              f"({len(matching)} skills)")
        return 0

    repo_version = "?"
    try:
        repo_version = json.loads(
            (REPO / "plugins" / "neorgon-forge" / ".claude-plugin" / "plugin.json").read_text()
        )["version"]
    except Exception:
        pass

    red(f"  {len(stale)} skill(s) are loaded twice, and the second copy is stale.")
    red(f"    cache version {', '.join(sorted(versions)) or '?'}  vs  repo version {repo_version}")
    for name, why in sorted(stale):
        red(f"    {name}: {why}")
    red("  A description is the whole routing decision, so the model is choosing between")
    red("  two entries per skill with different text. Editing this repo changes only one.")
    red("  Fix: push, then run `/plugin update neorgon-forge` in an interactive terminal.")
    red("  Or, if you develop this repo locally and do not want the plugin copy at all,")
    red("  remove the plugin install and keep the symlinks that bin/install.sh makes.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
