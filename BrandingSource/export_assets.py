"""Writes the generated brand imagery into TVArt/Assets.xcassets in Xcode's tvOS layout."""
import json, os, shutil, sys
from PIL import Image

SRC, XC = sys.argv[1], sys.argv[2]
INFO = {"author": "xcode", "version": 1}

def w(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)

def save(img, path, size, opaque=False):
    im = img.resize(size, Image.LANCZOS)
    if opaque:
        im = im.convert("RGB")
    im.save(path, optimize=True)

shutil.rmtree(XC, ignore_errors=True)
w(f"{XC}/Contents.json", {"info": INFO})

BA = f"{XC}/App Icon & Top Shelf Image.brandassets"
w(f"{BA}/Contents.json", {"assets": [
    {"filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"},
    {"filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"},
    {"filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"},
    {"filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"},
], "info": INFO})

layers = {n: Image.open(f"{SRC}/icon_{n.lower()}_master.png") for n in ("Front", "Middle", "Back")}
for stack, idiom, sizes in (("App Icon", "tv", [("1x", (400, 240)), ("2x", (800, 480))]),
                            ("App Icon - App Store", "tv-marketing", [("1x", (1280, 768)), ("2x", (2560, 1536))])):
    sp = f"{BA}/{stack}.imagestack"
    w(f"{sp}/Contents.json", {"info": INFO, "layers": [{"filename": f"{n}.imagestacklayer"} for n in ("Front", "Middle", "Back")]})
    for n, img in layers.items():
        lp = f"{sp}/{n}.imagestacklayer"
        w(f"{lp}/Contents.json", {"info": INFO})
        imgs = []
        for scale, size in sizes:
            fn = f"{n.lower()}{'' if scale == '1x' else '@2x'}.png"
            os.makedirs(f"{lp}/Content.imageset", exist_ok=True)
            save(img, f"{lp}/Content.imageset/{fn}", size, opaque=(n == "Back"))
            imgs.append({"filename": fn, "idiom": idiom, "scale": scale})
        w(f"{lp}/Content.imageset/Contents.json", {"images": imgs, "info": INFO})

for name, src, s1 in (("Top Shelf Image", "topshelf_2x", (1920, 720)), ("Top Shelf Image Wide", "topshelfwide_2x", (2320, 720))):
    p = f"{BA}/{name}.imageset"
    os.makedirs(p, exist_ok=True)
    img = Image.open(f"{SRC}/{src}.png").convert("RGB")
    base = name.lower().replace(" ", "_")
    save(img, f"{p}/{base}.png", s1, True)
    save(img, f"{p}/{base}@2x.png", (s1[0] * 2, s1[1] * 2), True)
    w(f"{p}/Contents.json", {"images": [{"filename": f"{base}.png", "idiom": "tv", "scale": "1x"},
                                         {"filename": f"{base}@2x.png", "idiom": "tv", "scale": "2x"}], "info": INFO})

# Splash / hero artwork
p = f"{XC}/SplashArt.imageset"
os.makedirs(p, exist_ok=True)
art = Image.open(f"{SRC}/splash_art.png").convert("RGB")
art.resize((1920, 1080), Image.LANCZOS).save(f"{p}/splash_art.jpg", quality=88)
art.save(f"{p}/splash_art@2x.jpg", quality=86)
w(f"{p}/Contents.json", {"images": [{"filename": "splash_art.jpg", "idiom": "tv", "scale": "1x"},
                                     {"filename": "splash_art@2x.jpg", "idiom": "tv", "scale": "2x"}], "info": INFO})

def color(name, r, g, b):
    w(f"{XC}/{name}.colorset/Contents.json", {"colors": [{"color": {"color-space": "srgb", "components": {
        "alpha": "1.000", "red": f"{r:.3f}", "green": f"{g:.3f}", "blue": f"{b:.3f}"}}, "idiom": "universal"}], "info": INFO})

color("LaunchBackground", 0.035, 0.030, 0.035)
color("AccentColor", 0.860, 0.700, 0.380)
print("assets written")
