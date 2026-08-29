# brandmark

Company and service logos in a UI, sourced without leaking who uses them.

## What it does

`brandmark` knows the three icon sources (Simple Icons CDN for vendored SVGs, Google s2 and
DuckDuckGo ip3 for live favicons), the trademark gaps in the vendored set (AWS, Slack,
OpenAI), and the render pattern that survives contact with a dark theme: vendored SVG,
then a deterministic letter badge, then an opt-in remote favicon tier.

The defining constraint is privacy: live favicon lookups broadcast the annotated list, one
request per row, to whoever serves the icons. Data naming things the visitor holds gets
vendored icons and a default-off remote toggle; data the site already publishes can hotlink
freely.

## When to reach for it

Type `/brandmark`, or the agent reaches for it when a table, board or list should show which
company each entry belongs to, or entries should group by brand.

## What it leaves behind

Vendored SVGs from `scripts/vendor.sh` (validated as actual SVG, misses reported by name),
and a slug map plus badge renderer in the site's own code. The reference implementation is
`projects/echeance-site/js/brand.js`.
