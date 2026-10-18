"""Builds all TVArt brand imagery: layered tvOS icon, top shelf, splash art."""
import sys, os, json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageEnhance
from scipy.ndimage import gaussian_filter
sys.path.insert(0, os.path.dirname(__file__))
from painter import paint, ramp

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
os.makedirs(OUT, exist_ok=True)
FONT = os.path.join(os.path.dirname(__file__), "..", "TVArt", "Fonts", "CormorantGaramond-SemiBold.ttf")
FONT_M = os.path.join(os.path.dirname(__file__), "..", "TVArt", "Fonts", "CormorantGaramond-Medium.ttf")

GOLD = [(0.0, (46, 28, 8)), (0.25, (112, 72, 22)), (0.5, (176, 128, 46)),
        (0.72, (222, 178, 88)), (0.9, (250, 222, 140)), (1.0, (255, 244, 205))]

def profile(t):
    h = np.zeros_like(t)
    a = t < 0.12; h[a] = 0.62 * np.sin(np.pi / 2 * t[a] / 0.12)
    b = (t >= 0.12) & (t < 0.23); h[b] = 0.62 + 0.16 * np.sin(np.pi * (t[b] - 0.12) / 0.11)
    c = (t >= 0.23) & (t < 0.55); h[c] = 0.42 + 0.42 * ((t[c] - 0.39) / 0.16) ** 2
    d = (t >= 0.55) & (t < 0.82); h[d] = 0.84 + 0.30 * np.sin(np.pi * (t[d] - 0.55) / 0.27)
    e = (t >= 0.82) & (t < 0.88); h[e] = 0.84 - 0.25 * (t[e] - 0.82) / 0.06
    f = t >= 0.88; h[f] = 0.59 - 0.45 * (t[f] - 0.88) / 0.12
    return h

