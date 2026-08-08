"""Read API keys from the environment, falling back to the nearest .env.

Kept separate so the scripts never inline a key and never print one.

The .env search walks up from the cwd only, and stops at the first .git it
meets. Searching up from this file would look inside the skill install instead of
the project being worked on, and would find nothing.
"""

import os
import sys
from pathlib import Path


def _nearest_env():
    start = Path.cwd().resolve()
    for directory in [start, *start.parents]:
        candidate = directory / ".env"
        if candidate.exists():
            return candidate
        if (directory / ".git").exists():
            break
    return None


def read_key(*names):
    """First of `names` that is set.

    Lets a script accept a generic key or a project-specific one without the
    caller caring which exists.
    """
    for name in names:
        value = os.environ.get(name)
        if value:
            return value.strip()

    env_file = _nearest_env()
    if env_file:
        for line in env_file.read_text().splitlines():
            key, _, raw = line.partition("=")
            if key.strip() in names:
                return raw.strip().strip("'\"")

    sys.exit(f"none of {', '.join(names)} found in the environment or .env")
