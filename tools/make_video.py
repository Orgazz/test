#!/usr/bin/env python3
"""Video de presentacion de Tiny Empire Tycoon renderizado a partir de los datos
reales del juego (tools/export_video.luau). No es una captura de Roblox: es una
vista previa con un renderizador propio (perspectiva, niebla, sombreado plano).

Uso:
  python3 tools/make_video.py build/video assets/video_presentacion.mp4 [--fast]
"""
import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render import ball_faces, box_faces, cylinder_faces, wedge_faces  # noqa: E402
import render_gui  # noqa: E402
import make_images  # noqa: E402

W, H = 1280, 720
FPS = 24
FAST = "--fast" in sys.argv
if FAST:
    W, H, FPS = 640, 360, 12

LIGHT = np.array([0.45, 0.85, 0.3]); LIGHT /= np.linalg.norm(LIGHT)
FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts", "Fredoka.ttf")


def fredoka(size, weight=b"Bold"):
    f = ImageFont.truetype(FONT, max(6, int(size)))
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def strip_emoji(t):
    return "".join(ch for ch in t if ord(ch) < 0x2190 or 0x3000 <= ord(ch) < 0xD000).strip()


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------------------
# Geometria
# ---------------------------------------------------------------------------

_face_cache = {}


def local_faces(shape, size):
    key = (shape, round(size[0], 2), round(size[1], 2), round(size[2], 2))
    if key in _face_cache:
        return _face_cache[key]
    sx, sy, sz = size
    if shape == 3:
        faces = wedge_faces(sx, sy, sz)
    elif shape == 1:
        faces = cylinder_faces(sx, sy, sz, n=10)
    elif shape == 2:
        faces = ball_faces(sx, sy, sz, nu=8, nv=5)
    else:
        faces = box_faces(sx, sy, sz)
        # Losas grandes: subdividir la cara superior en baldosas (recorte del plano cercano)
        if sx * sz > 1600:
            n_x = max(1, int(math.ceil(sx / 40)))
            n_z = max(1, int(math.ceil(sz / 40)))
            tiles = []
            for i in range(n_x):
                for j in range(n_z):
                    x0 = -sx / 2 + sx * i / n_x; x1 = -sx / 2 + sx * (i + 1) / n_x
                    z0 = -sz / 2 + sz * j / n_z; z1 = -sz / 2 + sz * (j + 1) / n_z
                    tiles.append(np.array([[x0, sy / 2, z0], [x0, sy / 2, z1], [x1, sy / 2, z1], [x1, sy / 2, z0]]))
            faces = [f for f in faces if not (np.allclose(f[:, 1], sy / 2))] + tiles
    _face_cache[key] = faces
    return faces


def cf_matrix(c):
    pos = np.array(c[:3], dtype=float)
    R = np.array([[c[3], c[4], c[5]], [c[6], c[7], c[8]], [c[9], c[10], c[11]]], dtype=float)
    return R, pos


class Batch:
    """Caras de un conjunto de piezas en coordenadas del espacio dado."""

    def __init__(self):
        self.verts = []   # listas de arrays (n x 3)
        self.color = []
        self.mat = []
        self.flags = []
        self.alpha = []
        self.flat = []

    def add_part(self, rec, R=None, pos=None):
        cf, size, color, shape, mat, transp, flags = rec[0], rec[1], rec[2], rec[3], rec[4], rec[5], rec[6]
        if R is None:
            R, pos = cf_matrix(cf)
        flat = (shape == 0 and ((size[1] <= 1.3 and size[0] * size[2] > 30) or size[0] * size[2] > 5000)) or (
            shape == 1 and size[0] <= 1.3 and size[1] >= 8 and abs(R[1][0]) > 0.9)
        for f in local_faces(shape, size):
            self.verts.append(f @ R.T + pos)
            self.color.append(color)
            self.mat.append(mat)
            self.flags.append(flags)
            self.alpha.append(transp)
            self.flat.append(flat)

    def finalize(self):
        self.counts = np.array([len(v) for v in self.verts], dtype=int)
        self.V = np.concatenate(self.verts) if self.verts else np.zeros((0, 3))
        self.color = np.array(self.color, dtype=float).reshape(-1, 3)
        self.mat = np.array(self.mat, dtype=int)
        self.flags = np.array(self.flags, dtype=int)
        self.alpha = np.array(self.alpha, dtype=float)
        self.flat = np.array(self.flat, dtype=bool)
        return self


