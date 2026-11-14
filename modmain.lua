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

-- Only pigs, merms and bunnymen can drop one, and only rarely, when they are killed.
local DROPPERS =
{
    pigman = true,
    pigguard = true,
    merm = true,
    mermguard = true,
    bunnyman = true,
}

AddComponentPostInit("lootdropper", function(self)
    if not DROPPERS[self.inst.prefab] then
        return
    end

    local old_DropLoot = self.DropLoot
    function self:DropLoot(pt, ...)
        old_DropLoot(self, pt, ...)
        if math.random() < DROP_CHANCE then
            self:SpawnLootPrefab("chokeobon", pt)
        end
    end
end)

-- The Pig King very rarely tosses a Choke-o-Bon out along with his usual reward
-- (gold or candy) when you trade him a trinket.
AddPrefabPostInit("pigking", function(inst)
    if not GLOBAL.TheWorld.ismastersim or PIGKING_CHANCE <= 0 then
        return
    end

    local trader = inst.components.trader
    if trader == nil then
        return
    end

    -- The king may not have a loot dropper; we only use it to fling the item out like his gold
    if inst.components.lootdropper == nil then
        inst:AddComponent("lootdropper")
    end

    local old_onaccept = trader.onaccept
    trader.onaccept = function(king, giver, item, ...)
        if old_onaccept ~= nil then
            old_onaccept(king, giver, item, ...)
        end
        if math.random() < PIGKING_CHANCE then
            local loot = GLOBAL.SpawnPrefab("chokeobon")
            local x, y, z = king.Transform:GetWorldPosition()
            loot.Transform:SetPosition(x, y, z)
            if king.components.lootdropper.FlingItem ~= nil then
                king.components.lootdropper:FlingItem(loot)
            else
                loot.Transform:SetPosition(x + 2.5, 0, z)
            end
        end
    end
end)
