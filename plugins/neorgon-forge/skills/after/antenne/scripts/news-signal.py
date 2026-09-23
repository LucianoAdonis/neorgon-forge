#!/usr/bin/env python3
"""Narrow a session's commits to the ones that could be news, and read the one
registry field that decides how a story may speak about the site.

Why the skill needs it: what counts as news is a judgement, but the git plumbing
under it is not, and the lifecycle must never be recalled from memory. Rule 3 of
the newsroom rules turns on a single field, and a site announced as open when the
registry says otherwise is a public lie on a public feed. Re-deriving the same
log and the same lookup by hand each run gets both subtly different every time.

This narrows, it never decides. A candidate here is a commit whose diff is worth
reading; the diff is the only evidence a story may rest on.

  python3 news-signal.py <repo-dir> <since-date> [--root <monorepo-root>]

The name is load-bearing. This file was `signal.py`, which sits on top of the
stdlib `signal` module: running it puts its own directory first on sys.path, so
`import subprocess` here resolved `signal` to this file. subprocess only finds
out at the moment it kills a timed-out child, where `signal.SIGKILL` raises
AttributeError, which is neither OSError nor SubprocessError and so escapes the
one guard git() has. A slow git turned a one-sentence stop into a traceback. The
hyphen makes the collision impossible: `news-signal` is not an importable name.

Exit 0 when it ran, 2 when the repo, the date or the root cannot be used, 3 when
the repo is a source the rules forbid, and 4 when the repo is outside the fleet's
scope. On 3 and 4 nothing further is gathered, here or in the caller.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True

# Rule 1 of the newsroom rules: employer and private context that must never
# reach a public feed. Matched on path components, so "site-metrics" is not one.
forbidden = ("o11y-harness", "metrics", "cartograph-site")
# Kept out of Claude's scope by the monorepo's .claudeignore; their lifecycle
# flips are named in the rules as not news.
out_of_scope = ("assistant", "fine-loop")
# Copied from scripts/fleet.sh's --foreign filter: a clone whose origin is not
# one of the owner's accounts is somebody else's work, never fleet news.
owned = re.compile(r"^(https://|git@|ssh://git@)github\.com[:/](energon-a-secas|LucianoAdonis)/", re.I)

# Conventional-commit types, mapped to the story kinds the rules allow.
news_types = {"feat": "feature", "fix": "fix", "perf": "feature"}
quiet_types = {"chore", "docs", "doc", "refactor", "style", "test", "tests",
               "build", "ci", "revert", "wip"}
# Deliberately narrow. "publish" is Antenne's own mechanism word and appears in
# commits that ship nothing to a reader, so it is not here: a false launch is a
# worse signal than a missed one, because a launch story is the loudest kind.
launch_words = re.compile(
    r"\b(launch(?:es|ed)?|goes live|now live|is live|ship(?:s|ped)|"
    r"release[ds]|opens to|first release)\b", re.I)
# Words that mark mechanical work even under a news-shaped type: a kit sync, a
# rename, a regeneration. These describe the fleet moving, not a reader gaining
# anything.
quiet_words = re.compile(
    r"\b(sync(?:s|ed)?|vendor(?:s|ed)?|bump(?:s|ed)?|dep(?:s|endencies)|lockfile|"
    r"typo|whitespace|format(?:ting)?|lint|regenerate[ds]?|re-?generate|"
    r"rename[ds]?|move[ds]?|extract(?:s|ed)?|tidy|cleanup|clean up)\b", re.I)
# A change confined to these paths gained a reader nothing.
quiet_paths = re.compile(r"^(docs/|\.claude/|\.forge/|\.github/|[^/]*\.md$|.*\.lock$|"
                         r"CLAUDE\.md$|README\.md$)")
git_timeout_s = 20
max_commits = 60
max_files = 40


def say(message):
    print(f"news-signal: {message}", file=sys.stderr)


def head(title):
    print(f"\n\033[1m== {title}\033[0m")


def git(repo, *args):
    """Text of a git command in repo, or None when git failed."""
    try:
        done = subprocess.run(("git", "-C", str(repo)) + args, stdin=subprocess.DEVNULL,
                              capture_output=True, text=True, timeout=git_timeout_s,
                              env=dict(os.environ, GIT_OPTIONAL_LOCKS="0"))
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout if done.returncode == 0 else None


def parse_subject(subject):
    """(type, scope, rest) of a conventional-commit subject; type is None without one."""
    match = re.match(r"^([a-z]+)(?:\(([^)]*)\))?!?:\s*(.*)$", subject.strip())
    if not match:
        return None, None, subject.strip()
    return match.group(1), match.group(2), match.group(3)


def classify(subject):
    """(lane, kind, why) for one commit subject. Lanes: candidate, quiet, unclear."""
    kind_word, scope, rest = parse_subject(subject)
    scope_and_rest = f"{scope or ''} {rest}"
    if kind_word in quiet_types:
        return "quiet", None, f"{kind_word} is not a kind a reader gains anything from"
    if kind_word in news_types:
        if quiet_words.search(scope_and_rest):
            return "quiet", None, "reads as mechanical work under a news-shaped type"
        kind = "launch" if launch_words.search(rest) else news_types[kind_word]
        return "candidate", kind, f"{kind_word} that a reader could notice"
    if kind_word:
        return "unclear", None, f"type '{kind_word}' is not one the rules map to a kind"
    if launch_words.search(rest):
        return "candidate", "launch", "no type, but the subject claims something went live"
    if quiet_words.search(rest):
        return "quiet", None, "no type, and the subject reads as mechanical work"
    return "unclear", None, "no type: read the diff and decide"


def components(path):
    return [part for part in Path(path).resolve().parts]


def forbidden_source(top):
    for part in components(top):
        if part in forbidden:
            return part
    return None


def find_root(start, given):
    """The monorepo root: the given one, else the nearest parent holding PROJECTS.md."""
    if given:
        root = Path(given).resolve()
        return root if (root / "PROJECTS.md").is_file() else None
    here = Path(start).resolve()
    for candidate in [here] + list(here.parents):
        if (candidate / "PROJECTS.md").is_file() and (candidate / "scripts").is_dir():
            return candidate
    return None


def registry_entry(root, project_id, top):
    """The site's registry row, or None. Matched by folder first, then by id."""
    if not root:
        return None
    path = root / "docs" / "site-registry.json"
    try:
        sites = json.loads(path.read_text(encoding="utf-8")).get("sites") or []
    except (OSError, UnicodeDecodeError, ValueError):
        return None
    try:
        folder = str(Path(top).resolve().relative_to(root))
    except ValueError:
        folder = None
    for site in sites:
        if isinstance(site, dict) and folder and site.get("folder") == folder:
            return site
    for site in sites:
        if isinstance(site, dict) and site.get("id") == project_id:
            return site
    return None