def concat(batches):
    out = Batch()
    bs = [b for b in batches if len(b.counts)]
    out.counts = np.concatenate([b.counts for b in bs])
    out.V = np.concatenate([b.V for b in bs])
    out.color = np.concatenate([b.color for b in bs])
    out.mat = np.concatenate([b.mat for b in bs])
    out.flags = np.concatenate([b.flags for b in bs])
    out.alpha = np.concatenate([b.alpha for b in bs])
    out.flat = np.concatenate([b.flat for b in bs])
    return out


# ---------------------------------------------------------------------------
# Camara y dibujo
# ---------------------------------------------------------------------------

class Camera:
    def __init__(self, pos, target, fov=55):
        self.pos = np.array(pos, dtype=float)
        fwd = np.array(target, dtype=float) - self.pos
        self.fwd = fwd / np.linalg.norm(fwd)
        r = np.cross(self.fwd, [0, 1, 0]); self.right = r / np.linalg.norm(r)
        self.up = np.cross(self.right, self.fwd)
        self.f = (H / 2) / math.tan(math.radians(fov) / 2)

    def project(self, P):
        rel = P - self.pos
        z = rel @ self.fwd
        x = rel @ self.right
        y = rel @ self.up
        zc = np.maximum(z, 0.05)
        self.last_xyz = np.stack([x, y, z], axis=1)
        return np.stack([W / 2 + self.f * x / zc, H / 2 - self.f * y / zc], axis=1), z

    def clip_project(self, xyz, near=0.5):
        """Recorta un poligono (coords de camara) contra el plano cercano y lo proyecta."""
        out = []
        n = len(xyz)
        for i in range(n):
            a, b = xyz[i], xyz[(i + 1) % n]
            ina, inb = a[2] >= near, b[2] >= near
            if ina:
                out.append(a)
            if ina != inb:
                t = (near - a[2]) / (b[2] - a[2])
                out.append(a + (b - a) * t)
        return [(W / 2 + self.f * p[0] / p[2], H / 2 - self.f * p[1] / p[2]) for p in out]


def sky_image(night):
    g = np.linspace(0, 1, H)[:, None]
    if night <= 0:
        top, bot = np.array([105, 170, 245]), np.array([215, 232, 250])
    else:
        dt, db = np.array([105, 170, 245]), np.array([215, 232, 250])
        nt, nb = np.array([12, 18, 50]), np.array([70, 60, 110])
        top = dt * (1 - night) + nt * night
        bot = db * (1 - night) + nb * night
    sky = top * (1 - g) + bot * g
    return np.repeat(sky[:, None, :], W, axis=1).astype(np.uint8)


GLOW = None


def glow_sprite(r):
    y, x = np.mgrid[-r:r + 1, -r:r + 1]
    d = np.sqrt(x * x + y * y) / r
    return np.clip(1 - d, 0, 1) ** 2


