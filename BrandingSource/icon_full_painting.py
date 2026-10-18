"""Full-bleed painting icon, split into 3 parallax layers (sky / hills / wheat field)."""
import sys, numpy as np
from PIL import Image, ImageEnhance
from scipy.ndimage import gaussian_filter
sys.path.insert(0, __import__('os').path.dirname(__file__))
from painter import paint
W, H = 2560, 1536
HZ = 0.58
art = paint(W, H, seed=11, sun=(0.68, 0.30), horizon=HZ, stroke_scale=2.0, sun_r=0.10)
art = ImageEnhance.Contrast(ImageEnhance.Color(art).enhance(1.2)).enhance(1.06)
a = np.asarray(art, np.float32)
# gentle vignette so the icon reads well on the home screen
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
u, v = xx / W, yy / H
r = np.sqrt(((u - 0.5) * 1.0) ** 2 + ((v - 0.5) * 0.6) ** 2)
a *= np.clip(1.08 - r * 0.5, 0.8, 1.08)[..., None]
img = np.clip(a, 0, 255).astype(np.uint8)
far = HZ - 0.045 - 0.035 * np.sin(u * 7.0 + 1.2) - 0.02 * np.sin(u * 17 + 0.3)
near = HZ + 0.15 - 0.06 * np.sin(u * 2.1 + 0.6)
def mask(curve, off):
    m = (v > curve + off).astype(np.float32)
    return gaussian_filter(m, 3)
mid_m, front_m = mask(far, 0.012), mask(near, 0.015)
out = 'out'
import os; os.makedirs(out, exist_ok=True)
Image.fromarray(img).save(f'{out}/icon_back_master.png')
Image.fromarray(np.dstack([img, (mid_m * 255).astype(np.uint8)]), 'RGBA').save(f'{out}/icon_middle_master.png')
Image.fromarray(np.dstack([img, (front_m * 255).astype(np.uint8)]), 'RGBA').save(f'{out}/icon_front_master.png')
Image.fromarray(img).save(f'{out}/icon_preview.png')
Image.fromarray(img).resize((400, 240), Image.LANCZOS).save(f'{out}/i400.png')
print('ok')
