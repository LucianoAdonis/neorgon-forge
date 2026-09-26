# Neorgon overlay: callsign

Read this only inside the Neorgon monorepo, detected by a `PROJECTS.md` in the
working directory or a parent. Nothing here applies anywhere else.

## Subdomain candidates for /new-project

`/new-project` Step 1 may offer a Callsign codename next to the brand names. A
designation never becomes a folder or a subdomain: it holds spaces, colons,
slashes and hyphens, and the fleet's subdomains have none. What can:

1. Forge with `--slot core --count 3 --json` on the project's one-line description.
2. Take `acronyms.three` and `acronyms.four`, lowercased. They are plain letters by
   construction; drop anything that is not `[a-z]{3,4}` anyway.
3. Drop any already taken as a subdomain or a folder, from the monorepo root:

   ```bash
   python3 -c 'import json,sys; s=json.load(open("docs/site-registry.json"))["sites"]; used={(x.get("domain") or "").split(".")[0] for x in s}|{x["id"].removesuffix("-site") for x in s}; print(" ".join(c for c in sys.argv[1:] if c not in used) or "none free")' rad radm
   ```

4. Offer the survivors beside the brand-name candidates, never instead of them.
   A three-letter subdomain is short and opaque, so say what it reads as.