def draw_frame(batch, cam, night=0.0, glows=(), fog_color=None):
    V2, Z = cam.project(batch.V)
    counts = batch.counts
    starts = np.concatenate([[0], np.cumsum(counts)[:-1]])
    nf = len(counts)
    # Datos por cara
    zmin = np.minimum.reduceat(Z, starts)
    zmean = np.add.reduceat(Z, starts) / counts
    centers = np.add.reduceat(batch.V, starts, axis=0) / counts[:, None]
    # normales
    i0 = starts; i1 = starts + 1; i2 = starts + 2
    n = np.cross(batch.V[i1] - batch.V[i0], batch.V[i2] - batch.V[i0])
    nn = np.linalg.norm(n, axis=1); nn[nn == 0] = 1
    n = n / nn[:, None]
    to_cam = cam.pos - centers
    zmax = np.maximum.reduceat(Z, starts)
    visible = (np.einsum("ij,ij->i", n, to_cam) > 0) & (zmax > 0.5) & (batch.alpha < 0.95)
    needs_clip = zmin < 0.5
    XYZ = cam.last_xyz
    sx = np.add.reduceat(V2[:, 0], starts) / counts
    sy = np.add.reduceat(V2[:, 1], starts) / counts
    xmin = np.minimum.reduceat(V2[:, 0], starts); xmax = np.maximum.reduceat(V2[:, 0], starts)
    ymin = np.minimum.reduceat(V2[:, 1], starts); ymax2 = np.maximum.reduceat(V2[:, 1], starts)
    visible &= needs_clip | ((xmax > 0) & (xmin < W) & (ymax2 > 0) & (ymin < H))
    dist = np.linalg.norm(to_cam, axis=1)
    # color
    shade = 0.55 + 0.45 * np.clip(n @ LIGHT, 0, None)
    col = batch.color * shade[:, None]
    neon = batch.mat == 1
    glass = batch.mat == 2
    col[neon] = np.clip(batch.color[neon] * 1.1 + 25, 0, 255)
    col[glass] = col[glass] * 0.75 + np.array([180, 210, 235]) * 0.25
    if night > 0:
        tint = np.array([0.32, 0.38, 0.62])
        dark = col * (1 - night) + col * tint * night
        win = (batch.flags & 1) > 0
        col = np.where((neon | win)[:, None], col, dark)
        col[win] = col[win] * (1 - night) + np.array([255, 215, 130]) * night
    fog = np.clip((dist - 180) / 900, 0, 0.75)[:, None]
    fogc = np.array(fog_color if fog_color is not None else ([200, 220, 245] if night <= 0 else [60, 60, 105]))
    col = col * (1 - fog) + fogc * fog
    col = np.clip(col, 0, 255).astype(int)
    # orden: losas primero (por altura), luego por distancia
    ymax = np.maximum.reduceat(batch.V[:, 1], starts)
    order_flat = np.where(batch.flat & visible)[0]
    order_flat = order_flat[np.lexsort((-zmean[order_flat], ymax[order_flat]))]
    order_rest = np.where(~batch.flat & visible)[0]
    order_rest = order_rest[np.argsort(-zmean[order_rest])]
    img = Image.fromarray(sky_image(night))
    d = ImageDraw.Draw(img, "RGBA")
    for idx in list(order_flat) + list(order_rest):
        s = starts[idx]
        if needs_clip[idx]:
            pts = cam.clip_project(XYZ[s:s + counts[idx]])
            if len(pts) < 3:
                continue
        else:
            pts = V2[s:s + counts[idx]]
        a = batch.alpha[idx]
        c = tuple(col[idx])
        if a > 0.02:
            d.polygon([tuple(p) for p in pts], fill=c + (int(255 * (1 - min(a, 0.9))),))
        else:
            d.polygon([tuple(p) for p in pts], fill=c)
    # Halos de luz de noche
    if night > 0.3 and len(glows):
        arr = np.asarray(img).astype(float)
        P = np.array([g[0] for g in glows])
        S, Zg = cam.project(P)
        for (pos, color), (x, y), z in zip(glows, S, Zg):
            if z < 1 or not (0 <= x < W and 0 <= y < H):
                continue
            r = int(max(3, min(60, 900 / z)))
            spr = glow_sprite(r) * 0.55 * night
            x0, y0 = int(x) - r, int(y) - r
            xs0, ys0 = max(0, x0), max(0, y0)
            xs1, ys1 = min(W, x0 + 2 * r + 1), min(H, y0 + 2 * r + 1)
            if xs1 <= xs0 or ys1 <= ys0:
                continue
            sp = spr[ys0 - y0:ys1 - y0, xs0 - x0:xs1 - x0]
            arr[ys0:ys1, xs0:xs1] += sp[:, :, None] * np.array(color)[None, None, :]
        img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return img


