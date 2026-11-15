PrefabFiles = { "chokeobon" }

Assets =
{
    Asset("ATLAS", "images/inventoryimages/chokeobon.xml"),
    Asset("IMAGE", "images/inventoryimages/chokeobon.tex"),
}

-- Game globals aren't visible directly in the mod environment; reach them through GLOBAL.
local STRINGS = GLOBAL.STRINGS

RegisterInventoryItemAtlas("images/inventoryimages/chokeobon.xml", "chokeobon.tex")

local DROP_CHANCE = GetModConfigData("drop_chance")
local MAP_AMOUNT = GetModConfigData("map_amount")
local PIGKING_CHANCE = GetModConfigData("pigking_chance")

STRINGS.NAMES.CHOKEOBON = "Choke-o-Bon"

-- What each character says when inspecting the bag. Keys are the game's STRINGS.CHARACTERS keys:
-- GENERIC is Wilson's table and is also the fallback for modded characters. Wes (a mime) needs
-- none; the game blanks his inspect text.
local INSPECT =
{
    GENERIC = "A rare little treat. I wonder how many are left inside.",
    WILLOW = "Chocolates! Shame they'd only melt if I burned them.",
    WOLFGANG = "Little bag of sweets! Wolfgang wonders how many are inside. Wolfgang is not good at counting.",
    WENDY = "A bag of sweetness. It will be empty soon enough. Everything is.",
    WX78 = "SUGAR CONTAINER. REMAINING DOSES: UNKNOWN. ANNOYING.",
    WICKERBOTTOM = "A confection of indeterminate quantity. I suspect the last piece carries a sting.",
    WOODIE = "Fancy chocolates, eh? Lucy says there's a catch. Lucy's usually right.",
    WAXWELL = "A bag of sweets. I'd wager the last one costs more than the first.",
    WATHGRITHR = "A treasure bag of sweets! Even Valhalla's feasts began with less.",
    WEBBER = "Chocolates! Can we eat them all? ...What if there's a trick?",
    WINONA = "No label saying how many are inside. Bad design. I'd have fitted a gauge.",
    WORTOX = "Hyuyu! A bag of sweets with a secret. I do love a secret.",
    WORMWOOD = "Bag. Smells sweet. Friend not sure how many inside.",
    WARLY = "Tiens, chocolate bonbons! A cook's delight. Shame the supply is a mystery.",
    WURT = "Flort! Sweets! Wurt wonders if an empty bag is mean.",
    WALTER = "Looks like candy, Woby. Might be a prank bag, though. Let's be careful.",
    WANDA = "A bag of sweets. Is the last one really the last? It never is... until it is.",
}

for character, text in pairs(INSPECT) do
    if STRINGS.CHARACTERS[character] ~= nil then -- skip any the game version does not have
        STRINGS.CHARACTERS[character].DESCRIBE.CHOKEOBON = text
    end
end

-- Only pigs, merms and bunnymen can drop one, and only rarely, when they are killed.
-- Hooked per prefab: a component post-init runs before the game has set inst.prefab,
-- so it cannot tell which creature it is looking at.
local DROPPERS = { "pigman", "pigguard", "merm", "mermguard", "bunnyman" }

for _, name in ipairs(DROPPERS) do
    AddPrefabPostInit(name, function(inst)
        local lootdropper = inst.components.lootdropper
        if lootdropper == nil then
            return -- clients don't have it
        end

        local old_DropLoot = lootdropper.DropLoot
        function lootdropper:DropLoot(pt, ...)
            old_DropLoot(self, pt, ...)
            if math.random() < DROP_CHANCE then
                self:SpawnLootPrefab("chokeobon", pt)
            end
        end
    end)
end

-- The Pig King very rarely tosses a Choke-o-Bon out along with his gold when you trade
-- him a trinket. This mirrors prefabs/pigking.lua: the gold comes out 2/3 s after the
-- trade, from 4.5 units up, launched toward the player.
AddPrefabPostInit("pigking", function(inst)
    -- ismastersim is a field of the world, not of every entity
    if not GLOBAL.TheWorld.ismastersim or PIGKING_CHANCE <= 0 then
        return
    end

    local trader = inst.components.trader
    if trader == nil then
        return
    end

    local function Launch(king, giver)
        local loot = GLOBAL.SpawnPrefab("chokeobon")
        local x, _, z = king.Transform:GetWorldPosition()
        loot.Transform:SetPosition(x, 4.5, z)

        local angle
        if giver ~= nil and giver:IsValid() then
            angle = 180 - giver:GetAngleToPoint(x, 0, z)
        else
            angle = math.random() * 360
        end
        local speed = math.random() * 4 + 2
        angle = (angle + math.random() * 60 - 30) * GLOBAL.DEGREES
        loot.Physics:SetVel(speed * math.cos(angle), math.random() * 2 + 8, speed * math.sin(angle))
    end

    local old_onaccept = trader.onaccept
    trader.onaccept = function(king, giver, item, ...)
        if old_onaccept ~= nil then
            old_onaccept(king, giver, item, ...)
        end
        -- Only trades that give gold (not the minigame token)
        local tradable = item ~= nil and item.components.tradable or nil
        if tradable ~= nil and (tradable.goldvalue or 0) > 0 and math.random() < PIGKING_CHANCE then
            king:DoTaskInTime(2 / 3, Launch, giver)
        end
    end
end)

-- A fixed, small number are scattered over the surface world when it first loads.
-- The amount is passed in directly: TUNING is replaced when a world loads, so values stored there are lost.
AddPrefabPostInit("forest", function(inst)
    if inst.ismastersim then
        inst:AddComponent("chokeobonscatter")
        inst.components.chokeobonscatter.amount = MAP_AMOUNT
    end
end)
