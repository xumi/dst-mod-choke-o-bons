-- Scatters a fixed number of Choke-o-Bons across the surface world, once,
-- the first time the world loads with the mod enabled.
local Scatter = Class(function(self, inst)
    self.inst = inst
    self.done = false
    self.amount = 0 -- set by modmain right after the component is added

    -- Wait a tick so OnLoad has had the chance to restore `done`
    inst:DoTaskInTime(0, function() self:Run() end)
end)

function Scatter:Run()
    if self.done then
        print("[chokeobon] scatter already done for this world, skipping")
        return
    end
    self.done = true

    local map = TheWorld.Map
    local width, height = map:GetSize()
    local wanted = self.amount
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

    -- Shows up in server_log.txt, to check what happened when the world loaded
    print(string.format("[chokeobon] scattered %d of %d (map %dx%d tiles, %d tries)", placed, wanted, width, height, tries))
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
