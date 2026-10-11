"""Generate Instagram profile-picture variants of the Hallowed Gains lettermark.

Instagram displays avatars as a circle cropped from a square upload, at
sizes down to ~32px in comments. The lettermark is tall (~0.6:1), so simply
dropping it on a square canvas either clips it in the circle or leaves it
tiny. This script instead:

  1. Uses the alpha channel of the master lettermark PNG as a shape mask,
     so any brand color can be applied without re-exporting from design tools.
  2. Finds the smallest circle that encloses every opaque pixel of the mark,
     then scales and positions the mark so that circle sits concentrically
     inside the avatar circle at SAFE_RATIO of its radius. This maximizes the
     mark's size while keeping uniform breathing room from the crop edge.
  3. Renders each color variant at 1080x1080 (Instagram's upload size; it
     downsamples to 320x320 for display), with a circular-crop preview.

Usage (from the repo root):
    python3 brand/instagram/make_avatars.py

Requires Pillow and NumPy.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parents[2]
MASTER_LOGO = REPO_ROOT / "HallowedGains_Logo_Lettermark_Gold.png"
OUTPUT_DIR = Path(__file__).resolve().parent

CANVAS_PX = 1080
# Fraction of the avatar circle's radius that the mark's enclosing circle
# may occupy. ~0.78 reads as "bold but not cramped" at small sizes.
SAFE_RATIO = 0.78
# Supersampling factor for smooth edges after downscaling.
SUPERSAMPLE = 2

# Brand colors. The first three match the official logo exports; ivory is the
# site's `ivory-50` background from index.html's Tailwind config.
GOLD = "#AE8F5D"
BURGUNDY = "#5D1D12"
NEAR_BLACK = "#190F0A"
IVORY = "#F7F3E3"

# (file stem, mark color, background color)
VARIANTS = [
    ("gold-on-black", GOLD, NEAR_BLACK),
    ("gold-on-burgundy", GOLD, BURGUNDY),
    ("ivory-on-burgundy", IVORY, BURGUNDY),
    ("burgundy-on-ivory", BURGUNDY, IVORY),
    ("black-on-ivory", NEAR_BLACK, IVORY),
]


def load_mask(path: Path) -> Image.Image:
    """Return the logo's alpha channel cropped tightly to the opaque shape."""
    alpha = Image.open(path).convert("RGBA").getchannel("A")
    return alpha.crop(alpha.getbbox())


def enclosing_circle(mask: Image.Image) -> tuple[float, float, float]:
    """Approximate the minimal enclosing circle of the mask's opaque pixels.

    Only boundary-relevant points matter, so we take the leftmost and
    rightmost opaque pixel of each row, then run a coarse-to-fine search for
    the center that minimizes the farthest-point distance. Accurate to well
    under a pixel at output resolution, which is all we need.

    Returns (center_x, center_y, radius) in mask pixel coordinates.
    """
    arr = np.asarray(mask) > 127
    rows = np.flatnonzero(arr.any(axis=1))
    xs_left = np.array([np.argmax(arr[y]) for y in rows])
    xs_right = np.array([arr.shape[1] - 1 - np.argmax(arr[y][::-1]) for y in rows])
    points = np.column_stack(
        [np.concatenate([xs_left, xs_right]), np.concatenate([rows, rows])]
    ).astype(float)

    def max_dist(cx: float, cy: float) -> float:
        return float(np.hypot(points[:, 0] - cx, points[:, 1] - cy).max())

    cx, cy = mask.width / 2, mask.height / 2
    step = max(mask.size) / 4
    while step > 0.5:
        candidates = [
            (cx + dx * step, cy + dy * step) for dx in (-1, 0, 1) for dy in (-1, 0, 1)
        ]
        best = min(candidates, key=lambda c: max_dist(*c))
        if best == (cx, cy):
            step /= 2
        cx, cy = best
    return cx, cy, max_dist(cx, cy)


def render_avatar(mask: Image.Image, circle, fg: str, bg: str) -> Image.Image:
    """Compose the recolored mark centered in a square avatar canvas."""
    size = CANVAS_PX * SUPERSAMPLE
    cx, cy, radius = circle
    scale = (size / 2 * SAFE_RATIO) / radius

    scaled = mask.resize(
        (round(mask.width * scale), round(mask.height * scale)), Image.LANCZOS
    )
    # Place the mark so its enclosing-circle center lands on the canvas center.
    offset = (round(size / 2 - cx * scale), round(size / 2 - cy * scale))

    canvas = Image.new("RGB", (size, size), bg)
    canvas.paste(Image.new("RGB", scaled.size, fg), offset, scaled)
    return canvas.resize((CANVAS_PX, CANVAS_PX), Image.LANCZOS)


def circle_preview(avatar: Image.Image) -> Image.Image:
    """Simulate Instagram's circular crop (transparent outside the circle)."""
    size = avatar.width * SUPERSAMPLE
    clip = Image.new("L", (size, size), 0)
    ImageDraw.Draw(clip).ellipse((0, 0, size - 1, size - 1), fill=255)
    clip = clip.resize(avatar.size, Image.LANCZOS)
    preview = avatar.convert("RGBA")
    preview.putalpha(clip)
    return preview


def main() -> None:
    mask = load_mask(MASTER_LOGO)
    circle = enclosing_circle(mask)
    preview_dir = OUTPUT_DIR / "previews"
    preview_dir.mkdir(exist_ok=True)

    for stem, fg, bg in VARIANTS:
        avatar = render_avatar(mask, circle, fg, bg)
        avatar.save(OUTPUT_DIR / f"hg-instagram-{stem}.png", optimize=True)
        circle_preview(avatar).save(preview_dir / f"{stem}-circle.png", optimize=True)
        print(f"wrote hg-instagram-{stem}.png")


if __name__ == "__main__":
    main()
