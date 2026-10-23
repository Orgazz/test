#!/usr/bin/env python3
"""Renderizador isometrico sencillo (pintor + sombreado) para revisar el mapa
exportado por tools/export_scene.luau sin abrir Roblox Studio.

Uso:
  python3 tools/render.py build/scene.json salida.png [cx cz radio [yaw] [pitch]]
"""
import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

SKY_TOP = np.array([120, 175, 235])
SKY_BOTTOM = np.array([205, 228, 250])


def rot_matrix(c):
    # componentes: x y z R00 R01 R02 R10 R11 R12 R20 R21 R22
    return np.array(c[:3]), np.array([[c[3], c[4], c[5]], [c[6], c[7], c[8]], [c[9], c[10], c[11]]])


def box_faces(sx, sy, sz):
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    v = np.array([[x, y, z] for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)])
    # indices: (x,y,z) bits -> 4x + 2y + z
    def idx(x, y, z):
        return 4 * x + 2 * y + z
    quads = [
        [idx(1, 0, 0), idx(1, 1, 0), idx(1, 1, 1), idx(1, 0, 1)],  # +X
        [idx(0, 0, 1), idx(0, 1, 1), idx(0, 1, 0), idx(0, 0, 0)],  # -X
        [idx(0, 1, 0), idx(0, 1, 1), idx(1, 1, 1), idx(1, 1, 0)],  # +Y
        [idx(0, 0, 0), idx(1, 0, 0), idx(1, 0, 1), idx(0, 0, 1)],  # -Y
        [idx(0, 0, 1), idx(1, 0, 1), idx(1, 1, 1), idx(0, 1, 1)],  # +Z
        [idx(0, 1, 0), idx(1, 1, 0), idx(1, 0, 0), idx(0, 0, 0)],  # -Z
    ]
    return [v[q] for q in quads]


def wedge_faces(sx, sy, sz):
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    # Cuna de Roblox: cara trasera (+Z) vertical, pendiente hacia -Z
    a = np.array([-hx, -hy, -hz]); b = np.array([hx, -hy, -hz])
    c = np.array([hx, -hy, hz]); d = np.array([-hx, -hy, hz])
    e = np.array([-hx, hy, hz]); f = np.array([hx, hy, hz])
    return [
        np.array([a, b, c, d]),  # base
        np.array([d, c, f, e]),  # trasera
        np.array([a, e, f, b]),  # pendiente
        np.array([a, d, e]),  # lateral -X
        np.array([b, f, c]),  # lateral +X
    ]


def cylinder_faces(sx, sy, sz, n=12):
    # eje a lo largo de X local
    hx = sx / 2
    r = min(sy, sz) / 2
    ring = [(math.cos(2 * math.pi * i / n) * r, math.sin(2 * math.pi * i / n) * r) for i in range(n)]
    faces = []
    for i in range(n):
        y0, z0 = ring[i]; y1, z1 = ring[(i + 1) % n]
        faces.append(np.array([[-hx, y0, z0], [hx, y0, z0], [hx, y1, z1], [-hx, y1, z1]]))
    faces.append(np.array([[hx, y, z] for y, z in ring]))
    faces.append(np.array([[-hx, y, z] for y, z in reversed(ring)]))
    return faces


def ball_faces(sx, sy, sz, nu=10, nv=6):
    r = min(sx, sy, sz) / 2
    faces = []
    for j in range(nv):
        t0 = math.pi * j / nv - math.pi / 2; t1 = math.pi * (j + 1) / nv - math.pi / 2
        for i in range(nu):
            p0 = 2 * math.pi * i / nu; p1 = 2 * math.pi * (i + 1) / nu
            def pt(t, p):
                return [r * math.cos(t) * math.cos(p), r * math.sin(t), r * math.cos(t) * math.sin(p)]
            faces.append(np.array([pt(t0, p0), pt(t0, p1), pt(t1, p1), pt(t1, p0)]))
    return faces


