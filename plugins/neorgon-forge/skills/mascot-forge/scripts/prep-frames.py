#!/usr/bin/env python3
"""Turn white-background mascot renders into aligned, transparent animation frames.

Generated art (Gemini, etc.) comes back on a flat white background and drifts a
few pixels between generations. Cross-fading those raw files reads as a jump
cut. This script fixes both problems:

  1. keys out the white background (soft, anti-aliased edges, no white fringe)
  2. splits off detached islands like floating hearts into their own layer
  3. aligns every frame to the reference frame so bodies sit still
  4. crops all frames to one shared canvas and exports PNG + WebP

Usage:
    python3 prep-frames.py idle=path/to/a.png wink=path/to/b.png

Run from the target project's root. The first frame listed is the alignment
reference. Output lands in ./images/mascot/ as <name>.png plus <name>@512.webp /
<name>@256.webp, and any detached islands as <name>-extras.png.
"""

import base64
import hashlib
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from keys import read_key

# Anchored on the cwd, not on this file: the script is installed once as a skill
# and run from whichever project owns the mascot.
PROJECT = Path.cwd().resolve()
OUT_DIR = PROJECT / "images" / "mascot"
CACHE_DIR = PROJECT / ".cache" / "removebg"

REMOVEBG_ENDPOINT = "https://api.remove.bg/v1.0/removebg"
# The free tier only returns a 0.25MP preview. That is useless as a final
# cutout but plenty for deciding which regions are background, which is the
# one thing local keying cannot do. Edges still come from the local keyer.
REMOVEBG_SIZE = "preview"
# A pocket must survive this much erosion to count. Real pockets are fat blobs;
# a coarse mask disagreeing with the local keyer along the silhouette produces
# thin ribbons, and those erode to nothing.
POCKET_ERODE = 3

# Pixels at least this close to pure white are background candidates.
WHITE_TOL = 14
# Whiteness at which a boundary pixel is treated as fully opaque.
EDGE_CUT = 0.86
# Width in pixels of the soft band feathered along the cutout boundary.
FEATHER = 2
# Detached islands smaller than this share of the largest island are treated as
# separate art (hearts, sparkles, motion lines) rather than part of the body.
ISLAND_RATIO = 0.05
# Islands below this many pixels are keying noise and get dropped outright.
MIN_ISLAND_PX = 24
# Half-width of the alignment search window, in pixels.
SEARCH = 24
# Rows (as a fraction of height) available for alignment. An expression frame
# changes only the face, so its still lower body is the signal. An outfit frame
# changes the whole garment, so its unchanged face is. Both are tried and the
# better match wins, which identifies the kind of frame for free.
ALIGN_BANDS = {"body": (0.58, 0.98), "face": (0.24, 0.46)}
# Residual mismatch in the winning band, above which the frame is probably drawn
# at a different scale — something no amount of translation can fix.
SCALE_SUSPECT = 0.045


