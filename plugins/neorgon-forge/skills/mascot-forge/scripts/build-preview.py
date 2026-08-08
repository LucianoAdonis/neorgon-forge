#!/usr/bin/env python3
"""Build the mascot motion preview from the prepared frames.

    python3 build-preview.py            # ./images/mascot/preview.html
    python3 build-preview.py --inline out.html

Run from the target project's root. The default writes a page next to the frames
that loads them by relative path, so it always reflects whatever prep-frames.py
last produced. `--inline` embeds the frames as data URIs instead, for a page that
travels on its own.
"""

import base64
import sys
from pathlib import Path

from PIL import Image

# Anchored on the cwd, not on this file: the script is installed once as a skill
# and run from whichever project owns the mascot.
PROJECT = Path.cwd().resolve()
FRAME_DIR = PROJECT / "images" / "mascot"
SKILL_ASSETS = Path(__file__).resolve().parent.parent / "assets"

# Frame name -> the file the page loads for it.
FRAMES = {
    "idle": "idle@512.webp",
    "blink": "blink@512.webp",
    "talk": "talk@512.webp",
    "surprise": "surprise@512.webp",
    "amused": "amused@512.webp",
    "deadpan": "deadpan@512.webp",
    "exasperated": "exasperated@512.webp",
    "exasperatedExtras": "exasperated-extras@512.webp",
}

# Reaction layers stacked over the base frame, in the order they are drawn.
# The sweat drop shares `exasperated` so both light up together.
LAYERS = [
    ("blink", "blink", "face-blink"),
    ("surprise", "surprise", ""),
    ("amused", "amused", ""),
    ("deadpan", "deadpan", ""),
    ("exasperated", "exasperated", ""),
    ("exasperatedExtras", "exasperated", ""),
]


def relative(name):
    return name


def inline(name):
    data = (FRAME_DIR / name).read_bytes()
    return f"data:image/webp;base64,{base64.b64encode(data).decode()}"