def frame_layer(W, H, rect, fw, seed=1):
    """Gilded picture frame as RGBA, transparent inside and outside."""
    x0, y0, x1, y1 = rect
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dl, dr, dt, db = xx - x0, x1 - xx, yy - y0, y1 - yy
    d = np.minimum(np.minimum(dl, dr), np.minimum(dt, db))
    inside = (d >= 0) & (d <= fw)
    t = np.clip(d / fw, 0, 1)
    # coordinate along the moulding (for beads / ornament)
    horiz = np.minimum(dt, db) < np.minimum(dl, dr)
    s = np.where(horiz, xx, yy)
    h = profile(t)
    bead_band = (t >= 0.12) & (t < 0.23)
    P = fw * 0.16
    h += np.where(bead_band, 0.10 * np.abs(np.sin(np.pi * s / P)) - 0.05, 0)
    cove = (t >= 0.25) & (t < 0.53)
    P2 = fw * 0.42
    leaf = np.sin(2 * np.pi * s / P2) * np.sin(np.pi * (t - 0.25) / 0.28)
    h += np.where(cove, 0.09 * np.clip(leaf, -0.2, 1), 0)
    rng = np.random.default_rng(seed)
    h += gaussian_filter(rng.random((H, W)).astype(np.float32), 1.2) * 0.04
    hs = gaussian_filter(h, 0.8) * fw * 0.32
    gy, gx = np.gradient(hs)
    n = np.dstack([-gx, -gy, np.ones_like(gx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    L = np.array([-0.42, -0.62, 0.66]); L /= np.linalg.norm(L)
    V = np.array([0, 0, 1.0]); Hv = (L + V) / np.linalg.norm(L + V)
    diff = np.clip(n @ L, 0, 1)
    spec = np.clip(n @ Hv, 0, 1) ** 38
    ao = np.clip(0.55 + 0.6 * profile(t), 0.4, 1.05)
    tone = np.clip(diff * 0.95 * ao + 0.08, 0, 1)
    col = ramp(tone, GOLD) + spec[..., None] * np.array([255, 235, 190]) * 0.75
    # worn bole (red clay) showing through on raised edges
    wear = gaussian_filter(rng.random((H, W)).astype(np.float32), fw * 0.05)
    wear = np.clip((wear - 0.53) * 18, 0, 1) * (h > 0.95)
    col = col * (1 - wear[..., None] * 0.35) + np.array([120, 40, 25]) * wear[..., None] * 0.35
    # darker linen-ish sight edge
    col = np.where((t > 0.93)[..., None], col * 0.62, col)
    alpha = inside.astype(np.float32)
    # anti-aliased edges
    edge = np.clip(np.minimum(d + 0.5, fw - d + 0.5), 0, 1)
    alpha = np.where(inside | (edge > 0), edge, 0) * (d > -1)
    rgba = np.dstack([np.clip(col, 0, 255), alpha * 255]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")

def wall(W, H, spot=(0.5, -0.15), seed=5, base=(58, 16, 24)):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = xx / W, yy / H
    # spotlight cone from above
    dx = (u - spot[0]) * W / H
    dy = v - spot[1]
    r = np.sqrt(dx * dx * 1.6 + dy * dy)
    light = 0.38 + 1.05 * np.exp(-(r / 0.95) ** 2)
    tex = gaussian_filter(rng.random((H, W)).astype(np.float32), 1.0) * 0.10 + \
          gaussian_filter(rng.random((H, W)).astype(np.float32), H / 60) * 0.6
    col = np.array(base, np.float32)[None, None, :] * (light * (0.92 + tex))[..., None]
    return col

def paste_shadow(col, rect, blur, offset, strength):
    H, W = col.shape[:2]
    m = Image.new("L", (W, H), 0)
    x0, y0, x1, y1 = rect
    ImageDraw.Draw(m).rectangle((x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]), fill=255)
    m = np.asarray(m.filter(ImageFilter.GaussianBlur(blur)), np.float32) / 255
    return col * (1 - m[..., None] * strength)

def icon(master_w=2560, master_h=1536):
    W, H = master_w, master_h
    mx, my = int(W * 0.105), int(H * 0.125)
    rect = (mx, my, W - mx, H - my)
    fw = int(H * 0.095)
    # back: museum wall + frame shadow
    back = wall(W, H, spot=(0.5, -0.25))
    back = paste_shadow(back, rect, blur=H * 0.035, offset=(int(H * 0.015), int(H * 0.04)), strength=0.75)
    back = Image.fromarray(np.clip(back, 0, 255).astype(np.uint8))
    # middle: the painting, extended under the frame
    ext = int(fw * 0.65)
    px0, py0, px1, py1 = rect[0] + fw - ext, rect[1] + fw - ext, rect[2] - fw + ext, rect[3] - fw + ext
    pw, ph = px1 - px0, py1 - py0
    art = paint(pw, ph, seed=11, sun=(0.66, 0.33), horizon=0.60, stroke_scale=2.1, sun_r=0.09)
    art = ImageEnhance.Contrast(ImageEnhance.Color(art).enhance(1.22)).enhance(1.08)
    a = np.asarray(art, np.float32)
    # warm picture-light from above
    a = a * (1.12 - 0.22 * np.linspace(0, 1, ph))[:, None, None]
    # inner shadow cast by the frame on the canvas
    yy, xx = np.mgrid[0:ph, 0:pw].astype(np.float32)
    dmin = np.minimum(np.minimum(xx - ext, pw - ext - xx), np.minimum(yy - ext, ph - ext - yy))
    sh = np.clip(1 - np.exp(-np.clip(dmin, 0, None) / (fw * 0.25)), 0, 1) * 0.55 + 0.45
    top = np.clip((yy - ext) / (fw * 0.45), 0, 1) * 0.25 + 0.75
    a = a * (sh * top)[..., None]
    mid = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mid.paste(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)), (px0, py0))
    # front: gilded frame
    front = frame_layer(W, H, rect, fw)
    return back, mid, front

def composite(layers):
    out = layers[0].convert("RGBA")
    for l in layers[1:]:
        out = Image.alpha_composite(out, l)
    return out.convert("RGB")

def wordmark(img, x, y, size, tag=None, tag_size=None):
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, size)
    # gold gradient text via mask
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).text((x, y), "TVArt", font=f, fill=255)
    bbox = mask.getbbox()
    grad = Image.new("RGB", img.size)
    gy = np.linspace(0, 1, img.size[1])[:, None].repeat(img.size[0], 1)
    t = np.clip((gy * img.size[1] - bbox[1]) / max(1, bbox[3] - bbox[1]), 0, 1)
    g = ramp(1 - t * 0.7, GOLD)
    grad = Image.fromarray(g.astype(np.uint8))
    shadow = mask.filter(ImageFilter.GaussianBlur(size * 0.06))
    img.paste(Image.new("RGB", img.size, (0, 0, 0)), (0, 0), shadow.point(lambda p: int(p * 0.7)))
    img.paste(grad, (0, 0), mask)
    if tag:
        ft = ImageFont.truetype(FONT_M, tag_size)
        ty = bbox[3] + int(size * 0.18)
        d.line((x + size * 0.04, ty, x + size * 0.04 + size * 0.9, ty), fill=(214, 172, 92), width=max(2, size // 60))
        d.text((x + size * 0.04, ty + int(size * 0.12)), tag, font=ft, fill=(236, 226, 206))
    return img

def topshelf(W, H, seed):
    art = paint(W, H, seed=seed, sun=(0.74, 0.34), horizon=0.62, stroke_scale=1.15, sun_r=0.11)
    art = ImageEnhance.Color(art).enhance(1.12)
    a = np.asarray(art, np.float32)
    u = np.linspace(0, 1, W)[None, :]
    shade = np.clip(1 - (0.62 - u) / 0.62, 0, 1) ** 1.4 * 0.75 + 0.25
    shade = np.where(u > 0.62, 1.0, shade)
    a = a * shade[..., None]
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    return wordmark(img, int(W * 0.06), int(H * 0.20), int(H * 0.36),
                    tag="Meesterwerken op je grootste scherm", tag_size=int(H * 0.075))

if __name__ == "__main__":
    which = sys.argv[2] if len(sys.argv) > 2 else "all"
    if which in ("all", "icon"):
        b, m, f = icon()
        for name, im in (("back", b), ("middle", m), ("front", f)):
            im.save(f"{OUT}/icon_{name}_master.png")
        composite([b, m, f]).save(f"{OUT}/icon_preview.png")
    if which in ("all", "shelf"):
        topshelf(3840, 1440, 21).save(f"{OUT}/topshelf_2x.png")
        topshelf(4640, 1440, 21).save(f"{OUT}/topshelfwide_2x.png")
    if which in ("all", "splash"):
        paint(3840, 2160, seed=7, sun=(0.68, 0.30), horizon=0.60, stroke_scale=1.0, sun_r=0.07).save(f"{OUT}/splash_art.png")
