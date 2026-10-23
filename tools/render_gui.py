#!/usr/bin/env python3
"""Renderizador aproximado de interfaces Roblox exportadas por tools/export_gui.luau.
Soporta Position/Size/AnchorPoint, UIListLayout, UIGridLayout, UIPadding, UICorner,
UIStroke, UIScale (raiz), ScrollingFrame y TextScaled con UITextSizeConstraint.
Los emojis se sustituyen por un circulo (no hay fuente de emojis en el contenedor).

Uso: python3 tools/render_gui.py build/gui/hud.json salida.png [ancho alto]
"""
import json
import re
import sys

from PIL import Image, ImageDraw, ImageFont

BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
EMOJI_RE = re.compile("[\U0001F000-\U0001FAFF☀-➿⬀-⯿️‍←-⇿⏩-⏺]")
_font_cache = {}


def font(size, bold=True):
    key = (int(size), bold)
    if key not in _font_cache:
        _font_cache[key] = ImageFont.truetype(BOLD if bold else REG, max(4, int(size)))
    return _font_cache[key]


def clean(text):
    return EMOJI_RE.sub("●", text)


def child(node, cls):
    for c in node["children"]:
        if c["class"] == cls:
            return c
    return None


def is_gui(node):
    return "size" in node


def wrap_lines(draw, text, f, width):
    lines = []
    for para in text.split("\n"):
        words = para.split(" ")
        cur = ""
        for w in words:
            trial = (cur + " " + w).strip()
            if draw.textlength(trial, font=f) <= width or not cur:
                cur = trial
            else:
                lines.append(cur)
                cur = w
        lines.append(cur)
    return lines