# ---------------------------------------------------------------------------
# Objetos animados
# ---------------------------------------------------------------------------

def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def look_matrix(direction):
    f = direction / np.linalg.norm(direction)
    r = np.cross(f, [0, 1, 0]); r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return np.stack([r, u, -f], axis=1)  # columnas: right, up, back


def ring_point(rx, rz, s):
    w, h = rx * 2, rz * 2
    perim = 2 * (w + h)
    s %= perim
    if s < w:
        return np.array([-rx + s, 0, -rz]), np.array([1, 0, 0.0])
    s -= w
    if s < h:
        return np.array([rx, 0, -rz + s]), np.array([0, 0, 1.0])
    s -= h
    if s < w:
        return np.array([rx - s, 0, rz]), np.array([-1, 0, 0.0])
    s -= w
    return np.array([-rx, 0, rz - s]), np.array([0, 0, -1.0])


def dynamic_batch(dyn, t, include_walkers=True, include_cars=True, include_clouds=True):
    b = Batch()
    rx, rz = dyn["ring"]
    if include_cars:
        for car in dyn["cars"]:
            perim = 2 * (rx * 2 + rz * 2)
            s = car["phase"] * perim + t * car["speed"] * car["lane"]
            pos, d = ring_point(rx, rz, s)
            if car["lane"] < 0:
                d = -d
            right = np.cross(d, [0, 1, 0])
            p = pos + right * 5 + np.array([0, 0.3, 0])
            M = look_matrix(d)
            for rec in car["parts"]:
                Rl, pl = cf_matrix(rec[0])
                b.add_part(rec, M @ Rl, M @ pl + p)
    if include_walkers:
        for w in dyn["walkers"]:
            if w["mode"] == "line":
                a, bb = np.array(w["a"]), np.array(w["b"])
                delta = bb - a
                L = np.linalg.norm(delta)
                s = (w["phase"] * 2 * L + t * abs(w["speed"])) % (2 * L)
                if s < L:
                    pos, d = a + delta * (s / L), delta / L
                else:
                    pos, d = bb - delta * ((s - L) / L), -delta / L
            else:
                ang = w["phase"] * 2 * math.pi + t * w["speed"] / w["radius"]
                pos = np.array([w["cx"] + math.cos(ang) * w["radius"], 0, w["cz"] + math.sin(ang) * w["radius"]])
                d = np.array([-math.sin(ang), 0, math.cos(ang)]) * (1 if w["speed"] >= 0 else -1)
            pos = np.array([pos[0], w["baseY"], pos[2]])
            M = look_matrix(d)
            swing = math.sin(t * abs(w["speed"]) * 1.9 + w["phase"] * 10) * 0.55
            for rec in w["parts"]:
                Rl, pl = cf_matrix(rec[0])
                limb = rec[8] if len(rec) > 8 else ""
                if limb in ("legL", "legR"):
                    a_ = swing if limb == "legL" else -swing
                    hip = np.array([0, 2, 0.0])
                    Rr = rot_x(a_)
                    Rl, pl = Rr @ Rl, Rr @ (pl - hip) + hip
                elif limb in ("armL", "armR"):
                    a_ = (-swing if limb == "armL" else swing) * 0.8
                    sh = np.array([0, 3.9, 0.0])
                    Rr = rot_x(a_)
                    Rl, pl = Rr @ Rl, Rr @ (pl - sh) + sh
                b.add_part(rec, M @ Rl, M @ pl + pos)
    if include_clouds:
        for c in dyn["clouds"]:
            x = ((c["pos"][0] + t * c["speed"] * 6 + 700) % 1400) - 700
            p = np.array([x, c["pos"][1], c["pos"][2]])
            for rec in c["parts"]:
                Rl, pl = cf_matrix(rec[0])
                b.add_part(rec, Rl, pl + p)
    return b.finalize() if b.verts else None


