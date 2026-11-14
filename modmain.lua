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
        if math.random() < PIGKING_CHANCE then
            -- The Pig King has no loot dropper, so place the bag ourselves, a little toward the giver
            local loot = GLOBAL.SpawnPrefab("chokeobon")
            local kx, ky, kz = king.Transform:GetWorldPosition()
            local dx, dz = 0, 2.5
            if giver ~= nil and giver:IsValid() then
                local gx, _, gz = giver.Transform:GetWorldPosition()
                local len = math.sqrt((gx - kx) ^ 2 + (gz - kz) ^ 2)
                if len > 0 then
                    dx, dz = (gx - kx) / len * 2.5, (gz - kz) / len * 2.5
                end
            end
            loot.Transform:SetPosition(kx + dx, 0, kz + dz)
        end
    end
end)

-- A fixed, small number are scattered over the surface world when it first loads.
AddPrefabPostInit("forest", function(inst)
    if GLOBAL.TheWorld.ismastersim then
        inst:AddComponent("chokeobonscatter")
    end
end)
