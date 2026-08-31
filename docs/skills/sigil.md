# sigil

A Neorgon site's own mark: the 24x24 card glyph, the accent colour, and the generated
favicon set.

## What it does

A tool's mark lives in two places that must not disagree, the card on the hub and the
favicon in the tab. `sigil` treats them as one object: you author the glyph and choose the
accent, and the favicon set is generated from the card itself, so there is no second copy
to drift.

Its real content is the part no README can hold, which is **which drawing to choose**. A
favicon is decided at 16 pixels, and every icon that looks right at 96 and dies at 16 fails
for the same reason: too much ink in too little space. The skill carries the measured
thresholds that separate the two, so the judgement is a number rather than an argument:
ink above 55% of the glyph's own bounding box reads heavy at any size, and zero enclosed
counters at 16px means the drawing has closed into a blob, unless it is open by
construction.

## When to reach for it

Type `/sigil`, or it is reached for by `/new-project` and `/add-to-hub` so a site is never
born without a mark. Also when an existing icon reads wrong in a tab, or a card's accent
changes and the tab stops matching the catalog.

## What it leaves behind

A linted glyph in the hub's icon folder, a card that references it, and six generated files
per site (`favicon.svg`, `favicon.ico`, `apple-touch-icon.png`, two maskable PNGs and
`site.webmanifest`) with every top-level page wired. The standard itself lives in
`packages/neorgon-ui/favicon/`, and `sync-favicon.sh --check` is what keeps a site's icon
and its hub card from disagreeing afterwards.

## What it does not decide

The stroke weight, the hexagon, the spark and the insets are the standard, measured once;
a per-site exception is how a fleet stops being one. Whether a dense glyph is acceptable is
a person's call, so the audit reports and never fails a build. And sweeping many sites that
already have marks is a loop over `sync-favicon.sh`, not a skill.
