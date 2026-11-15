local assets =
{
    Asset("ANIM", "anim/chokeobon.zip"),
}

local MIN_USES = 1
local MAX_USES = 8

local HEALTH = -1
local HUNGER = 1
local SANITY = 20
local EMPTY_SANITY_PENALTY = -100
local DEFAULT_EMPTY_LINE = "Empty. I feel so empty too."

-- What each character says on eating an empty bag, keyed by prefab name.
-- Anyone not listed (such as modded characters) gets DEFAULT_EMPTY_LINE.
local EMPTY_LINES =
{
    wilson = "Empty. A hollow result. I feel the same.",
    willow = "Nothing left. Not even for me to burn... or to feel.",
    wolfgang = "Bag is empty. Wolfgang is empty too. Wolfgang is sad.",
    wendy = "Empty, like everything. At least it understands me.",
    wx78 = "CONTAINER EMPTY. INTERNAL EMPTINESS ALSO DETECTED.",
    wickerbottom = "Empty. How very apt. I feel quite hollow myself.",
    woodie = "Empty as a hollow log, eh. Same goes for my insides.",
    wes = "...",
    waxwell = "Empty. How fitting. I know the feeling well.",
    wathgrithr = "An empty vessel! As hollow as a fallen hero's hall.",
    webber = "Aww, it's all gone. We feel empty too.",
    winona = "Nothing left in the bag. Nothing left in me either. Better fix that.",
    warly = "Quel dommage... an empty pantry is a sorry sight. My heart is a bare larder.",
    walter = "Woby, it's empty. I feel empty too.",
    wortox = "Hyuyu... empty. Even an imp can feel hollow.",
    wormwood = "Empty. Wormwood empty too. Sad leaves.",
    wurt = "Flort... empty. Wurt feel empty too.",
    wanda = "Empty. Just like all the time I've lost.",
}

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

-- Same path scheme the game uses for character voices (SGwilson.lua), e.g.
-- "dontstarve/characters/wilson/hurt"
local function VoicePath(doer, event)
    return (doer.talker_path_override or "dontstarve/characters/")..(doer.soundsname or doer.prefab).."/"..event
end

-- These mirror the game's own "cheer" and "sad" emotes (emotes.lua). The emote state plays the
-- character's emote voice by itself (and keeps mimes silent) when no `sound` is given.
-- If a `sound` is given it must be a sound path string; `true` crashes the server.
local function EmoteHappy(doer)
    Emote(doer, { anim = "emoteXL_happycheer" })
end

-- The game's sad emote (with tears) plus the character's pained voice
local function EmoteVerySad(doer)
    Emote(doer, { anim = "emoteXL_sad", fx = "tears", fxdelay = 17 * FRAMES })
    doer:DoTaskInTime(0.2, function()
        if doer:IsValid() and doer.SoundEmitter ~= nil and not doer:HasTag("mime") then
            doer.SoundEmitter:PlaySound(VoicePath(doer, "hurt"))
        end
    end)
end

-- Called after the stats were applied (Edible:OnEaten). Whether the bag is then removed is
-- decided by edible.handleremovefn below, so a bag with treats left stays the same item.
local function OnEaten(inst, eater)
    RollUses(inst)

    if inst.uses > 0 then
        inst.uses = inst.uses - 1
        RefreshEdible(inst)
        EmoteHappy(eater)
    else
        -- An empty bag bites back and is spent for good
        inst._spent = true
        if eater.components.sanity ~= nil then
            eater.components.sanity:DoDelta(EMPTY_SANITY_PENALTY)
        end
        if eater.SoundEmitter ~= nil then
            eater.SoundEmitter:PlaySound("dontstarve/wilson/use_break")
        end
        EmoteVerySad(eater)
        eater:DoTaskInTime(0.4, function()
            if eater:IsValid() and eater.components.talker ~= nil then
                eater.components.talker:Say(EMPTY_LINES[eater.prefab] or DEFAULT_EMPTY_LINE)
            end
        end)
    end
end

-- Eater calls this instead of removing the food (see Edible:HandleEatRemove)
local function HandleEatRemove(inst)
    if inst._spent then
        inst:Remove()
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

    inst:AddTag("cattoy")
    -- Warly only eats foods tagged "preparedfood" or "pre-preparedfood" (Eater:PrefersToEat).
    -- The game's candy uses the second one, which nothing else in the game reads.
    inst:AddTag("pre-preparedfood")

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
    inst.components.edible.handleremovefn = HandleEatRemove
    RefreshEdible(inst)

    inst:AddComponent("tradable")

    inst:ListenForEvent("onputininventory", RollUses)

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("chokeobon", fn, assets)