class Renderer:
    def __init__(self, width, height):
        self.W, self.H = width, height
        self.items = []  # (z, seq, kind, data)
        self.seq = 0

    def add(self, z, kind, data):
        self.seq += 1
        self.items.append((z, self.seq, kind, data))

    def layout(self, node, rect, clip, zbase, scale):
        """rect: (x, y, w, h) del contenido del padre."""
        kids = [c for c in node["children"] if is_gui(c) and c.get("visible", True)]
        pad = child(node, "UIPadding")
        x, y, w, h = rect
        if pad:
            l, r, t, b = pad["pad"]
            pl = l[0] * w + l[1]; pr = r[0] * w + r[1]; pt = t[0] * h + t[1]; pb = b[0] * h + b[1]
            x += pl; y += pt; w -= pl + pr; h -= pt + pb
        lst = child(node, "UIListLayout")
        grid = child(node, "UIGridLayout")
        placed = []
        if lst:
            kids_sorted = sorted(kids, key=lambda c: c.get("order", 0))
            padding = lst["padding"][0] * (h if lst["dir"] == "Vertical" else w) + lst["padding"][1]
            sizes = [self.size_of(c, w, h) for c in kids_sorted]
            if lst["dir"] == "Vertical":
                total = sum(s[1] for s in sizes) + padding * max(0, len(sizes) - 1)
                cy = y
                if lst["vAlign"] == "Center":
                    cy = y + (h - total) / 2
                elif lst["vAlign"] == "Bottom":
                    cy = y + h - total
                for c, (cw, ch) in zip(kids_sorted, sizes):
                    cx = x
                    if lst["hAlign"] == "Center":
                        cx = x + (w - cw) / 2
                    elif lst["hAlign"] == "Right":
                        cx = x + w - cw
                    placed.append((c, (cx, cy, cw, ch)))
                    cy += ch + padding
                content_h = total
            else:
                total = sum(s[0] for s in sizes) + padding * max(0, len(sizes) - 1)
                cx = x
                if lst["hAlign"] == "Center":
                    cx = x + (w - total) / 2
                elif lst["hAlign"] == "Right":
                    cx = x + w - total
                for c, (cw, ch) in zip(kids_sorted, sizes):
                    cy = y
                    if lst["vAlign"] == "Center":
                        cy = y + (h - ch) / 2
                    elif lst["vAlign"] == "Bottom":
                        cy = y + h - ch
                    placed.append((c, (cx, cy, cw, ch)))
                    cx += cw + padding
                content_h = max([s[1] for s in sizes] or [0])
        elif grid:
            kids_sorted = sorted(kids, key=lambda c: c.get("order", 0))
            cs = grid["cell"]; cp = grid["cellPad"]
            cw = cs[0] * w + cs[1]; ch = cs[2] * h + cs[3]
            pw = cp[0] * w + cp[1]; ph = cp[2] * h + cp[3]
            per_row = max(1, int((w + pw) // (cw + pw)))
            for i, c in enumerate(kids_sorted):
                r, col = divmod(i, per_row)
                placed.append((c, (x + col * (cw + pw), y + r * (ch + ph), cw, ch)))
            rows = (len(kids_sorted) + per_row - 1) // per_row
            content_h = rows * ch + max(0, rows - 1) * ph
        else:
            for c in kids:
                cw, ch = self.size_of(c, w, h)
                p = c["pos"]
                ax, ay = c["anchor"]
                cx = x + p[0] * w + p[1] - ax * cw
                cy = y + p[2] * h + p[3] - ay * ch
                placed.append((c, (cx, cy, cw, ch)))
            content_h = max([r[1] + r[3] - y for _, r in placed] or [0])
        return placed, content_h

    def size_of(self, c, pw, ph):
        s = c["size"]
        w = s[0] * pw + s[1]
        h = s[2] * ph + s[3]
        if c.get("autoSize") in ("Y", "XY"):
            _, ch = self.layout(c, (0, 0, w, h), None, 0, 1)
            h = max(h, ch)
        return w, h

    def visit(self, node, rect, clip, z):
        """Dibuja `node` (ya colocado en rect) y sus hijos."""
        x, y, w, h = rect
        if node.get("class") == "ScrollingFrame" or (clip is None):
            pass
        zi = z + node.get("z", 1)
        corner = child(node, "UICorner")
        radius = 0
        if corner:
            radius = corner["radius"][0] * min(w, h) + corner["radius"][1]
        stroke = None
        for c in node["children"]:
            if c["class"] == "UIStroke" and c.get("mode") == "Border":
                stroke = c
        if node.get("bgT", 1) < 1 and node.get("bg"):
            self.add(zi, "rect", (rect, radius, tuple(node["bg"]), int(255 * (1 - node["bgT"])), clip, child(node, "UIGradient") is not None))
        if stroke and stroke.get("t", 0) < 1:
            self.add(zi + 0.01, "stroke", (rect, radius, tuple(stroke["color"]), stroke["thickness"], clip))
        if "text" in node and node["text"]:
            tstroke = None
            for c in node["children"]:
                if c["class"] == "UIStroke" and c.get("mode") != "Border":
                    tstroke = c
            maxc = child(node, "UITextSizeConstraint")
            self.add(zi + 0.02, "text", (rect, node, maxc["max"] if maxc else 100, tstroke, clip))
        child_clip = clip
        if node.get("class") == "ScrollingFrame":
            child_clip = (x, y, x + w, y + h)
            if clip:
                child_clip = (max(x, clip[0]), max(y, clip[1]), min(x + w, clip[2]), min(y + h, clip[3]))
        placed, _ = self.layout(node, rect, child_clip, z, 1)
        for c, r in placed:
            self.visit(c, r, child_clip, zi)

    def render(self, root, out):
        # Misma formula que Hud.autoScale
        s = max(0.55, min(1.15, min(self.H / 820, self.W / 1280)))
        vw, vh = self.W / s, self.H / s
        # Cada hijo directo de la ScreenGui se coloca sobre la pantalla virtual
        placed, _ = self.layout(root, (0, 0, vw, vh), None, 0, 1)
        for c, r in placed:
            self.visit(c, r, None, 0)
        img = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
        bg = Image.open(sys.argv[4]).convert("RGBA").resize((self.W, self.H)) if len(sys.argv) > 4 else Image.new("RGBA", (self.W, self.H), (110, 170, 120, 255))
        img = bg
        for zi, _, kind, data in sorted(self.items, key=lambda t: (t[0], t[1])):
            layer = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
            d = ImageDraw.Draw(layer)
            if kind == "rect":
                (x, y, w, h), radius, col, alpha, clip, grad = data
                box = [x * s, y * s, (x + w) * s, (y + h) * s]
                if box[2] - box[0] < 1 or box[3] - box[1] < 1:
                    continue
                d.rounded_rectangle(box, radius=max(0, min(radius * s, (box[3] - box[1]) / 2)), fill=col + (alpha,))
                if grad:
                    # degradado vertical suave (de blanco a gris) como UIGradient
                    shade = Image.new("L", (1, 256))
                    for i in range(256):
                        shade.putpixel((0, i), int(i * 0.2))
                    shade = shade.resize((max(1, int(box[2] - box[0])), max(1, int(box[3] - box[1]))))
                    dark = Image.new("RGBA", shade.size, (0, 0, 0, 0))
                    dark.putalpha(shade)
                    mask = Image.new("L", shade.size, 0)
                    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shade.size[0] - 1, shade.size[1] - 1], radius=max(0, min(radius * s, shade.size[1] / 2)), fill=255)
                    dark.putalpha(Image.fromarray(__import__("numpy").minimum(__import__("numpy").array(shade), __import__("numpy").array(mask))))
                    layer.alpha_composite(dark, (int(box[0]), int(box[1])))
            elif kind == "stroke":
                (x, y, w, h), radius, col, th, clip = data
                box = [x * s, y * s, (x + w) * s, (y + h) * s]
                if box[2] - box[0] < 1 or box[3] - box[1] < 1:
                    continue
                d.rounded_rectangle(box, radius=max(0, min(radius * s, (box[3] - box[1]) / 2)), outline=col + (255,), width=max(1, int(th * s)))
            elif kind == "text":
                (x, y, w, h), node, maxsize, tstroke, clip = data
                text = clean(node["text"])
                bold = node.get("font") not in ("GothamMedium", "Gotham", "SourceSans")
                W = w * s; Hh = h * s
                if W < 2 or Hh < 2:
                    continue
                if node.get("scaled"):
                    size = min(maxsize * s, Hh)
                    while size > 4:
                        f = font(size, bold)
                        lines = wrap_lines(d, text, f, W)
                        lh = size * 1.15
                        if len(lines) * lh <= Hh + 1 and all(d.textlength(l, font=f) <= W + 1 for l in lines):
                            break
                        size -= 1
                else:
                    size = node.get("textSize", 14) * s
                f = font(size, bold)
                lines = wrap_lines(d, text, f, W) if (node.get("scaled") or node.get("wrapped")) else text.split("\n")
                lh = size * 1.15
                total = len(lines) * lh
                ty = y * s
                if node.get("yAlign") == "Center":
                    ty += (Hh - total) / 2
                elif node.get("yAlign") == "Bottom":
                    ty += Hh - total
                col = tuple(node.get("textColor") or [255, 255, 255])
                for line in lines:
                    lw = d.textlength(line, font=f)
                    tx = x * s
                    if node.get("xAlign") == "Center":
                        tx += (W - lw) / 2
                    elif node.get("xAlign") == "Right":
                        tx += W - lw
                    sw = int(tstroke["thickness"] * s * 0.8) if tstroke else 0
                    d.text((tx, ty), line, font=f, fill=col + (255,), stroke_width=sw, stroke_fill=tuple(tstroke["color"]) + (255,) if tstroke else None)
                    ty += lh
            clip = data[4]
            if clip:
                if True:
                    m = Image.new("L", (self.W, self.H), 0)
                    ImageDraw.Draw(m).rectangle([clip[0] * s, clip[1] * s, clip[2] * s, clip[3] * s], fill=255)
                    a = layer.getchannel("A")
                    layer.putalpha(Image.fromarray(__import__("numpy").minimum(__import__("numpy").array(a), __import__("numpy").array(m))))
            img.alpha_composite(layer)
        img.convert("RGB").save(out)
        print(out)


if __name__ == "__main__":
    data = json.load(open(sys.argv[1]))
    W, H = 1366, 768
    if len(sys.argv) > 3 and "x" in sys.argv[3]:
        W, H = [int(v) for v in sys.argv[3].split("x")]
    Renderer(W, H).render(data, sys.argv[2])
