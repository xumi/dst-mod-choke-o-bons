-- Runs in the world generation environment, where room hooks are available.
local DENSITY = GetModConfigData("world_density")

-- Sprinkle a few across common background rooms.
for _, room in ipairs({ "BGGrass", "BGForest", "BGDeciduous", "BGSavanna", "BGRocky", "BGMarsh" }) do
    AddRoomPreInit(room, function(r)
        r.contents.distributeprefabs = r.contents.distributeprefabs or {}
        r.contents.distributeprefabs.chokeobon = DENSITY
    end)
end