def report_signal(repo, since):
    """Print the narrowed commit list. Returns the number of candidates."""
    head("Signal: what could be news, narrowed and not decided")
    log = git(repo, "log", f"--since={since}", "--date=short",
              f"--max-count={max_commits}", "--pretty=%h\t%ad\t%s")
    if log is None:
        print("  (no git log here: not a work tree, or git refused)")
        return 0
    rows = [line for line in log.splitlines() if line.strip()]
    if not rows:
        print(f"  no commits since {since}.")
        print("  verdict: nothing landed in this window. Say so and stop.")
        return 0
    counts = {"candidate": 0, "quiet": 0, "unclear": 0}
    for row in rows:
        parts = row.split("\t", 2)
        if len(parts) != 3:
            continue
        sha, when, subject = parts
        lane, kind, why = classify(subject)
        counts[lane] += 1
        label = f"{lane}{'/' + kind if kind else ''}"
        print(f"  {label:<18} {sha} {when}  {subject[:88]}")
        print(f"  {'':<18} {why}")
    total = sum(counts.values())
    print(f"\n  {total} commits: {counts['candidate']} candidate, "
          f"{counts['quiet']} not news, {counts['unclear']} unclear")
    if counts["candidate"] or counts["unclear"]:
        print("  verdict: read the diff of each candidate and unclear commit before writing.")
    else:
        print("  verdict: nothing here looks like news. Say so and stop, do not submit filler.")
    return counts["candidate"]


