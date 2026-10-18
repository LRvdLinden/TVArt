"""Procedural impasto landscape painter for TVArt branding (original artwork)."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter, map_coordinates

def smooth_noise(W, H, scale, rng):
    small = rng.random((max(2, int(H / scale)) + 2, max(2, int(W / scale)) + 2))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0

def lerp(a, b, t):
    return a + (b - a) * t

def ramp(t, stops):
    """stops: list of (pos, (r,g,b)); t array -> rgb array"""
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,), np.float32)
    for (p0, c0), (p1, c1) in zip(stops[:-1], stops[1:]):
        m = (t >= p0) & (t <= p1)
        k = ((t - p0) / max(p1 - p0, 1e-6))[..., None]
        out[m] = (np.array(c0) + (np.array(c1) - np.array(c0)) * k)[m]
    return out

def paint(W, H, seed=3, sun=(0.70, 0.30), horizon=0.60, stroke_scale=1.0, sun_r=0.075):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = xx / W, yy / H
    aspect = W / H
    sx, sy = sun
    # ---------- base colour field ----------
    sky_t = v / horizon
    sky = ramp(sky_t, [(0.0, (18, 30, 92)), (0.35, (34, 68, 150)), (0.62, (70, 110, 170)),
                       (0.82, (226, 150, 82)), (1.0, (250, 206, 120))])
    dx, dy = (u - sx) * aspect, (v - sy)
    dist = np.sqrt(dx * dx + dy * dy)
    glow = np.exp(-(dist / (sun_r * 3.2)) ** 2)[..., None]
    sky = lerp(sky, np.array([255, 214, 120], np.float32), glow * 0.85)
    core = (dist < sun_r)[..., None]
    sky = np.where(core, np.array([255, 236, 150], np.float32), sky)
    ring = (np.abs(dist - sun_r * 1.55) < sun_r * 0.22)[..., None]
    sky = np.where(ring, lerp(sky, np.array([255, 196, 70], np.float32), 0.55), sky)

    n1 = smooth_noise(W, H, W / 7, rng)
    n2 = smooth_noise(W, H, W / 25, rng)
    # hills (far → near)
    far = horizon - 0.045 - 0.035 * np.sin(u * 7.0 + 1.2) - 0.02 * np.sin(u * 17 + 0.3)
    mid = horizon + 0.03 - 0.05 * np.sin(u * 3.4 + 2.2) - 0.015 * np.sin(u * 11)
    near = horizon + 0.15 - 0.06 * np.sin(u * 2.1 + 0.6)
    img = sky.copy()
    farc = ramp(n1, [(0, (78, 72, 138)), (1, (118, 96, 150))])
    midc = ramp(n1 * 0.6 + n2 * 0.4, [(0, (54, 96, 66)), (0.5, (112, 128, 62)), (1, (170, 150, 70))])
    field = ramp((v - near) / (1 - near) * 0.6 + n2 * 0.4,
                 [(0, (236, 182, 62)), (0.45, (220, 150, 44)), (0.75, (196, 112, 38)), (1, (150, 78, 34))])
    img = np.where((v > far)[..., None], farc, img)
    img = np.where((v > mid)[..., None], midc, img)
    img = np.where((v > near)[..., None], field, img)
    # a few dark trees on the mid hill
    trees = np.zeros((H, W), bool)
    for tx in []:
        ty = np.interp(tx, u[0], mid[0]) + 0.005
        r = 0.028 * rng.uniform(0.8, 1.3)
        trees |= (((u - tx) * aspect) ** 2 / (r * 0.75) ** 2 + (v - ty + r) ** 2 / r ** 2) < 1
    img = np.where(trees[..., None], np.array([28, 58, 42], np.float32), img)
    base = gaussian_filter(img, sigma=(H / 300, H / 300, 0))

    # ---------- flow field ----------
    tang = np.arctan2(dy, dx) + np.pi / 2
    swirl_w = np.exp(-(dist / 0.42) ** 2)
    wave = 0.35 * np.sin(u * 9 + v * 14 + n1 * 4) + (n2 - 0.5) * 0.8
    ang = np.where(v < horizon, lerp(wave, tang, swirl_w), 0.15 * np.sin(u * 5) + (n2 - 0.5) * 0.5)
    slope = np.gradient(mid[0])[None, :] * H  # follow the hill shape
    ang = np.where((v > far) & (v < near), np.arctan(slope / 1.0) * 0.6 + (n2 - .5) * .4, ang)
    ang = np.where(v > near, -1.2 + (n2 - 0.5) * 0.9, ang)

    # ---------- strokes ----------
    S = H / 1080 * stroke_scale
    canvas = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))
    hmap = Image.new("L", (W, H), 0)
    dc, dh = ImageDraw.Draw(canvas), ImageDraw.Draw(hmap)
    passes = [(int(W * H / (S * S) / 900 * 1.0), 22, 70), (int(W * H / (S * S) / 900 * 1.6), 14, 46),
              (int(W * H / (S * S) / 900 * 2.2), 8, 28)]
    for count, width, length in passes:
        for _ in range(count):
            x, y = rng.uniform(0, W), rng.uniform(0, H)
            w = max(2, width * S * rng.uniform(0.7, 1.25))
            L = length * S * rng.uniform(0.6, 1.4)
            if y > near[0, min(W - 1, int(x))] * H:  # field: shorter, chunkier
                L *= 0.6
            pts = [(x, y)]
            steps = 5
            for _ in range(steps):
                a = ang[int(np.clip(y, 0, H - 1)), int(np.clip(x, 0, W - 1))]
                x += np.cos(a) * L / steps
                y += np.sin(a) * L / steps
                pts.append((x, y))
            px, py = int(np.clip(pts[0][0], 0, W - 1)), int(np.clip(pts[0][1], 0, H - 1))
            c = base[py, px] * rng.uniform(0.86, 1.14) + rng.normal(0, 9, 3)
            c = tuple(int(v_) for v_ in np.clip(c, 0, 255))
            dc.line(pts, fill=c, width=int(w), joint="curve")
            hv = int(rng.uniform(90, 160))
            dh.line(pts, fill=hv, width=int(w), joint="curve")
            for (ex, ey) in (pts[0], pts[-1]):
                r_ = w / 2
                dc.ellipse((ex - r_, ey - r_, ex + r_, ey + r_), fill=c)
                dh.ellipse((ex - r_, ey - r_, ex + r_, ey + r_), fill=hv)
            dh.line(pts, fill=min(255, hv + 70), width=max(1, int(w * 0.35)), joint="curve")
    # poppies and little flowers in the wheat
    for _ in range(int(W * H / (S * S) / 17000)):
        x = rng.uniform(0, W)
        yn = near[0, min(W - 1, int(x))] * H
        y = rng.uniform(yn + 0.03 * H, H)
        depth = (y - yn) / (H - yn)
        r_ = (3 + 9 * depth) * S * rng.uniform(0.7, 1.3)
        c = (int(rng.uniform(200, 235)), int(rng.uniform(40, 70)), int(rng.uniform(25, 45))) if rng.random() < 0.9 else (238, 232, 214)
        for k in range(3):
            ox, oy = rng.normal(0, r_ * 0.5, 2)
            dc.ellipse((x + ox - r_, y + oy - r_ * 0.7, x + ox + r_, y + oy + r_ * 0.7), fill=c)
            dh.ellipse((x + ox - r_, y + oy - r_ * 0.7, x + ox + r_, y + oy + r_ * 0.7), fill=200)
    col = np.asarray(canvas, np.float32)
    hm = gaussian_filter(np.asarray(hmap, np.float32), 1.2 * S)
    gy, gx = np.gradient(hm)
    light = 1.0 + (-gx * -0.6 + -gy * -0.75) * 0.013 / max(S, 0.5)
    light = np.clip(light, 0.72, 1.35)[..., None]
    col = col * light
    # canvas weave
    weave = (np.sin(xx * 1.9) * np.sin(yy * 1.9)) * 4
    col = col + weave[..., None]
    return Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))

if __name__ == "__main__":
    import sys
    paint(1600, 900, stroke_scale=1.0).save(sys.argv[1])