HTML = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mascot — motion preview</title>
<style>
  :root {
    --color-bg: #0f1018;
    --color-bg-card: #1a1d2e;
    --color-border: #2a2d42;
    --color-text-primary: #e8e4de;
    --color-text-secondary: #9a9bb0;
    --color-text-muted: #7d7f96;
    --color-accent: #c84b4b;
    --color-accent-gold: #c9a96e;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 40px 24px 80px;
    background: var(--color-bg);
    color: var(--color-text-primary);
    font: 15px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  }
  .wrap { max-width: 1000px; margin: 0 auto; }
  h1 { font-size: 22px; margin: 0 0 4px; letter-spacing: -0.01em; }
  .sub { color: var(--color-text-muted); margin: 0 0 32px; font-size: 14px; }
  h2 {
    font-size: 12px; text-transform: uppercase; letter-spacing: 0.09em;
    color: var(--color-accent-gold); margin: 40px 0 14px; font-weight: 600;
  }
  .panel {
    background: var(--color-bg-card);
    border: 1px solid var(--color-border);
    border-radius: 14px;
    padding: 28px;
  }
  .stage-row { display: flex; gap: 28px; align-items: flex-end; flex-wrap: wrap; }
  .stage-note { flex: 1 1 240px; min-width: 220px; color: var(--color-text-secondary); font-size: 14px; }
  .stage-note strong { color: var(--color-text-primary); font-weight: 600; }

  /* ---- the rig ---- */
  .mascot {
    position: relative;
    flex: none;
    line-height: 0;
    cursor: pointer;
    transform-origin: 50% 100%;
    animation: mascot-bob 3.1s ease-in-out infinite;
  }
  /* Its own element because bob, physics and breathe/sway all animate
     transform, and one element carries one animation per property. JS owns this
     element's transform outright — no CSS animation here, or they would fight. */
  .mascot-poke { transform-origin: 50% 92%; will-change: transform; }
  .mascot-inner {
    position: relative;
    transform-origin: 50% 100%;
    animation: mascot-breathe 2.6s ease-in-out infinite,
               mascot-sway 7.3s ease-in-out infinite;
  }
  .mascot img {
    display: block;
    width: 100%;
    height: auto;
    -webkit-user-drag: none;
    user-select: none;
  }
  .mascot .layer { position: absolute; inset: 0; opacity: 0; }
  .mascot .layer.is-visible { opacity: 1; }
  /* Secondary chest motion: a masked copy of the sprite springing a beat behind
     the body. The chest is pixel-identical across every expression frame, so a
     single copy of `idle` composites seamlessly under all of them. The mask
     falls off softly, which is what hides the seam at these tiny amplitudes. */
  .mascot-bounce {
    position: absolute; inset: 0;
    transform-origin: 47% 47%;
    will-change: transform;
    -webkit-mask-image: radial-gradient(ellipse 34% 11% at 46% 59%, #000 50%, rgba(0,0,0,0) 82%);
    mask-image: radial-gradient(ellipse 34% 11% at 46% 59%, #000 50%, rgba(0,0,0,0) 82%);
  }
  /* A blink is a hard cut, not a fade: two states, no in-between. */
  .mascot .face-blink { animation: mascot-blink 4.5s steps(1, end) infinite; }
  /* She must not blink over a reaction. */
  .mascot.is-reacting .face-blink { animation: none; }

  @keyframes mascot-bob {
    0%, 100% { transform: translateY(0); }
    50%      { transform: translateY(-9px); }
  }
  @keyframes mascot-breathe {
    0%, 100% { transform: scale(1, 1); }
    50%      { transform: scale(0.995, 1.012); }
  }
  @keyframes mascot-sway {
    0%, 100% { rotate: -0.9deg; }
    50%      { rotate: 0.9deg; }
  }
  /* ~110ms closed, then again shortly after — people blink in pairs. */
  @keyframes mascot-blink {
    0%, 92.4%     { opacity: 0; }
    92.5%, 94.9%  { opacity: 1; }
    95%, 96.9%    { opacity: 0; }
    97%, 98.9%    { opacity: 1; }
    99%, 100%     { opacity: 0; }
  }
  /* Reactions still swap frames under reduced motion — a frame change is not
     motion. Only the movement stops. The physics opts out in JS. */
  @media (prefers-reduced-motion: reduce) {
    .mascot, .mascot-inner, .mascot .layer { animation: none; }
  }

  .size-340 { width: 340px; }
  .size-180 { width: 180px; }
  .size-96  { width: 96px; }

  /* ---- controls ---- */
  .toggles { display: flex; gap: 18px; flex-wrap: wrap; margin-top: 24px;
             padding-top: 20px; border-top: 1px solid var(--color-border); }
  label { display: flex; gap: 8px; align-items: center; font-size: 13px;
          color: var(--color-text-secondary); cursor: pointer; user-select: none; }
  input[type=checkbox] { accent-color: var(--color-accent); width: 15px; height: 15px; cursor: pointer; }
  body.no-bob     .mascot       { animation: none; }
  body.no-breathe .mascot-inner { animation-name: mascot-sway; }
  body.no-sway    .mascot-inner { animation-name: mascot-breathe; }
  body.no-breathe.no-sway .mascot-inner { animation: none; }
  body.no-blink   .face-blink   { animation: none; }

  /* ---- frame inventory ---- */
  .frames { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 14px; }
  .frame {
    background: var(--color-bg-card); border: 1px solid var(--color-border);
    border-radius: 12px; padding: 14px; text-align: center;
  }
  .frame .checker {
    background-image:
      linear-gradient(45deg, #23263a 25%, transparent 25%, transparent 75%, #23263a 75%),
      linear-gradient(45deg, #23263a 25%, #191b28 25%, #191b28 75%, #23263a 75%);
    background-size: 16px 16px; background-position: 0 0, 8px 8px;
    border-radius: 8px; margin-bottom: 10px; overflow: hidden;
  }
  .frame img { display: block; width: 100%; height: auto; }
  .frame b { display: block; font-size: 13px; font-weight: 600; }
  .frame span { font-size: 12px; color: var(--color-text-muted); }

  /* ---- in-context mock ---- */
  .mock {
    position: relative; overflow: hidden;
    border: 1px solid var(--color-border); border-radius: 14px;
    background: linear-gradient(160deg, #141622, #0f1018 60%);
    /* Tall enough that a waist-up figure clears the top edge. A waist-up
       render is ~1.74x as tall as it is wide, so the panel has to allow for
       that or overflow:hidden crops her head. */
    padding: 46px 40px; min-height: 340px;
  }
  .mock .kicker { font-size: 12px; letter-spacing: 0.09em; text-transform: uppercase;
                  color: var(--color-accent-gold); }
  .mock h3 { font-size: 34px; line-height: 1.15; margin: 12px 0 22px; max-width: 380px;
             letter-spacing: -0.02em; }
  .mock .btns { display: flex; gap: 10px; flex-wrap: wrap; }
  .mock .btn { padding: 10px 18px; border-radius: 8px; font-size: 14px; font-weight: 600;
               background: var(--color-accent); color: #fff; }
  .mock .btn.ghost { background: transparent; color: var(--color-text-secondary);
                     border: 1px solid var(--color-border); }
  .mock .mascot { position: absolute; right: 28px; bottom: -14px; width: 180px; }
  @media (max-width: 720px) { .mock .mascot { opacity: 0.2; right: -30px; } }
</style>
</head>
<body>
<div class="wrap">
  <h1>Mascot — motion preview</h1>
  <p class="sub">One base render plus six expression frames. All movement is CSS on those frames.
  <strong style="color:var(--color-accent-gold)">Click her &mdash; and keep clicking.</strong></p>

  <h2>Idle rig</h2>
  <div class="panel">
    <div class="stage-row">
      __RIG:size-340__
      <div class="stage-note">
        <p>What is running:</p>
        <p><strong>Bob</strong> — 3.1s float.<br>
        <strong>Breathe</strong> — 1.2% vertical scale from the waist.<br>
        <strong>Sway</strong> — &plusmn;0.9&deg; on a 7.3s period, so it never lines up with the bob
        and the idle never reads as a loop.<br>
        <strong>Blink</strong> — a hard cut to the blink frame, ~110ms, twice in quick
        succession every 4.5s. People blink in pairs; a single slow fade reads as a droop.</p>
        <p>Turn them off to feel what each one adds.</p>
      </div>
    </div>
    <div class="toggles">
      <label><input type="checkbox" data-cls="no-bob" checked> Bob</label>
      <label><input type="checkbox" data-cls="no-breathe" checked> Breathe</label>
      <label><input type="checkbox" data-cls="no-sway" checked> Sway</label>
      <label><input type="checkbox" data-cls="no-blink" checked> Blink</label>
    </div>
  </div>

  <h2>Expression frames</h2>
  <div class="frames">
    <div class="frame">
      <div class="checker"><img data-frame="idle" alt="idle"></div>
      <b>idle</b><span>base</span>
    </div>
    <div class="frame">
      <div class="checker"><img data-frame="blink" alt="blink"></div>
      <b>blink</b><span>idle loop</span>
    </div>
    <div class="frame">
      <div class="checker"><img data-frame="talk" alt="talk"></div>
      <b>talk</b><span>tips, onboarding</span>
    </div>
    <div class="frame">
      <div class="checker"><img data-frame="surprise" alt="surprise"></div>
      <b>surprise</b><span>1 click &middot; empty states</span>
    </div>
    <div class="frame">
      <div class="checker"><img data-frame="amused" alt="amused"></div>
      <b>amused</b><span>2 clicks</span>
    </div>
    <div class="frame">
      <div class="checker"><img data-frame="deadpan" alt="deadpan"></div>
      <b>deadpan</b><span>3&ndash;4 clicks</span>
    </div>
    <div class="frame">
      <div class="checker"><img data-frame="exasperated" alt="exasperated"></div>
      <b>exasperated</b><span>5+ clicks</span>
    </div>
    <div class="frame">
      <div class="checker"><img data-frame="exasperatedExtras" alt="sweat drop"></div>
      <b>&hellip;-extras</b><span>auto-split sweat drop</span>
    </div>
  </div>

  <h2>Click ladder</h2>
  <div class="panel">
    <div class="stage-note" style="min-width:0">
      <p>She escalates, then forgets. Each click bumps a counter; the counter picks the
      reaction; the reaction holds 1.4s after the last click and the counter resets after
      5s of being left alone.</p>
      <p><strong>1</strong> &rarr; surprise &middot; <strong>2</strong> &rarr; amused &middot;
      <strong>3&ndash;4</strong> &rarr; deadpan &middot; <strong>5+</strong> &rarr; exasperated,
      sweat drop and all.</p>
      <p>She is an older sister, so the ladder runs amused &rarr; unimpressed &rarr; fondly
      done with you, never angry. The idle blink is suspended while a reaction is up, so she
      cannot blink over her own expression.</p>
      <p><strong>Physics.</strong> Each click shoves a damped spring. Two softer springs chase
      it: one drives a whole-body tilt and shear, the other drives secondary chest motion.
      Both arrive late, and the lag is the whole trick &mdash; mass arriving behind the body is
      what reads as weight.</p>
      <p>Measured on one click: the body peaks at <strong>71ms</strong> and is quiet by
      <strong>471ms</strong>, while the chest peaks at <strong>271ms</strong> and is still
      ringing at <strong>1555ms</strong>. Soft mass overshooting and settling long after the
      rigid body stopped is exactly what games are faking, and it is the part you feel rather
      than see. Clicking again mid-wobble stacks onto the existing velocity, so a frenzy
      builds to about twice the deflection and then settles itself.</p>
      <p>The chest layer is a masked copy of the sprite with a soft elliptical falloff. It can
      use <code>idle</code> under every reaction because the chest is pixel-identical across
      all seven frames &mdash; only her face ever changes. The loop stops the moment she is
      still, so an idle mascot costs nothing.</p>
      <p style="color:var(--color-text-muted)">Behaviour lives in <code>js/mascot.js</code> and is
      inlined here, so this page and the site run the exact same code.</p>
    </div>
  </div>

  <h2>Holds up small</h2>
  <div class="panel">
    <div class="stage-row" style="gap: 40px;">
      __RIG:size-180__
      __RIG:size-96__
      <div class="stage-note">Same markup at 180px and 96px. Waist-up framing is what keeps the
      blink readable this small &mdash; on the full-body render the head is a third the size and
      the expression disappears entirely.</div>
    </div>
  </div>

  <h2>In context — page hero</h2>
  <div class="mock">
    <span class="kicker">Your kicker here</span>
    <h3>Your headline.<br>Two lines.</h3>
    <div class="btns">
      <span class="btn">Primary action</span>
      <span class="btn ghost">Secondary</span>
    </div>
    __RIG:__
  </div>
</div>

<script type="module">
  var FRAMES = __FRAMES__;
  document.querySelectorAll('img[data-frame]').forEach(function (img) {
    img.src = FRAMES[img.dataset.frame];
  });
  document.querySelectorAll('input[data-cls]').forEach(function (box) {
    box.addEventListener('change', function () {
      document.body.classList.toggle(box.dataset.cls, !box.checked);
    });
  });

__BEHAVIOUR__

  initAllMascots();
</script>
</body>
</html>
"""


def main(argv):
    if argv and argv[0] == "--inline":
        source = inline
        out = Path(argv[1]) if len(argv) > 1 else FRAME_DIR / "preview-inline.html"
    elif argv:
        sys.exit(__doc__)
    else:
        source, out = relative, FRAME_DIR / "preview.html"

    missing = [f for f in FRAMES.values() if not (FRAME_DIR / f).exists()]
    if missing:
        sys.exit(f"missing frames, run prep-frames.py first: {', '.join(missing)}")

    with Image.open(FRAME_DIR / FRAMES["idle"]) as base:
        width, height = base.size

    def rig(size_class):
        classes = f"mascot {size_class}".strip()
        parts = [
            f'<div class="{classes}" data-mascot>',
            '<div class="mascot-poke"><div class="mascot-inner">',
            f'<img data-frame="idle" width="{width}" height="{height}" alt="Mascot">',
        ]
        for frame, layer, extra in LAYERS:
            css = f"layer {extra}".strip()
            parts.append(
                f'<img class="{css}" data-frame="{frame}" data-layer="{layer}"'
                f' width="{width}" height="{height}" alt="" aria-hidden="true">'
            )
        parts.append(
            f'<img class="mascot-bounce" data-frame="idle" data-bounce'
            f' width="{width}" height="{height}" alt="" aria-hidden="true">'
        )
        parts.append("</div></div></div>")
        return "".join(parts)

    mapping = "{" + ", ".join(f'"{k}": "{source(v)}"' for k, v in FRAMES.items()) + "}"

    # One source of truth for the behaviour: the module the site will import,
    # inlined here so the preview stays a single self-contained file. Before the
    # site has vendored it, fall back to the skill's own copy — otherwise the
    # first preview of a new mascot cannot be built at all.
    behaviour_module = PROJECT / "js" / "mascot.js"
    if not behaviour_module.exists():
        behaviour_module = SKILL_ASSETS / "mascot.js"
    behaviour = behaviour_module.read_text().replace("export function", "function")

    html = HTML.replace("__FRAMES__", mapping).replace("__BEHAVIOUR__", behaviour)
    html = html.replace('width="512" height="889"', f'width="{width}" height="{height}"')
    for size_class in ("size-340", "size-180", "size-96", ""):
        html = html.replace(f"__RIG:{size_class}__", rig(size_class))
    out.write_text(html)
    print(f"{out}  {out.stat().st_size / 1024:.0f} KB  (frames {width}x{height})")


if __name__ == "__main__":
    main(sys.argv[1:])
