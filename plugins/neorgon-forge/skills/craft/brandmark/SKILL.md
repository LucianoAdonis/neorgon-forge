---
name: brandmark
description: "Use when a UI needs recognizable company or service logos: brand icons on rows and cards, services grouped by brand, a favicon column, 'show the GitHub/Google/Stripe logo next to each entry'. Triggers on: 'add brand icons', 'company favicons', 'service logos', 'represent these by brand', 'what site has all the company icons'. Knows the go-to sources (Simple Icons CDN for vendored SVGs, Google s2 and DuckDuckGo ip3 for live favicons), the privacy rule that decides between them, the vendoring recipe with validation, and the three-tier render pattern (vendored SVG, letter badge, opt-in remote) with the dark-background chip trick. Reference implementation: echeance-site js/brand.js. Not for generating a site's own favicon from an image (use favicon), not for drawing an original character (use mascot-forge)."
argument-hint: "[vendor <outdir> <slug...> | plan]"
user-invocable: true
license: MIT
---

# brandmark: company logos in a UI, without leaking who uses them

The question is never "where do I get the icons": three sources below cover
every company that matters. The question is the second one nobody asks:
**does fetching this icon tell a third party what the visitor is looking at?**
A list of services annotated with live-fetched favicons broadcasts that list,
one HTTP request per row, to whoever serves the icons. For a public catalog
that is nothing; for an inventory of the visitor's own credentials, accounts
or tools it is a disclosure the page's privacy copy probably forbids.

## The sources

| Source | Form | Coverage | Network |
|---|---|---|---|
| Simple Icons CDN: `https://cdn.simpleicons.org/<slug>` | brand-colored SVG | ~3000 tech brands, CC0 | build-time only (vendor it) |
| Google s2: `https://www.google.com/s2/favicons?domain=<d>&sz=64` | real favicon PNG | any domain | per pageview, per row |
| DuckDuckGo: `https://icons.duckduckgo.com/ip3/<d>.ico` | real favicon | any domain | per pageview, per row |

**Known Simple Icons gaps** (trademark removals, checked 2026-08-29): AWS,
Slack, OpenAI, Twitter/X. Plan a fallback before assuming a slug exists.

## The decision

- Data that names things the **visitor** holds (credentials, subscriptions,
  accounts): vendor locally, letter-badge the gaps, make remote lookup an
  explicit default-off toggle. Say what the toggle does where the user flips it.
- Data that is **the site's own** (a public catalog, a blog roll): hotlink s2
  freely; it discloses nothing the page does not already show.

## Vendoring recipe

```bash
bash "$FORGE/skills/craft/brandmark/scripts/vendor.sh" assets/brands \
    google github stripe cloudflare postgresql namecheap steam
```

The script curls each slug, keeps only responses that are actually SVG, and
reports misses instead of writing HTML error pages with an .svg name. Commit
the output; ~1 to 3 KB per icon. License is CC0, no attribution owed, but the
marks themselves are trademarks: use them to *identify* the brand, nothing else.

## The three-tier render

1. **Vendored SVG** by normalized service name via a slug map.
2. **Letter badge**: first letter on a chip whose hue is a hash of the name,
   so the same service always wears the same color.
3. **Opt-in remote favicon** for unmatched services, keyed on an explicit
   `domain` field first and a URL's hostname second, only when the visitor
   enabled it.

Two rendering traps, both learned the hard way:

- **Dark backgrounds eat dark marks.** GitHub's mark is near-black. Do not
  fetch white variants per-brand; put every icon on a small light chip
  (`background: rgba(255,255,255,.92)`, radius 5-6px) and all brand colors
  work everywhere.
- **The letter tier must be deterministic.** Hash the service name into a hue;
  random colors re-roll on every render and read as flicker.

Reference implementation with all three tiers, the toggle, and the chip CSS:
`projects/echeance-site/js/brand.js` plus the `.brand-badge` block in its
`css/style.css`.

## Invariants

- **Local first.** Data naming what the visitor holds never triggers per-row remote
  fetches by default; the remote tier is a visible, default-off choice.
- **Validate every vendored file.** A CDN error page saved under an .svg name is a
  silent broken square; keep only responses that are actually SVG.
- **Deterministic fallbacks.** The letter badge hashes the service name into its hue,
  so the same service wears the same color on every render.
- **Marks identify, never decorate.** The SVG collection is CC0; the marks are still
  trademarks.
