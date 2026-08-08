# MkDocs, Material, and Mermaid — the verified contract

Everything here was checked against `mkdocs 1.6.1` + `mkdocs-material` and
`mermaid-cli 11.12.0`, by building a site and reading the resulting HTML in a
browser. Where a claim is about behaviour rather than configuration, the way it
was verified is stated, because the failures in this area are all silent — the
build succeeds and the page looks wrong.

## The minimum that makes a fence render

```yaml
markdown_extensions:
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
```

All four keys are load-bearing. Without the `custom_fences` entry a
` ```mermaid ` block renders as a **syntax-highlighted code block** — the build
succeeds, no warning is printed, and the page shows source instead of a diagram.
That is the single most common failure and it does not announce itself.

`!!python/name:` is a Python object reference, so `mkdocs.yml` must be loaded by
MkDocs itself. A YAML parser in strict safe-load mode rejects it; that is
expected and not a problem to fix.

## What Material actually does with the fence

Verified by building and inspecting the output:

- The fence becomes `<pre class="mermaid">` in the HTML.
- Material's own `bundle.*.min.js` **lazy-loads Mermaid from
  `https://unpkg.com/mermaid@11/dist/mermaid.min.js`** when it finds a `.mermaid`
  element. Mermaid is not vendored into the site.
- It then calls `mermaid.initialize` with theme variables derived from the
  **active palette**, and re-renders on a palette toggle.

Two consequences that matter:

**A page fence must carry no theme.** Material's injected variables and a
frontmatter `themeVariables` block both target the same thing; the baked one wins
for the properties it sets. The result is a diagram that stays dark when the
reader switches to the light scheme — invisible to whoever wrote the page, since
they only ever looked at one palette.

**The docs site needs network for diagrams to appear.** A fully offline reader
gets an empty block with no error in the console. If offline rendering is a
requirement, pre-render to `export` SVGs and use image links instead.

## Auto-theming covers five diagram types

Material derives theme variables for **flowchart, sequence, class, state, and
ER** diagrams.

**C4 diagrams are not auto-themed.** A `C4Context` block in a page fence renders
with Mermaid's own defaults, which will not match the surrounding page in either
palette. Put C4 in `export` and link the image, or style it explicitly.

`pie`, `gantt`, and `gitgraph` are unsupported by Material's theming and are
discouraged in a docs context anyway — all three degrade badly at narrow widths.

## Images and captions

```yaml
markdown_extensions:
  - attr_list          # {: .class } and width/height on an image
  - md_in_html         # Markdown inside <figure>, <div>
  - pymdownx.blocks.caption
```

`pymdownx.blocks.caption` turns

```
/// caption
The caption text.
///
```

into a real `<figcaption>` inside a `<figure>` — verified in the built HTML. This
matters more than it sounds: a caption is where a generated diagram states what
it omitted, and a paragraph of italics below an image is not associated with it
for a screen reader.

`glightbox` (via `mkdocs-glightbox`) adds click-to-zoom. Optional, and worth it
only for diagrams too dense to read inline — which is usually a signal to split
the diagram instead.

## The light/dark palette toggle

```yaml
theme:
  name: material
  palette:
    - media: "(prefers-color-scheme: light)"
      scheme: default
      toggle: { icon: material/brightness-7, name: Switch to dark mode }
    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      toggle: { icon: material/brightness-4, name: Switch to light mode }
```

`scheme: default` is light, `scheme: slate` is dark. The `media` keys make the
first visit follow the OS preference; the `toggle` blocks let a reader override
it. Both palettes must be present for Mermaid re-theming to be exercised at all,
which is why a single-palette site hides the baked-theme bug indefinitely.

## The `\n` label regression

**Mermaid 11 renders a literal `\n` in a node label as the two characters
backslash-n.**

Verified: `A["app.js\nEntry point"]` rendered through mermaid-cli 11.12.0
produces a `<p>` inside a `foreignObject` containing the literal text
`app.js\nEntry point`. Labels go through HTML by default, and HTML has no reason
to interpret a backslash escape.

Three things that do work:

| Form | Notes |
|---|---|
| `A["app.js<br/>Entry point"]` | What `diagram.py` emits. Simplest, works everywhere |
| Backtick-quoted multi-line strings | Requires `markdown` label support |
| `-c cfg.json` with `{"flowchart":{"htmlLabels":false}}` | Switches to SVG text; changes font metrics for the whole diagram |

This is a **regression against committed output**, not a hypothetical. Diagram
sources across this fleet use `\n`, while their committed `.svg` files contain
`<br />` and no literals — meaning those SVGs were produced by an older renderer
and each one regresses the next time it is rendered. `render.sh` refuses a `.mmd`
containing a literal `\n` for that reason: the failure is visible only in the
render, so the check has to happen before it.

## mermaid-cli behaviour worth knowing

Verified empirically against 11.12.0:

- **It rewrites Markdown input in place.** Given a `.md` file, it replaces every
  fence with `![diagram](./out-N.svg)` and saves over the original. Pointing it
  at a docs page destroys the page. `render.sh` only ever accepts `.mmd`.
- Exit code is 1 on a parse error, for `.mmd`, `.md`, and stdin alike — so it is
  safe to branch on.
- **Reported line numbers are relative to the diagram body**, not the file. With
  a frontmatter config block above, the number in the error is offset by the
  height of that block.
- `-s 2` doubles raster scale; `-b transparent` keeps alpha; `-b '#040714'`
  flattens onto a plate colour.
- `-c cfg.json` accepts a Mermaid config object, e.g.
  `{"flowchart":{"htmlLabels":false}}`.
- Roughly one second per diagram, dominated by browser startup.

## Why exports are flattened rather than transparent

`render.sh --png` composites onto the plate colour by default. An alpha PNG
placed in a slide deck, a Medium post, or a LinkedIn preview gets composited onto
**white** by the host, which turns light diagram text on a dark diagram into
light text on white — unreadable, and only discovered after publishing. Keep the
SVG for anywhere alpha is genuinely honoured.
