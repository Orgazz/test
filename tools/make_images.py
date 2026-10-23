#!/usr/bin/env python3
"""Genera las imagenes del juego: icono de la experiencia, miniaturas y los iconos
de los 3 pases y 3 productos. Todo se dibuja por codigo (formas vectoriales).

Uso: python3 tools/make_images.py build/scene.json assets/
Necesita la fuente Fredoka (tools/fonts/Fredoka.ttf, licencia OFL).
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "fonts", "Fredoka.ttf")
SS = 2  # supermuestreo para bordes suaves


def fredoka(size, weight=b"Bold"):
    f = ImageFont.truetype(FONT, int(size))
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def vgradient(size, top, bottom):
    w, h = size
    img = Image.new("RGBA", size)
    d = ImageDraw.Draw(img)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=lerp(top, bottom, y / max(1, h - 1)) + (255,))
    return img


def radial_glow(size, center, radius, color, strength=180):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    for i in range(30, 0, -1):
        r = radius * i / 30
        a = int(strength * (1 - i / 30) ** 1.5)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (a,))
    return layer.filter(ImageFilter.GaussianBlur(radius / 12))


def outlined_text(d, xy, text, font, fill, stroke, width, anchor="mm"):
    d.text(xy, text, font=font, fill=fill, stroke_width=width, stroke_fill=stroke, anchor=anchor)


def shadowed(img, shape_fn, offset=(0, 14), blur=10, alpha=110):
    """Dibuja una sombra suave de la forma y luego la forma."""
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shape_fn(ImageDraw.Draw(sh), (0, 0, 0, alpha), offset)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(sh)
    shape_fn(ImageDraw.Draw(img), None, (0, 0))


def badge(size, top, bottom, border):
    """Fondo de icono: cuadrado redondeado con degradado, brillo y borde."""
    S = size * SS
    base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    grad = vgradient((S, S), top, bottom)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=S * 0.2, fill=255)
    base.paste(grad, (0, 0), mask)
    # rayos de sol
    rays = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    for i in range(16):
        a0 = math.radians(i * 22.5)
        a1 = math.radians(i * 22.5 + 9)
        R = S
        rd.polygon([(S / 2, S / 2), (S / 2 + math.cos(a0) * R, S / 2 + math.sin(a0) * R), (S / 2 + math.cos(a1) * R, S / 2 + math.sin(a1) * R)], fill=(255, 255, 255, 28))
    rays_masked = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rays_masked.paste(rays, (0, 0), mask)
    base.alpha_composite(rays_masked)
    base.alpha_composite(radial_glow((S, S), (S / 2, S * 0.45), S * 0.45, (255, 255, 255), 90))
    ImageDraw.Draw(base).rounded_rectangle([S * 0.015, S * 0.015, S * 0.985, S * 0.985], radius=S * 0.19, outline=border + (255,), width=int(S * 0.03))
    return base


def finish(img, size, path):
    img = img.resize((size, size) if img.size[0] == img.size[1] else (img.size[0] // SS, img.size[1] // SS), Image.LANCZOS)
    img.save(path)
    print(path)


# ---------------------------------------------------------------------------
# Iconos dibujados
# ---------------------------------------------------------------------------

def draw_coin(d, cx, cy, r, tilt=1.0):
    d.ellipse([cx - r, cy - r * tilt + r * 0.18, cx + r, cy + r * tilt + r * 0.18], fill=(200, 130, 20, 255))
    d.ellipse([cx - r, cy - r * tilt, cx + r, cy + r * tilt], fill=(255, 205, 60, 255), outline=(170, 105, 10, 255), width=max(2, int(r * 0.1)))
    d.ellipse([cx - r * 0.7, cy - r * 0.7 * tilt, cx + r * 0.7, cy + r * 0.7 * tilt], outline=(230, 160, 30, 255), width=max(2, int(r * 0.08)))
    f = fredoka(r * 1.1)
    d.text((cx, cy), "$", font=f, fill=(190, 120, 15, 255), anchor="mm")


def draw_sparkle(d, cx, cy, r, color=(255, 255, 255, 255)):
    pts = []
    for i in range(8):
        a = math.radians(i * 45 - 90)
        rr = r if i % 2 == 0 else r * 0.28
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=color)


def icon_decor(size):
    S = size * SS
    img = badge(size, (255, 140, 200), (150, 70, 220), (90, 30, 140))
    d = ImageDraw.Draw(img)
    cx = S / 2
    # palmera
    d.rounded_rectangle([S * 0.74, S * 0.36, S * 0.79, S * 0.78], radius=S * 0.02, fill=(150, 100, 55))
    for ang in (-150, -110, -60, -20, 200):
        a = math.radians(ang)
        x2 = S * 0.765 + math.cos(a) * S * 0.17
        y2 = S * 0.36 + math.sin(a) * S * 0.09
        d.line([(S * 0.765, S * 0.36), (x2, y2)], fill=(60, 180, 80), width=int(S * 0.045))
    # fuente
    def fountain(dd, col, off):
        ox, oy = off
        c = col
        dd.ellipse([cx - S * 0.32 + ox, S * 0.66 + oy, cx + S * 0.32 + ox, S * 0.84 + oy], fill=c or (240, 220, 255, 255))
        dd.ellipse([cx - S * 0.27 + ox, S * 0.675 + oy, cx + S * 0.27 + ox, S * 0.79 + oy], fill=c or (90, 190, 255, 255))
        dd.rectangle([cx - S * 0.045 + ox, S * 0.45 + oy, cx + S * 0.045 + ox, S * 0.73 + oy], fill=c or (245, 230, 255, 255))
        dd.ellipse([cx - S * 0.16 + ox, S * 0.42 + oy, cx + S * 0.16 + ox, S * 0.5 + oy], fill=c or (255, 215, 120, 255))
    shadowed(img, fountain)
    d = ImageDraw.Draw(img)
    # chorros de agua
    for side in (-1, 1):
        for k in range(3):
            pts = []
            for i in range(20):
                t = i / 19
                x = cx + side * t * S * (0.12 + k * 0.05)
                y = S * 0.42 - math.sin(t * math.pi) * S * (0.16 - k * 0.03) + t * S * 0.3
                pts.append((x, y))
            d.line(pts, fill=(170, 230, 255, 255), width=int(S * 0.018))
    d.ellipse([cx - S * 0.04, S * 0.23, cx + S * 0.04, S * 0.31], fill=(200, 240, 255))
    # arco de neon
    d.arc([S * 0.08, S * 0.08, S * 0.92, S * 0.98], 200, 340, fill=(255, 255, 255, 200), width=int(S * 0.03))
    d.arc([S * 0.1, S * 0.1, S * 0.9, S * 0.96], 200, 340, fill=(120, 240, 255, 255), width=int(S * 0.018))
    for (x, y, r) in [(0.18, 0.3, 0.05), (0.85, 0.22, 0.04), (0.28, 0.58, 0.03)]:
        draw_sparkle(d, S * x, S * y, S * r)
    return img


def icon_theme(size):
    S = size * SS
    img = badge(size, (70, 40, 120), (25, 15, 50), (255, 200, 60))
    img.alpha_composite(radial_glow(img.size, (S / 2, S * 0.62), S * 0.5, (255, 190, 60), 120))
    d = ImageDraw.Draw(img)
    gold = (255, 205, 70)
    dark_gold = (200, 135, 20)
    buildings = [(0.14, 0.5, 0.14), (0.3, 0.32, 0.15), (0.47, 0.22, 0.13), (0.62, 0.38, 0.14), (0.77, 0.52, 0.11)]

    def city(dd, col, off):
        ox, oy = off
        for (x, top, w) in buildings:
            dd.rectangle([S * x + ox, S * top + oy, S * (x + w) + ox, S * 0.86 + oy], fill=col or gold + (255,))
    shadowed(img, city, offset=(0, 18), blur=14, alpha=160)
    d = ImageDraw.Draw(img)
    for (x, top, w) in buildings:
        d.rectangle([S * (x + w * 0.75), S * top, S * (x + w), S * 0.86], fill=dark_gold)
        for row in range(int((0.8 - top) / 0.07)):
            for col in range(2):
                wx = S * (x + 0.025 + col * w * 0.4)
                wy = S * (top + 0.04 + row * 0.07)
                if wy < S * 0.8:
                    d.rectangle([wx, wy, wx + S * 0.035, wy + S * 0.035], fill=(190, 110, 255) if (row + col) % 3 == 0 else (255, 245, 210))
    # corona sobre la torre central
    cx, cy = S * 0.535, S * 0.15
    w = S * 0.2
    crown = [(cx - w / 2, cy + S * 0.06), (cx - w / 2, cy - S * 0.03), (cx - w / 4, cy + S * 0.02), (cx, cy - S * 0.06), (cx + w / 4, cy + S * 0.02), (cx + w / 2, cy - S * 0.03), (cx + w / 2, cy + S * 0.06)]
    d.polygon(crown, fill=gold, outline=dark_gold, width=int(S * 0.008))
    for px, py in [(cx - w / 2, cy - S * 0.03), (cx, cy - S * 0.06), (cx + w / 2, cy - S * 0.03)]:
        d.ellipse([px - S * 0.018, py - S * 0.018, px + S * 0.018, py + S * 0.018], fill=(255, 80, 150))
    d.rectangle([S * 0.08, S * 0.86, S * 0.92, S * 0.9], fill=gold)
    for (x, y, r) in [(0.16, 0.2, 0.045), (0.86, 0.25, 0.04), (0.8, 0.13, 0.025), (0.22, 0.38, 0.025)]:
        draw_sparkle(d, S * x, S * y, S * r, (255, 235, 150, 255))
    return img


def icon_x2(size):
    S = size * SS
    img = badge(size, (255, 210, 70), (255, 110, 40), (170, 60, 10))
    d = ImageDraw.Draw(img)
    bolt = [(0.56, 0.08), (0.24, 0.55), (0.46, 0.55), (0.36, 0.92), (0.78, 0.4), (0.55, 0.4), (0.68, 0.08)]

    def b(dd, col, off):
        ox, oy = off
        dd.polygon([(S * x + ox, S * y + oy) for x, y in bolt], fill=col or (255, 255, 255, 255))
    shadowed(img, b, offset=(8, 18), blur=12, alpha=130)
    d = ImageDraw.Draw(img)
    inner = [(0.565, 0.13), (0.3, 0.52), (0.5, 0.52), (0.42, 0.82), (0.72, 0.43), (0.51, 0.43), (0.635, 0.13)]
    d.polygon([(S * x, S * y) for x, y in inner], fill=(255, 235, 90))
    f = fredoka(S * 0.3)
    outlined_text(d, (S * 0.74, S * 0.76), "x2", f, (255, 255, 255), (150, 50, 10), int(S * 0.025))
    for (x, y, r) in [(0.2, 0.2, 0.05), (0.85, 0.22, 0.035), (0.18, 0.78, 0.03)]:
        draw_sparkle(d, S * x, S * y, S * r)
    return img


def icon_briefcase(size):
    S = size * SS
    img = badge(size, (130, 230, 120), (30, 150, 80), (20, 90, 45))
    d = ImageDraw.Draw(img)

    def case(dd, col, off):
        ox, oy = off
        dd.rounded_rectangle([S * 0.36 + ox, S * 0.24 + oy, S * 0.64 + ox, S * 0.4 + oy], radius=S * 0.04, outline=col or (90, 55, 25, 255), width=int(S * 0.04))
        dd.rounded_rectangle([S * 0.16 + ox, S * 0.34 + oy, S * 0.84 + ox, S * 0.78 + oy], radius=S * 0.06, fill=col or (160, 95, 45, 255))
    shadowed(img, case)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([S * 0.16, S * 0.34, S * 0.84, S * 0.46], radius=S * 0.05, fill=(185, 115, 55))
    d.rectangle([S * 0.16, S * 0.52, S * 0.84, S * 0.58], fill=(255, 200, 60))
    d.rounded_rectangle([S * 0.44, S * 0.49, S * 0.56, S * 0.61], radius=S * 0.02, fill=(255, 220, 90), outline=(170, 110, 20), width=int(S * 0.01))
    # billetes asomando
    for i, x in enumerate((0.28, 0.42, 0.56)):
        d.rectangle([S * x, S * 0.22 - i * S * 0.01, S * (x + 0.14), S * 0.34], fill=(120, 210, 110), outline=(40, 120, 60), width=int(S * 0.008))
        d.text((S * (x + 0.07), S * 0.28), "$", font=fredoka(S * 0.07), fill=(40, 120, 60), anchor="mm")
    draw_coin(d, S * 0.78, S * 0.78, S * 0.1)
    draw_coin(d, S * 0.22, S * 0.8, S * 0.08)
    draw_sparkle(d, S * 0.84, S * 0.2, S * 0.05)
    return img


def icon_safe(size):
    S = size * SS
    img = badge(size, (110, 220, 230), (30, 120, 170), (15, 70, 110))
    d = ImageDraw.Draw(img)

    def safe(dd, col, off):
        ox, oy = off
        dd.rounded_rectangle([S * 0.2 + ox, S * 0.18 + oy, S * 0.8 + ox, S * 0.8 + oy], radius=S * 0.06, fill=col or (120, 130, 150, 255))
    shadowed(img, safe)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([S * 0.26, S * 0.24, S * 0.74, S * 0.74], radius=S * 0.04, fill=(160, 170, 190), outline=(80, 90, 110), width=int(S * 0.012))
    cx, cy, r = S * 0.5, S * 0.49, S * 0.14
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(220, 225, 235), outline=(70, 80, 100), width=int(S * 0.015))
    for i in range(12):
        a = math.radians(i * 30)
        d.line([(cx + math.cos(a) * r * 0.7, cy + math.sin(a) * r * 0.7), (cx + math.cos(a) * r * 0.9, cy + math.sin(a) * r * 0.9)], fill=(70, 80, 100), width=int(S * 0.008))
    d.ellipse([cx - r * 0.3, cy - r * 0.3, cx + r * 0.3, cy + r * 0.3], fill=(255, 200, 60))
    d.rectangle([S * 0.66, S * 0.42, S * 0.7, S * 0.56], fill=(255, 200, 60))
    d.rectangle([S * 0.26, S * 0.8, S * 0.34, S * 0.85], fill=(80, 90, 110))
    d.rectangle([S * 0.66, S * 0.8, S * 0.74, S * 0.85], fill=(80, 90, 110))
    for i, (x, y) in enumerate([(0.18, 0.84), (0.27, 0.86), (0.78, 0.84), (0.86, 0.8), (0.82, 0.72)]):
        draw_coin(d, S * x, S * y, S * 0.075, 0.55)
    draw_sparkle(d, S * 0.84, S * 0.18, S * 0.05)
    draw_sparkle(d, S * 0.15, S * 0.25, S * 0.035)
    return img


def icon_truck(size):
    S = size * SS
    img = badge(size, (120, 170, 255), (60, 70, 200), (30, 30, 110))
    d = ImageDraw.Draw(img)

    def truck(dd, col, off):
        ox, oy = off
        dd.rounded_rectangle([S * 0.1 + ox, S * 0.32 + oy, S * 0.66 + ox, S * 0.7 + oy], radius=S * 0.04, fill=col or (225, 230, 240, 255))
        dd.rounded_rectangle([S * 0.64 + ox, S * 0.42 + oy, S * 0.88 + ox, S * 0.7 + oy], radius=S * 0.05, fill=col or (90, 160, 90, 255))
    shadowed(img, truck)
    d = ImageDraw.Draw(img)
    d.rectangle([S * 0.1, S * 0.46, S * 0.66, S * 0.53], fill=(255, 200, 60))
    d.text((S * 0.38, S * 0.4), "$$$", font=fredoka(S * 0.08), fill=(60, 130, 70), anchor="mm")
    d.rounded_rectangle([S * 0.7, S * 0.46, S * 0.84, S * 0.56], radius=S * 0.02, fill=(170, 220, 250))
    for x in (0.25, 0.52, 0.76):
        d.ellipse([S * (x - 0.07), S * 0.64, S * (x + 0.07), S * 0.78], fill=(40, 40, 50))
        d.ellipse([S * (x - 0.03), S * 0.68, S * (x + 0.03), S * 0.74], fill=(190, 190, 200))
    # sacos de dinero
    for (x, y, r) in [(0.3, 0.2, 0.09), (0.47, 0.18, 0.1)]:
        d.ellipse([S * (x - r), S * (y - r * 0.7), S * (x + r), S * (y + r)], fill=(200, 160, 100), outline=(130, 90, 50), width=int(S * 0.008))
        d.text((S * x, S * (y + r * 0.15)), "$", font=fredoka(S * r * 1.1), fill=(90, 150, 70), anchor="mm")
    draw_coin(d, S * 0.83, S * 0.25, S * 0.08)
    draw_sparkle(d, S * 0.65, S * 0.15, S * 0.04)
    return img


# ---------------------------------------------------------------------------
# Icono del juego y miniaturas
# ---------------------------------------------------------------------------

def title_block(d, cx, cy, scale):
    f1 = fredoka(150 * scale)
    outlined_text(d, (cx, cy), "TINY EMPIRE", f1, (255, 230, 90), (70, 30, 110), int(16 * scale))
    rib_w, rib_h = 520 * scale, 110 * scale
    ry = cy + 135 * scale
    d.polygon([(cx - rib_w / 2 - 50 * scale, ry - rib_h / 2 + 10 * scale), (cx - rib_w / 2 + 10 * scale, ry), (cx - rib_w / 2 - 50 * scale, ry + rib_h / 2 + 10 * scale), (cx - rib_w / 2 + 40 * scale, ry + rib_h / 2 + 10 * scale), (cx - rib_w / 2 + 40 * scale, ry - rib_h / 2 + 10 * scale)], fill=(200, 60, 90))
    d.polygon([(cx + rib_w / 2 + 50 * scale, ry - rib_h / 2 + 10 * scale), (cx + rib_w / 2 - 10 * scale, ry), (cx + rib_w / 2 + 50 * scale, ry + rib_h / 2 + 10 * scale), (cx + rib_w / 2 - 40 * scale, ry + rib_h / 2 + 10 * scale), (cx + rib_w / 2 - 40 * scale, ry - rib_h / 2 + 10 * scale)], fill=(200, 60, 90))
    d.rounded_rectangle([cx - rib_w / 2, ry - rib_h / 2, cx + rib_w / 2, ry + rib_h / 2], radius=20 * scale, fill=(255, 90, 120), outline=(130, 30, 60), width=int(8 * scale))
    outlined_text(d, (cx, ry), "TYCOON", fredoka(90 * scale), (255, 255, 255), (130, 30, 60), int(9 * scale))


def game_icon(size):
    S = size * SS
    img = vgradient((S, S), (110, 190, 255), (255, 190, 140))
    img.alpha_composite(radial_glow((S, S), (S * 0.78, S * 0.2), S * 0.35, (255, 245, 180), 200))
    d = ImageDraw.Draw(img)
    # nubes
    for (x, y, r) in [(0.18, 0.14, 0.07), (0.27, 0.12, 0.09), (0.36, 0.15, 0.06)]:
        d.ellipse([S * (x - r), S * (y - r), S * (x + r), S * (y + r)], fill=(255, 255, 255, 230))
    # skyline
    cols = [(255, 120, 150), (255, 200, 90), (110, 210, 160), (150, 130, 255), (90, 190, 240), (255, 150, 90)]
    x = -0.02
    i = 0
    import random
    rnd = random.Random(4)
    while x < 1:
        w = rnd.uniform(0.09, 0.15)
        top = rnd.uniform(0.48, 0.72)
        col = cols[i % len(cols)]
        d.rectangle([S * x, S * top, S * (x + w), S], fill=col)
        d.rectangle([S * (x + w * 0.72), S * top, S * (x + w), S], fill=lerp(col, (0, 0, 0), 0.18))
        for r in range(8):
            for c in range(2):
                wy = S * (top + 0.04 + r * 0.06)
                if wy < S * 0.95:
                    d.rectangle([S * (x + 0.02 + c * w * 0.33), wy, S * (x + 0.02 + c * w * 0.33) + S * 0.025, wy + S * 0.03], fill=(255, 250, 220))
        x += w + 0.01
        i += 1
    # suelo y monedas
    d.rectangle([0, S * 0.9, S, S], fill=(110, 200, 100))
    for (cx, cy, r) in [(0.14, 0.86, 0.08), (0.86, 0.85, 0.09), (0.74, 0.92, 0.06)]:
        draw_coin(d, S * cx, S * cy, S * r)
    title_block(d, S / 2, S * 0.3, S / 1024)
    return img


def thumbnail(scene_render, title, subtitle, out, accent=(255, 90, 120)):
    base = Image.open(scene_render).convert("RGBA").resize((1920, 1080), Image.LANCZOS)
    W, H = base.size
    # vineta inferior
    shade = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for y in range(H // 2, H):
        a = int(170 * ((y - H / 2) / (H / 2)) ** 1.6)
        sd.line([(0, y), (W, y)], fill=(20, 10, 40, a))
    base.alpha_composite(shade)
    d = ImageDraw.Draw(base)
    outlined_text(d, (W / 2, H - 230), title, fredoka(120), (255, 230, 90), (60, 25, 100), 12)
    pill_w = d.textlength(subtitle, font=fredoka(58)) + 90
    d.rounded_rectangle([W / 2 - pill_w / 2, H - 140, W / 2 + pill_w / 2, H - 50], radius=45, fill=accent + (255,), outline=(255, 255, 255), width=6)
    outlined_text(d, (W / 2, H - 95), subtitle, fredoka(58), (255, 255, 255), lerp(accent, (0, 0, 0), 0.5), 5)
    # logo pequeno
    logo = game_icon(512).resize((220, 220), Image.LANCZOS)
    mask = Image.new("L", logo.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 219, 219], radius=44, fill=255)
    base.paste(logo, (40, 40), mask)
    ImageDraw.Draw(base).rounded_rectangle([40, 40, 260, 260], radius=44, outline=(255, 255, 255), width=6)
    base.convert("RGB").save(out)
    print(out)


if __name__ == "__main__":
    out = sys.argv[2] if len(sys.argv) > 2 else "assets"
    renders = sys.argv[1] if len(sys.argv) > 1 else "build"
    os.makedirs(out, exist_ok=True)
    finish(game_icon(512), 512, os.path.join(out, "icono_juego.png"))
    for name, fn in [("pase_decoraciones", icon_decor), ("pase_tema_dorado", icon_theme), ("pase_productividad_x2", icon_x2),
                     ("producto_maletin_29", icon_briefcase), ("producto_caja_fuerte_49", icon_safe), ("producto_camion_79", icon_truck)]:
        finish(fn(512), 512, os.path.join(out, name + ".png"))
    thumbs = [
        ("thumb_parcela.png", "¡CONSTRUYE TU IMPERIO!", "10 negocios · 24 mejoras · 5 niveles", (255, 90, 120)),
        ("thumb_ciudad.png", "UNA CIUDAD ENTERA", "4 barrios · 8 parcelas · día y noche", (60, 150, 255)),
        ("thumb_plaza.png", "¡JUEGA CON AMIGOS!", "Plaza social · retos diarios · maletines", (60, 190, 110)),
    ]
    for fname, title, sub, accent in thumbs:
        src = os.path.join(renders, fname)
        if os.path.exists(src):
            thumbnail(src, title, sub, os.path.join(out, fname.replace("thumb_", "miniatura_")), accent)
