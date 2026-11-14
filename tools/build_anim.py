#!/usr/bin/env python3
"""Builds anim/chokeobon.zip (a static one-frame Klei animation) from a PNG.

Usage: build_anim.py <sprite.png> <out_dir> [variant]

The boxes follow Klei's own compiler (ds_mod_tools: src/app/scml/main.cpp and
buildanimation.py):
  * build file: one box per symbol frame, (x, y, w, h) with x, y the CENTRE of the image
    and w, h whole numbers;
  * anim file: per frame, the union of the build boxes moved by each element's matrix,
    then enlarged by 1.2 about its centre. The compiler treats (x, y) as a corner and
    computes the bottom edge from the left edge; that quirk is reproduced on purpose,
    since vanilla items are built with it.

Variants (the real model is variant 1, named "chokeobon"; the others are "chokeobon_v2"
and "chokeobon_v3"):
  1: exactly what Klei's compiler writes
  2: same, but with the bottom edge computed from the top edge
  3: same as 1, with the anim box a further 1.6x larger

Needs `ktech` on the PATH. The sprite is trimmed, fitted into a 256x256 atlas
and shown as a single "idle" frame in the "chokeobon" bank/build.
"""
import math, os, struct, subprocess, sys, zipfile, tempfile

NAME = "chokeobon"
VARIANT = 1
ATLAS = 256
WORLD_HEIGHT = 150.0  # height of the sprite in world units; tweak to resize and rebuild


def anim_box(w, h, ty):
    """Frame box as Klei's compiler writes it, for one centred image with matrix (1,0,0,1,0,ty)."""
    x1 = 0.0
    x2 = x1 + w
    y1 = ty
    y2 = (y1 if VARIANT == 2 else x1) + h     # the compiler uses x1 here (variant 1 and 3)
    bw, bh = int(math.ceil(x2 - x1)), int(math.ceil(y2 - y1))
    bx, by = x1, y1
    scale = 1.2 * (1.6 if VARIANT == 3 else 1.0)
    nw, nh = int(math.ceil(scale * bw)), int(math.ceil(scale * bh))
    bx += bw / 2.0 - nw / 2.0
    by += bh / 2.0 - nh / 2.0
    return bx, by, nw, nh


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
    # x, y are the image's centre (0, 0); w, h are whole numbers
    out += struct.pack("<IIffffII", 0, 1, 0.0, 0.0, float(int(round(w))), float(int(round(h))), 0, 6)
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
    bx, by, bw, bh = anim_box(int(round(w)), int(round(h)), -h / 2.0)
    out += struct.pack("<ffffII", bx, by, float(bw), float(bh), 0, 1)
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
