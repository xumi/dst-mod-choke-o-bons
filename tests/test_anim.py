#!/usr/bin/env python3
"""Pins the exact contents of anim/chokeobon.zip.

These numbers are the ones confirmed working in the game (click box and size). If this test
fails after you change tools/build_anim.py, the model changed: rebuild it on purpose,
re-check it in the game, then update the golden values below.

Formats follow Klei's compiler (ds_mod_tools: buildanimation.py).
"""
import struct, sys, zipfile

ZIP = "anim/chokeobon.zip"
NAME = "chokeobon"

# Confirmed in game: a 96x150 sprite, click box as written by Klei's compiler with the
# bottom-edge quirk fixed.
GOLDEN_BUILD_BOX = (0.0, 0.0, 96.0, 150.0)
GOLDEN_ANIM_BOX = (-10.0, -90.0, 116.0, 180.0)
GOLDEN_MATRIX = (1.0, 0.0, 0.0, 1.0, 0.0, -75.0)


def strhash(s):
    h = 0
    for c in s.lower():
        h = (ord(c) + (h << 6) + (h << 16) - h) & 0xFFFFFFFF
    return h


class Reader:
    def __init__(self, data):
        self.d, self.i = data, 0

    def take(self, fmt):
        n = struct.calcsize("<" + fmt)
        v = struct.unpack_from("<" + fmt, self.d, self.i)
        self.i += n
        return v if len(v) > 1 else v[0]

    def string(self):
        n = self.take("I")
        s = self.d[self.i:self.i + n].decode()
        self.i += n
        return s


def approx(a, b):
    return all(abs(x - y) < 1e-3 for x, y in zip(a, b))


def main():
    problems = []
    z = zipfile.ZipFile(ZIP)
    names = sorted(z.namelist())
    if names != ["anim.bin", "atlas-0.tex", "build.bin"]:
        problems.append("zip contents are %s" % names)
    if any(i.compress_type != zipfile.ZIP_STORED for i in z.infolist()):
        problems.append("zip should be stored (uncompressed); that is what was tested in the game")
    if z.read("atlas-0.tex")[:4] != b"KTEX":
        problems.append("atlas-0.tex is not a KTEX texture")

    # --- build.bin
    r = Reader(z.read("build.bin"))
    if r.d[:4] != b"BILD":
        problems.append("build.bin: bad magic")
    r.i = 4
    version = r.take("i")
    if version != 6:
        problems.append("build.bin: version %s, expected 6" % version)
    symbols, frames = r.take("II")
    if (symbols, frames) != (1, 1):
        problems.append("build.bin: %s symbols, %s frames" % (symbols, frames))
    if r.string() != NAME:
        problems.append("build.bin: wrong build name")
    if r.take("I") != 1 or r.string() != "atlas-0.tex":
        problems.append("build.bin: wrong atlas")
    sym_hash = r.take("I")
    if sym_hash != strhash(NAME):
        problems.append("build.bin: symbol hash does not match the name")
    r.take("I")  # frame count
    framenum, duration = r.take("II")
    box = r.take("ffff")
    if not approx(box, GOLDEN_BUILD_BOX):
        problems.append("build frame box %s, expected %s (x, y are the image CENTRE)" % (box, GOLDEN_BUILD_BOX))
    vb_start, vb_count = r.take("II")
    if vb_count != 6:
        problems.append("build.bin: %s vertices, expected 6 (two triangles)" % vb_count)
    total = r.take("I")
    verts = [r.take("ffffff") for _ in range(total)]
    xs = [v[0] for v in verts]
    ys = [v[1] for v in verts]
    w, h = GOLDEN_BUILD_BOX[2], GOLDEN_BUILD_BOX[3]
    # The box is rounded to whole numbers (as Klei's compiler does); the vertices are not.
    near = lambda a, b: all(abs(x - y) < 1.0 for x, y in zip(a, b))
    if not (near((min(xs), max(xs)), (-w / 2, w / 2)) and near((min(ys), max(ys)), (-h / 2, h / 2))):
        problems.append("vertices should be centred on the origin and match the box size")
    for v in verts:
        if not (0.0 <= v[3] <= 1.0 and 0.0 <= v[4] <= 1.0):
            problems.append("uv out of range: %s" % (v,))
            break

    # --- anim.bin
    r = Reader(z.read("anim.bin"))
    if r.d[:4] != b"ANIM":
        problems.append("anim.bin: bad magic")
    r.i = 4
    version = r.take("i")
    if version != 4:
        problems.append("anim.bin: version %s, expected 4" % version)
    elements, frames, events, anims = r.take("IIII")
    if (elements, frames, events, anims) != (1, 1, 0, 1):
        problems.append("anim.bin counts %s" % ((elements, frames, events, anims),))
    if r.string() != "idle":
        problems.append("anim.bin: the animation must be called 'idle'")
    facing = r.take("B")
    bank = r.take("I")
    if bank != strhash(NAME):
        problems.append("anim.bin: bank hash does not match '%s'" % NAME)
    rate = r.take("f")
    r.take("I")  # frames
    abox = r.take("ffff")
    if not approx(abox, GOLDEN_ANIM_BOX):
        problems.append("anim frame box %s, expected %s" % (abox, GOLDEN_ANIM_BOX))
    r.take("I")  # events
    r.take("I")  # elements
    el_hash, el_frame, layer = r.take("III")
    if el_hash != strhash(NAME) or layer != strhash(NAME) or el_frame != 0:
        problems.append("anim.bin: element does not reference the build symbol")
    mat = r.take("6f")
    if not approx(mat, GOLDEN_MATRIX):
        problems.append("element matrix %s, expected %s" % (mat, GOLDEN_MATRIX))
    r.take("f")  # z
    count = r.take("I")
    table = {}
    for _ in range(count):
        hh = r.take("I")
        table[hh] = r.string()
    if table.get(strhash(NAME)) != NAME:
        problems.append("anim.bin: hash table lacks '%s'" % NAME)

    if problems:
        print("FAIL anim/chokeobon.zip")
        for p in problems:
            print("  -", p)
        return 1
    print("ok    anim/chokeobon.zip matches the model confirmed in game")
    return 0


if __name__ == "__main__":
    sys.exit(main())
