# The rig — motion, springs, and the numbers behind them

Read this when tuning `assets/mascot.js`, when motion looks wrong, or when a
reaction reads as weightless. `SKILL.md` carries the structural rules; the
reasoning and the measured values live here because they only matter once
something is actually moving.

## Element structure

```html
<div class="mascot" data-mascot>
  <div class="mascot-poke"><div class="mascot-inner">
    <img src="idle@512.webp" width="512" height="668" alt="">
    <img class="layer face-blink" src="blink@512.webp" alt="" aria-hidden="true">
    <img class="layer" data-layer="surprise" src="surprise@512.webp" alt="" aria-hidden="true">
    <img class="mascot-bounce" data-bounce src="idle@512.webp" alt="" aria-hidden="true">
  </div></div>
</div>
```

**Each transform needs its own element.** Bob, physics and breathe/sway all
animate `transform`, and one element carries one animation per property. JS owns
`.mascot-poke` outright — a CSS animation there will fight it.

**Only the base frame carries dimensions.** The rest are absolutely positioned
and inherit the box, so a reprep that changes the canvas touches one line, not
eight.

## Motion that does not read as a loop

| Motion | How |
|--------|-----|
| Bob | `translateY` on the outer wrapper, ~3.1s |
| Breathe | `scale(0.995, 1.012)` from a bottom origin, ~2.6s |
| Sway | `rotate` ±0.9°, ~7.3s |
| Blink | hard cut to the blink frame |

Pick **mutually indivisible periods** (3.1 / 2.6 / 7.3s). The combined cycle then
takes minutes to repeat visibly. A blink is a **hard cut, twice in quick
succession** — people blink in pairs, and a single slow fade reads as a droop.
Suspend the blink during any reaction or the character blinks over its own
expression.

## Spring physics

A click injects velocity into a stiff body spring. Softer springs then *chase*
the body rather than being kicked directly, so they inherit its motion and arrive
late. **That lag is the entire effect** — mass arriving behind the body is what
reads as weight, and it is felt rather than seen.

| Spring | Stiffness / damping | Drives |
|--------|--------------------|--------|
| body | 190 / 14 | squash and stretch |
| trail | 90 / 9 | tilt and shear |
| bounce | 60 / 5 | secondary soft-tissue motion |

Measured on one click: body peaks at 71ms and is quiet by 471ms; the secondary
peaks at 271ms and still rings at 1555ms.

**Size `IMPULSE` so one click peaks the body spring near 1.0**, then amplitude
constants read directly as "at full deflection". Getting this wrong is silent —
the first attempt peaked at 0.15 and produced a 0.5% squash nobody could see.
Changing stiffness means re-tuning the impulse.

Stop the loop when every spring is at rest and clear the inline transforms, so an
idle character costs nothing. Opt out of physics under `prefers-reduced-motion` —
but keep expression swaps, because a frame change is not motion.

## Secondary motion on a flat sprite

Mask a copy of the sprite with a soft elliptical falloff and transform just that
copy. The soft falloff hides the seam.

The copy can reuse the `idle` frame under every expression, because the body is
pixel-identical wherever the face is the only thing that changed. That is an
assumption about the exported files, not a fact — `verify-frames.py` checks it,
and its `body` check exists for exactly this reason. A frame whose body drifted
makes the reuse wrong in a way that looks like a rigging bug.

## Placement

A waist-up render ends on a hard horizontal edge. Dissolve it with a gradient
mask rather than hiding it:

```css
mask-image: linear-gradient(to bottom, #000 80%, rgba(0,0,0,0) 97%);
```

Start the fade **below** anything characterful. At 62% it ate a folded-arms pose;
80% kept it. Check where the character collides with the headline and demote them
to a low-opacity watermark below that width rather than letting them fight for
the space.