def report_files(repo, since):
    head("Files the window touched")
    names = git(repo, "log", f"--since={since}", "--name-only", "--pretty=format:")
    touched = sorted({line.strip() for line in (names or "").splitlines() if line.strip()})
    dirty = git(repo, "status", "--porcelain")
    pending = sorted({line[3:].strip() for line in (dirty or "").splitlines() if len(line) > 3})
    if not touched and not pending:
        print("  (nothing committed in the window and nothing uncommitted)")
        return
    for name in touched[:max_files]:
        print(f"  committed    {name}")
    if len(touched) > max_files:
        print(f"  ... and {len(touched) - max_files} more committed files")
    for name in pending[:max_files]:
        print(f"  uncommitted  {name}")
    everything = touched + pending
    if everything and all(quiet_paths.match(name) for name in everything):
        print("\n  every changed path is docs, config or notes: that is not news by itself.")


def report_registry(root, project_id, top):
    head(f"Registry entry for {project_id}")
    site = registry_entry(root, project_id, top)
    if site is None:
        print("  no registry row for this repo.")
        print("  so: no link, and do not describe it as a fleet site.")
        return
    lifecycle = site.get("lifecycle")
    print(f"  id          {site.get('id')}")
    print(f"  name        {site.get('display_name')}")
    print(f"  lifecycle   {lifecycle}")
    print(f"  domain      {site.get('domain')}")
    print(f"  description {str(site.get('description') or '')[:100]}")
    repo_url = site.get("repo")
    if repo_url and not owned.search(repo_url):
        print("  FOREIGN: this clone's origin is not one of the owner's accounts.")
        print("  so: somebody else's work. It is not fleet news.")
        return
    if lifecycle == "live" and site.get("live_url"):
        print(f"  so: live, and the one link a story may carry is {site.get('live_url')}")
    elif lifecycle == "ready":
        print("  so: a domain is reserved and nothing is served. Coming-soon phrasing, no link.")
    else:
        print(f"  so: lifecycle is {lifecycle}, not live. No link, and never call it open.")


def out_of_scope_source(top):
    for part in components(top):
        if part in out_of_scope:
            return part
    return None


def main(argv):
    # Walked once, left to right, rather than filtered. Filtering out every
    # positional equal to the --root value also ate a repo argument that
    # happened to be the root, which is the monorepo itself: work lands there
    # too, and the usage error it produced blamed the caller for a collision
    # inside this function.
    args = []
    given_root = None
    index = 0
    while index < len(argv):
        token = argv[index]
        if token == "--root":
            if index + 1 >= len(argv):
                say("--root needs a directory")
                return 2
            given_root = argv[index + 1]
            index += 2
            continue
        if token.startswith("--"):
            say(f"unknown option: {token}")
            return 2
        args.append(token)
        index += 1
    if len(args) != 2:
        say("usage: news-signal.py <repo-dir> <since-date> [--root <monorepo-root>]")
        return 2
    repo, since = args
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", since):
        say(f"since must be YYYY-MM-DD, not {since!r}")
        return 2
    top = git(repo, "rev-parse", "--show-toplevel")
    if not top:
        say(f"{repo} is not a git work tree, so there is no diff to read")
        return 2
    top = top.strip()
    blocked = forbidden_source(top)
    if blocked:
        say(f"refused: {blocked} is a source the rules forbid, so nothing here is gathered "
            f"and no story may mention it")
        return 3
    project_id = Path(top).name
    root = find_root(top, given_root)
    head("Where this runs")
    print(f"  repo        {top}")
    print(f"  project     {project_id}")
    print(f"  monorepo    {root if root else 'not found: outside the monorepo, registry unread'}")
    print(f"  window      since {since}")
    # Out of scope ends the whole collection, the way a forbidden source does.
    # Narrowing alone used to stop here while the caller carried on to read the
    # brief, the feed and the desk queue for a repo whose work can never be a
    # story: the verdict was already in, so everything after it was cost.
    outside = out_of_scope_source(top)
    if outside:
        head("Scope")
        print(f"  {outside} is outside the fleet's scope: its work is not news.")
        print("  nothing further is gathered here. Say so and stop.")
        return 4
    report_signal(repo, since)
    report_files(repo, since)
    report_registry(root, project_id, top)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