def traffic_glows(dyn, t):
    out = []
    for tl in dyn["lights"]:
        cycle = (t / 12 + tl["phase"]) % 1
        state = 2 if cycle < 0.42 else (1 if cycle < 0.54 else 0)
        lamp = tl["lamps"][state]
        out.append((np.array(lamp["pos"]), lamp["color"]))
    return out


def traffic_batch(dyn, t):
    b = Batch()
    for tl in dyn["lights"]:
        cycle = (t / 12 + tl["phase"]) % 1
        state = 2 if cycle < 0.42 else (1 if cycle < 0.54 else 0)
        lamp = tl["lamps"][state]
        p = np.array(lamp["pos"])
        rec = [[0] * 12, [0.85, 0.85, 0.25], lamp["color"], 0, 1, 0, 0]
        # orientar hacia afuera no importa: es una baldosa brillante pequena
        for off in (np.array([0, 0, -0.08]), np.array([0, 0, 0.08]), np.array([-0.08, 0, 0]), np.array([0.08, 0, 0])):
            b.add_part(rec, np.eye(3), p + off)
    return b.finalize()


class Stage:
    """Parcela en una etapa: piezas estaticas + grupos animados."""

    def __init__(self, data):
        self.static = Batch()
        self.groups = []
        groups = data["groups"]
        grouped = {i + 1: [] for i in range(len(groups))}
        for rec in data["parts"]:
            g = rec[7]
            if g and g in grouped:
                grouped[g].append(rec)
            else:
                self.static.add_part(rec)
        self.static.finalize()
        for i, g in enumerate(groups):
            Rp, pp = cf_matrix(g["pivot"])
            parts = []
            for rec in grouped[i + 1]:
                R, p = cf_matrix(rec[0])
                parts.append((rec, Rp.T @ R, Rp.T @ (p - pp)))
            self.groups.append((g, Rp, pp, parts))
        self.keys = set(self.part_key(r) for r in data["parts"])
        self.data = data

    @staticmethod
    def part_key(rec):
        c = rec[0]
        return (round(c[0], 1), round(c[1], 1), round(c[2], 1), round(rec[1][0], 1), round(rec[1][1], 1), round(rec[1][2], 1), tuple(rec[2]))

    def animated(self, t):
        b = Batch()
        for g, Rp, pp, parts in self.groups:
            Ra = np.eye(3)
            off = np.zeros(3)
            if g.get("slide"):
                ph = t * g["slideSpeed"] + g["slidePhase"]
                f = ph % 1 if g["slideMode"] == "loop" else (1 - math.cos(ph * 2 * math.pi)) / 2
                off = off + np.array(g["slide"]) * f
            if g["spin"]:
                a = math.radians(g["spin"]) * t
                Ra = {"X": rot_x, "Z": rot_z}.get(g["axis"], rot_y)(a)
            bob = np.array([0, math.sin(t * g["bobSpeed"] * math.pi) * g["bob"], 0]) if g["bob"] else np.zeros(3)
            for rec, Rl, pl in parts:
                R = Rp @ Ra @ Rl
                p = Rp @ (Ra @ pl + off) + pp + bob
                b.add_part(rec, R, p)
        return b.finalize() if b.verts else None


def rising_batch(data, new_keys, progress):
    """Piezas nuevas de una etapa que suben desde el suelo."""
    b = Batch()
    for rec in data["parts"]:
        if Stage.part_key(rec) in new_keys:
            R, p = cf_matrix(rec[0])
            h = rec[0][1]
            lift = (1 - smooth(progress)) * (6 + h * 0.4)
            b.add_part(rec, R, p - np.array([0, lift, 0]))
    return b.finalize() if b.verts else None


# ---------------------------------------------------------------------------
# Superposiciones (HUD, textos)
# ---------------------------------------------------------------------------

