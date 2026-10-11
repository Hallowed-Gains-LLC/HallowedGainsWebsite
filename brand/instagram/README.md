# Instagram profile pictures

Square 1080×1080 PNGs of the Hallowed Gains lettermark, sized for Instagram's
circular avatar crop. Upload any `hg-instagram-*.png` directly; Instagram
downsamples to 320×320 for display.

| File | Mark | Background | Notes |
| --- | --- | --- | --- |
| `hg-instagram-gold-on-black.png` | Gold `#AE8F5D` | Near-black `#190F0A` | Recommended: highest contrast for the gold, reads well at 32px |
| `hg-instagram-gold-on-burgundy.png` | Gold | Burgundy `#5D1D12` | Warmer, lower contrast at tiny sizes |
| `hg-instagram-ivory-on-burgundy.png` | Ivory `#F7F3E3` | Burgundy | Strongest small-size legibility on a colored field |
| `hg-instagram-burgundy-on-ivory.png` | Burgundy | Ivory | Light option, matches the website palette |
| `hg-instagram-black-on-ivory.png` | Near-black | Ivory | Light, neutral option |

`previews/` shows each variant with the circular crop applied, so you can
check the fit without uploading.

## How the layout is computed

The mark is tall (~0.6:1), so naive centering either clips it in the circle or
leaves it small. `make_avatars.py` finds the smallest circle enclosing the
mark's opaque pixels and scales the mark so that circle fills 78%
(`SAFE_RATIO`) of the avatar's radius, concentric with it. That keeps uniform
breathing room from the crop edge while making the mark as large as possible.

The shape comes from the alpha channel of the master
`HallowedGains_Logo_Lettermark_Gold.png` at the repo root, so new color
combinations need no design-tool export.

## Regenerating

```sh
python3 brand/instagram/make_avatars.py   # needs Pillow + NumPy
```

Edit `VARIANTS` to add colors, or `SAFE_RATIO` to change the padding.

This folder is excluded from Firebase Hosting (`firebase.json` → `ignore`), so
it never ships with the website.
