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
GLOBAL.TUNING.CHOKEOBON_MAP_AMOUNT = GetModConfigData("map_amount")
local PIGKING_CHANCE = GetModConfigData("pigking_chance")

STRINGS.NAMES.CHOKEOBON = "Choke-o-Bon"

STRINGS.CHARACTERS.GENERIC.DESCRIBE.CHOKEOBON = "A rare little treat. Don't mind if I do."

-- Runtime: a tiny chance on any loot drop (mobs, mined rocks, chopped trees...).
AddComponentPostInit("lootdropper", function(self)
    local old_DropLoot = self.DropLoot
    function self:DropLoot(pt, ...)
        old_DropLoot(self, pt, ...)
        if math.random() < DROP_CHANCE then
            self:SpawnLootPrefab("chokeobon", pt)
        end
    end
end)

-- The Pig King very rarely tosses one out as a bonus when traded with.
AddPrefabPostInit("pigking", function(inst)
    if not GLOBAL.TheWorld.ismastersim or PIGKING_CHANCE <= 0 then
        return
    end

    local trader = inst.components.trader
    if trader == nil then
        return
    end

    local old_onaccept = trader.onaccept
    trader.onaccept = function(king, giver, item, ...)
        if old_onaccept ~= nil then
            old_onaccept(king, giver, item, ...)
        end
        if math.random() < PIGKING_CHANCE and king.components.lootdropper ~= nil then
            king.components.lootdropper:SpawnLootPrefab("chokeobon")
        end
    end
end)

-- A fixed, small number are scattered over the surface world when it first loads.
AddPrefabPostInit("forest", function(inst)
    if GLOBAL.TheWorld.ismastersim then
        inst:AddComponent("chokeobonscatter")
    end
end)
