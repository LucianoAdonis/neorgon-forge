---
name: mascot-forge
description: "Use for an illustrated character, mascot, or avatar — generated, cut out, and brought to life on a page. Triggers on: 'make a mascot', 'animate this character', 'generate a character for the site', 'add expressions to the mascot', 'give her different outfits', 'costume variants', 'add jiggle physics', 'make the mascot react to clicks', 'use my mascot for the favicon and logo'. Creates the art with the Gemini image API, then handles the parts that actually fail: keeping a character on-model across many frames, expression variants (blink, talk, surprise), seasonal outfits, background removal that survives a dark page, frame alignment that stops cross-fades jumping, and a click-reaction rig. Use it to draw the character; once the art exists, resizing it into icon files is the favicon skill's job. Not for photo editing, not for 3D (use 3d-web-experience), not for video."
argument-hint: "[design|frames|outfits|rig|preview]"
user-invocable: true
license: MIT
---

# mascot-forge — generate a character, then make it alive

Two halves that fail in different ways. **Generation** fails by drifting: the same
character comes back a little different every time, and a set of frames that drift
cannot be layered. **Animation** fails by looking pasted-on: a cut-out that ends on a
hard edge, motion that loops visibly, a rig with no weight.

Everything here exists because one of those bit.

## Pipeline

```bash
MF="$FORGE/skills/mascot-forge"

# 1. art
python3 "$MF/scripts/generate.py" --prompt-file "$MF/reference/prompts/base-a-standing.txt" \
    --ref path/to/reference.png --aspect 3:4 --count 3 --out .forge/mascot/base

# 2. cut out, align, export
python3 "$MF/scripts/prep-frames.py" --remove-bg idle=tmp/base-01.png blink=tmp/blink.png

# 3. prove the set is consistent — exits non-zero if it is not
python3 "$MF/scripts/verify-frames.py"

# 4. see it move
python3 "$MF/scripts/build-preview.py" && open images/mascot/preview.html
```

Run them from the target project's root — they write relative to the cwd, not to the
skill. They need `GEMINI_API_KEY` and, for `--remove-bg`, `REMOVE_BG_API_KEY`, taken from
the environment or the nearest `.env` searched upward to the repo boundary. Keys are never
printed, and `keys.py` is the only place that reads them.