def render(scene_path, out_path, cx=0.0, cz=0.0, radius=500.0, yaw=45.0, pitch=35.0, size=(1600, 1000), night=False):
    scene = json.load(open(scene_path))
    yawr = math.radians(yaw); pitchr = math.radians(pitch)
    to_cam = np.array([math.sin(yawr) * math.cos(pitchr), math.sin(pitchr), math.cos(yawr) * math.cos(pitchr)])
    forward = -to_cam
    right = np.cross(forward, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    light = np.array([0.45, 0.85, 0.3]); light /= np.linalg.norm(light)
    W, Hh = size
    scale = min(W, Hh) / (2 * radius) * 1.15
    center = np.array([cx, 0, cz])

    polys = []
    for p in scene["parts"]:
        pos, R = rot_matrix(p["cf"])
        sx, sy, sz = p["size"]
        reach = radius * 1.6 + max(sx, sz) / 2
        if abs(pos[0] - cx) > reach or abs(pos[2] - cz) > reach:
            continue
        if max(sx, sy, sz) > 900:
            pass
        shape = p["shape"]
        if shape == "Wedge":
            faces = wedge_faces(sx, sy, sz)
        elif shape == "Cylinder":
            faces = cylinder_faces(sx, sy, sz)
        elif shape == "Ball":
            faces = ball_faces(sx, sy, sz)
        else:
            faces = box_faces(sx, sy, sz)
        color = np.array(p["color"]) * 255
        flat = shape == "Block" and ((sy <= 1.3 and sx * sz > 30) or sx * sz > 5000)
        mat = p["m"]
        neon = mat == "Neon"
        glass = mat == "Glass"
        for f in faces:
            wf = (R @ f.T).T + pos
            n = np.cross(wf[1] - wf[0], wf[2] - wf[0])
            nn = np.linalg.norm(n)
            if nn < 1e-9:
                continue
            n /= nn
            if np.dot(n, to_cam) <= 0:
                continue
            shade = 0.55 + 0.45 * max(0.0, float(np.dot(n, light)))
            if neon:
                col = np.clip(color * 1.15 + 30, 0, 255)
            else:
                col = color * shade
                if glass:
                    col = col * 0.75 + np.array([180, 210, 235]) * 0.25
            if night and not neon:
                col = col * np.array([0.35, 0.4, 0.6])
            rel = wf - center
            xs = rel @ right * scale + W / 2
            ys = -(rel @ up) * scale + Hh / 2
            depth = float(np.mean(rel @ forward))
            # Las losas planas (suelo, carreteras, bases) se pintan primero por altura
            key = (0, float(np.max(wf[:, 1])), -depth) if flat else (1, -depth, 0.0)
            polys.append((key, list(zip(xs.tolist(), ys.tolist())), tuple(int(c) for c in col), p.get("t", 0)))

    polys.sort(key=lambda t: t[0])
    img = Image.new("RGB", size)
    grad = np.linspace(0, 1, Hh)[:, None]
    sky = (SKY_TOP * (1 - grad) + SKY_BOTTOM * grad) if not night else (np.array([10, 15, 40]) * (1 - grad) + np.array([40, 50, 90]) * grad)
    img = Image.fromarray(np.repeat(sky[:, None, :], W, axis=1).astype(np.uint8))
    draw = ImageDraw.Draw(img, "RGBA")
    for _, pts, col, t in polys:
        alpha = int(255 * (1 - min(0.85, t)))
        draw.polygon(pts, fill=col + (alpha,))
    img.save(out_path)
    print(f"{out_path}: {len(polys)} poligonos")


if __name__ == "__main__":
    args = sys.argv[1:]
    scene, out = args[0], args[1]
    nums = [float(a) for a in args[2:] if not a.startswith("--")][:5]
    night = "--night" in args
    kwargs = {}
    if len(nums) >= 3:
        kwargs.update(cx=nums[0], cz=nums[1], radius=nums[2])
    if len(nums) >= 4:
        kwargs["yaw"] = nums[3]
    if len(nums) >= 5:
        kwargs["pitch"] = nums[4]
    for a in args:
        if a.startswith("--size="):
            w, h = a[7:].split("x")
            kwargs["size"] = (int(w), int(h))
    ss = 2 if "--aa" in args else 1
    if ss > 1:
        size = kwargs.get("size", (1600, 1000))
        kwargs["size"] = (size[0] * ss, size[1] * ss)
        render(scene, out, night=night, **kwargs)
        from PIL import Image
        Image.open(out).resize(size, Image.LANCZOS).save(out)
    else:
        render(scene, out, night=night, **kwargs)
