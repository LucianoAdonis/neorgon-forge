#!/usr/bin/env python3
"""Check a prepared frame set against the assumptions the rig depends on.

Run from the target project's root, after prep-frames.py:

    python3 verify-frames.py                    # every frame in ./images/mascot/
    python3 verify-frames.py --reference idle    # name the base frame explicitly

The rig in assets/mascot.{css,js} is built on four claims about the exported
files. Each one is invisible when it breaks — the page still renders, the
character just looks subtly wrong in a way a screenshot review passes:

  canvas    Every layer shares one canvas. A frame on a different canvas is
            offset by the difference, and the cross-fade jumps.
  body      A layer stacked over the base must differ from it *only* where it is
            supposed to. The secondary-motion layer reuses the idle body under
            every expression, so an expression frame whose body drifted makes
            that reuse wrong.
  scale     A frame drawn at a different scale cannot be fixed by translation.
            prep-frames.py warns at export; this re-checks the exported file, so
            a warning scrolled past in a long run still fails a build.
  alpha     A cut-out frame has transparency, and a *-bare export keeps it.
            A flattened bare export shows a dark rectangle once composited.

Exits non-zero if any check fails, so it can gate a commit.
"""

import importlib.util
import sys
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path.cwd().resolve()
FRAME_DIR = PROJECT / "images" / "mascot"


def load_prep():
    """Borrow the exporter's own constants and band search.

    Restating SCALE_SUSPECT or the band bounds here would create a second copy
    of a tuned number, and the copy would be wrong the first time either is
    changed. The hyphen in the filename is why this needs importlib.
    """
    path = Path(__file__).resolve().parent / "prep-frames.py"
    spec = importlib.util.spec_from_file_location("prep_frames", path)
    module = importlib.util.module_from_spec(spec)
    sys.modules["prep_frames"] = module
    spec.loader.exec_module(module)
    return module


def alpha_of(path):
    image = Image.open(path).convert("RGBA")
    return np.asarray(image, dtype=np.float32)[:, :, 3] / 255.0


def rgb_of(path):
    image = Image.open(path).convert("RGBA")
    return np.asarray(image, dtype=np.int16)[:, :, :3]


def master_dir(prep):
    """Where the full-resolution masters live.

    They moved out of images/ so they are not deploy weight, and became lossless
    WebP on the way. Borrow the exporter's own constant rather than restating the
    path; fall back to the served directory for older sets that still keep PNG
    masters beside the derivatives.
    """
    configured = getattr(prep, "MASTER_DIR", None)
    if configured and Path(configured).is_dir() and frames_in(Path(configured)):
        return Path(configured)
    return FRAME_DIR


def frames_in(directory):
    """Base frames only: the @NNN.webp files and -extras are derived."""
    return sorted(
        p for p in directory.iterdir()
        if p.suffix in (".png", ".webp")
        and "@" not in p.stem and not p.stem.endswith("-extras")
    )


class Report:
    def __init__(self):
        self.failures = 0

    def ok(self, check, detail):
        print(f"  \033[32mok\033[0m    {check:<9} {detail}")

    def fail(self, check, detail):
        self.failures += 1
        print(f"  \033[31mFAIL\033[0m  {check:<9} {detail}")

    def note(self, detail):
        print(f"        {detail}")


def check_canvas(report, frames):
    sizes = {}
    for path in frames:
        with Image.open(path) as image:
            sizes.setdefault(image.size, []).append(path.stem)
    if len(sizes) == 1:
        size = next(iter(sizes))
        report.ok("canvas", f"{len(frames)} frames on one {size[0]}x{size[1]} canvas")
        return True
    report.fail("canvas", f"{len(sizes)} different canvases — layers cannot align")
    for size, names in sorted(sizes.items(), key=lambda kv: -len(kv[1])):
        report.note(f"{size[0]}x{size[1]}: {', '.join(names)}")
    report.note("re-run prep-frames.py with every frame in one command")
    return False


def check_scale(report, prep, reference, others, pinned=()):
    """Alignment reads the alpha silhouette, so it only means something on a
    frame that has one. A flattened frame is a fully-opaque rectangle and would
    report a large residual for a reason that has nothing to do with scale —
    check_alpha already named that defect, and reporting it twice under the
    wrong heading sends the fix in the wrong direction."""
    ref_alpha = alpha_of(reference)
    worst = 0.0
    for path in others:
        if path.stem in pinned:
            report.note(f"{path.stem} pinned — no shared silhouette to score")
            continue
        alpha = alpha_of(path)
        if alpha.shape != ref_alpha.shape or alpha.min() > 0.99:
            continue
        offset, band, residual = prep.find_offset(ref_alpha, alpha)
        worst = max(worst, residual)
        if residual > prep.SCALE_SUSPECT:
            report.fail(
                "scale",
                f"{path.stem} mismatches {reference.stem} by {residual:.1%} "
                f"on {band} (limit {prep.SCALE_SUSPECT:.1%})",
            )
            report.note("drawn at a different scale — regenerate it, do not re-align")
        elif offset != (0, 0):
            report.note(f"{path.stem} sits {offset} off {reference.stem}")
    if worst <= prep.SCALE_SUSPECT:
        report.ok("scale", f"worst residual {worst:.1%} "
                           f"(limit {prep.SCALE_SUSPECT:.1%})")