def subject_mask(path, shape):
    """Coarse "this is the subject" mask from remove.bg, cached on disk.

    Local keying floods inward from the border, so a pocket of background that
    gets sealed off — between a hair strand and a jaw, say — stays opaque. A
    segmentation model has no such blind spot. Responses are cached by content
    hash so re-running never spends another call.
    """
    source = Path(path).read_bytes()
    cached = CACHE_DIR / f"{hashlib.sha1(source).hexdigest()[:16]}.png"

    if not cached.exists():
        body = json.dumps(
            {
                "image_file_b64": base64.b64encode(source).decode(),
                "size": REMOVEBG_SIZE,
                "format": "png",
            }
        ).encode()
        request = urllib.request.Request(
            REMOVEBG_ENDPOINT,
            data=body,
            headers={
                "X-Api-Key": read_key("REMOVE_BG_API_KEY"),
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                charged = response.headers.get("X-Credits-Charged", "0")
                payload = response.read()
        except urllib.error.HTTPError as error:
            sys.exit(f"remove.bg HTTP {error.code}: {error.read().decode()[:300]}")

        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        cached.write_bytes(payload)
        print(f"  remove.bg: {Path(path).name} (credits charged: {charged})")

    with Image.open(cached) as mask_image:
        mask = np.asarray(mask_image.convert("RGBA"))[:, :, 3]

    full = Image.fromarray(mask).resize((shape[1], shape[0]), Image.BILINEAR)
    return np.asarray(full).astype(np.float32) / 255.0 > 0.5


def background_pockets(path, rgb):
    """Background regions the border flood fill cannot reach.

    The model's verdict alone is too coarse to cut with, so it only gets a vote
    on pixels that are already background-coloured. That makes it impossible for
    a bad mask to delete hair or clothing — the worst case is a missed pocket.
    """
    keep = subject_mask(path, rgb.shape[:2])
    candidate = (rgb.min(axis=2) >= 255 - WHITE_TOL) & ~keep

    core = ndimage.binary_erosion(candidate, iterations=POCKET_ERODE)
    if not core.any():
        return None

    labels, _ = ndimage.label(candidate)
    surviving = np.unique(labels[core])
    return np.isin(labels, surviving[surviving != 0])


def load_frame(path, use_removebg=False):
    """Return (rgb float array, alpha float array in 0..1) for one render.

    Renders arrive either already cut out (a real alpha channel) or flat on
    white, sometimes both in the same batch. Detect which and handle it.
    """
    img = Image.open(path).convert("RGBA")
    data = np.asarray(img).astype(np.float32)
    rgb, alpha = data[:, :, :3], data[:, :, 3] / 255.0

    if alpha.min() >= 0.98:
        pockets = background_pockets(path, rgb) if use_removebg else None
        rgb, alpha = key_white_background(rgb, pockets)

    return rgb, alpha


def key_white_background(rgb, extra_background=None):
    """Cut a flat white background out of an opaque render.

    `extra_background` marks regions the border flood fill cannot reach. They
    join the background before feathering, so pocket edges get the same soft
    alpha and colour decontamination as the outer silhouette.
    """
    rgb = rgb.copy()

    near_white = rgb.min(axis=2) >= 255 - WHITE_TOL

    # Only white connected to the border is background. This protects white
    # that belongs to the character: the collar, eye highlights, teeth.
    labels, _ = ndimage.label(near_white)
    edge_labels = np.unique(
        np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])
    )
    edge_labels = edge_labels[edge_labels != 0]
    background = np.isin(labels, edge_labels)
    if extra_background is not None:
        background |= extra_background

    solid = ~background
    alpha = solid.astype(np.float32)

    # Feather the boundary. Anti-aliased pixels sit just inside `solid` and are
    # part white, so derive their coverage from how white they are.
    band = ndimage.binary_dilation(background, iterations=FEATHER) & solid
    whiteness = rgb.min(axis=2) / 255.0
    soft = np.clip((1.0 - whiteness) / (1.0 - EDGE_CUT), 0.0, 1.0)
    alpha[band] = soft[band]

    # Undo the white the background contributed to partial pixels, otherwise
    # edges glow against a dark page.
    partial = (alpha > 0.01) & (alpha < 0.999)
    a = alpha[partial][:, None]
    rgb[partial] = np.clip((rgb[partial] - (1.0 - a) * 255.0) / a, 0, 255)

    return rgb, alpha


def split_islands(alpha):
    """Split alpha into (main body, detached extras) masks."""
    labels, count = ndimage.label(alpha > 0.5)
    if count <= 1:
        return alpha, None

    sizes = ndimage.sum(np.ones_like(labels), labels, range(1, count + 1))
    main_label = int(np.argmax(sizes)) + 1
    biggest = sizes.max()

    extras_labels, noise_labels = [], []
    for index, size in enumerate(sizes):
        label = index + 1
        if label == main_label or size >= biggest * ISLAND_RATIO:
            continue
        (noise_labels if size < MIN_ISLAND_PX else extras_labels).append(label)

    # Labelling thresholds alpha, so each island's soft edge falls outside its
    # own label. Grow the masks a little to carry that fringe along, otherwise a
    # ghost outline stays behind in the layer the island was lifted out of.
    def grow(chosen):
        return ndimage.binary_dilation(np.isin(labels, chosen), iterations=FEATHER + 1)

    main = alpha.copy()
    if noise_labels:
        main[grow(noise_labels)] = 0.0
    if not extras_labels:
        return main, None

    extras_mask = grow(extras_labels)
    main[extras_mask] = 0.0
    extras = np.where(extras_mask, alpha, 0.0)
    return main, extras


