-- Scatters a fixed number of Choke-o-Bons across the surface world, once,
-- the first time the world loads with the mod enabled.
local function ScatterAmount()
    return TUNING.CHOKEOBON_MAP_AMOUNT or 0
end

local Scatter = Class(function(self, inst)
    self.inst = inst
    self.done = false

    -- Wait a tick so OnLoad has had the chance to restore `done`
    inst:DoTaskInTime(0, function() self:Run() end)
end)

function Scatter:Run()
    if self.done then
        return
    end
    self.done = true

    local map = TheWorld.Map
    local width, height = map:GetSize()
    local wanted = ScatterAmount()
    local placed, tries = 0, 0

    while placed < wanted and tries < wanted * 500 do
        tries = tries + 1
        local x = (math.random() * width - width / 2) * TILE_SCALE
        local z = (math.random() * height - height / 2) * TILE_SCALE
        if map:IsAboveGroundAtPoint(x, 0, z) and map:IsPassableAtPoint(x, 0, z) then
            SpawnPrefab("chokeobon").Transform:SetPosition(x, 0, z)
            placed = placed + 1
        end
    end
end

function Scatter:OnSave()
    return { done = self.done }
end

function Scatter:OnLoad(data)
    if data ~= nil then
        self.done = data.done == true
    end
end

return Scatter
