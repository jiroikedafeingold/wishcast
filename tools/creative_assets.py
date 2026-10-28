#!/usr/bin/env python3
"""
Sunnyside's App Store creative assets (product page header, search results image, universal asset).

One text-free scene, rendered at each size: a storm on the left (dark clouds, rain) giving way to the
app's deep sky blue and a glowing sun on the right, the sunny side. It uses the same soft, irregular
sun and uneven rays as the app's backgrounds. With no text, it needs no localization; the App Store
shows the name and icon beside it. The story (storm turning to sun) sits inside each format's
centered safe area, so device crops never lose it.

    python3 tools/creative_assets.py        # writes fastlane/creative_assets/*.png

Requires Pillow. Deterministic: the same seed gives the same art every time.
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "fastlane", "creative_assets")

# name: (width, height, safe width, safe height, safe-area center y as a fraction of the height)
FORMATS = {
    "universal_5244x2950": (5244, 2950, 1402, 962, 0.45),
    "header_3840x1646": (3840, 1646, 1646, 661, 0.5),
    "search_3840x2560": (3840, 2560, 2168, 1030, 0.5),
}

STORM_TOP, STORM_BOTTOM = (34, 37, 44), (58, 62, 71)
SKY_TOP, SKY_BOTTOM = (28, 98, 205), (92, 158, 236)  # the app's sunny blue, deeper overhead
WARM = (255, 226, 150)


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def vertical_gradient(size, top, bottom):
    strip = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        strip.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return strip.resize(size, Image.BILINEAR)


def horizontal_mask(size, start, end):
    """0 left of `start`, 1 right of `end`, a smooth ramp between (in pixels)."""
    w, h = size
    strip = Image.new("L", (w, 1))
    for x in range(w):
        strip.putpixel((x, 0), int(255 * smoothstep((x - start) / max(end - start, 1))))
    return strip.resize(size, Image.NEAREST)


def radial_mask(size, center, radius, power=1.0):
    """255 at `center`, fading to 0 at `radius`."""
    base = Image.radial_gradient("L").point(lambda v: int(255 * max(0, 1 - v / 128) ** power))  # 256px, 0 at r=128
    d = int(radius * 2)
    blob = base.resize((d, d), Image.BILINEAR)
    mask = Image.new("L", size, 0)
    mask.paste(blob, (int(center[0] - radius), int(center[1] - radius)))
    return mask


def add_light(image, mask, color, strength):
    layer = Image.new("RGB", image.size, color)
    return Image.composite(layer, image, mask.point(lambda v: int(v * strength)))


def wobbly_circle(center, radius, wobble, seed):
    points = []
    for i in range(180):
        a = i / 180 * 2 * math.pi
        wave = 0.6 * math.sin(3 * a + seed) + 0.4 * math.sin(5 * a + seed * 1.7) + 0.3 * math.sin(8 * a + seed * 2.3)
        r = radius * (1 + wobble * wave / 1.3)
        points.append((center[0] + math.cos(a) * r, center[1] + math.sin(a) * r))
    return points


def cloud_mask(size, center, width, rng, puffs=11):
    """A billowy cloud: a soft base with two rows of overlapping puffs of varied size."""
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    cx, cy = center
    base_h = width * 0.14
    draw.ellipse((cx - width / 2, cy - base_h / 2, cx + width / 2, cy + base_h / 2), fill=255)
    for row, (count, rise, scale) in enumerate([(puffs, 0.45, 1.0), (max(3, puffs // 2), 1.1, 0.75)]):
        span = width * (1 - 0.3 * row)
        for i in range(count):
            t = (i + rng.uniform(0.2, 0.8)) / count
            px = cx - span / 2 + t * span
            r = width * (0.07 + 0.13 * math.sin(math.pi * t)) * scale * rng.uniform(0.75, 1.25)
            py = cy - r * rise * rng.uniform(0.7, 1.1)
            draw.ellipse((px - r, py - r, px + r, py + r), fill=255)
    return mask.filter(ImageFilter.GaussianBlur(width * 0.025))


def draw_cloud(image, center, width, rng, top, bottom, sun, lit, alpha, puffs=11):
    """Paints a cloud shaded light on top and dark underneath, glowing softly on the side facing the sun."""
    W, H = image.size
    mask = cloud_mask((W, H), center, width, rng, puffs)
    color = Image.new("RGB", (W, H), bottom)
    y0, y1 = int(center[1] - width * 0.45), int(center[1] + width * 0.1)
    if y1 > y0:
        color.paste(vertical_gradient((W, y1 - y0), top, bottom), (0, y0))
        color.paste(Image.new("RGB", (W, max(y0, 0)), top), (0, 0))
    image = Image.composite(color, image, mask.point(lambda v: int(v * alpha)))
    # The side facing the sun: the cloud minus a copy shifted toward the sun, blurred into a glow.
    dx, dy = sun[0] - center[0], sun[1] - center[1]
    dist = max(math.hypot(dx, dy), 1)
    shift = width * 0.09
    away = ImageChops.offset(mask, int(-dx / dist * shift), int(-dy / dist * shift))
    glow = ImageChops.subtract(mask, away).filter(ImageFilter.GaussianBlur(width * 0.05))
    return add_light(image, ImageChops.multiply(glow, mask), (255, 222, 165), lit)


def render(width, height, safe_w, safe_h, safe_cy):
    # Work at half size; everything here is soft, and it keeps big blurs fast.
    s = 0.5
    W, H = int(width * s), int(height * s)
    u = safe_h * s  # the size of the focal story
    cx, cy = W / 2, H * safe_cy
    sun = (cx + 0.27 * safe_w * s, cy - 0.08 * u)
    rng = random.Random(0x5A11)

    # Sky: storm on the left, deep blue on the right, the change happening inside the safe area.
    storm = vertical_gradient((W, H), STORM_TOP, STORM_BOTTOM)
    sky = vertical_gradient((W, H), SKY_TOP, SKY_BOTTOM)
    toward_sun = horizontal_mask((W, H), cx - 0.55 * safe_w * s, cx + 0.1 * safe_w * s)
    image = Image.composite(sky, storm, toward_sun)

    # Wide warm glow around the sun, reaching a little into the storm.
    image = add_light(image, radial_mask((W, H), sun, 2.6 * u, power=1.6), (255, 214, 130), 0.55)

    # Rain under the storm, fading out toward the sun.
    rain = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(rain)
    for _ in range(int(2200 * W * H / (2622 * 1475))):
        x = rng.uniform(-0.05, 0.75) * W
        y = rng.uniform(0.05, 1.0) * H
        length = rng.uniform(0.018, 0.04) * H
        draw.line((x, y, x + length * 0.18, y + length), fill=rng.randint(90, 170), width=max(1, int(W / 1300)))
    rain = ImageChops.multiply(rain, ImageChops.invert(horizontal_mask((W, H), cx - 0.75 * safe_w * s, cx - 0.05 * safe_w * s)))
    image = add_light(image, rain, (170, 192, 225), 0.55)

    # Shafts of sunlight: wide hazy beams and fine filaments, uneven, mostly over the blue side.
    for count, (lo, hi), blur, peak in [(18, (0.03, 0.09), 0.06, 0.42), (16, (0.008, 0.02), 0.025, 0.4)]:
        rays = Image.new("L", (W, H), 0)
        draw = ImageDraw.Draw(rays)
        reach = math.hypot(W, H)
        for _ in range(count):
            angle = rng.uniform(0, 2 * math.pi)
            half = rng.uniform(lo, hi)
            length = reach * rng.uniform(0.35, 0.9)
            bend = rng.uniform(-0.03, 0.03)
            pts = [(sun[0] + math.cos(angle) * u * 0.1, sun[1] + math.sin(angle) * u * 0.1)]
            for j in range(1, 9):
                d = length * j / 8
                pts.append((sun[0] + math.cos(angle - half + bend * j / 8) * d, sun[1] + math.sin(angle - half + bend * j / 8) * d))
            for j in range(8, 0, -1):
                d = length * j / 8
                pts.append((sun[0] + math.cos(angle + half + bend * j / 8) * d, sun[1] + math.sin(angle + half + bend * j / 8) * d))
            draw.polygon(pts, fill=int(255 * rng.uniform(0.35, 1)))
        rays = rays.filter(ImageFilter.GaussianBlur(u * blur))
        rays = ImageChops.multiply(rays, radial_mask((W, H), sun, reach * 0.75, power=0.9))
        rays = ImageChops.multiply(rays, horizontal_mask((W, H), cx - 0.6 * safe_w * s, cx + 0.15 * safe_w * s).point(lambda v: 50 + v * 205 // 255))
        image = add_light(image, rays, WARM, peak)

    # Storm clouds: layered across the left, back rows darker; they stop short of the sun.
    limit = sun[0] - 0.75 * u  # the storm's leading edge, reaching into the safe area
    for row in range(3):
        for _ in range(4 - row):
            w = rng.uniform(1.5, 2.6) * u * (1.15 - row * 0.15)
            x = min(rng.uniform(-0.1, 0.55) * W, limit - w * 0.45)
            y = rng.uniform(0.0, 0.7) * H + row * 0.08 * H
            shade = 46 + row * 16 + rng.randint(-5, 5)
            image = draw_cloud(image, (x, y), w, rng,
                               top=(shade + 34, shade + 38, shade + 48), bottom=(shade - 12, shade - 9, shade - 2),
                               sun=sun, lit=0.45, alpha=0.95)

    # A few bright fair-weather clouds drifting below the sun.
    for _ in range(3):
        x = sun[0] + rng.uniform(-0.5, 1.7) * u
        y = sun[1] + rng.uniform(0.85, 1.55) * u
        w = rng.uniform(0.7, 1.1) * u
        image = draw_cloud(image, (x, y), w, rng, top=(255, 255, 255), bottom=(196, 210, 232),
                           sun=sun, lit=0.3, alpha=0.95, puffs=9)

    # The sun: an uneven corona, then a softly edged, slightly irregular disc with an off-center hot core.
    r = 0.3 * u
    for i, (scale, blur, strength) in enumerate([(2.2, 0.7, 0.35), (1.55, 0.4, 0.5), (1.18, 0.16, 0.65)]):
        halo = Image.new("L", (W, H), 0)
        ImageDraw.Draw(halo).polygon(wobbly_circle(sun, r * scale, 0.07, i), fill=255)
        image = add_light(image, halo.filter(ImageFilter.GaussianBlur(r * blur)), (255, 205, 110), strength)
    disc = Image.new("L", (W, H), 0)
    ImageDraw.Draw(disc).polygon(wobbly_circle(sun, r, 0.025, 7), fill=255)
    disc = disc.filter(ImageFilter.GaussianBlur(r * 0.05))
    core = (sun[0] - r * 0.18, sun[1] + r * 0.15)
    ramp = radial_mask((W, H), core, r * 1.25, power=0.8)  # 255 at the core, 0 at the rim
    body = Image.merge("RGB", (
        Image.new("L", (W, H), 255),
        ramp.point(lambda v: int(190 + 60 * v / 255)),
        ramp.point(lambda v: int(80 + 150 * v / 255)),
    ))
    image = Image.composite(body, image, disc)

    return image.resize((width, height), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (w, h, sw, sh, scy) in FORMATS.items():
        image = render(w, h, sw, sh, scy).convert("RGB")  # no alpha channel, as Apple requires
        path = os.path.join(OUT, f"sunnyside_{name}.png")
        image.save(path, optimize=True)
        print(path, image.size)


if __name__ == "__main__":
    main()