def check_body(report, prep, reference, others):
    """Prove an expression frame changed only the face.

    The rig reuses the idle body beneath every expression layer, so this is the
    assumption that silently breaks the secondary motion. Compared inside the
    body band the exporter already defines, on opaque pixels of both frames.
    """
    top_frac, bottom_frac = prep.ALIGN_BANDS["body"]
    ref_alpha, ref_rgb = alpha_of(reference), rgb_of(reference)
    # Figure-relative, matching the exporter: the canvas grows when a wider
    # frame joins, which would slide a canvas-relative band off the body.
    rows = np.where((ref_alpha > 0.02).any(axis=1))[0]
    origin, span = rows.min(), rows.max() - rows.min()
    top, bottom = origin + int(span * top_frac), origin + int(span * bottom_frac)
    clean, compared = True, 0
    for path in others:
        # An outfit is supposed to differ below the neck. Only expression
        # frames carry the promise this check exists to enforce.
        if path.stem.startswith("outfit-"):
            continue
        alpha, rgb = alpha_of(path), rgb_of(path)
        if alpha.shape != ref_alpha.shape or alpha.min() > 0.99:
            continue
        solid = (ref_alpha[top:bottom] > 0.5) & (alpha[top:bottom] > 0.5)
        if not solid.any():
            continue
        compared += 1
        delta = np.abs(rgb[top:bottom] - ref_rgb[top:bottom]).max(axis=2)
        moved = np.count_nonzero((delta > 8) & solid) / np.count_nonzero(solid)
        if moved > 0.01:
            clean = False
            report.note(f"{path.stem}: body differs on {moved:.1%} of the band")
    if not compared:
        return
    if clean:
        report.ok("body", f"body band identical across {compared} frame(s) "
                          f"— idle reuse is safe")
    else:
        report.fail("body", "a frame changed outside the face")
        report.note("the shared idle body layer will not match it; either "
                    "regenerate the frame or give it its own body layer")


def check_alpha(report, frames):
    flat = [p.stem for p in frames if alpha_of(p).min() > 0.99]
    bare = [p for p in frames if p.stem.endswith("-bare")]
    solid_bare = [p.stem for p in bare if alpha_of(p).min() > 0.99]
    if solid_bare:
        report.fail("alpha", f"bare export is flattened: {', '.join(solid_bare)}")
        report.note("a bare frame keeps its alpha — it composites onto unknown art")
    elif bare:
        report.ok("alpha", f"{len(bare)} bare export(s) kept transparency")
    opaque = [name for name in flat if not name.endswith("-bare")]
    if opaque:
        report.fail("alpha", f"never cut out: {', '.join(opaque)}")
        report.note("run prep-frames.py on it, or --remove-bg if it has sealed pockets")
    elif not bare:
        report.ok("alpha", f"all {len(frames)} frames have transparency")


def check_derivatives(report, frames):
    missing = [p.stem for p in frames if not list(FRAME_DIR.glob(f"{p.stem}@*.webp"))]
    if missing:
        report.fail("webp", f"no @NNN.webp for: {', '.join(missing)}")
        report.note("the page references the webp, so this is a broken image at runtime")
    else:
        report.ok("webp", f"every frame has its webp derivatives")


def main():
    argv = sys.argv[1:]
    # A frame can be on its own canvas on purpose — a chibi redraw is a different
    # shape, not a costume, and gets its own CSS size. Without a way to say so,
    # this check fails forever and stops being read.
    pinned = set()
    if "--pinned" in argv:
        index = argv.index("--pinned") + 1
        if index < len(argv):
            pinned.update(argv[index].split(","))
    separate = set()
    if "--separate" in argv:
        index = argv.index("--separate") + 1
        if index < len(argv):
            separate.update(argv[index].split(","))
    wanted = None
    if "--reference" in argv:
        index = argv.index("--reference") + 1
        if index < len(argv):
            wanted = argv[index]

    if not FRAME_DIR.is_dir():
        print(f"no {FRAME_DIR.relative_to(PROJECT)} — run prep-frames.py first",
              file=sys.stderr)
        return 1

    source = master_dir(load_prep())
    frames = [p for p in frames_in(source) if p.stem not in separate]
    if separate:
        print(f"excluding {', '.join(sorted(separate))} — declared separate\n")
    if not frames:
        print(f"no frames in {source.relative_to(PROJECT)}", file=sys.stderr)
        return 1

    reference = next((p for p in frames if p.stem == (wanted or "idle")), None)
    if reference is None:
        reference = frames[0]
        print(f"no {wanted or 'idle'} frame — comparing against {reference.stem}")

    others = [p for p in frames if p != reference]
    print(f"{len(frames)} frame(s) in {source.relative_to(PROJECT)}, "
          f"reference {reference.stem}\n")

    report = Report()
    aligned = check_canvas(report, frames)
    check_alpha(report, frames)
    check_derivatives(report, frames)
    if aligned and others:
        prep = load_prep()
        check_scale(report, prep, reference, others, pinned)
        check_body(report, prep, reference, others)
    elif not aligned:
        report.note("skipping scale and body checks — canvases disagree first")

    print()
    if report.failures:
        print(f"\033[31m{report.failures} check(s) failed\033[0m")
        return 1
    print("\033[32mframe set is consistent\033[0m")
    return 0


if __name__ == "__main__":
    sys.exit(main())