Where output lands, by lifetime: served frames and the preview in `images/mascot/`
(shipped); full-resolution masters in `scripts/mascot/masters/` (committed, never served —
the one argued exception to the three output roots, see the forge's `docs/authoring.md`);
raw generations and the remove.bg response cache under `.forge/` (ephemeral, safe to
delete).

Image models are **paid-tier only**: the Gemini free tier reports `limit: 0` for
every one of them. If every model returns 429 including text, the project is out of
credit rather than the key being wrong. The API validates the request body before it
checks quota, so a 429 at least means the call was well formed.

---

## Step 1 — Design the character

Generate 3–4 *directions*, not 3–4 variations of one direction. Vary the axes that
change the answer — pose, silhouette, wardrobe — and keep everything else fixed.
Judge them **on the background they will actually sit on**, at the size they will
actually be. A palette that sings on white can dissolve into a dark page.

Two failure modes worth checking for explicitly:

- **Competing with the UI.** A character wearing the site's accent colour steals
  attention from the primary button. Check them side by side before committing.
- **Losing the silhouette.** A dark outfit on a dark page leaves a floating head.

### Framing decides whether expressions are possible

A full-body figure at 7.5 heads tall has a face about a third the size of a chibi's
at the same on-screen height. At a 300px hero width that is a ~30px head, and a blink
will not read at all.

**If the character needs expressions, frame waist-up.** Keep a full-body render as a
separate asset for larger placements. This is not a crop preference; it decides
whether half the work is visible.

---

## Step 2 — Hold the character on-model

`--ref` is repeatable and is the whole game. Pass the approved base frame into every
subsequent generation.

### Changing the face

Name the one thing that changes, then pin everything else:

> Using this image as the exact reference, change ONLY **&lt;the change&gt;**. Keep
> everything else pixel-identical: same pose, same body position, same arm placement,
> same hair shape, same clothing, same scale, same framing, same position on the
> canvas. Same illustration style, same outlines, same flat shading, identical
> colour palette.

### Changing the style

The opposite framing, and it is counter-intuitive. Calling the reference an "exact
character sheet" and asking to "change only the rendering style" reads as *keep it
similar* — it returns near-copies. Demote the reference first:

> Use the reference image only for WHO she is and how she is posed. Now REDRAW her
> completely as **&lt;style&gt;**. Do not imitate the reference's rendering — replace
> it entirely.

Then give concrete limits: a colour count, an outline weight, "legible at 32px".

### Restate identity in every prompt

A style prompt that does not defend the character's identity will lose it. A flat
vector pass flattened a character's amber irises to solid black purely because
nothing in that prompt mentioned eyes. **Anything that makes the character
recognisable — eye colour, a ribbon, glasses — must be named in every prompt**, not
just the base one.

### Keep every frame at one aspect ratio

Changing the aspect to make room for something changes the framing *and* the figure
scale. Alignment can fix translation; it cannot fix scale. See `reference/prompts/`
for working examples of all three prompt shapes.

---

## Step 3 — Cut out and align

`prep-frames.py` takes `name=path` pairs. For each render it:

- **Detects the background.** Renders arrive either already cut out or flat on white;
  both are handled.
- **Keys white by connectivity, not colour.** Only white connected to the border is
  background, so a white collar, teeth and eye highlights survive. Boundary pixels get
  a feathered alpha and their colour is un-blended from the white, so edges do not
  glow on a dark page.
- **Splits detached islands** — floating hearts, sparkles, a sweat drop — into
  `<name>-extras.png`, so they can animate on their own.
- **Pads mixed sizes** onto one canvas, anchored on each frame's own content.
- **Aligns**, then crops everything to one shared canvas and exports PNG + WebP.

### The two alignment traps

**Sealed background pockets.** A flood fill from the border cannot enter background
the art closes off — between a hair strand and a jaw, say. It stays opaque and shows
as a white patch. `--remove-bg` asks remove.bg for a subject mask and feeds the
unreachable pockets back in.

That integration is built to never spend a paid credit: the model returns a coarse
0.25MP *region* verdict on the free tier, while the local keyer still does every edge
at full resolution. The model only gets a vote on pixels that are **already
background-coloured**, and a region must survive a 3px erosion, so a bad mask cannot
eat hair — the worst case is a pocket it misses. Responses cache by content hash.

**Matching on the wrong thing.** Expression frames change only the face, so the still
lower body is the signal. Outfit frames change the whole garment, so the unchanged
face is. The aligner scores both bands and takes the better match, which identifies
the kind of frame for free — the log says which band won. A residual above ~4.5%
after aligning means the frame is drawn at a different **scale**, which no amount of
translation fixes. Regenerate it.

### When alignment cannot help

Alignment needs something unchanged to match on. A frame that changes the pose
*and* the clothing offers nothing — the body differs and limbs move into rows the
reference leaves empty — and the search will confidently return a wrong answer.
Pin it and trust the padding, which is exact when the render was told to hold its
scale and head position:

```bash
python3 scripts/prep-frames.py --remove-bg --pin=outfit-bikini idle=... outfit-bikini=...
```

`--search=N` widens the window instead, for a frame that is merely displaced
rather than unmatchable. Cost is quadratic, so it stays opt-in.

Verify alignment by a landmark rather than by eye: every frame's crown row should
match, bar deliberate exceptions like headwear.

Three bugs worth not rediscovering, all fixed in the shipped script:

- **Padding can break frames that were already aligned.** Anchoring each frame on
  its own content is right for mixed-size sources and wrong for re-prepping an
  existing set — a hat's content centre is not where the body's is. Frames
  matching the reference's size inherit the reference's offset instead.
- **Alignment bands must be fractions of the figure, not the canvas.** The canvas
  grows whenever a wider frame joins, sliding a band off the body part it was
  chosen for.
- **Bands must be clipped to where the reference has content.** A full-width band
  compares raised arms against empty background beside the reference's head and
  scores terribly for reasons unrelated to the face.

**Always re-run every frame together.** The shared canvas is the union of all of
them; preparing one alone puts it on a different canvas and the layers stop aligning.

---

## Step 4 — Verify the frame set before rigging it

The rig stands on four claims about the exported files, and all four fail
invisibly — the page renders either way, and a screenshot review passes.

```bash
python3 "$MF/scripts/verify-frames.py"
```

| Check | The assumption | What a break looks like |
|---|---|---|
| `canvas` | Every layer shares one canvas | Cross-fades jump |
| `scale` | No frame is drawn at a different size | Alignment pins at the search boundary |
| `body` | An expression frame changed only the face | The shared idle body layer no longer matches |
| `alpha` | Frames are cut out; `-bare` kept its alpha | A dark rectangle once composited |
| `webp` | Every frame has its `@NNN.webp` | A broken image at runtime |

It reads `prep-frames.py`'s own constants rather than restating them, so the
4.5% scale threshold cannot drift between the exporter and the check. Exit
status is non-zero on failure, so it can gate a commit.

Run it after every reprep. It is the cheap version of the invariant at the
bottom of this file, and the `body` check is the only mechanical test that the
idle-reuse trick in the rig is still valid.

## Step 5 — The rig

`assets/mascot.css` and `assets/mascot.js` are a working starting point. Two
structural rules decide whether the rest works at all:

**Each transform needs its own element.** Bob, physics and breathe/sway all
animate `transform`, and one element carries one animation per property. JS owns
`.mascot-poke` outright — a CSS animation there will fight it.

**Only the base frame carries dimensions.** The rest are absolutely positioned and
inherit the box, so a reprep that changes the canvas touches one line, not eight.

The markup, the spring constants, the measured settling times, the
mutually-indivisible periods that keep the idle loop from reading as a loop, and
the placement mask are in **`reference/rig.md`**. Read it when tuning motion or
when a reaction reads as weightless — not before, since none of it matters until
something moves.

---

## Step 6 — Outfits and costumes

Outfits are **alternate base frames, not overlays**: only `idle` exists for each, so
hide the expression layers and stop the blink while one is on, or the character wears
default clothes from the neck down. Load them on demand instead of shipping every
costume to every visitor. Any layer that is a copy of the base — the bounce layer —
has to swap with them.

Cycle them off a click counter past the last reaction, and expose `?mascot=<name>`
for screenshots and direct links.

**Hats are the hard case.** At a fixed figure scale a 1:1 render leaves almost no
headroom, so a tall hat clips. Do **not** solve this by generating at a taller aspect
— that changes framing and scale, and alignment pins at the search boundary.
Constrain the hat instead: a santa hat slouched to one side, a witch hat tipped back
so its cone lies behind the head.

**A chibi is a redraw, not a costume.** Different proportions cannot align with the
main set, so give it its own canvas and its own CSS size — at a shared width it will
render *taller* than the full-size character and the joke lands backwards. Chibify
the character in their **existing wardrobe**; a chibi plus a school uniform reads as
a different, much younger character, which is rarely what anyone wants.

---

## Invariants

- **Every prompt restates the character's identity.** The model defends nothing you
  do not name.
- **One aspect ratio for every frame in a set.** Alignment cannot fix scale.
- **Re-prep the whole set together**, never one frame.
- **Judge art on the real background at the real size**, never on white.
- **Run `verify-frames.py` after every reprep**, and never report a frame set as
  done on the strength of a screenshot. The four things that break here all
  render fine.