def hud_overlay(gui_json):
    data = json.load(open(gui_json))

    def blank(node):
        name = node.get("name")
        if name in ("Tutorial", "Goal", "Toasts", "Level", "Badge"):
            node["visible"] = False
        elif name in ("Amount", "Income"):
            node["text"] = ""
        elif "text" in node and render_gui.clean(node["text"]).replace("●", "").strip() == "":
            node["text"] = ""  # solo emojis: el renderizador no tiene fuente de emojis
        for c in node["children"]:
            blank(c)
    blank(data)
    r = render_gui.Renderer(W, H)
    tmp = "/tmp/_hud_overlay.png"
    r.render(data, tmp, background="transparent")
    s = r.scale
    amount = r.rects.get("Amount"); income = r.rects.get("Income")
    return Image.open(tmp).convert("RGBA"), [v * s for v in amount], [v * s for v in income]


def text_center(img, text, y, size, fill=(255, 230, 90), stroke=(60, 25, 100), sw=None, alpha=1.0):
    if alpha <= 0:
        return
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((W / 2, y), text, font=fredoka(size), fill=fill + (255,), stroke_width=sw or max(2, int(size / 10)), stroke_fill=stroke + (255,), anchor="mm")
    if alpha < 1:
        a = layer.getchannel("A").point(lambda v: int(v * alpha))
        layer.putalpha(a)
    img.alpha_composite(layer)


def pill(img, text, y, color, alpha=1.0, size=None):
    if alpha <= 0:
        return
    size = size or H * 0.045
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = fredoka(size)
    w = d.textlength(text, font=f) + size * 1.6
    d.rounded_rectangle([W / 2 - w / 2, y - size * 0.85, W / 2 + w / 2, y + size * 0.85], radius=size * 0.85, fill=color + (235,), outline=(255, 255, 255, 255), width=max(2, int(size / 12)))
    d.text((W / 2, y), text, font=f, fill=(255, 255, 255, 255), stroke_width=max(1, int(size / 14)), stroke_fill=tuple(int(c * 0.5) for c in color) + (255,), anchor="mm")
    if alpha < 1:
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v * alpha)))
    img.alpha_composite(layer)


def fmt_cash(n):
    suf = ["", "K", "M", "B", "T", "Qa"]
    i = 0
    while n >= 1000 and i < len(suf) - 1:
        n /= 1000; i += 1
    if i == 0:
        return "$%d" % n
    return ("$%.2f" % n).rstrip("0").rstrip(".") + suf[i] if n < 100 else "$%d%s" % (n, suf[i])


# ---------------------------------------------------------------------------
# Guion
# ---------------------------------------------------------------------------

