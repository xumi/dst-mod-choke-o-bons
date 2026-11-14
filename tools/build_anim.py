#!/usr/bin/env python3
"""Builds anim/chokeobon.zip (a static one-frame Klei animation) from a PNG.

Usage: build_anim.py <sprite.png> <out_dir> [variant]

The click box seems to be read by the game at a smaller scale than the sprite and with
the vertical axis pointing up, so the box is the sprite size times a padding factor.
Variants try different factors (1: 2.0, 2: 2.6, 3: 3.4); variant 1 is the real model
name ("chokeobon"), the others are "chokeobon_v2" and "chokeobon_v3".

Needs `ktech` on the PATH. The sprite is trimmed, fitted into a 256x256 atlas
and shown as a single "idle" frame in the "chokeobon" bank/build.
"""
import os, struct, subprocess, sys, zipfile, tempfile

NAME = "chokeobon"
VARIANT = 1
ATLAS = 256
WORLD_HEIGHT = 150.0  # height of the sprite in world units; tweak to resize and rebuild
HITBOX_PADS = {1: 2.0, 2: 2.6, 3: 3.4}   # click box size relative to the sprite, per variant


def strhash(s):
    h = 0
    for c in s.lower():
        h = (ord(c) + (h << 6) + (h << 16) - h) & 0xFFFFFFFF
    return h


def lstr(s):
    b = s.encode()
    return struct.pack("<I", len(b)) + b


def build_bin(w, h, u0, v0, u1, v1):
    hw, hh = w / 2.0, h / 2.0
    # two triangles; vertices are (x, y, z, u, v, depth)
    tl = (-hw, -hh, 0, u0, v1, 0)
    tr = (hw, -hh, 0, u1, v1, 0)
    bl = (-hw, hh, 0, u0, v0, 0)
    br = (hw, hh, 0, u1, v0, 0)
    verts = [tl, tr, bl, tr, br, bl]
    sym = strhash(NAME)

    out = b"BILD" + struct.pack("<i", 6)
    out += struct.pack("<II", 1, 1)               # symbols, frames
    out += lstr(NAME)
    out += struct.pack("<I", 1) + lstr("atlas-0.tex")
    out += struct.pack("<I", sym)
    out += struct.pack("<I", 1)                   # symbol frame count
    # Frame bbox is measured from the sprite's centre, so it must be centred too
    pad = HITBOX_PADS[VARIANT]
    bw, bh = w * pad, h * pad
    out += struct.pack("<IIffffII", 0, 1, -bw / 2.0, -bh / 2.0, bw, bh, 0, 6)
    out += struct.pack("<I", 6)                   # total vertices
    for v in verts:
        out += struct.pack("<6f", *v)
    out += struct.pack("<I", 1) + struct.pack("<I", sym) + lstr(NAME)
    return out


def anim_bin(w, h):
    sym = strhash(NAME)
    out = b"ANIM" + struct.pack("<i", 4)
    out += struct.pack("<IIII", 1, 1, 0, 1)       # elements, frames, events, anims
    out += lstr("idle")
    out += struct.pack("<B", 0xFF)                # facing: any
    out += struct.pack("<I", strhash(NAME))       # bank
    out += struct.pack("<f", 30.0)
    out += struct.pack("<I", 1)                   # frames
    # frame: bbox, events, elements
    # The box is centred on the sprite (whose centre is h/2 above the ground)
    pad = HITBOX_PADS[VARIANT]
    bw, bh = w * pad, h * pad
    # y points up for this box, so the sprite's centre is h/2 above the ground
    out += struct.pack("<ffffII", -bw / 2.0, h / 2.0 - bh / 2.0, bw, bh, 0, 1)
    # element: symbol hash, build frame, layer hash, matrix a b c d tx ty, z
    out += struct.pack("<III", sym, 0, sym)
    out += struct.pack("<6f", 1, 0, 0, 1, 0, -h / 2.0)
    out += struct.pack("<f", 0.0)
    out += struct.pack("<I", 1) + struct.pack("<I", sym) + lstr(NAME)
    return out


def main():
    global NAME, VARIANT
    src, out_dir = sys.argv[1], sys.argv[2]
    VARIANT = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    if VARIANT != 1:
        NAME = "chokeobon_v%d" % VARIANT
    os.makedirs(out_dir, exist_ok=True)
    tmp = tempfile.mkdtemp()
    atlas_png = os.path.join(tmp, "atlas-0.png")
    # trim, fit into the atlas and centre on a transparent canvas
    subprocess.check_call(["convert", src, "-trim", "+repage",
                           "-resize", "%dx%d" % (ATLAS, ATLAS), "-background", "none",
                           "-gravity", "center", "-extent", "%dx%d" % (ATLAS, ATLAS), atlas_png])
    # find the trimmed size to place the quad on the right atlas region
    trimmed = subprocess.check_output(["convert", src, "-trim", "+repage",
                                       "-resize", "%dx%d" % (ATLAS, ATLAS), "-format", "%w %h", "info:"]).split()
    tw, th = int(trimmed[0]), int(trimmed[1])
    u0, u1 = (ATLAS - tw) / 2.0 / ATLAS, (ATLAS + tw) / 2.0 / ATLAS
    v0, v1 = (ATLAS - th) / 2.0 / ATLAS, (ATLAS + th) / 2.0 / ATLAS
    scale = WORLD_HEIGHT / th
    w, h = tw * scale, th * scale

    tex = os.path.join(tmp, "atlas-0.tex")
    subprocess.check_call(["ktech", atlas_png, tex], stdout=subprocess.DEVNULL)

    for name, data in (("build.bin", build_bin(w, h, u0, v0, u1, v1)),
                       ("anim.bin", anim_bin(w, h))):
        with open(os.path.join(tmp, name), "wb") as f:
            f.write(data)

    zpath = os.path.join(out_dir, NAME + ".zip")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_STORED) as z:
        for name in ("anim.bin", "build.bin", "atlas-0.tex"):
            z.write(os.path.join(tmp, name), name)
    print("wrote", zpath)


if __name__ == "__main__":
    main()
