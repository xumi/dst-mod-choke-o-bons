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

-- The number of uses is rolled once, the first time the item is picked up,
-- and is never shown to the player.
local function RollUses(inst)
    if inst.uses == nil then
        inst.uses = math.random(MIN_USES, MAX_USES)
    end
end

-- The emote is pushed on the next tick so it isn't swallowed by the use action's own state.
local function Emote(doer, data)
    doer:DoTaskInTime(0.2, function()
        if doer:IsValid() and doer.sg ~= nil and not doer.sg:HasStateTag("busy") then
            doer:PushEvent("emote", data)
        end
    end)
end

local function EmoteHappy(doer)
    Emote(doer, { anim = "emoteXL_happycheer", sound = true })
end

-- Sad animation plus the character's own pained voice
local function EmoteVerySad(doer)
    Emote(doer, { anim = "emoteXL_sad", sound = true })
    doer:DoTaskInTime(0.2, function()
        if doer:IsValid() and doer.SoundEmitter ~= nil then
            doer.SoundEmitter:PlaySound((doer.talker_path_override or "dontstarve/characters/")..(doer.soundsname or doer.prefab).."/hurt")
        end
    end)
end

local function OnUse(inst)
    local doer = inst.components.inventoryitem.owner
    -- Let the item be used again next time
    inst.components.useableitem.inuse = false

    if doer == nil or not doer:HasTag("player") then
        return false
    end

    RollUses(inst)

    if inst.uses > 0 then
        inst.uses = inst.uses - 1
        if doer.components.health ~= nil then doer.components.health:DoDelta(HEALTH, nil, inst.prefab) end
        if doer.components.hunger ~= nil then doer.components.hunger:DoDelta(HUNGER) end
        if doer.components.sanity ~= nil then doer.components.sanity:DoDelta(SANITY) end
        EmoteHappy(doer)
    else
        if doer.components.sanity ~= nil then doer.components.sanity:DoDelta(EMPTY_SANITY_PENALTY) end
        EmoteVerySad(doer)
        -- The empty bag is spent for good once it has bitten back
        if doer.SoundEmitter ~= nil then
            doer.SoundEmitter:PlaySound("dontstarve/wilson/use_break")
        end
        inst:Remove()
    end

    return true
end

local function OnSave(inst, data)
    data.uses = inst.uses
end

local function OnLoad(inst, data)
    if data ~= nil then
        inst.uses = data.uses
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

    inst:AddComponent("useableitem")
    inst.components.useableitem:SetOnUseFn(OnUse)

    inst:AddComponent("tradable")

    inst:ListenForEvent("onputininventory", RollUses)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("chokeobon", fn, assets)
