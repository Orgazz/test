#!/usr/bin/env python3
"""Renderiza el video de fisicas y animaciones exportado por
tools/export_physics_video.luau (codigo real del juego ejecutado en el arnes).

Uso: python3 tools/make_physics_video.py build/pvideo assets/video_fisicas.mp4
"""
import glob
import json
import os
import subprocess
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_video as mv  # noqa: E402

FPS = 24


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "build/pvideo"
    out = sys.argv[2] if len(sys.argv) > 2 else "assets/video_fisicas.mp4"
    frames_dir = "/tmp/te_pframes"
    os.makedirs(frames_dir, exist_ok=True)
    for f in os.listdir(frames_dir):
        os.remove(os.path.join(frames_dir, f))
    info = json.load(open(os.path.join(src, "scenes.json")))
    W, H = mv.W, mv.H
    n_out = 0

    def emit(img):
        nonlocal n_out
        img.convert("RGB").save(os.path.join(frames_dir, "f%05d.png" % n_out))
        n_out += 1
        if n_out % 48 == 0:
            print("  frame %d" % n_out, flush=True)

    # Portada
    icon = mv.make_images.game_icon(512).resize((int(H * 0.34), int(H * 0.34)), Image.LANCZOS)
    bg = mv.make_images.vgradient((W, H), (255, 170, 120), (90, 110, 220))
    for i in range(int(2.5 * FPS)):
        u = i / (2.5 * FPS)
        img = bg.copy()
        img.alpha_composite(icon, (int(W / 2 - icon.size[0] / 2), int(H * 0.12)))
        mv.text_center(img, "FÍSICAS Y ANIMACIONES", H * 0.6, H * 0.085, alpha=mv.smooth(u * 4))
        mv.pill(img, "Tiny Empire Tycoon · código real del juego", H * 0.74, (60, 150, 255), alpha=mv.smooth(u * 4 - 0.5))
        emit(img)

    for sidx in range(1, info["count"] + 1):
        base_data = json.load(open(os.path.join(src, "s%02d_base.json" % sidx)))
        base = mv.Batch()
        for rec in base_data["parts"]:
            base.add_part(rec)
        base.finalize()
        title = base_data["title"]
        files = sorted(glob.glob(os.path.join(src, "s%02d_f*.json" % sidx)))
        print("Escena %d: %d fotogramas, %d caras base" % (sidx, len(files), len(base.counts)))
        total = len(files)
        for i, fpath in enumerate(files):
            fr = json.load(open(fpath))
            b = mv.Batch()
            for rec in fr["parts"]:
                b.add_part(rec)
            b.finalize()
            batch = mv.concat([base, b]) if len(b.counts) else base
            c = fr["cam"]
            cam = mv.Camera(c[0:3], c[3:6], fov=c[6])
            img = mv.draw_frame(batch, cam).convert("RGBA")
            u = i / max(1, total - 1)
            alpha = mv.smooth(u * 6) * (1 - mv.smooth((u - 0.9) * 10))
            mv.pill(img, title, H * 0.9, (40, 40, 70), alpha=alpha, size=H * 0.034)
            mv.text_center(img, "%d/%d" % (sidx, info["count"]), H * 0.06, H * 0.04, fill=(255, 255, 255), alpha=alpha)
            emit(img)

    print("Codificando %d fotogramas..." % n_out)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(frames_dir, "f%05d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "21", "-preset", "medium", "-movflags", "+faststart", out], check=True)
    print(out)


if __name__ == "__main__":
    main()