def shift(array, dy, dx):
    """Translate by whole pixels, filling the vacated edge with zeros."""
    out = np.zeros_like(array)
    src_rows = slice(max(0, -dy), array.shape[0] - max(0, dy))
    dst_rows = slice(max(0, dy), array.shape[0] - max(0, -dy))
    src_cols = slice(max(0, -dx), array.shape[1] - max(0, dx))
    dst_cols = slice(max(0, dx), array.shape[1] - max(0, -dx))
    out[dst_rows, dst_cols] = array[src_rows, src_cols]
    return out


def pad_to_canvas(frame, height, width):
    """Grow one frame onto a common canvas, anchored on its own content.

    Renders do not all come back the same size — a taller aspect ratio is the
    only way to fit a hat above her head without shrinking her. Landing each
    frame's content bottom on the canvas bottom, and its horizontal centre on
    the canvas centre, leaves the aligner only a few pixels to absorb.
    """
    height_before, width_before = frame["alpha"].shape
    if (height_before, width_before) == (height, width):
        return

    solid = frame["alpha"] > 0.02
    rows = np.where(solid.any(axis=1))[0]
    cols = np.where(solid.any(axis=0))[0]
    dy = (height - 1) - rows.max()
    dx = width // 2 - (cols.min() + cols.max()) // 2

    def place(array):
        out = np.zeros((height, width) + array.shape[2:], dtype=array.dtype)
        src_rows = slice(max(0, -dy), min(height_before, height - dy))
        src_cols = slice(max(0, -dx), min(width_before, width - dx))
        out[
            src_rows.start + dy : src_rows.stop + dy,
            src_cols.start + dx : src_cols.stop + dx,
        ] = array[src_rows, src_cols]
        return out

    frame["rgb"] = place(frame["rgb"])
    frame["alpha"] = place(frame["alpha"])
    if frame["extras"] is not None:
        frame["extras"] = place(frame["extras"])


def _best_in_band(ref_alpha, alpha, band):
    """Lowest mismatch (as a fraction of band area) and the offset achieving it."""
    height = ref_alpha.shape[0]
    top, bottom = int(height * band[0]), int(height * band[1])
    ref_band = ref_alpha[top:bottom] > 0.5

    best, best_offset = None, (0, 0)
    for dy in range(-SEARCH, SEARCH + 1):
        moved_y = shift(alpha, dy, 0)
        for dx in range(-SEARCH, SEARCH + 1):
            candidate = shift(moved_y, 0, dx)[top:bottom] > 0.5
            score = np.count_nonzero(ref_band ^ candidate)
            if best is None or score < best:
                best, best_offset = score, (dy, dx)
    return best / ref_band.size, best_offset


def find_offset(ref_alpha, alpha):
    """Offset that best lands `alpha` on `ref_alpha`, plus how it was matched."""
    results = [
        (*_best_in_band(ref_alpha, alpha, band), name) for name, band in ALIGN_BANDS.items()
    ]
    residual, offset, band = min(results)

    if max(abs(offset[0]), abs(offset[1])) == SEARCH:
        print(f"  warning: best offset {offset} sits on the search boundary")
    return offset, band, residual