def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "build/video"
    out = sys.argv[2] if len(sys.argv) > 2 else "assets/video_presentacion.mp4"
    frames_dir = "/tmp/te_frames"
    os.makedirs(frames_dir, exist_ok=True)
    for f in os.listdir(frames_dir):
        os.remove(os.path.join(frames_dir, f))

    print("Cargando escena...")
    world_data = json.load(open(os.path.join(src, "world.json")))
    world = Batch()
    for rec in world_data["parts"]:
        world.add_part(rec)
    world.finalize()
    world_lamps = [(np.array(r[0][:3]), (255, 200, 120)) for r in world_data["parts"] if r[6] & 2]
    dyn = json.load(open(os.path.join(src, "dynamic.json")))
    info = json.load(open(os.path.join(src, "stages.json")))
    stages_raw = [json.load(open(os.path.join(src, "stage_%02d.json" % i))) for i in range(info["count"])]
    stages = [Stage(d) for d in stages_raw]
    final = stages[-1]
    plot_lamps = [(np.array(r[0][:3]), (255, 200, 120)) for r in stages_raw[-1]["parts"] if r[6] & 2]
    pcx, pcz = info["plotCenter"]
    hud, amount_rect, income_rect = hud_overlay(os.path.join("build", "gui", "hud.json"))
    icon = make_images.game_icon(512).resize((int(H * 0.36), int(H * 0.36)), Image.LANCZOS)
    print("Caras del mundo: %d" % len(world.counts))

    frame_no = [0]

    def emit(img):
        img.convert("RGB").save(os.path.join(frames_dir, "f%05d.png" % frame_no[0]))
        frame_no[0] += 1
        if frame_no[0] % 24 == 0:
            print("  frame %d" % frame_no[0], flush=True)

    def scene_batch(t, stage_index=None, rising=None, walkers=True, cars=True, clouds=True):
        parts = [world]
        st = stages[stage_index] if stage_index is not None else final
        parts.append(st.static)
        anim = st.animated(t)
        if anim is not None:
            parts.append(anim)
        if rising is not None:
            parts.append(rising)
        dynb = dynamic_batch(dyn, t, walkers, cars, clouds)
        if dynb is not None:
            parts.append(dynb)
        parts.append(traffic_batch(dyn, t))
        return concat(parts)

    def frames(seconds):
        return int(seconds * FPS)

    T = 0.0  # tiempo de juego para animaciones

    # 1) Intro: vuelo sobre la ciudad con el titulo
    n = frames(4.5)
    for i in range(n):
        u = i / n
        a = math.radians(-160 + 40 * u)
        target = np.array([40, 0, 40])
        cam = Camera(target + np.array([math.sin(a) * 400, 170 - 30 * u, math.cos(a) * 400]), target)
        img = draw_frame(scene_batch(T, clouds=False), cam).convert("RGBA")
        alpha = smooth(u * 3) * (1 - smooth((u - 0.85) * 7))
        if alpha > 0:
            ic = icon.copy()
            ic.putalpha(ic.getchannel("A").point(lambda v: int(v * alpha)))
            img.alpha_composite(ic, (int(W / 2 - ic.size[0] / 2), int(H * 0.16)))
        text_center(img, "TINY EMPIRE TYCOON", H * 0.66, H * 0.09, alpha=alpha)
        pill(img, "¡Construye el imperio de tus sueños!", H * 0.78, (255, 90, 120), alpha=alpha)
        emit(img)
        T += 1 / FPS

    # 2) Construccion en camara rapida con HUD
    per = 0.42
    n_stages = len(stages)
    total = per * n_stages + 1.0
    n = frames(total)
    cash = 0.0
    for i in range(n):
        tl = i / FPS
        k = min(n_stages - 1, int(tl / per))
        local = (tl - k * per) / per
        new_keys = stages[k].keys - stages[k - 1].keys if k > 0 else set()
        rising = rising_batch(stages_raw[k], new_keys, local * 1.6) if new_keys and local < 0.65 else None
        st_index = k - 1 if rising is not None else k
        u = tl / total
        a = math.radians(-35 + 50 * u)
        target = np.array([pcx, 8 + 10 * u, pcz])
        R = 125 + 45 * u
        cam = Camera(target + np.array([math.sin(a) * R, 60 + 30 * u, -math.cos(a) * R]), target)
        img = draw_frame(scene_batch(T, st_index, rising), cam).convert("RGBA")
        img.alpha_composite(hud)
        income = info["info"][k]["income"]
        cash += income * 40 / FPS + (k + 1) * 3
        d = ImageDraw.Draw(img)
        x, y, w, h = amount_rect
        make_images.draw_coin(d, x - h * 0.75, y + h * 0.75, h * 0.45)
        d.text((x, y + h / 2), fmt_cash(cash), font=fredoka(h * 0.8), fill=(255, 255, 255), stroke_width=max(1, int(h * 0.06)), stroke_fill=(20, 60, 30), anchor="lm")
        x, y, w, h = income_rect
        d.text((x, y + h / 2), "+" + fmt_cash(income) + "/s", font=fredoka(h * 0.85), fill=(90, 220, 120), anchor="lm")
        label = strip_emoji(info["info"][k]["label"])
        if label:
            pill(img, label, H * 0.86, (80, 160, 255) if "Nv" in label else (80, 200, 110), alpha=min(1, local * 4) if k > 0 else 0)
        if i < FPS * 1.6:
            text_center(img, "¡Construye y mejora 10 negocios!", H * 0.24, H * 0.06, alpha=1 - smooth((i / FPS - 1.2) * 3))
        emit(img)
        T += 1 / FPS

    # 3) Primer plano de la parcela terminada (animaciones de produccion)
    n = frames(6)
    for i in range(n):
        u = i / n
        a = math.radians(20 + 70 * u)
        target = np.array([pcx, 12, pcz + 5])
        cam = Camera(target + np.array([math.sin(a) * 70, 32, -math.cos(a) * 70]), target, fov=60)
        img = draw_frame(scene_batch(T), cam).convert("RGBA")
        text_center(img, "Fábricas, laboratorios y rascacielos animados", H * 0.9, H * 0.05, alpha=smooth(u * 4) * (1 - smooth((u - 0.85) * 7)))
        emit(img)
        T += 1 / FPS

    # 4) Plaza social
    n = frames(5.5)
    for i in range(n):
        u = i / n
        a = math.radians(200 + 60 * u)
        target = np.array([0, 4, 0])
        cam = Camera(target + np.array([math.sin(a) * 62, 22, math.cos(a) * 62]), target, fov=60)
        img = draw_frame(scene_batch(T), cam).convert("RGBA")
        text_center(img, "Plaza social: juega con tus amigos", H * 0.9, H * 0.05, alpha=smooth(u * 4) * (1 - smooth((u - 0.85) * 7)))
        emit(img)
        T += 1 / FPS

    # 5) Calles con trafico
    n = frames(4.5)
    for i in range(n):
        u = i / n
        target = np.array([30 + 40 * u, 0, 185])
        cam = Camera(np.array([-75 + 45 * u, 26, 128]), target, fov=60)
        img = draw_frame(scene_batch(T), cam, glows=[]).convert("RGBA")
        text_center(img, "4 barrios llenos de vida", H * 0.9, H * 0.05, alpha=smooth(u * 4) * (1 - smooth((u - 0.85) * 7)))
        emit(img)
        T += 1 / FPS

    # 6) Atardecer y noche
    n = frames(6)
    for i in range(n):
        u = i / n
        night = smooth(u * 1.6)
        a = math.radians(-40 + 50 * u)
        target = np.array([pcx - 40, 10, pcz - 30])
        cam = Camera(target + np.array([math.sin(a) * 230, 120 - 30 * u, -math.cos(a) * 230]), target)
        glows = world_lamps + plot_lamps + traffic_glows(dyn, T)
        img = draw_frame(scene_batch(T, walkers=True, clouds=False), cam, night=night, glows=glows).convert("RGBA")
        text_center(img, "Ciclo de día y noche", H * 0.9, H * 0.05, alpha=smooth((u - 0.2) * 4) * (1 - smooth((u - 0.88) * 8)))
        emit(img)
        T += 1 / FPS

    # 7) Cierre
    n = frames(3.5)
    bg = make_images.vgradient((W, H), (255, 170, 120), (90, 110, 220))
    for i in range(n):
        u = i / n
        img = bg.copy()
        sc = 0.6 + 0.4 * smooth(u * 3)
        ic = icon.resize((int(icon.size[0] * sc), int(icon.size[1] * sc)), Image.LANCZOS)
        img.alpha_composite(ic, (int(W / 2 - ic.size[0] / 2), int(H * 0.32 - ic.size[1] / 2)))
        text_center(img, "TINY EMPIRE TYCOON", H * 0.62, H * 0.1, alpha=smooth((u - 0.1) * 4))
        pill(img, "¡Tu ciudad te espera en Roblox!", H * 0.76, (60, 190, 110), alpha=smooth((u - 0.3) * 4))
        emit(img)

    print("Codificando %d fotogramas..." % frame_no[0])
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(frames_dir, "f%05d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", "-preset", "medium", "-movflags", "+faststart", out], check=True)
    print(out)


if __name__ == "__main__":
    main()
