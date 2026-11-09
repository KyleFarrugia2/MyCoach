"""Build every app icon size from the supplied logo.

The source is a navy rounded tile on black corners. We:
  1. find the rounded-rect edge, fit the navy background gradient (linear in x, y) from clean background pixels,
  2. make a FULL-BLEED master: original interior kept as-is, corners/edge ring repainted with the fitted gradient,
  3. derive: iOS 1024 (opaque, full bleed), Android maskable (logo inside the 80% safe zone), rounded tiles with
     transparent corners for browser/desktop, favicon, apple-touch-icon, in-app logo.
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# Usage: python Scripts/make_icons.py docs/brand/logo-source.png web/public/icons \
#        MyCoach/Resources/Assets.xcassets/AppIcon.appiconset MyCoach/Resources/Assets.xcassets/AppLogo.imageset web/public
src, web_icons, ios_appicon, ios_logo_dir, web_public = sys.argv[1:6]
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float64)
H, W, _ = im.shape
assert H == W
N = W

# 1. Rounded-rect geometry: first non-black pixel along the diagonal → corner radius.
bright = im.sum(axis=2)
d = next(i for i in range(N // 2) if bright[i, i] > 30)
radius = d / (1 - 1 / np.sqrt(2))
inset = 3  # tile edge sits a few px in from the canvas edge
yy, xx = np.mgrid[0:N, 0:N].astype(np.float64)


def rounded_mask(size, r, margin):
    """True inside a rounded rect of corner radius r, shrunk by margin px."""
    lo, hi = margin, size - 1 - margin
    cx = np.clip(xx[:size, :size], lo + r, hi - r)
    cy = np.clip(yy[:size, :size], lo + r, hi - r)
    return (xx[:size, :size] - cx) ** 2 + (yy[:size, :size] - cy) ** 2 <= r * r


interior = rounded_mask(N, radius - 14, inset + 14)  # safely inside the tile, away from the edge highlight

# 2. Fit background gradient from interior pixels outside the glyph + shadow area.
glyph = (xx > 120) & (xx < N - 120) & (yy > 280) & (yy < N - 230)
sample = interior & ~glyph
A = np.stack([np.ones(sample.sum()), xx[sample] / N, yy[sample] / N], axis=1)
coef = {c: np.linalg.lstsq(A, im[..., c][sample], rcond=None)[0] for c in range(3)}
bg = np.stack([coef[c][0] + coef[c][1] * xx / N + coef[c][2] * yy / N for c in range(3)], axis=2)
resid = np.abs(im[sample] - bg[sample]).mean()
print(f"corner radius ~ {radius:.0f}px, gradient fit mean error {resid:.2f}/255")

# Full-bleed master: interior from the original, everything else from the fitted gradient, soft seam.
seam = Image.fromarray((interior * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))
alpha = np.asarray(seam).astype(np.float64)[..., None] / 255
master = np.clip(im * alpha + bg * (1 - alpha), 0, 255).astype(np.uint8)
master_img = Image.fromarray(master)


def gradient_canvas(size):
    s = np.mgrid[0:size, 0:size].astype(np.float64) / size
    return np.stack([coef[c][0] + coef[c][1] * s[1] + coef[c][2] * s[0] for c in range(3)], axis=2)


def maskable(size, scale=0.84):
    """Full-bleed canvas with the logo scaled into the Android safe zone (radius 40%)."""
    canvas = gradient_canvas(N)
    inner = int(round(N * scale))
    small = np.asarray(master_img.resize((inner, inner), Image.LANCZOS)).astype(np.float64)
    off = (N - inner) // 2
    # Feather the pasted square into the canvas so no seam shows.
    m = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(m).rounded_rectangle([8, 8, inner - 9, inner - 9], radius=inner // 6, fill=255)
    m = np.asarray(m.filter(ImageFilter.GaussianBlur(10))).astype(np.float64)[..., None] / 255
    region = canvas[off:off + inner, off:off + inner]
    canvas[off:off + inner, off:off + inner] = small * m + region * (1 - m)
    return Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8)).resize((size, size), Image.LANCZOS)


def rounded_tile(size):
    """Original look: rounded navy tile, transparent corners (browser tab, desktop, in-app logo)."""
    big = master_img.convert("RGBA")
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, N - 1, N - 1], radius=int(N * 0.225), fill=255)
    big.putalpha(m)
    return big.resize((size, size), Image.LANCZOS)


# iOS: opaque 1024 full bleed (iOS applies its own mask; alpha is rejected by App Store).
master_img.resize((1024, 1024), Image.LANCZOS).save(f"{ios_appicon}/AppIcon-1024.png", optimize=True)
# iOS in-app logo (onboarding welcome): rounded tile @1x/2x/3x.
for scale in (1, 2, 3):
    rounded_tile(96 * scale).save(f"{ios_logo_dir}/AppLogo{'' if scale == 1 else f'@{scale}x'}.png", optimize=True)

# Web / Android.
for s in (192, 512):
    rounded_tile(s).save(f"{web_icons}/icon-{s}.png", optimize=True)
    maskable(s).save(f"{web_icons}/maskable-{s}.png", optimize=True)
master_img.resize((180, 180), Image.LANCZOS).save(f"{web_icons}/apple-touch-icon.png", optimize=True)
rounded_tile(64).save(f"{web_icons}/favicon-64.png", optimize=True)
rounded_tile(256).save(f"{web_icons}/logo-256.png", optimize=True)

bgc = master[N // 2, 40]
print("splash/background colour #%02x%02x%02x" % tuple(int(v) for v in bgc))
