local assets =
{
    Asset("ANIM", "anim/chokeobon.zip"),
}

-- Size of the model on the ground (1 = as built). Raise it to make the item bigger.
local WORLD_SCALE = 2.2

local MIN_USES = 1
local MAX_USES = 8

local HEALTH = -1
local HUNGER = 1
local SANITY = 20
local EMPTY_SANITY_PENALTY = -100

-- Eating a full bag gives the stats below; an empty bag gives nothing (and costs sanity).
local function RefreshEdible(inst)
    local empty = inst.uses ~= nil and inst.uses <= 0
    local edible = inst.components.edible
    edible.healthvalue = empty and 0 or HEALTH
    edible.hungervalue = empty and 0 or HUNGER
    edible.sanityvalue = empty and 0 or SANITY
end

-- The number of uses is rolled once, the first time the item is picked up,
-- and is never shown to the player.
local function RollUses(inst)
    if inst.uses == nil then
        inst.uses = math.random(MIN_USES, MAX_USES)
        RefreshEdible(inst)
    end
end

-- The emote is pushed on the next tick so it isn't swallowed by the eating state.
local function Emote(doer, data)
    doer:DoTaskInTime(0.2, function()
        if doer:IsValid() and doer.sg ~= nil and not doer.sg:HasStateTag("busy") then
            doer:PushEvent("emote", data)
        end
    end)
end

-- The character's own voice event, e.g. "dontstarve/characters/wilson/emote"
local function VoicePath(doer, event)
    return (doer.talker_path_override or "dontstarve/characters/")..(doer.soundsname or doer.prefab).."/"..event
end

-- Note: the emote's `sound` field must be a sound path (a string), never a boolean.
local function EmoteHappy(doer)
    Emote(doer, { anim = "emoteXL_happycheer", sound = VoicePath(doer, "emote") })
end

-- Sad animation plus the character's pained voice
local function EmoteVerySad(doer)
    Emote(doer, { anim = "emoteXL_sad" })
    doer:DoTaskInTime(0.2, function()
        if doer:IsValid() and doer.SoundEmitter ~= nil then
            doer.SoundEmitter:PlaySound(VoicePath(doer, "hurt"))
        end
    end)
end

-- Called after the stats were applied. The game removes eaten food afterwards, so for
-- a bag that still has treats left we block that Remove for this one tick and keep the
-- same item, just with one fewer use.
local function OnEaten(inst, eater)
    RollUses(inst)

    if inst.uses > 0 then
        inst.uses = inst.uses - 1
        RefreshEdible(inst)

        inst.Remove = function() end
        inst:DoTaskInTime(0, function()
            inst.Remove = nil
            -- If the game already took the bag out of the inventory, put it back
            if inst:IsValid() and eater:IsValid() and eater.components.inventory ~= nil
                and inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner ~= eater then
                eater.components.inventory:GiveItem(inst, nil, eater:GetPosition())
            end
        end)
        EmoteHappy(eater)
    else
        -- An empty bag bites back and is spent for good
        if eater.components.sanity ~= nil then
            eater.components.sanity:DoDelta(EMPTY_SANITY_PENALTY)
        end
        if eater.SoundEmitter ~= nil then
            eater.SoundEmitter:PlaySound("dontstarve/wilson/use_break")
        end
        EmoteVerySad(eater)
    end
end

local function OnSave(inst, data)
    data.uses = inst.uses
end

local function OnLoad(inst, data)
    if data ~= nil then
        inst.uses = data.uses
        RefreshEdible(inst)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("chokeobon")
    inst.AnimState:SetBuild("chokeobon")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetScale(WORLD_SCALE, WORLD_SCALE)

    inst:AddTag("cattoy")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/chokeobon.xml"

    inst:AddComponent("edible")
    inst.components.edible.foodtype = FOODTYPE.GOODIES
    inst.components.edible.oneaten = OnEaten
    inst.RefreshEdible = RefreshEdible
    RefreshEdible(inst)

    inst:AddComponent("tradable")

    inst:ListenForEvent("onputininventory", RollUses)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("chokeobon", fn, assets)