def to_image(rgb, alpha):
    """Compose to RGBA, clearing colour under fully transparent pixels."""
    rgb = np.where(alpha[:, :, None] > 0.003, rgb, 0.0)
    rgba = np.dstack([np.clip(rgb, 0, 255), np.clip(alpha * 255.0, 0, 255)])
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def resize_premultiplied(image, width):
    """Downscale without pulling the colour behind transparent pixels inward."""
    data = np.asarray(image).astype(np.float32)
    alpha = data[:, :, 3:4] / 255.0
    premultiplied = np.dstack([data[:, :, :3] * alpha, data[:, :, 3]])

    height = round(image.height * width / image.width)
    small = np.asarray(
        Image.fromarray(premultiplied.astype(np.uint8), "RGBA").resize(
            (width, height), Image.LANCZOS
        )
    ).astype(np.float32)

    small_alpha = small[:, :, 3:4] / 255.0
    colour = np.divide(
        small[:, :, :3], small_alpha, out=np.zeros_like(small[:, :, :3]), where=small_alpha > 0.003
    )
    out = np.dstack([np.clip(colour, 0, 255), small[:, :, 3]])
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def export(image, name):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    png_path = OUT_DIR / f"{name}.png"
    image.save(png_path, optimize=True)
    written = [png_path]

    for width in (512, 256):
        if width >= image.width:
            continue
        webp_path = OUT_DIR / f"{name}@{width}.webp"
        resize_premultiplied(image, width).save(webp_path, quality=90, method=6)
        written.append(webp_path)

    for path in written:
        with Image.open(path) as opened:
            dimensions = f"{opened.width}x{opened.height}"
        print(f"  {path.relative_to(PROJECT)}  {dimensions}  {path.stat().st_size / 1024:.0f} KB")


def main(argv):
    use_removebg = "--remove-bg" in argv
    argv = [a for a in argv if a != "--remove-bg"]

    pairs = []
    for arg in argv:
        if "=" not in arg:
            sys.exit(f"expected name=path, got: {arg}")
        name, path = arg.split("=", 1)
        pairs.append((name, Path(path).expanduser()))
    if not pairs:
        sys.exit(__doc__)

    frames = []
    for name, path in pairs:
        if not path.exists():
            sys.exit(f"missing input: {path}")
        rgb, alpha = load_frame(path, use_removebg)
        main_alpha, extras_alpha = split_islands(alpha)
        frames.append({"name": name, "rgb": rgb, "alpha": main_alpha, "extras": extras_alpha})
        detached = "" if extras_alpha is None else "  (+ detached extras)"
        print(f"loaded {name}: {path.name}{detached}")

    canvas_height = max(f["alpha"].shape[0] for f in frames)
    canvas_width = max(f["alpha"].shape[1] for f in frames)
    for frame in frames:
        pad_to_canvas(frame, canvas_height, canvas_width)

    # Align every frame onto the first.
    reference = frames[0]["alpha"]
    for frame in frames[1:]:
        (dy, dx), band, residual = find_offset(reference, frame["alpha"])
        if (dy, dx) != (0, 0):
            frame["rgb"] = shift(frame["rgb"], dy, dx)
            frame["alpha"] = shift(frame["alpha"], dy, dx)
            if frame["extras"] is not None:
                frame["extras"] = shift(frame["extras"], dy, dx)
        print(
            f"aligned {frame['name']}: dy={dy:+d} dx={dx:+d} "
            f"(matched on {band}, residual {residual:.1%})"
        )
        # Translation the aligner can fix; a scale mismatch it cannot. If even
        # the best-matching band still disagrees this much, the frame is drawn
        # at a different size and needs regenerating, not nudging.
        if residual > SCALE_SUSPECT:
            print(
                f"  warning: {frame['name']} still mismatches by {residual:.1%} after "
                "aligning — likely drawn at a different scale, regenerate it"
            )

    # One shared canvas so the frames stack pixel-for-pixel in the browser.
    union = np.zeros_like(reference, dtype=bool)
    for frame in frames:
        union |= frame["alpha"] > 0.02
        if frame["extras"] is not None:
            union |= frame["extras"] > 0.02
    rows, cols = np.where(union)
    pad = 4
    top = max(rows.min() - pad, 0)
    bottom = min(rows.max() + pad + 1, union.shape[0])
    left = max(cols.min() - pad, 0)
    right = min(cols.max() + pad + 1, union.shape[1])
    print(f"shared canvas: {right - left}x{bottom - top} (from {union.shape[1]}x{union.shape[0]})")

    for frame in frames:
        crop = lambda a: a[top:bottom, left:right]
        print(f"{frame['name']}:")
        export(to_image(crop(frame["rgb"]), crop(frame["alpha"])), frame["name"])
        if frame["extras"] is not None:
            export(to_image(crop(frame["rgb"]), crop(frame["extras"])), f"{frame['name']}-extras")


if __name__ == "__main__":
    main(sys.argv[1:])
