#!/usr/bin/env python3
"""High-res gallery showcase art for Monster Merge (v1.2, Worker D).

Draws one large polished 1024x1024 PNG per tier in assets/gallery/
tier1.png .. tier8.png with PIL: a big detailed version of that tier's
creature on a bright sky background, with its name banner and tier badge.
Drawn at 2x and downscaled for smooth edges.

Usage:  python3 tools/generate_gallery_art.py
Requires: Pillow (pip install pillow)
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT_DIR = os.path.join(ROOT, "assets", "gallery")

SIZE = 1024
SS = 2  # supersample factor

TIERS = [
    # name, body, dark, light, belly, sky top, sky bottom
    ("Blue Spotted Egg", (73, 169, 237), (40, 120, 190), (140, 205, 250),
     (190, 225, 250), (135, 206, 250), (255, 248, 223)),
    ("Cute Green Slime", (114, 214, 78), (70, 170, 45), (170, 240, 130),
     (210, 250, 180), (120, 200, 250), (255, 248, 223)),
    ("Baby Green Dino", (131, 201, 77), (85, 155, 45), (180, 235, 130),
     (220, 245, 180), (140, 210, 250), (255, 248, 223)),
    ("Winged Flame Wyrm", (242, 118, 66), (190, 70, 30), (255, 170, 110),
     (255, 210, 160), (255, 170, 90), (255, 220, 180)),
    ("Golden Phoenix", (246, 200, 68), (200, 140, 30), (255, 225, 140),
     (255, 240, 190), (255, 200, 110), (255, 240, 200)),
    ("Crystal Unicorn", (140, 232, 239), (90, 180, 200), (190, 245, 250),
     (225, 250, 255), (160, 220, 250), (255, 248, 223)),
    ("Robo-Rex", (137, 149, 168), (90, 100, 120), (180, 195, 215),
     (210, 220, 235), (120, 180, 230), (230, 240, 250)),
    ("Cosmic King Dragon", (155, 107, 219), (105, 60, 170), (200, 160, 250),
     (230, 200, 255), (120, 80, 200), (200, 170, 255)),
]

BG_DECO = ["#ffffff", "#ffd93d", "#ff8fab"]


def font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def ellipse(d, box, fill, outline=None, width=1):
    d.ellipse(box, fill=fill, outline=outline, width=width)


def eye(d, cx, cy, r, look=(0, 0)):
    ellipse(d, [cx - r, cy - r, cx + r, cy + r], (38, 55, 76))
    ellipse(d, [cx - r * 0.45 + look[0], cy - r * 0.45 + look[1],
                cx + r * 0.25 + look[0], cy + r * 0.25 + look[1]], (255, 255, 255))
    ellipse(d, [cx + r * 0.35, cy + r * 0.35, cx + r * 0.6, cy + r * 0.6],
            (255, 255, 255))


def sparkle(d, cx, cy, r, color):
    pts = [(cx, cy - r), (cx + r * 0.28, cy - r * 0.28), (cx + r, cy),
           (cx + r * 0.28, cy + r * 0.28), (cx, cy + r),
           (cx - r * 0.28, cy + r * 0.28), (cx - r, cy),
           (cx - r * 0.28, cy - r * 0.28)]
    d.polygon(pts, fill=color)


def star(d, cx, cy, r, color):
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    d.polygon(pts, fill=color)


def background(d, w, top, bottom, rng):
    # Vertical gradient sky.
    for y in range(w):
        t = y / w
        col = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=col)
    # Sun with rays.
    sx, sy, sr = w * 0.82, w * 0.16, w * 0.085
    for i in range(12):
        ang = i * math.pi / 6
        d.line([(sx + math.cos(ang) * (sr + 12), sy + math.sin(ang) * (sr + 12)),
                (sx + math.cos(ang) * (sr + 52), sy + math.sin(ang) * (sr + 52))],
               fill=(255, 220, 90), width=10)
    ellipse(d, [sx - sr, sy - sr, sx + sr, sy + sr], (255, 214, 64),
            (255, 180, 40), 6)
    # Clouds.
    for (cx, cy, s) in [(w * 0.2, w * 0.18, 90), (w * 0.45, w * 0.10, 70),
                        (w * 0.12, w * 0.38, 60)]:
        for dx, dy, r in ((-s, 0, s * 0.55), (0, -s * 0.25, s * 0.6),
                          (s, 0, s * 0.5), (0, s * 0.15, s * 0.55)):
            ellipse(d, [cx + dx - r, cy + dy - r, cx + dx + r, cy + dy + r],
                    (255, 255, 255))
    # Rolling green hill + ground shadow handled by creature draw.
    d.ellipse([-w * 0.2, w * 0.78, w * 1.2, w * 1.25], fill=(139, 214, 120))
    d.ellipse([-w * 0.2, w * 0.80, w * 1.2, w * 1.22], fill=(110, 200, 95))


def banner(d, w, name, tier):
    # Name banner at the bottom + tier badge top-left.
    bw, bh = w * 0.86, w * 0.115
    bx, by = (w - bw) / 2, w * 0.845
    d.rounded_rectangle([bx, by, bx + bw, by + bh], radius=28,
                        fill=(255, 248, 223), outline=(255, 201, 60), width=6)
    f = font(int(w * 0.048))
    tw = d.textlength(name, font=f)
    d.text(((w - tw) / 2, by + bh * 0.16), name, font=f, fill=(39, 55, 82))
    # Tier badge.
    badge_r = w * 0.075
    cx, cy = w * 0.10, w * 0.10
    ellipse(d, [cx - badge_r, cy - badge_r, cx + badge_r, cy + badge_r],
            (255, 201, 60), (183, 110, 20), 5)
    f2 = font(int(w * 0.052))
    label = f"TIER {tier}"
    tw2 = d.textlength(label, font=f2)
    d.text((cx - tw2 / 2, cy - w * 0.028), label, font=f2, fill=(113, 67, 25))
    # Sparkles scattered.
    rng = random.Random(tier * 7)
    for _ in range(14):
        x = rng.uniform(w * 0.06, w * 0.94)
        y = rng.uniform(w * 0.06, w * 0.78)
        sparkle(d, x, y, rng.uniform(8, 20), (255, 255, 255))


def draw_creature(d, w, tier, body, dark, light, belly):
    cx, cy = w * 0.5, w * 0.52
    s = w * 0.30  # creature scale
    # Ground shadow.
    d.ellipse([cx - s * 0.85, cy + s * 0.78, cx + s * 0.85, cy + s * 0.98],
              fill=(0, 0, 0, 60) if d else (60, 90, 60))
    if tier == 1:  # Egg with spots + crack + tiny sprout.
        ellipse(d, [cx - s * 0.72, cy - s * 0.85, cx + s * 0.72, cy + s * 0.85],
                body, dark, 8)
        ellipse(d, [cx - s * 0.45, cy - s * 0.55, cx + s * 0.1, cy + s * 0.1],
                light)
        for (ex, ey, r) in [(-0.3, -0.35, 0.13), (0.28, 0.05, 0.11),
                            (-0.05, 0.45, 0.12), (0.35, -0.4, 0.08)]:
            ellipse(d, [cx + ex * s - r * s, cy + ey * s - r * s,
                        cx + ex * s + r * s, cy + ey * s + r * s], dark)
        # Crack + sprout.
        d.line([(cx - s * 0.3, cy - s * 0.85), (cx - s * 0.1, cy - s * 0.7),
                (cx + s * 0.15, cy - s * 0.88)], fill=dark, width=8)
        d.line([(cx, cy - s * 0.85), (cx, cy - s * 1.05)], fill=(90, 180, 70),
               width=10)
        ellipse(d, [cx - s * 0.28, cy - s * 1.22, cx + s * 0.05, cy - s * 0.98],
                (110, 205, 90))
        ellipse(d, [cx - s * 0.02, cy - s * 1.22, cx + s * 0.3, cy - s * 0.98],
                (110, 205, 90))
        eye(d, cx - s * 0.25, cy + s * 0.05, s * 0.13)
        eye(d, cx + s * 0.25, cy + s * 0.05, s * 0.13)
        d.arc([cx - s * 0.25, cy + s * 0.25, cx + s * 0.25, cy + s * 0.55],
              20, 160, fill=(38, 55, 76), width=8)
    elif tier == 2:  # Slime blob.
        pts = [(cx - s * 0.85, cy + s * 0.55), (cx - s * 0.8, cy - s * 0.1),
               (cx - s * 0.45, cy - s * 0.75), (cx, cy - s * 0.9),
               (cx + s * 0.45, cy - s * 0.72), (cx + s * 0.82, cy - s * 0.05),
               (cx + s * 0.85, cy + s * 0.55)]
        d.polygon(pts, fill=body, outline=dark)
        ellipse(d, [cx - s * 0.85, cy + s * 0.25, cx + s * 0.85, cy + s * 0.75],
                belly)
        ellipse(d, [cx - s * 0.55, cy - s * 0.55, cx - s * 0.1, cy - s * 0.1],
                light)
        eye(d, cx - s * 0.28, cy - s * 0.05, s * 0.16)
        eye(d, cx + s * 0.28, cy - s * 0.05, s * 0.16)
        d.arc([cx - s * 0.28, cy + s * 0.2, cx + s * 0.28, cy + s * 0.55],
              20, 160, fill=(38, 55, 76), width=9)
        ellipse(d, [cx - s * 0.6, cy + s * 0.15, cx - s * 0.4, cy + s * 0.3],
                (255, 120, 140))
        ellipse(d, [cx + s * 0.4, cy + s * 0.15, cx + s * 0.6, cy + s * 0.3],
                (255, 120, 140))
    elif tier == 3:  # Baby dino.
        ellipse(d, [cx - s * 0.7, cy - s * 0.35, cx + s * 0.7, cy + s * 0.8],
                body, dark, 8)
        ellipse(d, [cx - s * 0.4, cy + s * 0.1, cx + s * 0.4, cy + s * 0.75],
                belly)
        ellipse(d, [cx - s * 0.45, cy - s * 0.95, cx + s * 0.45, cy - s * 0.15],
                body, dark, 8)
        for i, fx in enumerate((-0.25, 0.0, 0.25)):
            d.polygon([(cx + fx * s - s * 0.12, cy - s * 0.85),
                       (cx + fx * s, cy - s * 1.12),
                       (cx + fx * s + s * 0.12, cy - s * 0.85)],
                      fill=light)
        eye(d, cx - s * 0.18, cy - s * 0.6, s * 0.12)
        eye(d, cx + s * 0.18, cy - s * 0.6, s * 0.12)
        d.arc([cx - s * 0.2, cy - s * 0.4, cx + s * 0.2, cy - s * 0.15],
              20, 160, fill=(38, 55, 76), width=8)
        # Tail + tiny arms.
        d.polygon([(cx + s * 0.6, cy + s * 0.3), (cx + s * 1.05, cy - s * 0.1),
                   (cx + s * 0.95, cy + s * 0.45)], fill=body, outline=dark)
        ellipse(d, [cx - s * 0.95, cy + s * 0.15, cx - s * 0.6, cy + s * 0.4],
                body, dark, 6)
        ellipse(d, [cx + s * 0.6, cy + s * 0.15, cx + s * 0.95, cy + s * 0.4],
                body, dark, 6)
    elif tier == 4:  # Wyrm: serpent body + wings + flame.
        d.polygon([(cx - s * 0.9, cy + s * 0.2), (cx - s * 0.2, cy - s * 0.55),
                   (cx + s * 0.15, cy + s * 0.1)], fill=(255, 150, 80))
        d.polygon([(cx + s * 0.9, cy + s * 0.2), (cx + s * 0.2, cy - s * 0.55),
                   (cx - s * 0.15, cy + s * 0.1)], fill=(255, 150, 80))
        ellipse(d, [cx - s * 0.75, cy - s * 0.2, cx + s * 0.75, cy + s * 0.85],
                body, dark, 8)
        ellipse(d, [cx - s * 0.42, cy + s * 0.15, cx + s * 0.42, cy + s * 0.8],
                belly)
        ellipse(d, [cx - s * 0.5, cy - s * 0.9, cx + s * 0.5, cy - s * 0.1],
                body, dark, 8)
        d.polygon([(cx - s * 0.35, cy - s * 0.8), (cx - s * 0.2, cy - s * 1.15),
                   (cx - s * 0.05, cy - s * 0.8)], fill=dark)
        d.polygon([(cx + s * 0.05, cy - s * 0.8), (cx + s * 0.2, cy - s * 1.15),
                   (cx + s * 0.35, cy - s * 0.8)], fill=dark)
        eye(d, cx - s * 0.2, cy - s * 0.55, s * 0.13)
        eye(d, cx + s * 0.2, cy - s * 0.55, s * 0.13)
        # Flame breath.
        for (fx, fy, fr, col) in [(0.55, -0.35, 0.22, (255, 200, 60)),
                                  (0.75, -0.3, 0.16, (255, 140, 40)),
                                  (0.9, -0.25, 0.11, (255, 90, 30))]:
            ellipse(d, [cx + fx * s - fr * s, cy + fy * s - fr * s,
                        cx + fx * s + fr * s, cy + fy * s + fr * s], col)
    elif tier == 5:  # Phoenix.
        d.polygon([(cx - s * 0.95, cy + s * 0.5), (cx - s * 0.7, cy - s * 0.7),
                   (cx - s * 0.2, cy + s * 0.1)], fill=(255, 140, 60))
        d.polygon([(cx + s * 0.95, cy + s * 0.5), (cx + s * 0.7, cy - s * 0.7),
                   (cx + s * 0.2, cy + s * 0.1)], fill=(255, 140, 60))
        ellipse(d, [cx - s * 0.6, cy - s * 0.3, cx + s * 0.6, cy + s * 0.8],
                body, dark, 8)
        ellipse(d, [cx - s * 0.35, cy + s * 0.1, cx + s * 0.35, cy + s * 0.75],
                belly)
        ellipse(d, [cx - s * 0.42, cy - s * 0.95, cx + s * 0.42, cy - s * 0.2],
                body, dark, 8)
        # Crest flames.
        for (fx, fh) in [(-0.2, 0.35), (0.0, 0.5), (0.2, 0.35)]:
            d.polygon([(cx + fx * s - s * 0.12, cy - s * 0.85),
                       (cx + fx * s, cy - s * (0.85 + fh)),
                       (cx + fx * s + s * 0.12, cy - s * 0.85)],
                      fill=(255, 120, 40))
        ellipse(d, [cx - s * 0.45, cy - s * 0.75, cx - s * 0.05, cy - s * 0.35],
                light)
        eye(d, cx - s * 0.16, cy - s * 0.6, s * 0.12)
        eye(d, cx + s * 0.16, cy - s * 0.6, s * 0.12)
        d.polygon([(cx - s * 0.08, cy - s * 0.35), (cx + s * 0.08, cy - s * 0.35),
                   (cx, cy - s * 0.2)], fill=(255, 140, 40))
        # Tail feathers.
        for i, col in enumerate(((255, 120, 60), (255, 180, 60), (255, 90, 90))):
            x0 = cx + (i - 1) * s * 0.28
            d.polygon([(x0 - s * 0.12, cy + s * 0.7), (x0 + s * 0.12, cy + s * 0.7),
                       (x0 + s * 0.05, cy + s * 1.15), (x0 - s * 0.05, cy + s * 1.15)],
                      fill=col)
    elif tier == 6:  # Unicorn.
        ellipse(d, [cx - s * 0.75, cy - s * 0.25, cx + s * 0.75, cy + s * 0.75],
                body, dark, 8)
        ellipse(d, [cx - s * 0.4, cy + s * 0.15, cx + s * 0.4, cy + s * 0.7],
                belly)
        ellipse(d, [cx - s * 0.4, cy - s * 0.95, cx + s * 0.4, cy - s * 0.2],
                body, dark, 8)
        # Horn + mane (rainbow).
        d.polygon([(cx - s * 0.1, cy - s * 0.9), (cx + s * 0.1, cy - s * 0.9),
                   (cx, cy - s * 1.35)], fill=(255, 215, 90), outline=(200, 150, 40))
        for i, col in enumerate(((255, 120, 160), (255, 200, 80), (140, 200, 255))):
            d.polygon([(cx + s * 0.25, cy - s * (0.9 - i * 0.12)),
                       (cx + s * 0.55, cy - s * (0.75 - i * 0.12)),
                       (cx + s * 0.5, cy - s * (0.35 - i * 0.12)),
                       (cx + s * 0.2, cy - s * (0.5 - i * 0.12))], fill=col)
        # Ears.
        d.polygon([(cx - s * 0.35, cy - s * 0.85), (cx - s * 0.42, cy - s * 1.12),
                   (cx - s * 0.18, cy - s * 0.95)], fill=body, outline=dark)
        d.polygon([(cx + s * 0.35, cy - s * 0.85), (cx + s * 0.42, cy - s * 1.12),
                   (cx + s * 0.18, cy - s * 0.95)], fill=body, outline=dark)
        eye(d, cx - s * 0.17, cy - s * 0.58, s * 0.13)
        eye(d, cx + s * 0.17, cy - s * 0.58, s * 0.13)
        d.arc([cx - s * 0.2, cy - s * 0.38, cx + s * 0.2, cy - s * 0.12],
              20, 160, fill=(38, 55, 76), width=8)
        # Legs.
        for lx in (-0.45, -0.15, 0.15, 0.45):
            d.rounded_rectangle([cx + lx * s - s * 0.07, cy + s * 0.6,
                                 cx + lx * s + s * 0.07, cy + s * 1.05],
                                radius=12, fill=body, outline=dark, width=4)
        star(d, cx + s * 0.62, cy - s * 0.55, s * 0.14, (255, 215, 90))
    elif tier == 7:  # Robo-Rex.
        d.rounded_rectangle([cx - s * 0.72, cy - s * 0.3, cx + s * 0.72, cy + s * 0.8],
                            radius=40, fill=body, outline=dark, width=8)
        d.rounded_rectangle([cx - s * 0.5, cy - s * 0.95, cx + s * 0.5, cy - s * 0.2],
                            radius=36, fill=light, outline=dark, width=8)
        # Antenna + bolts.
        d.line([(cx, cy - s * 0.95), (cx, cy - s * 1.2)], fill=dark, width=10)
        ellipse(d, [cx - s * 0.09, cy - s * 1.32, cx + s * 0.09, cy - s * 1.14],
                (255, 80, 80))
        for (bx, by) in [(-0.55, -0.1), (0.55, -0.1), (-0.55, 0.6), (0.55, 0.6)]:
            ellipse(d, [cx + bx * s - 10, cy + by * s - 10,
                        cx + bx * s + 10, cy + by * s + 10], dark)
        # Glowing visor eyes.
        d.rounded_rectangle([cx - s * 0.38, cy - s * 0.72, cx + s * 0.38, cy - s * 0.45],
                            radius=18, fill=(30, 40, 60))
        ellipse(d, [cx - s * 0.26, cy - s * 0.66, cx - s * 0.08, cy - s * 0.5],
                (90, 220, 255))
        ellipse(d, [cx + s * 0.08, cy - s * 0.66, cx + s * 0.26, cy - s * 0.5],
                (90, 220, 255))
        # Chest panel + teeth grille.
        d.rounded_rectangle([cx - s * 0.35, cy + s * 0.1, cx + s * 0.35, cy + s * 0.45],
                            radius=16, fill=(60, 80, 110))
        for i in range(4):
            x = cx - s * 0.25 + i * s * 0.17
            d.line([(x, cy + s * 0.18), (x, cy + s * 0.37)], fill=(200, 220, 240),
                   width=6)
        # Arms + tail.
        d.rounded_rectangle([cx - s * 0.95, cy + s * 0.0, cx - s * 0.68, cy + s * 0.45],
                            radius=14, fill=body, outline=dark, width=5)
        d.rounded_rectangle([cx + s * 0.68, cy + s * 0.0, cx + s * 0.95, cy + s * 0.45],
                            radius=14, fill=body, outline=dark, width=5)
        d.polygon([(cx + s * 0.65, cy + s * 0.4), (cx + s * 1.05, cy + s * 0.1),
                   (cx + s * 0.95, cy + s * 0.55)], fill=body, outline=dark)
    else:  # Cosmic King Dragon.
        d.polygon([(cx - s * 0.95, cy + s * 0.3), (cx - s * 0.55, cy - s * 0.75),
                   (cx - s * 0.1, cy + s * 0.0)], fill=(200, 140, 255))
        d.polygon([(cx + s * 0.95, cy + s * 0.3), (cx + s * 0.55, cy - s * 0.75),
                   (cx + s * 0.1, cy + s * 0.0)], fill=(200, 140, 255))
        ellipse(d, [cx - s * 0.72, cy - s * 0.25, cx + s * 0.72, cy + s * 0.8],
                body, dark, 8)
        ellipse(d, [cx - s * 0.4, cy + s * 0.1, cx + s * 0.4, cy + s * 0.75],
                belly)
        ellipse(d, [cx - s * 0.48, cy - s * 0.95, cx + s * 0.48, cy - s * 0.15],
                body, dark, 8)
        # Crown.
        d.polygon([(cx - s * 0.35, cy - s * 0.88), (cx - s * 0.35, cy - s * 1.18),
                   (cx - s * 0.12, cy - s * 0.95), (cx, cy - s * 1.28),
                   (cx + s * 0.12, cy - s * 0.95), (cx + s * 0.35, cy - s * 1.18),
                   (cx + s * 0.35, cy - s * 0.88)], fill=(255, 215, 90),
                  outline=(200, 150, 40))
        star(d, cx, cy - s * 1.28, s * 0.12, (255, 240, 150))
        # Horns.
        d.polygon([(cx - s * 0.45, cy - s * 0.8), (cx - s * 0.7, cy - s * 1.1),
                   (cx - s * 0.3, cy - s * 0.95)], fill=light)
        d.polygon([(cx + s * 0.45, cy - s * 0.8), (cx + s * 0.7, cy - s * 1.1),
                   (cx + s * 0.3, cy - s * 0.95)], fill=light)
        eye(d, cx - s * 0.19, cy - s * 0.58, s * 0.13)
        eye(d, cx + s * 0.19, cy - s * 0.58, s * 0.13)
        # Starry belly spots + tail.
        for (sx, sy, r) in [(-0.2, 0.35, 0.07), (0.15, 0.5, 0.06), (0.0, 0.2, 0.05)]:
            star(d, cx + sx * s, cy + sy * s, r * s, (255, 240, 150))
        d.polygon([(cx + s * 0.6, cy + s * 0.35), (cx + s * 1.05, cy - s * 0.05),
                   (cx + s * 0.95, cy + s * 0.5)], fill=body, outline=dark)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for i, (name, body, dark, light, belly, sky_top, sky_bot) in enumerate(TIERS):
        tier = i + 1
        w = SIZE * SS
        img = Image.new("RGB", (w, w))
        d = ImageDraw.Draw(img, "RGBA")
        background(d, w, sky_top, sky_bot, random.Random(tier))
        draw_creature(d, w, tier, body, dark, light, belly)
        banner(d, w, name, tier)
        img = img.resize((SIZE, SIZE), Image.LANCZOS)
        path = os.path.join(OUT_DIR, f"tier{tier}.png")
        img.save(path, "PNG", optimize=True)
        print(f"tier{tier}: {name} -> {path} ({os.path.getsize(path)} bytes)")


if __name__ == "__main__":
    main()
