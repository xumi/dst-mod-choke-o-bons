-- Regression tests. Run from the repository root:  lua tests/run.lua
--
-- The game cannot run in CI, so this recreates the rules of its Lua environment closely
-- enough to catch the mistakes made while building this mod (see tests/README.md):
--   * modmain.lua runs in a STRICT mod environment: reading a global the game does not
--     provide there (STRINGS, TheWorld, TUNING...) is an error, as in the real game.
--   * prefab/component files run in a fake game environment with stub engine objects.
--   * hooks registered by modmain.lua (AddPrefabPostInit, ...) are captured and exercised.
-- Works on Lua 5.1 (what DST runs) and newer.

local unpack = table.unpack or unpack

local failures, passed = {}, 0

local function check(cond, msg)
    if not cond then
        error(msg or "check failed", 2)
    end
end

local function eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", msg or "values differ", tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

---------------------------------------------------------------------------
-- Loading files into an environment (5.1 and 5.2+)
---------------------------------------------------------------------------

local function load_in_env(path, env)
    local chunk, err
    if setfenv then
        chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(path, "t", env)
    end
    if not chunk then error(err, 0) end
    return chunk
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

---------------------------------------------------------------------------
-- Fake engine
---------------------------------------------------------------------------

local function new_game(opts)
    opts = opts or {}
    local G = setmetatable({}, { __index = _G })
    G._G = G

    local game = { G = G, tasks = {}, spawned = {}, prefabs = {}, pushed = {} }

    G.TILE_SCALE = 4
    G.DEGREES = math.pi / 180
    G.FOODTYPE = { GOODIES = "GOODIES", MEAT = "MEAT" }
    G.TUNING = {}           -- the game replaces this table on world load, so it starts empty
    G.STRINGS = { NAMES = {}, CHARACTERS = { GENERIC = { DESCRIBE = {} } } }

    function G.Asset(kind, file) return { kind = kind, file = file } end
    function G.Prefab(name, fn, assets) return { name = name, fn = fn, assets = assets or {} } end
    function G.MakeInventoryPhysics() end
    function G.MakeHauntableLaunch() end

    function G.Class(ctor)
        local cls = {}
        cls.__index = cls
        return setmetatable(cls, { __call = function(c, ...)
            local o = setmetatable({}, c)
            ctor(o, ...)
            return o
        end })
    end

    -- Entities -----------------------------------------------------------
    local function new_entity()
        local e = { components = {}, tags = {}, handlers = {}, removed = false, pos = { 0, 0, 0 } }
        e.entity = {
            AddTransform = function() end, AddAnimState = function() end, AddNetwork = function() end,
            SetPristine = function() end,
        }
        e.Transform = {
            SetPosition = function(_, x, y, z) e.pos = { x, y, z } end,
            GetWorldPosition = function() return e.pos[1], e.pos[2], e.pos[3] end,
        }
        e.AnimState = setmetatable({ calls = {} }, { __index = function(t, k)
            return function(_, ...) t.calls[#t.calls + 1] = { k, ... } end
        end })
        e.Physics = { SetVel = function(_, x, y, z) e.vel = { x, y, z } end }
        e.SoundEmitter = { played = {}, PlaySound = function(self, s) self.played[#self.played + 1] = s end }
        function e:AddTag(t) self.tags[t] = true end
        function e:HasTag(t) return self.tags[t] == true end
        function e:IsValid() return not self.removed end
        function e:Remove() self.removed = true end
        function e:GetPosition() return self.pos[1], self.pos[2], self.pos[3] end
        function e:ListenForEvent(name, fn) self.handlers[name] = self.handlers[name] or {}; table.insert(self.handlers[name], fn) end
        function e:PushEvent(name, data)
            game.pushed[#game.pushed + 1] = { ent = self, name = name, data = data }
            for _, fn in ipairs(self.handlers[name] or {}) do fn(self, data) end
        end
        function e:DoTaskInTime(t, fn, ...)
            game.tasks[#game.tasks + 1] = { t = t, fn = fn, args = { ... }, ent = self }
        end
        function e:AddComponent(name)
            local path = "scripts/components/" .. name .. ".lua"
            if file_exists(path) then
                local cls = load_in_env(path, G)()
                self.components[name] = cls(self)
            else
                self.components[name] = {}
            end
            return self.components[name]
        end
        return e
    end
    G.CreateEntity = new_entity
    game.new_entity = new_entity

    -- World ----------------------------------------------------------------
    local world = new_entity()
    world.ismastersim = opts.client and false or true
    world.Map = {
        GetSize = function() return opts.map_w or 100, opts.map_h or 100 end,
        IsAboveGroundAtPoint = function() return opts.land ~= false end,
        IsPassableAtPoint = function() return opts.land ~= false end,
    }
    G.TheWorld = world
    game.world = world

    -- Prefabs ----------------------------------------------------------------
    function game.register_prefab_file(name)
        local p = load_in_env("scripts/prefabs/" .. name .. ".lua", G)()
        game.prefabs[p.name] = p
        return p
    end
    function G.SpawnPrefab(name)
        local p = game.prefabs[name]
        if not p then
            local e = new_entity()
            e.prefab = name
            game.spawned[#game.spawned + 1] = e
            return e
        end
        local e = p.fn()
        e.prefab = name
        game.spawned[#game.spawned + 1] = e
        return e
    end

    function game.run_tasks()
        local tasks = game.tasks
        game.tasks = {}
        for _, t in ipairs(tasks) do
            if t.ent == nil or t.ent:IsValid() then t.fn(t.ent, unpack(t.args)) end
        end
    end

    return game
end

---------------------------------------------------------------------------
-- The mod environment (modmain.lua): strict, like the game's
---------------------------------------------------------------------------

local function load_modinfo()
    local env = {}
    load_in_env("modinfo.lua", env)()
    return env
end

local function config_values(modinfo, overrides)
    local values = {}
    for _, opt in ipairs(modinfo.configuration_options) do
        if opt.name ~= "" then values[opt.name] = opt.default end
    end
    for k, v in pairs(overrides or {}) do values[k] = v end
    return values
end

-- Returns the captured hooks, the mod env, and the fake game.
local function load_modmain(game, config)
    local hooks = { prefab = {}, component = {} }
    local env = {}
    local allowed = {
        math = math, string = string, table = table, ipairs = ipairs, pairs = pairs, print = print,
        tostring = tostring, tonumber = tonumber, type = type, unpack = unpack, select = select,
        pcall = pcall, error = error, next = next,
    }
    env.GLOBAL = game.G
    env.Asset = game.G.Asset
    function env.AddPrefabPostInit(name, fn)
        hooks.prefab[name] = hooks.prefab[name] or {}
        table.insert(hooks.prefab[name], fn)
    end
    function env.AddComponentPostInit(name, fn)
        hooks.component[name] = hooks.component[name] or {}
        table.insert(hooks.component[name], fn)
    end
    function env.AddSimPostInit() end
    function env.RegisterInventoryItemAtlas(xml, tex) hooks.atlas = { xml, tex } end
    env.requested_config = {}
    function env.GetModConfigData(name)
        env.requested_config[#env.requested_config + 1] = name
        return config[name]
    end

    -- Anything else is NOT available in the real mod environment.
    setmetatable(env, { __index = function(_, k)
        if allowed[k] ~= nil then return allowed[k] end
        error("modmain.lua read the global '" .. tostring(k) .. "', which does not exist in the mod environment (use GLOBAL." .. tostring(k) .. ")", 2)
    end })

    load_in_env("modmain.lua", env)()
    return hooks, env
end

local function setup(overrides, game_opts)
    local game = new_game(game_opts)
    game.register_prefab_file("chokeobon")
    local modinfo = load_modinfo()
    local config = config_values(modinfo, overrides)
    local hooks, env = load_modmain(game, config)
    return game, hooks, env, config, modinfo
end

local function with_random(value, fn)
    local real = math.random
    math.random = function(a, b)
        if a == nil then return value end
        if b == nil then return a end
        return a
    end
    local ok, err = pcall(fn)
    math.random = real
    if not ok then error(err, 0) end
end

---------------------------------------------------------------------------
-- Tests: loading and wiring
---------------------------------------------------------------------------

test("modmain.lua loads in the strict mod environment (no STRINGS/TheWorld/TUNING reads)", function()
    local _, hooks, env = setup()
    eq(env.PrefabFiles[1], "chokeobon", "PrefabFiles")
end)

test("modmain.lua writes strings and registers the inventory icon", function()
    local game, hooks = setup()
    eq(game.G.STRINGS.NAMES.CHOKEOBON, "Choke-o-Bon", "item name")
    check(game.G.STRINGS.CHARACTERS.GENERIC.DESCRIBE.CHOKEOBON ~= nil, "inspect string")
    eq(hooks.atlas[2], "chokeobon.tex", "atlas tex")
end)

test("every hook modmain.lua should register is registered (nothing silently deleted)", function()
    local _, hooks = setup()
    for _, name in ipairs({ "forest", "pigking", "pigman", "pigguard", "merm", "mermguard", "bunnyman" }) do
        check(hooks.prefab[name] ~= nil and #hooks.prefab[name] >= 1, "missing AddPrefabPostInit for '" .. name .. "'")
    end
end)

local function code_without_comments(path)
    local f = assert(io.open(path)); local src = f:read("*a"); f:close()
    return (src:gsub("%-%-[^\n]*", ""))
end

test("the mod does not use TUNING (the game replaces it on world load, wiping mod values)", function()
    check(not code_without_comments("modmain.lua"):find("TUNING"), "modmain.lua uses TUNING")
    check(not code_without_comments("scripts/components/chokeobonscatter.lua"):find("TUNING"), "the scatter component uses TUNING")
end)

test("every config name read by modmain.lua exists in modinfo.lua, with a valid default", function()
    local game, _, env, _, modinfo = setup()
    local names = {}
    for _, opt in ipairs(modinfo.configuration_options) do
        if opt.name ~= "" then
            names[opt.name] = true
            local found = false
            for _, o in ipairs(opt.options) do if o.data == opt.default then found = true end end
            check(found, "default of '" .. opt.name .. "' is not one of its options")
        end
    end
    for _, n in ipairs(env.requested_config) do check(names[n], "modmain reads unknown config '" .. n .. "'") end
end)

test("every referenced file exists (assets, prefab files, components)", function()
    local game, _, env = setup()
    for _, f in ipairs(env.PrefabFiles) do check(file_exists("scripts/prefabs/" .. f .. ".lua"), "missing prefab file " .. f) end
    for _, a in ipairs(env.Assets) do check(file_exists(a.file), "missing asset " .. a.file) end
    for _, p in pairs(game.prefabs) do
        for _, a in ipairs(p.assets) do check(file_exists(a.file), "missing prefab asset " .. a.file) end
    end
    check(file_exists("scripts/components/chokeobonscatter.lua"), "missing scatter component")
    check(file_exists("modicon.tex") and file_exists("modicon.xml"), "missing mod icon")
    local modinfo = load_modinfo()
    eq(modinfo.api_version, 10, "api_version")
    check(modinfo.version and modinfo.version ~= "", "version")
end)

---------------------------------------------------------------------------
-- Tests: map scatter
---------------------------------------------------------------------------

test("the surface world gets the scatter component with the configured amount", function()
    local game, hooks = setup({ map_amount = 12 })
    local world = game.new_entity()
    world.ismastersim = true
    for _, fn in ipairs(hooks.prefab.forest) do fn(world) end
    local comp = world.components.chokeobonscatter
    check(comp ~= nil, "component not added")
    eq(comp.amount, 12, "amount")
end)

test("clients do not get the scatter component", function()
    local game, hooks = setup()
    local world = game.new_entity()
    world.ismastersim = false
    for _, fn in ipairs(hooks.prefab.forest) do fn(world) end
    check(world.components.chokeobonscatter == nil, "client got the component")
end)

test("the scatter places exactly the configured number, once, even with an empty TUNING", function()
    local game, hooks = setup({ map_amount = 12 })
    game.G.TUNING = {} -- what the game does on world load
    local world = game.new_entity(); world.ismastersim = true
    for _, fn in ipairs(hooks.prefab.forest) do fn(world) end
    game.run_tasks()
    local n = 0
    for _, e in ipairs(game.spawned) do if e.prefab == "chokeobon" then n = n + 1 end end
    eq(n, 12, "items placed")

    -- Save/load: a reloaded world must not scatter again
    local data = world.components.chokeobonscatter:OnSave()
    local world2 = game.new_entity(); world2.ismastersim = true
    for _, fn in ipairs(hooks.prefab.forest) do fn(world2) end
    world2.components.chokeobonscatter:OnLoad(data)
    game.spawned = {}
    game.run_tasks()
    eq(#game.spawned, 0, "items placed on reload")
end)

test("the scatter only uses valid land and stays inside the map", function()
    local game, hooks = setup({ map_amount = 6 }, { map_w = 50, map_h = 80 })
    local world = game.new_entity(); world.ismastersim = true
    for _, fn in ipairs(hooks.prefab.forest) do fn(world) end
    game.run_tasks()
    for _, e in ipairs(game.spawned) do
        check(math.abs(e.pos[1]) <= 50 / 2 * 4 and math.abs(e.pos[3]) <= 80 / 2 * 4, "item outside the map")
    end
end)

test("the scatter does not hang when there is no land", function()
    local game, hooks = setup({ map_amount = 12 }, { land = false })
    local world = game.new_entity(); world.ismastersim = true
    for _, fn in ipairs(hooks.prefab.forest) do fn(world) end
    game.run_tasks()
    eq(#game.spawned, 0, "items placed")
end)

---------------------------------------------------------------------------
-- Tests: mob drops
---------------------------------------------------------------------------

local function fake_creature(game, name)
    local e = game.new_entity()
    e.prefab = name
    local ld = { original_calls = 0, loot = {} }
    function ld:DropLoot(pt) self.original_calls = self.original_calls + 1 end
    function ld:SpawnLootPrefab(prefab, pt) self.loot[#self.loot + 1] = prefab end
    e.components.lootdropper = ld
    return e, ld
end

test("pigs, merms and bunnymen can drop a Choke-o-Bon, and still drop their normal loot", function()
    local game, hooks = setup({ drop_chance = 0.5 })
    for _, name in ipairs({ "pigman", "pigguard", "merm", "mermguard", "bunnyman" }) do
        local e, ld = fake_creature(game, name)
        for _, fn in ipairs(hooks.prefab[name]) do fn(e) end
        with_random(0.0, function() ld:DropLoot({}) end)
        eq(ld.original_calls, 1, name .. ": original DropLoot calls")
        eq(ld.loot[1], "chokeobon", name .. ": bonus drop")
    end
end)

test("no bonus drop when the roll fails", function()
    local game, hooks = setup({ drop_chance = 0.01 })
    local e, ld = fake_creature(game, "pigman")
    for _, fn in ipairs(hooks.prefab.pigman) do fn(e) end
    with_random(0.99, function() ld:DropLoot({}) end)
    eq(#ld.loot, 0, "bonus drops")
    eq(ld.original_calls, 1, "original DropLoot calls")
end)

test("creatures without a loot dropper (clients) are left alone", function()
    local game, hooks = setup()
    local e = game.new_entity(); e.prefab = "pigman"
    for _, fn in ipairs(hooks.prefab.pigman) do fn(e) end -- must not error
end)

test("other creatures are not hooked", function()
    local _, hooks = setup()
    check(hooks.prefab.spider == nil and hooks.prefab.rabbit == nil, "unexpected hook")
    check(hooks.component.lootdropper == nil, "a lootdropper component hook cannot know the prefab name")
end)

---------------------------------------------------------------------------
-- Tests: Pig King
---------------------------------------------------------------------------

local function fake_pigking(game)
    local king = game.new_entity(); king.prefab = "pigking"
    king.pos = { 10, 0, 20 }
    king.components.trader = { onaccept_calls = 0 }
    king.components.trader.onaccept = function() king.components.trader.onaccept_calls = king.components.trader.onaccept_calls + 1 end
    return king
end

local function trade(game, hooks, gold, prefab, roll)
    local king = fake_pigking(game)
    for _, fn in ipairs(hooks.prefab.pigking) do fn(king) end
    local giver = game.new_entity()
    giver.GetAngleToPoint = function() return 90 end
    local item = { prefab = prefab or "trinket_1", components = { tradable = { goldvalue = gold } } }
    game.spawned = {}
    with_random(roll, function()
        king.components.trader.onaccept(king, giver, item)
        game.run_tasks()
    end)
    return king
end

test("Pig King: a gold trade can also toss out a Choke-o-Bon, after his coin toss, launched", function()
    local game, hooks = setup({ pigking_chance = 0.05 })
    local king = fake_pigking(game)
    for _, fn in ipairs(hooks.prefab.pigking) do fn(king) end
    local giver = game.new_entity(); giver.GetAngleToPoint = function() return 90 end
    local item = { prefab = "trinket_1", components = { tradable = { goldvalue = 2 } } }
    with_random(0.0, function() king.components.trader.onaccept(king, giver, item) end)
    eq(king.components.trader.onaccept_calls, 1, "his normal reward handler")
    eq(#game.tasks, 1, "scheduled rewards")
    eq(game.tasks[1].t, 2 / 3, "delay (his gold comes out after 2/3 s)")
    with_random(0.0, function() game.run_tasks() end)
    local loot = game.spawned[1]
    check(loot ~= nil and loot.prefab == "chokeobon", "no Choke-o-Bon spawned")
    eq(loot.pos[2], 4.5, "spawn height (same as his gold)")
    check(loot.vel ~= nil, "not launched")
end)

test("Pig King: no bonus for trades without gold (minigame token) or on a failed roll", function()
    local game, hooks = setup({ pigking_chance = 0.05 })
    trade(game, hooks, 0, "pig_token", 0.0)
    eq(#game.spawned, 0, "spawned for a zero-gold trade")
    trade(game, hooks, 2, "trinket_1", 0.99)
    eq(#game.spawned, 0, "spawned on a failed roll")
end)

---------------------------------------------------------------------------
-- Tests: the item
---------------------------------------------------------------------------

local function new_item(game)
    local item = game.G.SpawnPrefab("chokeobon")
    return item
end

local function new_eater(game, prefab)
    local e = game.new_entity()
    e.prefab = prefab or "wilson"
    e.stats = { health = 0, hunger = 0, sanity = 0 }
    e.components.health = { DoDelta = function(_, n) e.stats.health = e.stats.health + n end }
    e.components.hunger = { DoDelta = function(_, n) e.stats.hunger = e.stats.hunger + n end }
    e.components.sanity = { DoDelta = function(_, n) e.stats.sanity = e.stats.sanity + n end }
    e.said = {}
    e.components.talker = { Say = function(_, s) e.said[#e.said + 1] = s end }
    e.sg = { HasStateTag = function() return false end }
    return e
end

-- Mirrors Eater:Eat + Edible:OnEaten + Edible:HandleEatRemove in the game's scripts.
local function eat(item, eater)
    local edible = item.components.edible
    eater.components.health:DoDelta(edible.healthvalue)
    eater.components.hunger:DoDelta(edible.hungervalue)
    eater.components.sanity:DoDelta(edible.sanityvalue)
    if edible.oneaten then edible.oneaten(item, eater) end
    if edible.handleremovefn then edible.handleremovefn(item) else item:Remove() end
end

test("the item has the pieces the game needs (food type, icon, model)", function()
    local game = setup()
    local item = new_item(game)
    eq(item.components.edible.foodtype, "GOODIES", "food type")
    eq(item.components.inventoryitem.atlasname, "images/inventoryimages/chokeobon.xml", "atlas")
    check(item.components.edible.oneaten ~= nil, "oneaten hook")
    check(item.components.edible.handleremovefn ~= nil, "handleremovefn (without it the game removes the bag on every bite)")
    local bank = nil
    for _, c in ipairs(item.AnimState.calls) do if c[1] == "SetBank" then bank = c[2] end end
    eq(bank, "chokeobon", "animation bank")
end)

test("the number of uses is rolled once on first pickup, between 1 and 8, and saved", function()
    local game = setup()
    for n = 1, 20 do
        local item = new_item(game)
        item:PushEvent("onputininventory")
        check(item.uses >= 1 and item.uses <= 8, "uses out of range: " .. tostring(item.uses))
        local first = item.uses
        item:PushEvent("onputininventory")
        eq(item.uses, first, "uses were re-rolled")
    end
    local item = new_item(game); item:PushEvent("onputininventory")
    local data = {}; item.OnSave(item, data)
    local copy = new_item(game); copy.OnLoad(copy, data)
    eq(copy.uses, item.uses, "uses after reload")
end)

test("eating: the same bag stays, loses one use, and gives the stats; an empty bag gives none", function()
    local game = setup()
    local item, eater = new_item(game), new_eater(game)
    item.uses = 2
    item.components.edible.healthvalue = -1
    eat(item, eater)
    check(not item.removed, "bag was removed with treats left")
    eq(item.uses, 1, "uses after one bite")
    eq(eater.stats.health, -1, "health")
    eq(eater.stats.hunger, 1, "hunger")
    eq(eater.stats.sanity, 20, "sanity")

    eat(item, eater)
    check(not item.removed, "bag was removed when it just became empty")
    eq(item.uses, 0, "uses")
    eq(item.components.edible.sanityvalue, 0, "an empty bag must not give sanity")
    eq(item.components.edible.healthvalue, 0, "an empty bag must not give health")
end)

test("eating an empty bag: -100 sanity, a spoken line, a sad emote, a break sound, and the bag is destroyed", function()
    local game = setup()
    local item, eater = new_item(game), new_eater(game, "wendy")
    item.uses = 0
    item.components.edible.sanityvalue = 0
    eat(item, eater)
    check(item.removed, "the empty bag was not destroyed")
    eq(eater.stats.sanity, -100, "sanity")
    game.run_tasks()
    eq(eater.said[1], "Empty, like everything. At least it understands me.", "character line")
    local broke = false
    for _, s in ipairs(eater.SoundEmitter.played) do if s:find("use_break") then broke = true end end
    check(broke, "no break sound")
end)

test("unknown (modded) characters get the default line", function()
    local game = setup()
    local item, eater = new_item(game), new_eater(game, "some_modded_character")
    item.uses = 0
    eat(item, eater)
    game.run_tasks()
    eq(eater.said[1], "Empty. I feel so empty too.", "default line")
end)

test("emote events never carry a non-string sound (a boolean crashed the server)", function()
    local game = setup()
    local eater = new_eater(game)
    for _, uses in ipairs({ 3, 0 }) do
        local item = new_item(game); item.uses = uses
        game.pushed = {}
        eat(item, eater)
        game.run_tasks()
        local seen = false
        for _, p in ipairs(game.pushed) do
            if p.name == "emote" then
                seen = true
                check(type(p.data.anim) == "string", "emote anim must be a string")
                check(p.data.sound == nil or type(p.data.sound) == "string", "emote sound must be a string path, got " .. type(p.data.sound))
            end
        end
        check(seen, "no emote was pushed (uses=" .. uses .. ")")
    end
end)

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------

for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)
    if ok then
        passed = passed + 1
        print("  ok    " .. t.name)
    else
        failures[#failures + 1] = t.name
        print("  FAIL  " .. t.name .. "\n        " .. tostring(err))
    end
end

print(string.format("\n%d passed, %d failed", passed, #failures))
if #failures > 0 then os.exit(1) end
