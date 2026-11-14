#!/bin/sh
# Runs every check: Lua syntax, the behaviour tests, the model test, and the mutation check.
# Usage: tools/test.sh      (set LUA=lua5.1 LUAC=luac5.1 to use Lua 5.1, which is what DST runs)
set -e
cd "$(dirname "$0")/.."
LUA=${LUA:-lua}
LUAC=${LUAC:-luac}
export LUA

echo "== Lua syntax"
for f in modinfo.lua modmain.lua scripts/prefabs/*.lua scripts/components/*.lua tests/run.lua; do
    "$LUAC" -p "$f"
done
echo "ok"

echo "== Behaviour tests"
"$LUA" tests/run.lua | grep -v '^\[chokeobon\]'

echo "== Model (anim/chokeobon.zip)"
python3 tests/test_anim.py

echo "== Mutation check (re-introduces past bugs; the tests must catch every one)"
python3 tests/mutation_check.py | tail -1
