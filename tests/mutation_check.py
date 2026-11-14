#!/usr/bin/env python3
"""Proves the tests stay sharp: re-introduces bugs this mod really had, one at a time, into a
temporary copy, and checks that tests/run.lua fails each time. Run: python3 tests/mutation_check.py
Add a case here whenever a new bug is fixed."""
import os, shutil, subprocess, sys, tempfile
SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def run(mutation):
    name, path, fn = mutation
    d = tempfile.mkdtemp(prefix="mut-")

    shutil.rmtree(d); shutil.copytree(SRC, d, ignore=shutil.ignore_patterns(".git", "dist"))
    p = os.path.join(d, path)
    s = open(p).read()
    new = fn(s)
    assert new != s, "mutation did not change anything: " + name
    open(p, "w").write(new)
    r = subprocess.run([os.environ.get("LUA", "lua"), "tests/run.lua"], cwd=d, capture_output=True, text=True)
    failed = [l.strip() for l in r.stdout.splitlines() if l.startswith("  FAIL")]
    shutil.rmtree(d, ignore_errors=True)
    print(("CAUGHT " if r.returncode != 0 else "MISSED ") + name + ("  <- " + failed[0][6:90] if failed else ""))
    return r.returncode != 0

def rep(a, b): return lambda s: s.replace(a, b, 1)
M = [
 ("bare STRINGS in modmain (was nil in the game)", "modmain.lua", rep("local STRINGS = GLOBAL.STRINGS", "")),
 ("AddRoomPreInit used in modmain (worldgen-only)", "modmain.lua", lambda s: s + '\nAddRoomPreInit("BGGrass", function() end)\n'),
 ("scatter hook deleted by a careless edit", "modmain.lua", lambda s: s[:s.index("-- A fixed, small number are scattered")]),
 ("amount stored in TUNING instead of the component", "modmain.lua", rep("inst.components.chokeobonscatter.amount = MAP_AMOUNT", "GLOBAL.TUNING.X = MAP_AMOUNT")),
 ("mob drops through a component hook filtering prefab", "modmain.lua", lambda s: s.replace("for _, name in ipairs(DROPPERS) do", 'AddComponentPostInit("lootdropper", function(self) if self.inst.prefab then end end)\nfor _, name in ipairs({}) do', 1)),
 ("Pig King master check on the entity", "modmain.lua", rep("if not GLOBAL.TheWorld.ismastersim or PIGKING_CHANCE", "if not inst.ismastersim or PIGKING_CHANCE")),
 ("Pig King bonus given instantly (not after his coin toss)", "modmain.lua", rep("king:DoTaskInTime(2 / 3, Launch, giver)", "Launch(king, giver)")),
 ("Pig King bonus on the minigame token", "modmain.lua", rep("(tradable.goldvalue or 0) > 0 and ", "")),
 ("emote sound = true (crashed the server)", "scripts/prefabs/chokeobon.lua", rep('Emote(doer, { anim = "emoteXL_happycheer" })', 'Emote(doer, { anim = "emoteXL_happycheer", sound = true })')),
 ("Warly cannot eat it (tag missing)", "scripts/prefabs/chokeobon.lua", rep('inst:AddTag("pre-preparedfood")', '')),
 ("mime made to cry out", "scripts/prefabs/chokeobon.lua", rep(' and not doer:HasTag("mime")', '')),
 ("bag removed on every bite (no handleremovefn)", "scripts/prefabs/chokeobon.lua", rep("    inst.components.edible.handleremovefn = HandleEatRemove\n", "")),
 ("empty bag not destroyed", "scripts/prefabs/chokeobon.lua", rep("inst._spent = true", "inst._spent = false")),
 ("empty bag still gives sanity", "scripts/prefabs/chokeobon.lua", rep("edible.sanityvalue = empty and 0 or SANITY", "edible.sanityvalue = SANITY")),
 ("uses rolled outside 1-8", "scripts/prefabs/chokeobon.lua", rep("local MAX_USES = 8", "local MAX_USES = 12")),
 ("scatter ignores its own save flag", "scripts/components/chokeobonscatter.lua", rep("self.done = data.done == true", "self.done = false")),
 ("config option read by modmain removed from modinfo", "modinfo.lua", rep('name = "drop_chance"', 'name = "drop_chance_x"')),
 ("asset file missing", "scripts/prefabs/chokeobon.lua", rep('"anim/chokeobon.zip"', '"anim/missing.zip"')),
]
ok = [run(m) for m in M]
print("\n%d of %d mutations caught" % (sum(ok), len(ok)))
sys.exit(0 if all(ok) else 1)
